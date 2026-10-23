#!/usr/bin/env python3
"""Pack the generated Windows PNGs into a multi-resolution .ico file."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "build" / "icon_gen" / "windows"
DEST = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
SIZES = (16, 24, 32, 48, 64, 128, 256)


def main() -> None:
    images = [(size, (SOURCE / f"icon_{size}.png").read_bytes()) for size in SIZES]
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + (16 * len(images))
    directory = bytearray()
    payload = bytearray()

    for size, data in images:
        width = 0 if size >= 256 else size
        height = 0 if size >= 256 else size
        directory.extend(
            struct.pack(
                "<BBBBHHII",
                width,
                height,
                0,
                0,
                1,
                32,
                len(data),
                offset,
            )
        )
        payload.extend(data)
        offset += len(data)

    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_bytes(header + directory + payload)
    print(f"Wrote {DEST.relative_to(ROOT)} ({len(SIZES)} sizes)")


if __name__ == "__main__":
    main()
