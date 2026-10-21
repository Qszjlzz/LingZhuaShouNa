#!/bin/sh
set -eu

# Static App Store submission gate. It deliberately does not archive, sign, upload,
# contact a service, or run the test suite. Run it from any directory.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail=0
warn=0
pass() { printf 'PASS %s\n' "$1"; }
warn() { warn=$((warn + 1)); printf 'WARN %s\n' "$1"; }
fail() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }

if [ -f SmartPaw.xcodeproj/project.pbxproj ]; then
  pass "Xcode project found"
else
  fail "SmartPaw.xcodeproj/project.pbxproj is missing"
fi

if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VERSION=$(xcodebuild -version 2>/dev/null | sed -n '1p' || true)
  SDK_LIST=$(xcodebuild -showsdks 2>/dev/null || true)
  XCODE_MAJOR=$(printf '%s\n' "$XCODE_VERSION" | awk '$1 == "Xcode" { split($2, version, "."); if (version[1] ~ /^[0-9]+$/) print version[1] }')
  IOS_SDK_MAJOR=$(printf '%s\n' "$SDK_LIST" | sed -n 's/.*-sdk iphoneos\([0-9][0-9]*\).*/\1/p' | sort -nr | head -n 1)
  if [ "${XCODE_MAJOR:-0}" -ge 26 ] && [ "${IOS_SDK_MAJOR:-0}" -ge 26 ]; then
    pass "${XCODE_VERSION} exposes an iOS ${IOS_SDK_MAJOR} SDK (minimum 26) for App Store uploads"
  else
    fail "${XCODE_VERSION:-xcodebuild unavailable} does not meet Apple's Xcode 26 + iOS 26 SDK upload requirement (effective 2026-04-28)"
  fi
else
  fail "xcodebuild is unavailable"
fi

PBX=SmartPaw.xcodeproj/project.pbxproj
if grep -q 'PrivacyInfo.xcprivacy in Resources' "$PBX" && [ -f Resources/PrivacyInfo.xcprivacy ]; then
  pass "Privacy manifest is present and copied into the app"
else
  fail "PrivacyInfo.xcprivacy is absent from the app resources"
fi
if grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' Resources/PrivacyInfo.xcprivacy \
  && grep -q 'CA92.1' Resources/PrivacyInfo.xcprivacy; then
  pass "UserDefaults required-reason declaration is present"
else
  fail "UserDefaults required-reason declaration is missing"
fi
if grep -q 'NSPrivacyCollectedDataTypePhotosorVideos' Resources/PrivacyInfo.xcprivacy; then
  pass "optional cloud-photo data flow is represented in the manifest"
else
  warn "manifest does not describe the optional cloud-photo data flow; reconcile with App Store Connect privacy answers"
fi
if command -v python3 >/dev/null 2>&1; then
  if python3 - Resources/PrivacyInfo.xcprivacy <<'PY'
import plistlib
import sys

try:
    with open(sys.argv[1], 'rb') as source:
        manifest = plistlib.load(source)
    defaults = [item for item in manifest.get('NSPrivacyAccessedAPITypes', [])
                if item.get('NSPrivacyAccessedAPIType') == 'NSPrivacyAccessedAPICategoryUserDefaults']
    if not any('CA92.1' in item.get('NSPrivacyAccessedAPITypeReasons', []) for item in defaults):
        raise ValueError('UserDefaults reason CA92.1 is not attached to its API category')
    content = {item['NSPrivacyCollectedDataType']: item
               for item in manifest.get('NSPrivacyCollectedDataTypes', [])}
    for name in ['NSPrivacyCollectedDataTypePhotosorVideos', 'NSPrivacyCollectedDataTypeOtherUserContent']:
        if 'NSPrivacyCollectedDataTypePurposeAppFunctionality' not in content.get(name, {}).get('NSPrivacyCollectedDataTypePurposes', []):
            raise ValueError(f'{name} is missing its App Functionality purpose')
except (OSError, ValueError, TypeError, KeyError, plistlib.InvalidFileException) as error:
    print(f'Privacy manifest validation: {error}', file=sys.stderr)
    sys.exit(1)
PY
  then
    pass "Privacy manifest parses and associates required reasons/data purposes correctly"
  else
    fail "Privacy manifest structure or declarations are invalid"
  fi
  if python3 - "$ROOT" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import hashlib
import sys
from urllib.parse import unquote, urlsplit

root = Path(sys.argv[1])
bundle = root / 'Resources/FigmaMakeLatestWeb'
build = root / 'FigmaMakeLatest-v3/dist'

class Resources(HTMLParser):
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        value = attrs.get('src') if tag == 'script' else attrs.get('href') if tag == 'link' else None
        if not value:
            return
        parsed = urlsplit(value)
        if not parsed.scheme and not parsed.netloc and parsed.path:
            path = bundle / unquote(parsed.path).lstrip('/')
            if not path.is_file():
                raise ValueError(f'bundled entry references missing resource: {parsed.path}')

def hashes(folder):
    return {str(path.relative_to(folder)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in folder.rglob('*') if path.is_file() and path.name != 'VERSION.txt'}

try:
    entry = bundle / 'index.html'
    Resources().feed(entry.read_text(encoding='utf-8'))
    if not (bundle / 'assets').is_dir():
        raise ValueError('bundled assets directory is missing')
    if build.is_dir() and hashes(build) != hashes(bundle):
        raise ValueError('dist and bundled web resources differ; run scripts/build-bundled-web.sh')
except (OSError, ValueError) as error:
    print(f'Web resource validation: {error}', file=sys.stderr)
    sys.exit(1)
PY
  then
    pass "Bundled web entry references existing assets and matches dist when present"
  else
    fail "Bundled web resources are incomplete or out of sync"
  fi
else
  fail "python3 is required to validate privacy declarations and bundled web resources"
fi
if grep -q 'iPhoneOS26.0.sdk' "$PBX"; then
  fail "project contains a hard-coded iPhoneOS26.0 SDK path"
else
  pass "project has no hard-coded iPhoneOS26 SDK path"
fi
if grep -q 'llm-defaults.json' "$PBX"; then
  fail "llm-defaults.json is still referenced by the Xcode project"
else
  pass "llm-defaults.json is not an app resource"
fi

if [ -f Resources/llm-defaults.json ]; then
  warn "local ignored Resources/llm-defaults.json exists; remove it before archiving and revoke any key it contained"
fi
if git grep -n -E 'sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' -- ':!docs/app-store/*' >/dev/null 2>&1; then
  fail "a tracked file appears to contain a service credential"
else
  pass "no common service credential pattern found in tracked files"
fi

if grep -q 'MARKETING_VERSION = 1\.0\.0;' "$PBX" && grep -q 'CURRENT_PROJECT_VERSION = 1;' "$PBX"; then
  pass "marketing/build versions are 1.0.0 (1)"
else
  warn "marketing/build version is not the audited 1.0.0 (1) value"
fi
if grep -q 'INFOPLIST_KEY_CFBundleDisplayName = "灵爪收纳";' "$PBX"; then
  pass "Release display name is 灵爪收纳"
else
  fail "Release display name is not configured"
fi

if grep -R -n -E 'Ultralytics.*AGPL|AGPL-3\.0' Resources/Models >/dev/null 2>&1; then
  fail "bundled model metadata identifies Ultralytics AGPL-3.0 models; obtain commercial rights or replace them"
else
  pass "no AGPL model marker found"
fi
if [ ! -f Resources/Models/EdgeSAM/LICENSE ] && [ ! -f Resources/Models/LICENSE ]; then
  warn "model license files are not present beside bundled weights; see docs/app-store/model-license-inventory.md"
fi

printf '\nPreflight result: %s failure(s), %s warning(s).\n' "$fail" "$warn"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
