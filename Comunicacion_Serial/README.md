# Comunicación serial entre FPGA

## 1. Planteamiento del problema

Como parte del desarrollo del proyecto de interconexión entre placas FPGA, se requiere implementar un sistema de comunicación que permita el intercambio de información entre dos dispositivos. Esta comunicación es necesaria para transmitir los datos correspondientes al estado del juego, principalmente las posiciones de los jugadores, de manera que ambas placas puedan actualizar sus respectivas variables y mantener sincronizada la partida.

El sistema contempla dos dispositivos con funciones diferenciadas:

- **HOST:** encargado de generar la señal de reloj (`CLK`) y controlar el inicio de la comunicación mediante la señal `CS`.
- **GUEST:** recibe la señal de reloj generada por el HOST y utiliza sus flancos para sincronizar la transmisión y recepción de información.

Se dispone de una línea de transmisión (`TX`) y una línea de recepción (`RX`) para cada FPGA, permitiendo el intercambio simultáneo de información entre ambas placas.

## 2. Arquitectura de comunicación propuesta

Se propone implementar un protocolo de comunicación serial síncrona personalizado, utilizando un reloj compartido entre las dos FPGA.

El funcionamiento se establece bajo las siguientes condiciones:

1. El HOST genera la señal de reloj que sincroniza las operaciones de ambos dispositivos.
2. La señal `CS` habilita la comunicación e indica el inicio de la partida.
3. Los datos se transmiten serialmente, un bit por ciclo de reloj.
4. La actualización de las salidas de transmisión se realiza durante el flanco de subida del reloj.
5. La captura de los datos recibidos se realiza durante el flanco de bajada.
6. La comunicación es bidireccional, permitiendo que ambas FPGA transmitan y reciban información simultáneamente.

## 3. Organización de los datos

Debido a que cada palabra de información está compuesta por 32 bits, se plantea dividirla en cuatro paquetes consecutivos de 8 bits (bytes).

La FPGA receptora utiliza un registro de desplazamiento de 32 bits para reconstruir la información recibida.

Para controlar el proceso se implementan dos contadores:

- **Contador de bits (`bit_count`):** identifica los 8 bits correspondientes a cada byte.
- **Contador de bytes (`byte_count`):** identifica los cuatro bytes que conforman la palabra completa.

Una vez recibidos los 32 bits, se almacena la palabra reconstruida y se activa la señal `DATA_VALID`, indicando que la información está completa y puede ser utilizada por el sistema principal.

La organización de los datos se define de la siguiente manera:

\[
D = \{B_1,B_2,B_3,B_4\}
\]

Donde cada byte contiene 8 bits y la palabra completa contiene 32 bits.

## 4. Señales principales

| Señal | Descripción |
|---|---|
| `CLK` | Reloj generado por el HOST. |
| `CS` | Habilitación e inicio de la comunicación. |
| `TX` | Línea de transmisión de datos. |
| `RX` | Línea de recepción de datos. |
| `bit_count` | Contador de bits recibidos por byte. |
| `byte_count` | Contador de bytes recibidos. |
| `DATA_VALID` | Indica que se completó la recepción de 32 bits. |
| `rx_data` | Registro con la palabra reconstruida. |

## 5. Implementación en Verilog

El archivo `comunicacion_serial.v` contendrá:

- El módulo `serial_endpoint`, encargado de implementar las funciones de transmisión y recepción.
- El módulo `tb_serial_pingpong`, encargado de simular las dos FPGA y sus conexiones.

Para facilitar las primeras pruebas, ambos módulos se encuentran dentro de un único archivo Verilog.

## 6. Simulación

La simulación se realiza utilizando Icarus Verilog y GTKWave.

Desde la terminal, ubicándose en la carpeta que contiene el archivo, se ejecutan los siguientes comandos:

### Compilación

```bash
iverilog -g2012 -o comunicacion.out -s tb_serial_pingpong comunicacion_serial.v
```

### Ejecución

```bash
vvp comunicacion.out
```

### Visualización de señales

```bash
gtkwave comunicacion_serial.vcd
```

## 7. Pruebas iniciales

Para verificar el funcionamiento de la comunicación se utilizan patrones de prueba de 32 bits:

| Dirección | Dato transmitido |
|---|---|
| HOST → GUEST | `0xAABBCCDD` |
| GUEST → HOST | `0x11223344` |

Posteriormente se prueban nuevas palabras para verificar que el sistema puede realizar transmisiones consecutivas.

Se espera comprobar que ambas FPGA reconstruyan correctamente los datos recibidos y activen `DATA_VALID` al completar los cuatro bytes.

## 8. Estado actual del desarrollo

Esta implementación corresponde a una primera aproximación del protocolo de comunicación serial síncrona.

Quedan como aspectos para etapas posteriores:

- Adaptación de la lógica de comunicación a los pines físicos de las FPGA.
- Configuración de la frecuencia de reloj para el hardware.
- Integración con las variables del juego.
- Implementación de mecanismos de detección de errores.
- Validación de la comunicación entre las placas físicas.
