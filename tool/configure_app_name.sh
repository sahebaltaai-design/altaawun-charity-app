#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
if p.exists():
    text = p.read_text()
    import re
    text = re.sub(r'android:label="[^"]*"', 'android:label="@string/app_name"', text, count=1)
    p.write_text(text)
p = Path('ios/Runner/Info.plist')
if p.exists():
    text = p.read_text()
    import re
    text = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', r'\1جمعية التعاون الخيرية\2', text)
    text = re.sub(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)', r'\1جمعية التعاون الخيرية\2', text)
    p.write_text(text)
PY
