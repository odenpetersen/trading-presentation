import glob, os, time, subprocess, multiprocessing as mp

ROOT = os.path.dirname(os.path.abspath(__file__))
PCAPS = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps'))
OUT = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps_parsed'))
STABLE_S = 90
WORKERS = 3

def discover():
	return glob.glob(os.path.join(PCAPS, '*.pcap.zst')) + glob.glob(os.path.join(PCAPS, '*', '*.pcap.zst'))

def stem(fn):
	return os.path.basename(fn).replace('.pcap.zst', '')

def stable(fn):
	return time.time() - os.path.getmtime(fn) > STABLE_S

def done(fn):
	return os.path.exists(os.path.join(OUT, stem(fn), '_DONE'))

def worker(fn):
	outdir = os.path.join(OUT, stem(fn))
	os.makedirs(outdir, exist_ok=True)
	r = subprocess.run(['python3', os.path.join(ROOT, 'extract.py'), fn, outdir])
	return fn, r.returncode

def main():
	os.makedirs(OUT, exist_ok=True)
	while True:
		files = discover()
		pending = [f for f in files if stable(f) and not done(f)]
		if pending:
			print(f'processing {len(pending)} file(s)', flush=True)
			with mp.Pool(WORKERS) as pool:
				for fn, rc in pool.imap_unordered(worker, pending):
					print('finished', fn, 'rc', rc, flush=True)
		growing = [f for f in files if not stable(f)]
		all_done = all(done(f) for f in files)
		if all_done and not growing:
			print('all files processed', flush=True)
			break
		print(f'waiting: {len(growing)} still growing, sleeping 60s', flush=True)
		time.sleep(60)

if __name__ == '__main__':
	main()
