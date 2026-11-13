#!/usr/bin/env python3
"""Enable Android core library desugaring for flutter_local_notifications.

Run AFTER flutter create has generated android/app/build.gradle.kts.
"""
from pathlib import Path

gradle = Path("android/app/build.gradle.kts")
if gradle.exists():
    source = gradle.read_text()
    if "isCoreLibraryDesugaringEnabled = true" not in source:
        if "compileOptions {" not in source:
            raise SystemExit("Expected Kotlin Android compileOptions block was not found")
        source = source.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:" not in source:
        source += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    gradle.write_text(source)
else:
    gradle = Path("android/app/build.gradle")
    if not gradle.exists():
        raise SystemExit("Android Gradle build file missing. Run flutter create first.")
    source = gradle.read_text()
    if "coreLibraryDesugaringEnabled true" not in source:
        if "compileOptions {" not in source:
            raise SystemExit("Expected Groovy Android compileOptions block was not found")
        source = source.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    if "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:" not in source:
        source += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    gradle.write_text(source)
print(f"Core library desugaring configured in {gradle}")
