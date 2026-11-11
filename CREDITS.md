# Credits

This repository is a thin, ready-to-build fork of
**[NInfer-all](https://github.com/iamwavecut/ninfer-all)** by **iamwavecut**, itself continuing
**[NInfer](https://github.com/Neroued/ninfer)** by **Neroued**. All engine work — the C++/CUDA
kernels, the `.ninfer` format, tensor parallelism, the host prefix cache, vision, MTP, the CLI and
serving — belongs to them and to the forks credited in upstream's `CONTRIBUTORS.md`. Please direct
engine questions and improvements upstream.

## Lineage the recipe relies on

| Capability | Origin |
|---|---|
| NInfer engine, `.ninfer` artifacts, serving | Neroued/ninfer → iamwavecut/ninfer-all |
| Tensor parallelism over two GPUs | [`wamansou/ninfer-tp2-1m`](https://github.com/wamansou/ninfer-tp2-1m) |
| Host-RAM context/prefix cache | [`gzenz/ninfer`](https://github.com/gzenz/ninfer) lineage |
| Model artifacts (GSQ-RCO IQ3_S) | WaveCut / [ISTA-DASLab](https://huggingface.co/ISTA-DASLab) |

## What this fork adds

- **`fix(rope)`: YaRN over 12/2 head shares for tensor parallelism** — the rope dispatch only
  instantiated the 24/4 and 16/2 Text head geometries, so `--rope-yarn` plus `--tensor-parallel`
  aborted. Submitted upstream as [PR #327](https://github.com/iamwavecut/ninfer-all/pull/327).
- **This dual-5090 1M recipe, benchmarks and needle validation** (README, `configs/`, `scripts/`).

## Licenses

NInfer's source is licensed under Apache-2.0 (see [`LICENSE`](LICENSE) and upstream `NOTICE`). The
model weights are distributed under their own terms (Qwen Community License 1.0 and the NVIDIA Open
Model License for the NVFP4 source); they are not part of this repository.
