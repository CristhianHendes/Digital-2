#!/usr/bin/env python3
"""
img2hex.py - Convierte una imagen a leds.hex para el controlador WS2812B.

La imagen se redimensiona a 8x8 y cada pixel se escribe como una linea
de 6 digitos hex en orden GRB (formato del WS2812B), MSB primero,
compatible con $readmemh.

Uso:
    python img2hex.py imagen.png
    python img2hex.py imagen.png -o leds.hex
    python img2hex.py imagen.png --serpentine        # matriz en zigzag
    python img2hex.py imagen.png --brightness 0.3    # limitar corriente

Requiere: pip install pillow
"""

import argparse
from PIL import Image


def convertir(ruta_imagen, salida, ancho, alto, serpentine, brillo):
    img = Image.open(ruta_imagen).convert("RGB")
    img = img.resize((ancho, alto), Image.NEAREST)

    lineas = []
    for fila in range(alto):
        # En cableado serpentine las filas impares van de derecha a izquierda
        cols = range(ancho - 1, -1, -1) if (serpentine and fila % 2 == 1) \
               else range(ancho)
        for col in cols:
            r, g, b = img.getpixel((col, fila))
            r = int(r * brillo)
            g = int(g * brillo)
            b = int(b * brillo)
            # Orden GRB exigido por el WS2812B
            lineas.append(f"{g:02X}{r:02X}{b:02X}")

    with open(salida, "w") as f:
        f.write("\n".join(lineas) + "\n")

    print(f"OK: {len(lineas)} pixeles escritos en {salida}")
    print(f"   Layout: {'serpentine (zigzag)' if serpentine else 'row-major'}"
          f", brillo {int(brillo * 100)}%")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Imagen -> leds.hex (WS2812B, GRB)")
    p.add_argument("imagen", help="Ruta de la imagen (png, jpg, bmp, ...)")
    p.add_argument("-o", "--output", default="leds.hex",
                   help="Archivo de salida (default: leds.hex)")
    p.add_argument("--width", type=int, default=8, help="Ancho en LEDs (default 8)")
    p.add_argument("--height", type=int, default=8, help="Alto en LEDs (default 8)")
    p.add_argument("--serpentine", action="store_true",
                   help="Matriz cableada en zigzag (filas impares invertidas)")
    p.add_argument("--brightness", type=float, default=1.0,
                   help="Factor de brillo 0.0-1.0 (default 1.0)")
    args = p.parse_args()

    convertir(args.imagen, args.output, args.width, args.height,
              args.serpentine, args.brightness)
