#!/usr/bin/env python3
"""Add --force-overwrite to the "apk add" call in package/Makefile.

apk v3 refuses to overwrite a file that is already owned by another package.
During the package/install stage of the firmware build that turns into a hard
failure, e.g.:

    ERROR: xray-core-26.3.27-r1: trying to overwrite etc/init.d/xray
           owned by base-files-1719~20261021.
    make[2]: *** [package/Makefile:100: package/install] Error 6

apk v3 supports --force-overwrite ("Overwrite files in other packages"), the
apk equivalent of the old opkg behaviour, so the build keeps going instead of
losing hours of compilation over a file name clash.

Upstream (openwrt 25.12) ships:

    $(call apk,$(TARGET_DIR)) add --no-cache --initdb --no-scripts --arch ...

and this script turns it into:

    $(call apk,$(TARGET_DIR)) add --force-overwrite --no-cache --initdb ...

The script is idempotent and never exits non-zero: if the upstream file does
not look the way we expect, a warning is printed and the build continues.
"""

import os
import re
import sys

TARGET = os.path.join("package", "Makefile")
FLAG = "--force-overwrite"


def main():
    if not os.path.isfile(TARGET):
        print("WARNING: %s not found, skip %s patch" % (TARGET, FLAG), file=sys.stderr)
        return 0

    try:
        with open(TARGET, "r", encoding="utf-8", errors="surrogateescape") as fh:
            lines = fh.read().splitlines(keepends=True)
    except OSError as exc:
        print("WARNING: cannot read %s: %s" % (TARGET, exc), file=sys.stderr)
        return 0

    for index, line in enumerate(lines):
        if "$(call apk" not in line or not re.search(r"\badd\b", line):
            continue
        if FLAG in line:
            print("%s already contains %s, nothing to do" % (TARGET, FLAG))
            return 0
        lines[index] = re.sub(r"(\badd\b)", r"\1 " + FLAG, line, count=1)
        try:
            with open(TARGET, "w", encoding="utf-8", errors="surrogateescape") as fh:
                fh.write("".join(lines))
        except OSError as exc:
            print("WARNING: cannot write %s: %s" % (TARGET, exc), file=sys.stderr)
            return 0
        print("patched %s: added %s to the apk add call" % (TARGET, FLAG))
        print("  " + lines[index].strip())
        return 0

    print('WARNING: no "$(call apk,...) add" line found in %s' % TARGET, file=sys.stderr)
    print("WARNING: apk file conflicts may break package/install", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
