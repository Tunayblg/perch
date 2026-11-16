#!/bin/bash
# README görüntülerini üretir (örnek verilerle, kişisel veri yok): ./Scripts/render_previews.sh
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build_app.sh >/dev/null
./build/Perch.app/Contents/MacOS/Perch --render-previews docs/screenshots
