# Calculadora con pantalla WS2812

Sistema digital que integra una **calculadora aritmética** (suma, resta,
multiplicación y división) con una **matriz de LEDs WS2812 de 8×8**, todo
implementado como un único System-on-Chip (SoC) sobre FPGA usando el
framework LiteX/Migen, ejecutándose en una Colorlight i9 (Lattice ECP5).

El diseño sigue la metodología clásica de diseño de sistemas digitales
, todo periférico de hardware se modela como la separación entre una **Unidad de Control**
(la máquina de estados finitos, o FSM, que decide *qué hacer y cuándo*)
y una **Ruta de Datos** (los registros, contadores, sumadores/restadores
y multiplexores que *ejecutan* la operación indicada por el control).
El CPU (VexRiscv) se comunica con cada periférico mediante **registros
mapeados en memoria** (CSR — *Control and Status Registers*), sin
necesidad de instrucciones especiales: escribir o leer una dirección de
memoria concreta equivale a escribir/leer un registro del hardware.

## 1. Arquitectura general

```
                 ┌─────────────────────────────────────────┐
                 │              CPU (VexRiscv)              │
                 │         ejecuta firmware/main.c          │
                 └───────────────┬───────────────────────────┘
                                  │ Bus Wishbone / Bus CSR
        ┌─────────────┬──────────┼──────────┬─────────────┐
        │             │          │          │             │
   ┌────▼───┐   ┌─────▼───┐ ┌────▼────┐ ┌───▼────┐  ┌─────▼──────┐
   │  add0  │   │  sub0   │ │  mult0  │ │  div0  │  │   disp0    │
   │(comb.) │   │ (comb.) │ │ (FSM+   │ │ (FSM+  │  │ (WS2812 +  │
   │        │   │         │ │ datapath│ │datapath│  │  DMA)      │
   └────────┘   └─────────┘ └─────────┘ └────────┘  └────────────┘
```

Cada bloque es un **periférico independiente**: vive en hardware, corre
en paralelo a los demás y al CPU, y solo se activa cuando el firmware
escribe en sus registros CSR. El firmware es el único que conoce el
**orden** en que deben usarse (leer un operando, mostrarlo, calcular,
mostrar el resultado); el hardware, por sí solo, no sabe nada de "una
calculadora" — solo sabe sumar, restar, multiplicar, dividir o dibujar
un pixel cuando se le pide.

## 2. Estructura de carpetas

| Carpeta | Contenido |
|---|---|
| `board/` | Definición de la placa (pines, relojes, SDRAM, SPI flash) de la Colorlight i9/i5. |
| `add/`, `sub/` | Periféricos combinacionales puros (sin Unidad de Control: el resultado está disponible de inmediato). |
| `mult/` | Multiplicador serie 16×16→32 bits (algoritmo *shift-and-add*, con FSM). |
| `div/` | Divisor serie 32/32 bits (algoritmo *shift-subtract* o división restauradora, con FSM). |
| `ws2812/` | Periférico de la matriz de LEDs (jerarquía de 4 niveles + carga por DMA). |
| `firmware/` | Programa en C que orquesta todos los periféricos anteriores. |
| `colorlight_i9_calc_ws2812.py` | Punto de entrada: arma el SoC completo (CPU + bus + todos los periféricos). |

Cada periférico tiene dos partes:
- Un **wrapper en Migen (`.py`)**: no implementa la aritmética en sí,
  solo declara los registros CSR y usa `Instance(...)` para conectar
  esos registros a un módulo Verilog ya escrito — es decir, Migen actúa
  como *pegamento* entre el bus del CPU y el circuito real.
- El **circuito en Verilog puro (`.v`)**: aquí vive la Unidad de
  Control y la Ruta de Datos reales.

## 3. Los periféricos aritméticos

### `add` / `sub` — lógica combinacional pura

No tienen Unidad de Control porque no hay nada que secuenciar: son un
sumador/restador de cable fijo (`assign sum = A + B;`). El resultado
está disponible tan pronto cambian los operandos, sin señales de
`init`/`done`.

### `mult` — Unidad de Control + Ruta de Datos (algoritmo *shift-and-add*)

Multiplica dos operandos de 16 bits sumando A desplazada a la posición
correspondiente por cada bit en 1 de B. La Ruta de Datos tiene:
registro de corrimiento derecho de B (`rsr`), registro de corrimiento
izquierdo de A (`lsr_mult`), detector de cero (`comp`) y acumulador
(`acc`). La Unidad de Control (`control_mult`) es un diagrama ASM de 5
estados: `START → CHECK → (ADD) → SHIFT → END`, repitiendo
`CHECK/SHIFT` una vez por cada bit de B.

### `div` — Unidad de Control + Ruta de Datos (algoritmo de división restauradora)

Divide dos operandos de 32 bits mediante 32 iteraciones de
"desplazar y restar": en cada ciclo se intenta restar el divisor del
residuo parcial; si el resultado no es negativo, ese bit del cociente
es 1 y se conserva la resta; si es negativo, el bit es 0 y se descarta.
La Ruta de Datos usa un único registro combinado cociente:residuo de 64
bits (`qr_reg`), el divisor retenido en `divisor_reg`, y el
resta/comparación en `sub_cmp33`. La Unidad de Control (`control_div`)
tiene 3 estados (`START → RUN × 32 → END`), estructuralmente análoga a
`control_mult`.

> **Limitaciones conocidas** (documentadas, no corregidas): `mult` solo
> admite operandos de 16 bits (el producto sí es de 32); ninguno de los
> cuatro periféricos detecta *overflow*; `div` opera sobre patrones de
> bits sin signo, por lo que un operando negativo produce un resultado
> incorrecto en hardware (el firmware nunca envía divisiones por cero,
> pero sí puede enviar negativos).

## 4. El periférico de la matriz WS2812

Jerarquía de 4 niveles, de mayor a menor nivel de abstracción:

```
ws2812_streamer.py (Migen)          ← CSR + calculo de tiempos reales
  └─ ws2812_periph.v                ← recorre las 64 direcciones (LEDs)
       └─ ws2812_led.v              ← serializa UN pixel (24 bits RGB)
            └─ ws2812.v             ← genera UN pulso (ancho T0H/T1H/RES/PER)
```

- **Nivel Migen**: calcula los tiempos del protocolo (`T0H`, `T1H`,
  `PER`, `RES`) en *ciclos de reloj reales* a partir de la frecuencia
  del sistema (`sys_clk_freq`), y conecta el flujo del DMA a la memoria
  de LEDs, reordenando los bytes al orden **G-R-B** que exige el
  protocolo WS2812.
- **`ws2812_periph.v`**: contiene la memoria de video (`led_mem_dual`),
  el contador de dirección, el comparador de fin de pasada y la Unidad
  de Control que recorre las 64 posiciones, esperando entre cada pasada
  completa un tiempo de refresco (`WAIT_REFRESH`) para que los LEDs
  puedan re-latchear datos nuevos.
- **`ws2812_led.v` / `ws2812.v`**: descomponen cada pixel en sus 24
  bits y cada bit en el pulso eléctrico exacto que exige el datasheet.

### Carga de imágenes por DMA

Siguiendo la filosofía del libro sobre gestión de memoria: en vez de
que el CPU escriba LED por LED, el `WishboneDMAReader` transfiere un
bloque completo de la RAM (un arreglo `const uint32_t frame[64]`)
directamente a la memoria de video del periférico, indicando solo
**dirección base** y **longitud**. El CPU no participa en la
transferencia misma, solo la dispara y espera a que termine.

## 5. El firmware: la máquina de estados de la calculadora

`firmware/main.c` implementa, en software, una máquina de estados que
orquesta ambos grupos de periféricos:

```
READ_A → READ_OP → READ_B → COMPUTE → SHOW_RESULT → (repite)
```

- **READ_A / READ_OP / READ_B**: cada carácter recibido por UART se
  dibuja de inmediato en la matriz (`render_char`) y permanece fijo
  hasta que llega el siguiente carácter.
- **COMPUTE**: según el operador, se escriben los CSR del periférico
  correspondiente (`add0`, `sub0`, `mult0` o `div0`) y se lee el
  resultado (con espera activa sobre `done` para `mult`/`div`, que son
  secuenciales).
- **SHOW_RESULT**: se arma la expresión completa (p.ej. `9+2=11`) sobre
  un lienzo ancho (*canvas*) construido con una fuente 5×7, y se
  desplaza por la matriz de derecha a izquierda (efecto *scroll*).

Es la misma lógica de "Unidad de Control + Ruta de Datos" aplicada a
nivel de software: el firmware es el control (decide el orden), y los
periféricos de hardware son la ruta de datos (ejecutan cada operación).

## 6. Construcción y carga

```bash
cd /home/cristhianhendes/digital_2/Digital-2/calculadora_ws2812
source /home/cristhianhendes/litex/.venv/bin/activate

python3 colorlight_i9_calc_ws2812.py --board=i9 --revision=7.2 --build   # SoC (gateware + BIOS)
python3 colorlight_i9_calc_ws2812.py --board=i9 --revision=7.2 --load    # Carga a SRAM (nunca --write-flash)

make -C firmware/                # Compila firmware.bin
make -C firmware/ litex_term     # Sube el firmware y abre la terminal serie
```
