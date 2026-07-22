#ifndef FONT5X7_H
#define FONT5X7_H

#include <stdint.h>

// Fuente 5x7 (5 columnas x 7 filas), solo para los caracteres que puede
// producir la calculadora: digitos 0-9, '+','-','*','/','=' y espacio.
//
// Cada glifo son 5 bytes, uno por columna (columna 0 = izquierda del
// caracter). Dentro de cada byte, bit0 = fila superior del glifo,
// bit6 = fila inferior (bit7 sin usar). Generado con un script que
// convierte "arte ASCII" (una fila de texto por fila del glifo) a esta
// representacion, para poder verificar visualmente cada caracter antes
// de convertirlo a bits (ver /tmp/genfont.py usado durante el diseño).
#define FONT_COLS 5
#define FONT_ROWS 7

typedef struct {
    char    ch;
    uint8_t col[FONT_COLS];
} font_glyph_t;

static const font_glyph_t font5x7[] = {
    { '0', { 0x3E, 0x51, 0x49, 0x45, 0x3E } },
    { '1', { 0x00, 0x42, 0x7F, 0x40, 0x00 } },
    { '2', { 0x42, 0x61, 0x51, 0x49, 0x46 } },
    { '3', { 0x21, 0x41, 0x45, 0x4B, 0x31 } },
    { '4', { 0x18, 0x14, 0x12, 0x7F, 0x10 } },
    { '5', { 0x27, 0x45, 0x45, 0x45, 0x39 } },
    { '6', { 0x3C, 0x4A, 0x49, 0x49, 0x30 } },
    { '7', { 0x01, 0x71, 0x09, 0x05, 0x03 } },
    { '8', { 0x36, 0x49, 0x49, 0x49, 0x36 } },
    { '9', { 0x06, 0x49, 0x49, 0x29, 0x1E } },
    { '+', { 0x08, 0x08, 0x3E, 0x08, 0x08 } },
    { '-', { 0x08, 0x08, 0x08, 0x08, 0x08 } },
    { '*', { 0x2A, 0x1C, 0x3E, 0x1C, 0x2A } },
    { '/', { 0x60, 0x10, 0x0C, 0x02, 0x01 } },
    { '=', { 0x0A, 0x0A, 0x0A, 0x0A, 0x0A } },
    { ' ', { 0x00, 0x00, 0x00, 0x00, 0x00 } },
};

#define FONT_GLYPH_COUNT (sizeof(font5x7) / sizeof(font5x7[0]))

// Busca el glifo de un caracter; si no existe (no deberia pasar, la
// calculadora solo produce digitos/operadores/'='), devuelve el espacio.
static inline const font_glyph_t *font_lookup(char ch)
{
    for (unsigned i = 0; i < FONT_GLYPH_COUNT; i++)
        if (font5x7[i].ch == ch)
            return &font5x7[i];
    return &font5x7[FONT_GLYPH_COUNT - 1]; // ' '
}

#endif
