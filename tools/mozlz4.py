#!/usr/bin/env python3
"""Read and write Mozilla's .jsonlz4 / .mozlz4 files (magic "mozLz40\\0", uint32 size,
one LZ4 block) without the lz4 module.

    mozlz4.py -d FILE          print the JSON inside
    import mozlz4; mozlz4.read(path) / mozlz4.write(path, obj)

Writing stores the data as a single literal run: a valid LZ4 block, just not
compressed, which Firefox/Zen read like any other.
"""
import json, struct, sys

MAGIC = b"mozLz40\0"


def lz4_block_decompress(src, size):
    out, i = bytearray(), 0
    while i < len(src):
        token = src[i]; i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255:
                    break
        out += src[i:i + lit]; i += lit
        if i >= len(src):
            break
        off = src[i] | (src[i + 1] << 8); i += 2
        ml = token & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255:
                    break
        ml += 4
        start = len(out) - off
        for k in range(ml):                      # may overlap: byte by byte
            out.append(out[start + k])
    return bytes(out[:size])


def lz4_block_literals(data):
    n = len(data)
    if n < 15:
        return bytes([n << 4]) + data
    rest, ext = n - 15, bytearray()
    while rest >= 255:
        ext.append(255); rest -= 255
    ext.append(rest)
    return bytes([0xF0]) + bytes(ext) + data


def read(path):
    raw = open(path, "rb").read()
    if raw[:8] != MAGIC:
        raise ValueError("not a mozlz4 file")
    size = struct.unpack("<I", raw[8:12])[0]
    return json.loads(lz4_block_decompress(raw[12:], size))


def write(path, obj):
    data = json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode()
    with open(path, "wb") as f:
        f.write(MAGIC + struct.pack("<I", len(data)) + lz4_block_literals(data))


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "-d":
        print(json.dumps(read(sys.argv[2]), indent=1, ensure_ascii=False))
    else:
        print(__doc__)
