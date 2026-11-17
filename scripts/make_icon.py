#!/usr/bin/env python3
"""Genera l'icona 1024×1024 di Mustang Studio, senza dipendenze."""

import struct
import sys
import zlib


def write_png(path, width, height, pixel):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(png)


def blend(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def pixel(x, y):
    size = 1024
    cx = cy = (size - 1) / 2
    dx = x - cx
    dy = y - cy
    dist = (dx * dx + dy * dy) ** 0.5

    background = (22, 20, 16, 255)
    wood = (196, 132, 58, 255)
    wood_deep = (122, 72, 28, 255)
    hole = (28, 18, 12, 255)
    string = (245, 230, 204, 255)
    rosette = (92, 48, 22, 255)

    if dist > 430:
        return background

    color = wood if dy < 40 else blend(wood, wood_deep, min(1, (dy - 40) / 380))

    hole_dist = ((x - cx) ** 2 + (y - (cy + 30)) ** 2) ** 0.5
    if 78 <= hole_dist <= 96:
        color = rosette
    elif hole_dist < 78:
        color = hole

    for index in range(6):
        string_y = cy - 150 + index * 58
        if abs(y - string_y) <= 2.2 and 250 <= x <= 774 and dist < 400 and hole_dist > 100:
            color = string

    if dist > 400:
        fade = (430 - dist) / 30
        color = blend(background, color, max(0, min(1, fade)))

    return color


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("uso: make_icon.py uscita.png")
    write_png(sys.argv[1], 1024, 1024, pixel)
