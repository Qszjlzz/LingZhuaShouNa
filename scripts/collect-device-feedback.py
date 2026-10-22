#!/usr/bin/env python3
"""Read a small, redacted local feedback snapshot; never modify the iPhone."""
import argparse
from datetime import datetime
import json
import math
from pathlib import Path
import re
import subprocess
import tempfile
import uuid
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "com.qszjlzz.smartpaw"
DEVICE = "87026BD1-C420-5477-9689-C5107AEB7B8D"
DOCUMENTS = {
    "state": "smart-paw-demo-state.json",
    "recognition": "smartpaw-diagnostics.txt",
    "image_generation": "smartpaw-image-generation-diagnostics.txt",
}
CATEGORIES = {"书籍", "电子产品", "文具", "衣物", "玩偶杂物", "待丢弃", "收纳工具", "厨房", "饮品", "健康", "装饰"}
EVENTS = {"consent-granted", "generation-succeeded", "generation-failed", "reset", "debug-import-succeeded", "debug-import-failed"}
IMAGE_NAME = re.compile(r"(?:before|after)-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\.jpg", re.I)


def identifier(value):
    try:
        return str(uuid.UUID(str(value)))
    except (ValueError, TypeError, AttributeError):
        return None


def number(value, low=0, high=1_000_000):
    if type(value) in (int, float) and math.isfinite(value) and low <= value <= high:
        return value
    return None


def label(value):
    """Only a short item label; never export notes, summaries, URLs or settings."""
    if not isinstance(value, str):
        return ""
    if re.search(r"(?i)([a-z][a-z0-9+.-]*://|www\.|bearer\s|(?:api.?key|token|secret|authorization)\s*[:=]|sk-|[a-z0-9_+/=-]{16,})", value):
        return "[redacted]"
    return re.sub(r"[\x00-\x1f\x7f]", "", value)[:80]


def rows(value):
    return [row for row in value if isinstance(row, dict)][:1000] if isinstance(value, list) else []


def ids(value):
    return [identifier(v) for v in value[:1000] if identifier(v)] if isinstance(value, list) else []


def timestamp(value):
    if type(value) in (int, float):
        return number(value, -1e11, 1e11) or 0
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() - 978307200
        except ValueError:
            pass
    return 0


def latest_plan(space):
    if isinstance(space.get("activePlan"), dict):
        return space["activePlan"]
    plans = rows(space.get("completedPlans"))
    return max(plans, key=lambda p: timestamp(p.get("completedAt")), default={})


def select_space(state, session):
    spaces = [s for s in rows(state.get("spaces")) if identifier(s.get("id"))]
    if session:
        return next((s for s in spaces if identifier(s.get("id")) == session), None), "explicit_space_uuid"
    if not spaces:
        return None, "no_persisted_space"
    # The app has no scan-session creation timestamp. Do not invent one.
    def rank(pair):
        index, space = pair
        dates = [timestamp(space.get("lastOrganizedAt"))]
        dates += [timestamp(p.get("completedAt")) for p in rows(space.get("completedPlans"))]
        return max(dates), index
    return max(enumerate(spaces), key=rank)[1], "latest_recorded_completion_else_last_space"


def safe_snapshot(space):
    plan = latest_plan(space)
    items = []
    for row in rows(space.get("detectedItems")):
        if not identifier(row.get("id")):
            continue
        item = {"id": identifier(row["id"]), "name": label(row.get("name")),
                "category": row.get("category") if row.get("category") in CATEGORIES else "unknown",
                "confidence": number(row.get("confidence"), 0, 1), "isSelected": row.get("isSelected") is True,
                "hasMask": isinstance(row.get("arMask"), dict)}
        hint = row.get("arHint")
        if isinstance(hint, dict) and all(number(hint.get(k), 0, 1) is not None for k in ("x", "y", "width", "height")):
            item["box"] = {k: hint[k] for k in ("x", "y", "width", "height")}
        items.append(item)
    steps = [{"id": identifier(s.get("id")),
              "status": s.get("status") if s.get("status") in {"pending", "active", "done"} else "unknown",
              "itemIDs": ids(s.get("itemIDs"))}
             for s in rows(plan.get("steps")) if identifier(s.get("id"))]
    return {"spaceID": identifier(space.get("id")), "items": items,
            "activePlanPresent": isinstance(space.get("activePlan"), dict),
            "completedPlanCount": len(rows(space.get("completedPlans"))),
            "photoPairRecorded": space.get("hasVerifiedComparison") is True,
            "plan": {"id": identifier(plan.get("id")), "isPaused": plan.get("isPaused") is True,
                     "timeBudgetMinutes": number(plan.get("timeBudget"), 0, 1440), "steps": steps}}


def safe_diagnostics(text, kind):
    result = {}
    for line in text.splitlines():
        key, sep, value = line.partition("=" if kind == "image_generation" else ":")
        if not sep:
            continue
        key, value = key.strip(), value.strip()
        if key in {"enabled", "configured", "hasConsent", "云端开关", "有密钥", "可请求视觉"} and value in {"true", "false"}:
            result[key] = value == "true"
        elif key in {"本地模型数", "本次结果数"} and re.fullmatch(r"\d{1,6}", value):
            result[key] = int(value)
        elif key == "event" and value in EVENTS:
            result[key] = value
        elif key == "detail" and re.fullmatch(r"bytes=\d{1,9}", value):
            result["image_bytes"] = int(value[6:])
        elif key in {"time", "时间"} and re.fullmatch(r"[0-9T Z:+.\-]{10,40}", value):
            result["recorded_time"] = value
    # These files describe only the most recent diagnostic event, not a session log.
    return {"scope": "latest_global_event_not_proven_to_match_selected_space", "fields": result}


def copy_from_device(device, remote, destination):
    allowed = {"Documents/" + name for name in DOCUMENTS.values()}
    if remote not in allowed:
        prefix = "Documents/SmartPawImages/"
        if not remote.startswith(prefix) or not IMAGE_NAME.fullmatch(remote[len(prefix):]):
            raise ValueError("source is outside the exact file allowlist")
    try:
        run = subprocess.run(["xcrun", "devicectl", "device", "copy", "from", "--device", device,
                              "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE,
                              "--source", remote, "--destination", str(destination), "--quiet", "--timeout", "30",
                              "--json-output", str(destination.with_suffix(".copy-result.json"))],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=35)
        # Do not parse or relay devicectl console output; it can contain device data.
        return run.returncode == 0 and destination.is_file() and not destination.is_symlink()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def reencode_image(source, destination):
    from PIL import Image, ImageOps
    Image.MAX_IMAGE_PIXELS = 40_000_000
    with Image.open(source) as original:
        pixels = ImageOps.exif_transpose(original).convert("RGB")
        clean = Image.frombytes("RGB", pixels.size, pixels.tobytes())
        clean.save(destination, "JPEG", quality=90)  # New image: no EXIF, ICC, comments or location.
    destination.chmod(0o600)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    path.chmod(0o600)


def self_test():
    sid, iid = str(uuid.uuid4()), str(uuid.uuid4())
    fake_secret = "sk-FAKE_ONLY_DO_NOT_USE_123456789"
    space = {"id": sid, "detectedItems": [{"id": iid, "name": fake_secret, "category": "书籍",
              "confidence": 0.8, "apiKey": fake_secret, "url": "https://example.test/private"}],
             "beforeImageName": "../../image-generation-import.json", "completedPlans": []}
    state = {"spaces": [space], "llmSettings": {"apiKey": fake_secret, "endpoint": "https://example.test/private"}}
    selected, _ = select_space(state, sid)
    output = json.dumps(safe_snapshot(selected), ensure_ascii=False)
    output += json.dumps(safe_diagnostics("event=generation-failed\ndetail=" + fake_secret + "\nmodel=" + fake_secret + "\nendpointHost=example.test\nenabled=true", "image_generation"))
    assert fake_secret not in output and "example.test" not in output and "apiKey" not in output
    assert not IMAGE_NAME.fullmatch(space["beforeImageName"])
    assert not IMAGE_NAME.fullmatch("before-" + sid + ".jpg/../other")
    assert label("custom://private-location") == "[redacted]"
    assert safe_snapshot({"id": sid, "activePlan": {"steps": [{"id": iid, "itemIDs": None}]}})["plan"]["steps"][0]["itemIDs"] == []
    assert select_space(state, str(uuid.uuid4()))[0] is None
    assert select_space({"spaces": []}, None)[0] is None
    image_check = "not installed; image export needs Pillow"
    try:
        from PIL import Image
        with tempfile.TemporaryDirectory() as temporary:
            source, dest = Path(temporary) / "source.jpg", Path(temporary) / "clean.jpg"
            exif = Image.Exif(); exif[315] = fake_secret
            Image.new("RGB", (8, 8)).save(source, exif=exif)
            reencode_image(source, dest)
            with Image.open(dest) as image:
                assert not image.getexif() and "exif" not in image.info
        image_check = "passed"
    except ImportError:
        pass
    print("Synthetic redaction, space selection and path checks passed; image metadata check: " + image_check)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default=DEVICE)
    parser.add_argument("--session", type=lambda s: str(uuid.UUID(s)), help="persisted space UUID (the app has no independent scan-session archive)")
    parser.add_argument("--include-images", action="store_true", help="opt in to re-encoded before/after photos from this space only; requires Pillow")
    parser.add_argument("--output", type=Path, help="new directory inside this repository's ignored outputs/; existing paths are refused")
    parser.add_argument("--self-test", action="store_true", help="synthetic fixtures only; does not connect to a device")
    args = parser.parse_args()
    if args.self_test:
        self_test(); return
    if args.include_images:
        try:
            import PIL  # noqa: F401
        except ImportError:
            parser.error("--include-images requires a Python environment with Pillow")
    now = datetime.now(ZoneInfo("Asia/Shanghai"))
    base = ROOT / "outputs"
    if base.is_symlink():
        parser.error("outputs/ must not be a symlink")
    destination = args.output or base / ("device-feedback-" + now.strftime("%Y%m%d-%H%M%S"))
    destination = destination.absolute()
    if ".." in destination.parts or not destination.resolve().is_relative_to(base.resolve()):
        parser.error("output must remain inside the repository's ignored outputs/ directory")
    if destination.exists() or any(p.is_symlink() for p in [destination, *destination.parents]):
        parser.error("output must be a new path without symlink components")
    destination.mkdir(parents=True, mode=0o700)
    manifest = {"formatVersion": 1, "createdAt": now.isoformat(), "bundleID": BUNDLE,
                "includeImages": args.include_images, "sources": {}, "images": {},
                "limitations": ["Local export only; no uploads or device writes.",
                    "No independent historical scan session exists: --session selects a space snapshot.",
                    "Default selection uses recorded completion dates; otherwise last persisted space. It may not be the newest capture.",
                    "Only current candidates and one active/latest completed plan are exported; notes, settings, masks and historical projects are excluded.",
                    "Diagnostics are global latest events and may not match this space.",
                    "Before/after photos belong to the space, not necessarily the selected plan. Generated-image cache has no reliable state association and is excluded.",
                    "Snapshot is not atomic while the app writes. This is not recognition-accuracy or release-readiness proof."]}
    with tempfile.TemporaryDirectory(prefix="smartpaw-feedback-") as temporary:
        temp = Path(temporary)
        for kind, filename in DOCUMENTS.items():
            path = temp / filename
            copied = copy_from_device(args.device, "Documents/" + filename, path)
            manifest["sources"][kind] = "copied_temporarily" if copied else "missing_or_copy_failed"
            if not copied:
                continue
            try:
                if path.stat().st_size > (64_000_000 if kind == "state" else 1_000_000):
                    raise ValueError("size limit")
                if kind != "state":
                    write_json(destination / (kind + "-diagnostics.json"), safe_diagnostics(path.read_text(), kind))
                    continue
                state = json.loads(path.read_text())
                space, method = select_space(state, args.session)
                manifest["selectionMethod"] = method
                if space is None:
                    manifest["sources"][kind] = "requested_space_not_found" if args.session else "no_persisted_space"
                    continue
                write_json(destination / "session.json", safe_snapshot(space))
                manifest["selectedSpaceID"] = identifier(space.get("id"))
                if args.include_images:
                    for field, role in [("beforeImageName", "before"), ("afterImageName", "after")]:
                        name = space.get(field)
                        if not isinstance(name, str) or not IMAGE_NAME.fullmatch(name):
                            manifest["images"][role] = "no_safe_local_reference"; continue
                        image = temp / (role + ".jpg")
                        if not copy_from_device(args.device, "Documents/SmartPawImages/" + name, image):
                            manifest["images"][role] = "missing_or_copy_failed"; continue
                        try:
                            if image.stat().st_size > 64_000_000:
                                raise ValueError("size limit")
                            reencode_image(image, destination / (role + ".jpg"))
                            manifest["images"][role] = "reencoded_without_metadata"
                        except Exception:
                            (destination / (role + ".jpg")).unlink(missing_ok=True)
                            manifest["images"][role] = "decode_or_reencode_failed"
            except (ValueError, TypeError, AttributeError, KeyError, OSError):
                manifest["sources"][kind] = "invalid_or_unsupported_data"
    # TemporaryDirectory removes the raw state/logs, command metadata and original photos.
    write_json(destination / "manifest.json", manifest)
    print("Local feedback: " + str(destination))
    if "selectedSpaceID" not in manifest:
        print("No space snapshot was exported; check the per-source status in manifest.json.")
    print("Read manifest.json for missing data and limits. Nothing was uploaded; no accuracy claim is implied.")


if __name__ == "__main__":
    main()
