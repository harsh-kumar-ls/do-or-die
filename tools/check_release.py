"""Checks a release build before it is uploaded or installed.

Usage: python3 -I tools/check_release.py dist/DoOrDie-0.9.1.aab [more files]

For each .apk or .aab it checks, and fails loudly if any check fails:
- versionCode is above every build ever published (13 was 0.9.0);
- targetSdkVersion meets Google Play's current minimum (36);
- android:allowBackup is false (the privacy policy says nothing is backed up);
- the compiled Dart code is the safe rules engine: it contains
  'penalty_expired' and 'I AM 18 OR OLDER', and not 'carried_over'.
"""

import glob
import os
import re
import subprocess
import sys
import zipfile

MIN_VERSION_CODE = 14
MIN_TARGET_SDK = 36
MUST_CONTAIN = [b"penalty_expired", b"I AM 18 OR OLDER"]
MUST_NOT_CONTAIN = [b"carried_over"]


def aapt2():
    found = sorted(glob.glob(
        "/opt/homebrew/share/android-commandlinetools/build-tools/*/aapt2"))
    home = os.path.expanduser("~/Library/Android/sdk/build-tools/*/aapt2")
    found += sorted(glob.glob(home))
    if not found:
        sys.exit("aapt2 not found (Android build-tools)")
    return found[-1]


def _varint(b, i):
    n = shift = 0
    while True:
        c = b[i]
        i += 1
        n |= (c & 0x7F) << shift
        shift += 7
        if c < 0x80:
            return n, i


def _fields(b):
    """Decodes one protobuf message into (field, value) pairs, or None."""
    out, i = [], 0
    try:
        while i < len(b):
            key, i = _varint(b, i)
            field, wire = key >> 3, key & 7
            if wire == 0:
                v, i = _varint(b, i)
            elif wire == 2:
                ln, i = _varint(b, i)
                v = b[i:i + ln]
                i += ln
            elif wire == 1:
                v = b[i:i + 8]
                i += 8
            elif wire == 5:
                v = b[i:i + 4]
                i += 4
            else:
                return None
            out.append((field, v))
        return out if i == len(b) else None
    except IndexError:
        return None


def _bundle_attrs(b, found, depth=0):
    """Finds aapt2 XmlAttribute messages (2: name, 3: raw value) anywhere."""
    fields = _fields(b)
    if not fields or depth > 40:
        return
    names = [v for f, v in fields if f == 2 and isinstance(v, bytes)]
    values = [v for f, v in fields if f == 3 and isinstance(v, bytes)]
    if names and values:
        try:
            found.setdefault(names[0].decode(), values[0].decode())
        except UnicodeDecodeError:
            pass
    for _, v in fields:
        if isinstance(v, bytes) and len(v) > 1:
            _bundle_attrs(v, found, depth + 1)


def manifest_attrs(path):
    """Manifest attributes by name: aapt2 for an APK, the protobuf manifest
    for an App Bundle (aapt2 can't read bundles)."""
    if path.endswith(".aab"):
        with zipfile.ZipFile(path) as z:
            raw = z.read("base/manifest/AndroidManifest.xml")
        found = {}
        _bundle_attrs(raw, found)
        return found
    xml = subprocess.run(
        [aapt2(), "dump", "xmltree", "--file", "AndroidManifest.xml", path],
        capture_output=True, text=True, check=True).stdout
    found = {}
    for m in re.finditer(
            r"android:(\w+)\(0x[0-9a-f]+\)=(?:\(type 0x[0-9a-f]+\))?(\S+)",
            xml):
        found.setdefault(m.group(1), m.group(2))
    return found


def libapp(path):
    with zipfile.ZipFile(path) as z:
        names = [n for n in z.namelist() if n.endswith("arm64-v8a/libapp.so")]
        if not names:
            sys.exit(f"{path}: no arm64-v8a/libapp.so")
        return z.read(names[0])


def check(path):
    problems = []
    attrs = manifest_attrs(path)
    code = attrs.get("versionCode")
    target = attrs.get("targetSdkVersion")
    backup = attrs.get("allowBackup")
    try:
        if int(code, 0) < MIN_VERSION_CODE:
            problems.append(f"versionCode {code} < {MIN_VERSION_CODE}")
    except (TypeError, ValueError):
        problems.append(f"versionCode unreadable: {code}")
    try:
        if int(target, 0) < MIN_TARGET_SDK:
            problems.append(f"targetSdkVersion {target} < {MIN_TARGET_SDK}")
    except (TypeError, ValueError):
        problems.append(f"targetSdkVersion unreadable: {target}")
    if backup is None or backup.lower() not in ("false", "0x0", "0"):
        problems.append(f"allowBackup is {backup}, expected false")
    so = libapp(path)
    for s in MUST_CONTAIN:
        if s not in so:
            problems.append(f"compiled code lacks {s.decode()!r}")
    for s in MUST_NOT_CONTAIN:
        if s in so:
            problems.append(f"compiled code still has {s.decode()!r}")
    status = "OK" if not problems else "FAIL"
    print(f"{status}  {path}  versionCode={code} targetSdk={target} "
          f"allowBackup={backup}")
    for p in problems:
        print(f"      - {p}")
    return not problems


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    results = [check(p) for p in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)
