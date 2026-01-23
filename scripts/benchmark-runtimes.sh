#!/usr/bin/env bash
set -euo pipefail

readonly ITERATIONS=${ITERATIONS:-10}

echo "# Gemini CLI Runtime Benchmark"
echo ""
echo "Comparing Node.js and Bun performance for Gemini CLI"
echo "Iterations: $ITERATIONS"
echo ""

if [ ! -d "result" ]; then
    echo "Building packages..."
    nix build .#gemini-cli -o result-node
    nix build .#gemini-cli-bun -o result-bun
else
    echo "Using existing builds..."
    if [ ! -L "result-node" ]; then
        nix build .#gemini-cli -o result-node
    fi
    if [ ! -L "result-bun" ]; then
        nix build .#gemini-cli-bun -o result-bun
    fi
fi

NODE_BIN="./result-node/bin/gemini"
BUN_BIN="./result-bun/bin/gemini-bun"

if [ ! -x "$NODE_BIN" ] || [ ! -x "$BUN_BIN" ]; then
    echo "Error: Binaries not found. Please build first."
    exit 1
fi

echo "## Startup Time (--version)"
echo ""

measure_startup() {
    local bin="$1"
    local name="$2"
    local total=0

    for i in $(seq 1 $ITERATIONS); do
        start=$(date +%s%N)
        $bin --version > /dev/null 2>&1 || true
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        total=$((total + elapsed))
    done

    avg=$((total / ITERATIONS))
    echo "- $name: ${avg}ms (avg over $ITERATIONS runs)"
}

measure_startup "$NODE_BIN" "Node.js"
measure_startup "$BUN_BIN" "Bun"

echo ""
echo "## Memory Usage (--help)"
echo ""

measure_memory() {
    local bin="$1"
    local name="$2"

    if command -v /usr/bin/time > /dev/null 2>&1; then
        mem=$(/usr/bin/time -l $bin --help 2>&1 | grep "maximum resident set size" | awk '{print $1}' || echo "N/A")
        if [ "$mem" != "N/A" ] && [ -n "$mem" ]; then
            mem_mb=$((mem / 1024 / 1024))
            echo "- $name: ${mem_mb}MB"
        else
            echo "- $name: N/A"
        fi
    else
        echo "- $name: N/A (time command not available)"
    fi
}

measure_memory "$NODE_BIN" "Node.js"
measure_memory "$BUN_BIN" "Bun"

echo ""
echo "## Sustained Operations (--help x $ITERATIONS)"
echo ""

measure_sustained() {
    local bin="$1"
    local name="$2"

    start=$(date +%s%N)
    for i in $(seq 1 $ITERATIONS); do
        $bin --help > /dev/null 2>&1 || true
    done
    end=$(date +%s%N)
    elapsed=$(( (end - start) / 1000000 ))
    avg=$((elapsed / ITERATIONS))
    echo "- $name: ${elapsed}ms total, ${avg}ms avg per operation"
}

measure_sustained "$NODE_BIN" "Node.js"
measure_sustained "$BUN_BIN" "Bun"

echo ""
echo "Benchmark complete!"

if [ "${OUTPUT_FILE:-}" != "" ]; then
    echo ""
    echo "Saving results to $OUTPUT_FILE..."
    {
        echo "# Benchmark Results"
        echo ""
        echo "Date: $(date)"
        echo "Iterations: $ITERATIONS"
        echo ""
    } > "$OUTPUT_FILE"
fi
