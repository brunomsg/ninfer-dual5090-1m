#!/bin/bash
# build-test.sh v2 — run on dualrtxsrv00 as userpro.
# 1) stop service, 2) sync fork master + build 120a, 3) baseline,
# 4) flag A/B matrix (each = restart + bench), 5) needle accuracy for the KV-dtype change,
# 6) leave the best config running.
set -u
P='Oit!2024-'
R=~/ninfer-all
FORKDIR=~/ninfer-dual5090-1m
FORK="https://github.com/brunomsg/ninfer-dual5090-1m.git"
SVC=/etc/systemd/system/ninfer.service

bench() { python3 "$FORKDIR/scripts/bench.py" 2>&1; }
needle() { python3 "$FORKDIR/scripts/needle.py" 300000 2>&1; }

echo "[0] clone do fork"
[ -d "$FORKDIR" ] || git clone --depth 1 "$FORK" "$FORKDIR"
cd "$FORKDIR" && git pull --ff-only 2>/dev/null

echo "[1] stop ninfer"
echo "$P" | sudo -S -p "" systemctl stop ninfer.service
sync

echo "[2] sync fork master + build 120a"
cd "$R" || exit 1
git stash push -m "pre-fork local edits" 2>/dev/null && echo "(stashed)" || true
git remote get-url fork >/dev/null 2>&1 || git remote add fork "$FORK"
git fetch fork master
git checkout -B fork-master fork/master
git log --oneline -3
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_ARCHITECTURES=120a 2>&1 | tail -2
cmake --build build -j24 2>&1 | tail -3
ls -la build/apps/ninfer-serve

restart() {
  echo "$P" | sudo -S -p "" sed -i "$1" "$SVC"
  echo "$P" | sudo -S -p "" systemctl daemon-reload
  echo "$P" | sudo -S -p "" systemctl restart ninfer.service
  sleep 75
  echo -n "active: "; echo "$P" | sudo -S -p "" systemctl is-active ninfer.service
  echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 300 2>/dev/null | grep -E "capacity \||FATAL|out of memory" | tail -2
}

echo "[3] BASELINE: adaptive-mtp + gate129"
restart 's|--spec mtp --draft-tokens 3|--spec mtp --draft-tokens 15 --adaptive-mtp|'
bench; needle
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 10 2>/dev/null | grep "req#.*done" | tail -1

echo "[4a] T1: + --gdn-state-fp16 (halves host state images -> RAM)"
restart 's|--host-kv-mib 32768|--gdn-state-fp16 --host-kv-mib 32768|'
free -h | head -2 | tail -1
bench
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 10 2>/dev/null | grep "req#.*done" | tail -1

echo "[4b] T2: + --kv-dtype k8v4 (KV 25% menor que int8; verificar qualidade)"
restart 's|--kv-dtype int8|--kv-dtype k8v4|; s|--gdn-state-fp16 --host-kv-mib|--host-kv-mib|'
bench; needle
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 10 2>/dev/null | grep "req#.*done" | tail -1

echo "[4c] T3: --tensor-split 45,55 (GPU0 c/ cap 400W faz menos trabalho)"
restart 's|--kv-dtype k8v4|--kv-dtype int8 --tensor-split 45,55|'
bench
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 10 2>/dev/null | grep "req#.*done" | tail -1

echo "[4d] T4: --decode-rounds-per-prefill 1 (intercalar decode nos prefills concorrentes)"
restart 's|--tensor-split 45,55 |--|; s|--host-kv-mib|--decode-rounds-per-prefill 1 --host-kv-mib|'
bench
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 10 2>/dev/null | grep "req#.*done" | tail -1

echo "[5] RAM/VRAM finais"
free -h | head -2 | tail -1
nvidia-smi --query-gpu=index,memory.used,power.limit --format=csv,noheader
echo "FIM — escolher a melhor config e fixar no service"
