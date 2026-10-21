#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT/FigmaMakeLatest-v3"
if command -v npm >/dev/null 2>&1; then
    npm run build
elif command -v pnpm >/dev/null 2>&1; then
    pnpm run build
else
    echo "Node.js and npm or pnpm are required to build the bundled web UI." >&2
    exit 1
fi

# Keep the bundled entry and assets from the same build.
python3 - "$PROJECT_ROOT" <<'PY'
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1])
source = root / 'FigmaMakeLatest-v3/dist'
destination = root / 'Resources/FigmaMakeLatestWeb'
if not (source / 'index.html').is_file() or not (source / 'assets').is_dir():
    raise SystemExit('Missing web build output')
temporary = destination.with_name('FigmaMakeLatestWeb.next')
if temporary.exists():
    shutil.rmtree(temporary)
shutil.copytree(source, temporary)
(temporary / 'VERSION.txt').write_text('Source: FigmaMakeLatest-v3\n', encoding='utf-8')
previous = destination.with_name('FigmaMakeLatestWeb.previous')
if previous.exists():
    shutil.rmtree(previous)
if destination.exists():
    destination.rename(previous)
try:
    temporary.rename(destination)
except Exception:
    if previous.exists():
        previous.rename(destination)
    raise
if previous.exists():
    shutil.rmtree(previous)
print('Bundled web resources updated. Rebuild SmartPaw in Xcode.')
PY
