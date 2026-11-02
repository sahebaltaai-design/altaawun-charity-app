#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
p=Path('android/settings.gradle.kts')
if p.exists():
 s=p.read_text()
 s=s.replace('id("com.android.application") version', 'id("com.google.gms.google-services") version "4.4.2" apply false\n    id("com.android.application") version')
 p.write_text(s)
p=Path('android/app/build.gradle.kts')
if p.exists():
 s=p.read_text()
 s=s.replace('id("com.android.application")', 'id("com.android.application")\n    id("com.google.gms.google-services")',1)
 p.write_text(s)
p=Path('android/app/src/main/AndroidManifest.xml')
if p.exists():
 s=p.read_text()
 s=s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ',1) if 'xmlns:tools=' not in s else s
 s=s.replace('<application', '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application',1)
 p.write_text(s)
PY
