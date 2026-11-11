#!/usr/bin/env python3
"""Decode micro-benchmark: single stream, then 4- and 8-way concurrent.

    NINFER_URL=http://localhost:30000/v1 NINFER_MODEL=qwen3.8-27b python3 bench.py
"""
import json, os, threading, time, urllib.request

BASE = os.environ.get("NINFER_URL", "http://localhost:30000/v1")
MODEL = os.environ.get("NINFER_MODEL", "qwen3.8-27b")


def req(n=256):
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": "Write a 200-word paragraph about the ocean."}],
        "max_tokens": n,
    }).encode()
    rq = urllib.request.Request(BASE + "/chat/completions", data=body,
                                headers={"Content-Type": "application/json"})
    t = time.time()
    r = urllib.request.urlopen(rq, timeout=600)
    d = json.load(r)
    return time.time() - t, d["usage"].get("completion_tokens", 0)


def run(n):
    res = [None] * n

    def w(i):
        res[i] = req()

    ts = [threading.Thread(target=w, args=(i,)) for i in range(n)]
    t0 = time.time()
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    dt = time.time() - t0
    agg = sum(x[1] for x in res if x)
    print(f"{n:>2} concurrent: {agg} tok in {dt:.1f}s = {agg / dt:.0f} t/s agg = {agg / dt / n:.0f}/session")


if __name__ == "__main__":
    dt, tok = req()
    print(f" 1 concurrent: {tok} tok in {dt:.1f}s = {tok / dt:.0f} t/s")
    for n in (4, 8):
        run(n)
