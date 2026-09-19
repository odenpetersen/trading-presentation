#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
ENV_FILE="$REPO_ROOT/.env"
STATE_FILE="$SCRIPT_DIR/state.json"

[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

TAG_PROJECT=latency-demo
INSTANCE_TYPE=${INSTANCE_TYPE:-t3.micro}
ROLES="me gw-a gw-b strat-a strat-b"

die() { echo "error: $*" >&2; exit 1; }
require_state() { [ -f "$STATE_FILE" ] || die "no $STATE_FILE - run 'up' first"; }

delete_sg_retry() {
	local sg="$1"
	for i in $(seq 1 10); do
		aws ec2 delete-security-group --group-id "$sg" 2>/dev/null && return 0
		sleep 5
	done
	echo "warning: could not delete SG $sg (still in use?) - retry manually or run 'sweep'" >&2
}

cmd_up() {
	[ -f "$STATE_FILE" ] && die "state file exists ($STATE_FILE) - run 'down' first, or delete it if stale"

	local run_id my_ip vpc_id subnet_id ami_id key_name sg_id
	run_id="$(date +%s)-$RANDOM"
	my_ip="$(curl -s https://checkip.amazonaws.com)"
	vpc_id="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
	subnet_id="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$vpc_id" --query 'Subnets[0].SubnetId' --output text)"
	ami_id="$(aws ec2 describe-images --owners 099720109477 \
		--filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" \
		--query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)"

	echo "run_id=$run_id vpc=$vpc_id subnet=$subnet_id ami=$ami_id my_ip=$my_ip"

	key_name="latency-demo-$run_id"
	aws ec2 create-key-pair --key-name "$key_name" --query 'KeyMaterial' --output text > "$SCRIPT_DIR/$key_name.pem"
	chmod 600 "$SCRIPT_DIR/$key_name.pem"
	local key_id
	key_id="$(aws ec2 describe-key-pairs --key-names "$key_name" --query 'KeyPairs[0].KeyPairId' --output text)"
	aws ec2 create-tags --resources "$key_id" --tags Key=Project,Value=$TAG_PROJECT Key=RunId,Value="$run_id" >/dev/null

	sg_id="$(aws ec2 create-security-group --group-name "latency-demo-$run_id" --description "latency demo $run_id" --vpc-id "$vpc_id" --query 'GroupId' --output text)"
	aws ec2 create-tags --resources "$sg_id" --tags Key=Project,Value=$TAG_PROJECT Key=RunId,Value="$run_id" >/dev/null
	aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 0-65535 --source-group "$sg_id" >/dev/null
	aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 22 --cidr "$my_ip/32" >/dev/null
	aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 17000-19999 --cidr "$my_ip/32" >/dev/null

	declare -A iid
	for role in $ROLES; do
		iid[$role]="$(aws ec2 run-instances \
			--image-id "$ami_id" --instance-type "$INSTANCE_TYPE" \
			--key-name "$key_name" --security-group-ids "$sg_id" --subnet-id "$subnet_id" \
			--associate-public-ip-address \
			--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=latency-demo-$role},{Key=Project,Value=$TAG_PROJECT},{Key=RunId,Value=$run_id},{Key=Role,Value=$role}]" \
			--query 'Instances[0].InstanceId' --output text)"
		echo "launched $role -> ${iid[$role]}"
	done

	# state.json written before waiting on anything: if a wait below times out,
	# 'down'/'sweep' must still be able to find and terminate these instances.
	jq -n \
		--arg run_id "$run_id" --arg region "${AWS_DEFAULT_REGION:-}" --arg vpc "$vpc_id" --arg subnet "$subnet_id" \
		--arg sg "$sg_id" --arg key "$key_name" --arg my_ip "$my_ip" \
		--arg me "${iid[me]}" --arg gwa "${iid[gw-a]}" --arg gwb "${iid[gw-b]}" \
		--arg sa "${iid[strat-a]}" --arg sb "${iid[strat-b]}" \
		'{run_id:$run_id, region:$region, vpc_id:$vpc, subnet_id:$subnet, sg_id:$sg, key_name:$key, my_ip:$my_ip,
		  instances:{me:$me,"gw-a":$gwa,"gw-b":$gwb,"strat-a":$sa,"strat-b":$sb}}' > "$STATE_FILE"
	echo "state written to $STATE_FILE (before waits, so 'down'/'sweep' work even if a wait below times out)"

	echo "waiting for instances to be running..."
	aws ec2 wait instance-running --instance-ids "${iid[me]}" "${iid[gw-a]}" "${iid[gw-b]}" "${iid[strat-a]}" "${iid[strat-b]}" \
		|| echo "warning: wait timed out, instances may still be launching - check 'status'"

	echo "waiting for SSH..."
	for role in $ROLES; do
		local ip
		ip="$(aws ec2 describe-instances --instance-ids "${iid[$role]}" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
		for i in $(seq 1 30); do
			ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -i "$SCRIPT_DIR/$key_name.pem" ubuntu@"$ip" true 2>/dev/null && break
			sleep 5
		done
	done

	echo "up complete"
	cmd_status
}

cmd_push() {
	require_state
	local key_name pem
	key_name="$(jq -r .key_name "$STATE_FILE")"
	pem="$SCRIPT_DIR/$key_name.pem"

	declare -A pub priv
	for role in $ROLES; do
		local iid
		iid="$(jq -r ".instances[\"$role\"]" "$STATE_FILE")"
		pub[$role]="$(aws ec2 describe-instances --instance-ids "$iid" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
		priv[$role]="$(aws ec2 describe-instances --instance-ids "$iid" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
	done

	for role in $ROLES; do
		local ip="${pub[$role]}"
		echo "pushing to $role ($ip)..."
		ssh -o StrictHostKeyChecking=no -i "$pem" ubuntu@"$ip" \
			'sudo apt-get update -y -qq && sudo apt-get install -y -qq build-essential rsync python3'
		rsync -az -e "ssh -o StrictHostKeyChecking=no -i $pem" \
			--exclude '*.o' --exclude '*.out' --exclude 'infra' --exclude 'old' --exclude 'fpga' \
			"$CODE_DIR/" ubuntu@"$ip":code/
		ssh -o StrictHostKeyChecking=no -i "$pem" ubuntu@"$ip" 'cd code && make'
	done

	start_remote() {
		local role="$1" bin="$2" args="$3"
		local ip="${pub[$role]}"
		# 'cd code;' (not '&&') before the backgrounded part matters: 'cmd1 &&
		# cmd2 &' backgrounds (cmd1 && cmd2) as one compound job and the
		# wrapper shell hangs waiting on it despite disown; 'cmd1; cmd2 &'
		# backgrounds only cmd2 and returns immediately. setsid fully detaches
		# the process from the ssh session so the channel can close cleanly.
		# pkill/pgrep pattern is anchored ('^\./bin') so it matches only the
		# actual target process, not this wrapper's own cmdline (which
		# contains the literal text './bin' as part of the script it's
		# running) - unanchored, pkill was self-matching and killing its own
		# shell before it could finish.
		ssh -o StrictHostKeyChecking=no -i "$pem" ubuntu@"$ip" \
			"cd code; pkill -f '^\./$bin' 2>/dev/null; sleep 1; setsid ./$bin $args < /dev/null > ${bin}.log 2>&1 & disown; sleep 1; pgrep -f '^\./$bin' >/dev/null && echo started || echo FAILED"
	}

	echo "starting me..."
	start_remote me a.out ""
	sleep 1
	echo "starting gateways..."
	start_remote gw-a gateway.out "18000 18001 ${priv[me]} 17000"
	start_remote gw-b gateway.out "18000 18001 ${priv[me]} 17000"
	sleep 1
	echo "starting strategies..."
	start_remote strat-a strategy.out "19000 100 101 ${priv[me]} 17001 ${priv[gw-a]} 18000 ${priv[gw-b]} 18000"
	start_remote strat-b strategy.out "19000 200 201 ${priv[me]} 17001 ${priv[gw-a]} 18000 ${priv[gw-b]} 18000"

	echo "push complete."
	echo "ME public IP (for local dashboard/binance adapter): ${pub[me]}"
	echo "e.g. python3 dashboard_backend.py ${pub[me]} 17001 17003 ${pub[gw-a]} 18001 ${pub[gw-b]} 18001 ${pub[strat-a]} 19000 ${pub[strat-b]} 19000"
	echo "e.g. python3 binance_adapter.py ${pub[me]} 17002"
}

cmd_down() {
	require_state
	local iids sg_id key_name
	iids="$(jq -r '.instances | to_entries[] | .value' "$STATE_FILE" | tr '\n' ' ')"
	sg_id="$(jq -r .sg_id "$STATE_FILE")"
	key_name="$(jq -r .key_name "$STATE_FILE")"

	if [ -n "$(echo "$iids" | tr -d '[:space:]')" ]; then
		echo "terminating instances: $iids"
		aws ec2 terminate-instances --instance-ids $iids >/dev/null || true
		aws ec2 wait instance-terminated --instance-ids $iids \
			|| echo "warning: wait timed out, continuing teardown anyway (check 'status')"
	fi

	echo "deleting security group $sg_id"
	delete_sg_retry "$sg_id"

	echo "deleting key pair $key_name"
	aws ec2 delete-key-pair --key-name "$key_name" || true
	rm -f "$SCRIPT_DIR/$key_name.pem"

	rm -f "$STATE_FILE"
	echo "down complete"
}

cmd_sweep() {
	echo "sweeping all resources tagged Project=$TAG_PROJECT (independent of $STATE_FILE)..."

	local iids
	iids="$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
		--query 'Reservations[].Instances[].InstanceId' --output text)"
	if [ -n "$iids" ]; then
		echo "terminating: $iids"
		aws ec2 terminate-instances --instance-ids $iids >/dev/null || true
		aws ec2 wait instance-terminated --instance-ids $iids \
			|| echo "warning: wait timed out, continuing sweep anyway (check 'status')"
	fi

	local sgids
	sgids="$(aws ec2 describe-security-groups --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'SecurityGroups[].GroupId' --output text)"
	for sg in $sgids; do
		echo "deleting sg $sg"
		delete_sg_retry "$sg"
	done

	local keys
	keys="$(aws ec2 describe-key-pairs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'KeyPairs[].KeyName' --output text)"
	for k in $keys; do
		echo "deleting key pair $k"
		aws ec2 delete-key-pair --key-name "$k" || true
		rm -f "$SCRIPT_DIR/$k.pem"
	done

	rm -f "$STATE_FILE"
	echo "sweep complete"
}

cmd_status() {
	echo "instances tagged Project=$TAG_PROJECT:"
	aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
		--query 'Reservations[].Instances[].{Role:Tags[?Key==`Role`]|[0].Value,Id:InstanceId,State:State.Name,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress}' --output table
	echo "security groups:"
	aws ec2 describe-security-groups --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'SecurityGroups[].{Id:GroupId,Name:GroupName}' --output table
	echo "key pairs:"
	aws ec2 describe-key-pairs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'KeyPairs[].KeyName' --output table
	echo "(running instances cost money even when idle - 'down' or 'sweep' when done)"
}

case "${1:-}" in
	up) cmd_up ;;
	push) cmd_push ;;
	down) cmd_down ;;
	sweep) cmd_sweep ;;
	status) cmd_status ;;
	*) die "usage: $0 {up|push|down|sweep|status}" ;;
esac
