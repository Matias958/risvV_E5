#!/usr/bin/env python3
"""Convierte imagenes PPM (P6) a PNG sin dependencias externas.
uso: ppm2png.py a.ppm [b.ppm ...]   -> a.png, b.png ..."""
import struct
import sys
import zlib


def read_ppm(path):
    data = open(path, 'rb').read()
    fields, i = [], 0
    while len(fields) < 4:                      # P6 ancho alto maximo
        while data[i:i + 1].isspace():
            i += 1
        if data[i:i + 1] == b'#':
            while data[i:i + 1] not in (b'\n', b''):
                i += 1
            continue
        j = i
        while not data[j:j + 1].isspace():
            j += 1
        fields.append(data[i:j]); i = j
    i += 1
    w, h = int(fields[1]), int(fields[2])
    pix = data[i:i + w * h * 3]
    pix += b'\0' * (w * h * 3 - len(pix))      # cuadro incompleto: completar en negro
    return w, h, pix


def write_png(path, w, h, pix):
    raw = b''.join(b'\0' + pix[y * w * 3:(y + 1) * w * 3] for y in range(h))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)


for p in sys.argv[1:]:
    w, h, pix = read_ppm(p)
    out = p[:-4] + '.png'
    write_png(out, w, h, pix)
    print(f'  {out}  ({w}x{h})')
