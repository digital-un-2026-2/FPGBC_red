# Demo visual: TXS0101, OE y dos transmisores

Esta demo es un **modelo digital didáctico** de una conexión bidireccional controlada por `OE`. Permite ver en GTKWave cuándo se abre el paso y qué ocurre si dos extremos conducen valores opuestos en el mismo cable.

> **Idea principal:** los dos FPGA pueden tener un dato guardado (`data_ready=1`) al mismo tiempo. Eso no significa que ambos deban conducir el cable. `OE` solo habilita o aísla el traductor; **no elige el transmisor**. Para un cable compartido, la lógica de protocolo debe habilitar un solo transmisor por turno y poner al receptor en alta impedancia.

## Qué enseña la forma de onda

| Tiempo | Situación | Resultado esperado |
|---|---|---|
| 0–10 ns | Los dos datos están listos (FPGA1=1, FPGA2=0), ambos manejan su lado, `OE=0`. | Los lados quedan aislados: A=1 y B=0. |
| 10–20 ns | `OE=1`; transmite solo FPGA1. | El 1 aparece a ambos lados. |
| 20–30 ns | FPGA1 libera; transmite solo FPGA2. | El 0 aparece a ambos lados. |
| 30–40 ns | `OE=1`; ambos conducen 1. | Se ve 1, pero eso no demuestra que sea seguro: hay dos conductores activos. |
| 40–50 ns | `OE=1`; FPGA1 conduce 1 y FPGA2 conduce 0. | La simulación ideal resuelve el bus como `X`, indicando conflicto. |
| 50–60 ns | `OE=0` con ambos conduciendo localmente. | Se separan otra vez: A=1 y B=0. |
| 60–70 ns | Ambos transmisores liberan sus líneas. | A=Z y B=Z. |

`X` es una advertencia digital de valores incompatibles en la simulación; **no modela exactamente** la tensión, corriente ni el daño posible en el TXS0101 real. El módulo usa una compuerta ideal `tranif1`, no un modelo eléctrico de TI.

## Abrir en GTKWave

Desde esta carpeta:

```bash
iverilog -g2012 -Wall -s tb_oe_demo -o oe_demo.out oe_demo.v
vvp oe_demo.out
gtkwave oe_demo.vcd
```

En GTKWave, agrega estas señales: `oe`, `fpga1_data_ready`, `fpga2_data_ready`, `fpga1_tx_en`, `fpga2_tx_en`, `fpga1_data`, `fpga2_data`, `side_a`, `side_b`, `both_driving`, `driver_conflict` y `phase`.

### ¿Qué significa cada señal?

| Señal en GTKWave | Significado |
|---|---|
| `oe` | Habilitación del traductor: `1` permite el paso entre lados; `0` los aísla. |
| `fpga1_data_ready` | La FPGA 1 tiene un dato preparado; **no indica que esté transmitiendo**. |
| `fpga2_data_ready` | La FPGA 2 tiene un dato preparado; **no indica que esté transmitiendo**. |
| `fpga1_tx_en` | Si vale `1`, la FPGA 1 conduce su dato; si vale `0`, libera su línea. |
| `fpga2_tx_en` | Si vale `1`, la FPGA 2 conduce su dato; si vale `0`, libera su línea. |
| `fpga1_data` | Valor del bit que la FPGA 1 tiene preparado para transmitir. |
| `fpga2_data` | Valor del bit que la FPGA 2 tiene preparado para transmitir. |
| `side_a` | Valor observado en el lado A del traductor, donde se conecta la FPGA 1 en este ejemplo. |
| `side_b` | Valor observado en el lado B del traductor, donde se conecta la FPGA 2 en este ejemplo. |
| `both_driving` | Vale `1` cuando ambos transmisores están habilitados, aunque `oe=0` los mantenga aislados. |
| `opposite_values` | Vale `1` cuando los dos datos preparados son diferentes; por sí solo no significa que haya conflicto. |
| `driver_conflict` | Vale `1` cuando `oe=1`, ambos transmiten y sus datos son diferentes. |
| `phase` | Número de la fase del ejemplo, de `0` a `6`, correspondiente a las filas de la tabla de tiempos. |

**Valores especiales:** `Z` significa alta impedancia: el transmisor libera la línea; `X` indica un valor indeterminado en la simulación, como cuando dos conductores imponen valores opuestos.

## Importante para tu proyecto

- En la foto actualizada, `Pin 29 FPGA` controla `OE`; en el TXS0101, `OE` alto habilita y bajo pone las salidas en alta impedancia. Consulta la sección 4 de `../explicacion_detallada_conexiones.md` para el pinout y la fuente TI.
- Esta demo usa **un solo cable de datos compartido**, por eso modela una transferencia half-duplex con turnos.
- El enlace serial clásico de Game Boy tiene `SO` y `SI` separados y un reloj compartido `SC`. En esa topología, ambos lados pueden enviar un bit simultáneamente por cables distintos; `OE` no es el mecanismo que arbitra esa comunicación.
- El TXS0101 real tiene detección automática de dirección. `OE` no fija el sentido, no escoge qué FPGA habla y no inicia el reloj.
