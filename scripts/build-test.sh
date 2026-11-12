#!/bin/bash
# build-test.sh — run on dualrtxsrv00 as userpro.
# Stops the service (frees the 32 GB pinned host KV + VRAM), rebuilds the fork's master
# (120a), restarts with the new MTP config, and re-runs the benchmark + needle suite.
set -u
P='Oit!2024-'
R=~/ninfer-all
FORK="https://github.com/brunomsg/ninfer-dual5090-1m.git"
SVC=/etc/systemd/system/ninfer.service

echo "[1/7] stop ninfer (liberta ~40 GB RAM + VRAM)"
echo "$P" | sudo -S -p "" systemctl stop ninfer.service
sync

echo "[2/7] sync fork master para a arvore de build"
cd "$R" || exit 1
git stash push -m "pre-fork local edits" 2>/dev/null && echo "(stashed local edits)" || true
git remote get-url fork >/dev/null 2>&1 || git remote add fork "$FORK"
git fetch fork master
git checkout -B fork-master fork/master
git log --oneline -4

echo "[3/7] build 120a (incremental sobre build/ existente)"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_ARCHITECTURES=120a 2>&1 | tail -3
cmake --build build -j24 2>&1 | tail -5
ls -la build/apps/ninfer-serve

echo "[4/7] atualizar service flags (MTP max) e arrancar"
echo "$P" | sudo -S -p "" sed -i 's|--spec mtp --draft-tokens 3|--spec mtp --draft-tokens 15 --adaptive-mtp|' "$SVC"
grep -oE "spec mtp[^ ]* --draft-tokens [0-9]+[^ ]* --adaptive-mtp" "$SVC" || grep -oE "spec mtp.*host-kv-mib" "$SVC"
echo "$P" | sudo -S -p "" systemctl daemon-reload
echo "$P" | sudo -S -p "" systemctl restart ninfer.service
sleep 75
echo -n "is-active: "; echo "$P" | sudo -S -p "" systemctl is-active ninfer.service
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 300 2>/dev/null | grep -E "capacity \||listening|FATAL|out of memory" | tail -4

echo "[5/7] bench (single / 4 / 8)"
python3 ~/ninfer-dual5090-1m/scripts/bench.py

echo "[6/7] needle 291K (correcao + prefill)"
python3 ~/ninfer-dual5090-1m/scripts/needle.py 300000

echo "[7/7] acceptance MTP/adaptive (ultimo req)"
echo "$P" | sudo -S -p "" journalctl -u ninfer.service --no-pager -n 20 2>/dev/null | grep -E "req#.*done" | tail -2
echo "FIM"
