#!/usr/bin/env python3
"""Run once after `flutter create --platforms=android .` (Codemagic does it on every build).

Patches the generated Gradle file for this app:
- minSdk 24 (flutter_local_notifications 21+)
- core library desugaring (needed by flutter_local_notifications)
Works with both build.gradle.kts (Flutter >= 3.29 default) and Groovy build.gradle. Safe to run twice.
"""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent / "android" / "app"
kts, groovy = root / "build.gradle.kts", root / "build.gradle"
f = kts if kts.exists() else groovy
if not f.exists():
    sys.exit("android/app/build.gradle(.kts) not found: run `flutter create --platforms=android .` first")
s = f.read_text()
is_kts = f.suffix == ".kts"

if "desugar_jdk_libs" not in s:
    # minSdk
    s = re.sub(r"minSdk\s*=?\s*flutter\.minSdkVersion", "minSdk = 24" if is_kts else "minSdk 24", s)
    # desugaring flag inside compileOptions
    flag = "isCoreLibraryDesugaringEnabled = true" if is_kts else "coreLibraryDesugaringEnabled true"
    s, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        " + flag, s, count=1)
    if n == 0:
        s = s.replace("android {", "android {\n    compileOptions {\n        " + flag + "\n    }", 1)
    dep = ('    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if is_kts
           else "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
    if re.search(r"^dependencies\s*\{", s, re.M):
        s = re.sub(r"^dependencies\s*\{", "dependencies {\n" + dep, s, count=1, flags=re.M)
    else:
        s += "\ndependencies {\n" + dep + "\n}\n"
    f.write_text(s)
    print("patched", f)
else:
    print("already patched", f)
