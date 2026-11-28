# Comunicación serial entre FPGA

## 1. Planteamiento del problema

Como parte del desarrollo del proyecto de interconexión entre placas FPGA, se requiere implementar un sistema de comunicación que permita el intercambio de información entre dos dispositivos. Esta comunicación es necesaria para transmitir los datos correspondientes al estado del juego, principalmente las posiciones de los jugadores, de manera que ambas placas puedan actualizar sus respectivas variables y mantener sincronizada la partida.

El sistema contempla dos dispositivos con funciones diferenciadas:

- **HOST:** encargado de generar la señal de reloj (`CLK`) y controlar el inicio de la comunicación mediante la señal `CS`.
- **GUEST:** recibe la señal de reloj generada por el HOST y utiliza sus flancos para sincronizar la transmisión y recepción de información.

En la implementación inicial se dispone de una línea de transmisión (`TX`) y una línea de recepción (`RX`) para cada FPGA, permitiendo el intercambio simultáneo de información entre ambas placas.

## 2. Arquitectura de comunicación propuesta

Se propone implementar un protocolo de comunicación serial síncrona personalizado, utilizando un reloj compartido entre las dos FPGA.

El funcionamiento se establece bajo las siguientes condiciones:

1. El HOST genera la señal de reloj que sincroniza las operaciones de ambos dispositivos.
2. La señal `CS` habilita la comunicación e indica el inicio de la transmisión.
3. Los datos se transmiten serialmente, un bit por ciclo de reloj.
4. La transmisión de los bits se realiza en el flanco de subida del reloj.
5. La recepción de los bits se realiza en el flanco de bajada.
6. En esta implementación inicial, la comunicación es bidireccional y simultánea, mediante líneas independientes de transmisión y recepción.

## 3. Organización y transmisión de los datos

Cada palabra de información está compuesta por 32 bits. Estos se transmiten secuencialmente, un bit por cada ciclo de reloj, sin dividir la transmisión en paquetes independientes de 8 bits.

Para realizar este proceso se utilizan registros de desplazamiento de 32 bits, tanto en el transmisor como en el receptor.

### 3.1. Transmisión

El transmisor utiliza un registro denominado `tx_shift`, en el cual se carga inicialmente la palabra completa de 32 bits proveniente de `tx_data`.

La transmisión comienza enviando el bit más significativo (MSB), correspondiente a la posición 31 del registro:

\[
TX = tx\_shift[31]
\]

En cada flanco de subida del reloj, el registro se desplaza una posición hacia la izquierda, introduciendo un cero por el bit menos significativo (LSB):

\[
tx\_shift \leftarrow \{tx\_shift[30:0],0\}
\]

De esta manera, el siguiente bit queda disponible en la salida `TX` para ser transmitido.

El procedimiento se repite hasta completar los 32 bits. Posteriormente, el transmisor carga nuevamente la palabra de entrada y comienza otra transmisión.

### 3.2. Recepción

El receptor utiliza un registro de desplazamiento denominado `rx_shift`, donde almacena progresivamente los bits recibidos por la entrada `RX`.

En cada flanco de bajada del reloj se realiza el siguiente desplazamiento:

\[
rx\_shift \leftarrow \{rx\_shift[30:0],RX\}
\]

Esto significa que el registro se desplaza una posición hacia la izquierda y el nuevo bit recibido ingresa por el LSB.

Como el transmisor envía primero el MSB y posteriormente los bits restantes en orden descendente, después de recibir los 32 bits el registro contiene nuevamente la palabra original.

### 3.3. Finalización de la recepción

Para controlar el proceso se utiliza un contador de bits (`bit_count`) de 5 bits, capaz de identificar las 32 posiciones de la palabra transmitida.

Cuando se recibe el bit número 32:

- Se completa la reconstrucción de la palabra.
- El contenido del registro de desplazamiento se almacena en `rx_data`.
- Se activa la señal `DATA_VALID`, indicando que la palabra completa está disponible.
- El contador se reinicia para preparar la siguiente recepción.

La palabra reconstruida corresponde a:

\[
rx\_data = \{rx\_shift[30:0],RX\}
\]

De esta manera, la información recibida queda disponible para ser utilizada por el sistema principal.

## 4. Señales principales

| Señal | Descripción |
|---|---|
| `CLK` | Reloj generado por el HOST. |
| `CS` | Habilitación e inicio de la comunicación. |
| `TX` | Línea serial de transmisión de datos. |
| `RX` | Línea serial de recepción de datos. |
| `tx_data` | Palabra de 32 bits que se desea transmitir. |
| `tx_shift` | Registro de desplazamiento utilizado por el transmisor. |
| `rx_shift` | Registro de desplazamiento utilizado por el receptor. |
| `bit_count` | Contador de bits recibidos, de 0 a 31. |
| `rx_data` | Registro que almacena la palabra de 32 bits reconstruida. |
| `DATA_VALID` | Indica que se completó la recepción de los 32 bits. |

Adicionalmente, se incluyen señales de observación para facilitar la verificación del funcionamiento mediante GTKWave:

- `tx_complete_word`: almacena la palabra completa cargada en el transmisor.
- `debug_tx_shift`: permite observar el contenido del registro de desplazamiento del transmisor.
- `debug_rx_shift`: permite observar el contenido del registro de desplazamiento del receptor.

## 5. Implementación en Verilog

El archivo `comunicacion_serial.v` contiene los siguientes módulos:

- **`serial_endpoint`:** encargado de implementar las funciones de transmisión y recepción serial, incluyendo los registros de desplazamiento y el control de los contadores.
- **`tb_serial_pingpong`:** banco de pruebas encargado de simular las dos FPGA, sus conexiones y el intercambio de información.

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

Para verificar el funcionamiento de la comunicación se utilizan inicialmente las siguientes palabras de prueba:

| Dirección | Dato transmitido |
|---|---|
| HOST → GUEST | `0xAABBCCDD` |
| GUEST → HOST | `0x11223344` |

Posteriormente se actualizan los datos de transmisión para comprobar el comportamiento con nuevas palabras:

| Dirección | Nuevo dato transmitido |
|---|---|
| HOST → GUEST | `0x12345678` |
| GUEST → HOST | `0x87654321` |

Se espera comprobar que:

1. Los transmisores carguen correctamente las palabras de 32 bits.
2. Los bits se transmitan comenzando por el más significativo.
3. Los registros de desplazamiento realicen correctamente el corrimiento en cada ciclo de reloj.
4. Los receptores reconstruyan las palabras originales.
5. La señal `DATA_VALID` se active al completar los 32 bits recibidos.

## 8. Estado actual del desarrollo

Esta implementación corresponde a una primera aproximación del protocolo de comunicación serial síncrona. La simulación permite verificar la transmisión, recepción y reconstrucción de palabras de 32 bits mediante registros de desplazamiento.

Quedan como aspectos para etapas posteriores:

- Adaptación del protocolo a la disponibilidad de conexiones físicas entre las FPGA.
- Evaluación de la transmisión y recepción utilizando una única línea de datos bidireccional, si las restricciones de conexión lo requieren.
- Configuración de la frecuencia de reloj para el hardware.
- Integración con las variables del juego.
- Implementación de mecanismos de detección de errores.
- Validación de la comunicación entre las placas físicas.
