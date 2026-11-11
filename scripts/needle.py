#!/usr/bin/env python3
"""Needle-in-a-haystack check at long contexts (validates YaRN past the 262K native window).

    python3 needle.py                # 300K, 650K, 900K
    python3 needle.py 300000 650000  # explicit sizes

Give `--max_tokens` room: with thinking enabled the answer needs more than the
code itself, so a short cap returns empty content on a correct model.
"""
import json, os, sys, time, urllib.request

BASE = os.environ.get("NINFER_URL", "http://localhost:30000/v1")
MODEL = os.environ.get("NINFER_MODEL", "qwen3.8-27b")
CODE = "CORAL-FALCON-9271"


def gen(target):
    block = ("This is a neutral filler sentence for testing long context "
             "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu. ")
    n = target // 30
    half = n // 2
    return block * half + f" THE SECRET CODE IS {CODE}. " + block * (n - half)


def ask(prompt):
    body = json.dumps({"model": MODEL, "messages": [{"role": "user", "content": prompt}],
                       "max_tokens": 384}).encode()
    rq = urllib.request.Request(BASE + "/chat/completions", data=body,
                                headers={"Content-Type": "application/json"})
    t = time.time()
    r = urllib.request.urlopen(rq, timeout=2400)
    return time.time() - t, json.load(r)


if __name__ == "__main__":
    sizes = [int(x) for x in sys.argv[1:]] or [300_000, 650_000, 900_000]
    for s in sizes:
        dt, d = ask(gen(s) + " What is the secret code? Reply with only the code.")
        c = (d["choices"][0]["message"].get("content") or "").strip()
        print(f"{s // 1000}K: {d['usage']['prompt_tokens'] // 1000}K tok | {dt:.0f}s | OK={CODE in c.upper()}")
