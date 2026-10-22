#!/usr/bin/env python3
"""Run the opt-in production-bridge camera test after build-for-testing."""
import argparse
from pathlib import Path
import plistlib
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--derived-data", type=Path, required=True)
parser.add_argument("--device", required=True)
parser.add_argument("--result", type=Path, required=True)
parser.add_argument("--test", choices=["bridge", "burst", "react"], default="bridge")
args = parser.parse_args()
method = {
    "bridge": "testHardwareCameraSixCapturesThroughProductionBridge",
    "burst": "testHardwareCameraBurstQueueThroughProductionBridge",
    "react": "testHardwareReactPhotoRetakeDeleteAndLocalPlan",
}[args.test]
products = args.derived_data.resolve() / "Build/Products"
candidates = [p for p in products.glob("*.xctestrun") if not p.name.endswith("-hardware.xctestrun")]
if len(candidates) != 1:
    parser.error(f"Expected one generated xctestrun, found {len(candidates)}")
if args.result.exists():
    parser.error("Result path exists; choose a new path to preserve earlier evidence")
data = plistlib.loads(candidates[0].read_bytes())
target_count = 0
for target in data.values():
    if isinstance(target, dict) and "TestBundlePath" in target:
        target.setdefault("EnvironmentVariables", {})["SMARTPAW_RUN_CAMERA_HARDWARE"] = "1"
        target["OnlyTestIdentifiers"] = [f"SmartPawTests/{method}"]
        target_count += 1
if target_count != 1:
    parser.error(f"Expected one test target, found {target_count}")
configured = candidates[0].with_name(candidates[0].stem + "-hardware.xctestrun")
configured.write_bytes(plistlib.dumps(data))
command = ["xcodebuild", "test-without-building", "-xctestrun", str(configured),
           "-destination", f"platform=iOS,id={args.device}",
           f"-only-testing:SmartPawTests/SmartPawTests/{method}",
           "-parallel-testing-enabled", "NO", "-resultBundlePath", str(args.result.resolve())]
print(f"Running real camera regression ({args.test}); unlock iPhone first.", flush=True)
raise SystemExit(subprocess.call(command))
