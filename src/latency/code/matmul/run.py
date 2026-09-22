#!/usr/bin/env python3
import csv
import os
import subprocess
import sys

import matplotlib.pyplot as plt


SIZES = [100, 150, 200, 250, 300, 400, 500, 600, 700, 800]

REPEATS = 3
FLAMEGRAPH_N = 200
FLAMEGRAPH_REPETITIONS = 20

EVENTS = [
    "task-clock",
    "cycles",
    "instructions",
    "cache-references",
    "cache-misses",
]

VERSION_NAMES = {
    1: "list / fragmented allocator",
    2: "list / standard allocator",
    3: "vector / no reserve",
    4: "vector / reserve",
    5: "vector / reserve + good loops",
}

PERF = os.path.expanduser("~/bin/perf")


# -----------------------------------------------------------------------------
# perf stat
# -----------------------------------------------------------------------------

def run_perf(version, n):
    command = [
        PERF,
        "stat",
        "-x,",
        "-r", str(REPEATS),
        "-e", ",".join(EVENTS),
        "--",
        f"./matmul{version}",
        str(n),
        "1",
    ]

    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )

    values = {}

    for line in result.stderr.splitlines():
        fields = line.split(",")

        if len(fields) < 3:
            continue

        value = fields[0].strip()
        event = fields[2].strip()

        if event not in EVENTS:
            continue

        try:
            values[event] = float(value)
        except ValueError:
            pass

    return values


# -----------------------------------------------------------------------------
# Benchmark all versions
# -----------------------------------------------------------------------------

def run_benchmarks():
    rows = []

    for version in range(1, 6):
        print(f"\n=== Version {version}: {VERSION_NAMES[version]} ===")

        for n in SIZES:
            print(n, flush=True)

            values = run_perf(version, n)

            row = {
                "version": version,
                "name": VERSION_NAMES[version],
                "N": n,
            }

            row.update(values)
            rows.append(row)

    return rows


# -----------------------------------------------------------------------------
# CSV
# -----------------------------------------------------------------------------

def write_csv(rows):
    with open("results.csv", "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "version",
                "name",
                "N",
                *EVENTS,
            ],
        )

        writer.writeheader()
        writer.writerows(rows)


# -----------------------------------------------------------------------------
# Plotting
# -----------------------------------------------------------------------------

def make_plot(rows, event, ylabel, filename):
    plt.figure()

    for version in range(1, 6):
        version_rows = [
            row
            for row in rows
            if row["version"] == version and event in row
        ]

        xs = [row["N"] for row in version_rows]
        ys = [row[event] for row in version_rows]

        plt.plot(
            xs,
            ys,
            marker="o",
            label=VERSION_NAMES[version],
        )

    plt.xlabel("Matrix size N")
    plt.ylabel(ylabel)
    plt.title(ylabel)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(filename, dpi=150)
    plt.close()


def make_plots(rows):
    make_plot(
        rows,
        "task-clock",
        "CPU time (ms)",
        "time.png",
    )

    make_plot(
        rows,
        "cycles",
        "cycles",
        "cycles.png",
    )

    make_plot(
        rows,
        "cache-misses",
        "cache misses",
        "cache_misses.png",
    )


# -----------------------------------------------------------------------------
# Native perf flamegraph
# -----------------------------------------------------------------------------

def make_flamegraph(version):
    n = FLAMEGRAPH_N
    repetitions = FLAMEGRAPH_REPETITIONS

    print(
        f"=== Flame graph: version {version}, "
        f"N={n}, repetitions={repetitions} ==="
    )

    # perf script defaults to perf.data, so always use that filename.
    try:
        os.remove("perf.data")
    except FileNotFoundError:
        pass

    # Record samples with call stacks.
    subprocess.run([
        PERF,
        "record",
        "-F", "999",
        "--call-graph", "dwarf",
        "--",
        f"./matmul{version}",
        str(n),
        str(repetitions),
    ], check=True)

    # Generate the native perf flamegraph.
    subprocess.run([
        PERF,
        "script",
        "report",
        "flamegraph",
    ], check=True)

    output = f"flamegraph{version}.html"

    try:
        os.remove(output)
    except FileNotFoundError:
        pass

    os.rename("flamegraph.html", output)

    os.remove("perf.data")

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    flamegraph_only = "--flamegraph" in sys.argv

    if flamegraph_only:
        for version in range(1, 6):
            make_flamegraph(version)

        return

    rows = run_benchmarks()

    write_csv(rows)
    make_plots(rows)

    print("\nResults written to results.csv")
    print("Plots written to:")
    print("  time.png")
    print("  cycles.png")
    print("  cache_misses.png")


if __name__ == "__main__":
    main()
