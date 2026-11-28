#!/usr/bin/env python3
"""Preview the NVIDIA driver files needed by kind; write them only with --apply."""

import argparse
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile


def output(*command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(result.stderr)
    return result.stdout.strip()


def require(condition, message):
    if not condition:
        raise SystemExit(message)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--apply", action="store_true", help="Modify the existing kind node (requires approval).")
args = parser.parse_args()
node = "kubernetes-ai-iac-control-plane"

require("version 1.20.2" in output("nvidia-ctk", "--version"), "Expected NVIDIA Container Toolkit 1.20.2")
require(output("nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader") == "580.178.04", "Expected one GPU with driver 580.178.04")
require(output("docker", "inspect", "--format", '{{ index .Config.Labels "io.x-k8s.kind.cluster" }}', node) == "kubernetes-ai-iac", "Unexpected kind cluster")
require("enable_cdi = true" in output("docker", "exec", node, "containerd", "config", "dump"), "containerd CDI must already be enabled")
for device in ("/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-uvm"):
    subprocess.run(["docker", "exec", node, "test", "-c", device], check=True)

# Use NVIDIA's own inventory, retaining only CUDA compute and NVML libraries.
spec = json.loads(output("nvidia-ctk", "--quiet", "cdi", "generate", "--format=json"))
edits = [spec.get("containerEdits", {})] + [d.get("containerEdits", {}) for d in spec["devices"]]
prefixes = ("libcuda.", "libcudadebugger.", "libnvidia-ml.", "libnvidia-ptxjitcompiler.", "libnvidia-nvvm", "libnvidia-gpucomp.")
files = {
    Path(m["hostPath"]): "usr/local/lib/" + Path(m["hostPath"]).name
    for edit in edits for m in edit.get("mounts", [])
    if Path(m["hostPath"]).name.startswith(prefixes) and Path(m["hostPath"]).is_file()
}
for required in ("libcuda.", "libnvidia-ml.", "libnvidia-ptxjitcompiler."):
    require(any(p.name.startswith(required) for p in files), "Missing driver library: " + required)
files[Path("/usr/bin/nvidia-smi")] = "usr/local/bin/nvidia-smi"
files[Path("/usr/bin/nvidia-cdi-hook")] = "usr/bin/nvidia-cdi-hook"
for source in files:
    require(source.is_file(), "Missing NVIDIA file: " + str(source))

print(f"{node}: {len(files)} NVIDIA files, {sum(p.stat().st_size for p in files) // (1024 * 1024)} MiB")
for source, destination in sorted(files.items()):
    print(f"  {source} -> /{destination}")
if not args.apply:
    print("Preview only. After approval: python3 ai/prepare-kind-gpu.py --apply")
    raise SystemExit(0)

# Keep this separate from Terraform: driver updates must not recreate kind.
with tempfile.TemporaryFile() as bundle:
    with tarfile.open(fileobj=bundle, mode="w", dereference=True) as archive:
        for source, destination in sorted(files.items()):
            archive.add(source, arcname=destination, recursive=False)
    bundle.seek(0)
    subprocess.run(["docker", "exec", "-i", node, "tar", "-xpf", "-", "-C", "/"], stdin=bundle, check=True)
subprocess.run(["docker", "exec", node, "ldconfig"], check=True)
subprocess.run(["docker", "exec", node, "nvidia-smi", "--query-gpu=name,driver_version", "--format=csv,noheader"], check=True)
print("Node prepared. The NVIDIA device plugin will generate its CDI specification in /var/run/cdi.")
