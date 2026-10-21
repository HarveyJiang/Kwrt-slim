#!/usr/bin/env python3
"""Add --allow-untrusted (and --force-overwrite) to the per-device rootfs apk add.

openwrt 25.12 builds with apk v3. The package index (staging_dir/packages/<target>/
packages.adb) is only signed when CONFIG_SIGNED_PACKAGES is enabled; by default it
is an *unsigned* index. Upstream therefore passes --allow-untrusted wherever the
index is consumed, e.g. in package/Makefile:

    $(call apk,$(TARGET_DIR)) add --no-cache --initdb --no-scripts --arch ... \
        --repositories-file /dev/null --repository file://$(PACKAGE_DIR_ALL)/packages.adb \
        $(if $(CONFIG_SIGNED_PACKAGES),,--allow-untrusted) ...

but include/image.mk (per-device rootfs, CONFIG_TARGET_PER_DEVICE_ROOTFS=y) was
left out of that:

    apk_target = \
        $(call apk,$(mkfs_cur_target_dir)) --no-scripts \
            --repositories-file /dev/null --repository file://$(PACKAGE_DIR_ALL)/packages.adb
    ...
        $(apk_target) add $(mkfs_packages_add))

So apk refuses the unsigned index, drops it entirely and the device packages
cannot be resolved:

    WARNING: opening file:///.../staging_dir/packages/qualcommax/packages.adb: UNTRUSTED signature
    ERROR: unable to select packages:
      ipq-wifi-jdcloud_re-ss-01 (no such package):
        required by: world[ipq-wifi-jdcloud_re-ss-01]
    make[5]: *** [include/image.mk:397: target-dir-3458f57f] Error 1

This script adds --allow-untrusted (so the unsigned index is accepted, exactly
like upstream does for the rootfs install) plus --force-overwrite (so device
packages may overwrite files owned by another package, same policy the repo
already applies to the package/install stage).

The script is idempotent and never exits non-zero: if the upstream file does not
look the way we expect, a warning is printed and the build continues.
"""

import os
import re
import sys

TARGET = os.path.join("include", "image.mk")
FLAGS = "--allow-untrusted --force-overwrite"


def main():
    if not os.path.isfile(TARGET):
        print("WARNING: %s not found, skip apk allow-untrusted patch" % TARGET, file=sys.stderr)
        return 0

    try:
        with open(TARGET, "r", encoding="utf-8", errors="surrogateescape") as fh:
            lines = fh.read().splitlines(keepends=True)
    except OSError as exc:
        print("WARNING: cannot read %s: %s" % (TARGET, exc), file=sys.stderr)
        return 0

    pattern = re.compile(r"\$\(\s*apk_target\s*\)\s+add\b")
    for index, line in enumerate(lines):
        if not pattern.search(line):
            continue
        if "--allow-untrusted" in line:
            print("%s already contains --allow-untrusted, nothing to do" % TARGET)
            return 0
        new_line = re.sub(r"(\$\(\s*apk_target\s*\)\s+add\b)", r"\1 " + FLAGS, line, count=1)
        lines[index] = new_line
        try:
            with open(TARGET, "w", encoding="utf-8", errors="surrogateescape") as fh:
                fh.write("".join(lines))
        except OSError as exc:
            print("WARNING: cannot write %s: %s" % (TARGET, exc), file=sys.stderr)
            return 0
        print("patched %s: added %s to the apk_target add call" % (TARGET, FLAGS))
        print("  " + new_line.strip())
        return 0

    print('WARNING: no "$(apk_target) add" line found in %s' % TARGET, file=sys.stderr)
    print("WARNING: per-device rootfs apk install may fail on the unsigned index", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
