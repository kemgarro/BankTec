ad; =============================================================================
; BANKTEC - Sistema Bancario en Assembly 8086
; Curso: Paradigmas de Programacion - ITCR
; Archivo: banktec.asm
;
; RESPONSABILIDADES POR PERSONA:
;   PERSONA 1 (este archivo):
;       - Infraestructura: estructuras de datos, constantes, buffers
;       - Utilidades de I/O: mostrarCadena, leerCadena, leerNumero
;       - Utilidades numericas: numeroAAscii, imprimirNumeroWord,
;                              imprimirDecimal4, imprimirSaldoEscalado
;       - Rutinas de cuenta: buscarCuentaPorNumero, verificarCuentaActiva
;   PERSONA 2:
;       - Modulos bancarios: crearCuenta, consultarSaldo
;       - depositarDinero, retirarDinero, desactivarCuenta
;   PERSONA 3:
;       - Menu principal interactivo
;       - Integracion final y flujo completo del sistema
;
; ESTABILIDAD: Las definiciones de esta seccion deben permanecer fijas.
;              Cualquier cambio en CUENTA_SIZE u offsets rompe TODOS los modulos.
; =============================================================================

.model small
.stack 100h

; =============================================================================
; CONSTANTES GLOBALES (EQU)
; =============================================================================

; Capacidad maxima del arreglo de cuentas
MAX_CUENTAS     EQU 10

; --- Estructura CUENTA (28 bytes por registro) ---
; Patron de acceso: EA = base + (indice * CUENTA_SIZE) + OFFSET_CAMPO
;
; +--------+------+--------+------------------------------------------+
; | Offset | Size | Campo  | Descripcion                              |
; +--------+------+--------+------------------------------------------+
; |   0    |  2B  | NUMERO | Identificador unico (Word)               |
; |   2    | 20B  | NOMBRE | Nombre del titular (ASCII, null-padded)  |
; |  22    |  4B  | SALDO  | Saldo x10000 escala entero (DWord)       |
; |  26    |  1B  | ESTADO | 0=inactiva / 1=activa                    |
; |  27    |  1B  | (pad)  | Padding de alineacion a 28 bytes         |
; +--------+------+--------+------------------------------------------+
;
; IMPORTANTE: no cambiar estos offsets sin actualizar TODOS los modulos.

CUENTA_NUMERO   EQU 0   ; offset 0  - Word  (2 bytes) - ID de cuenta
CUENTA_NOMBRE   EQU 2   ; offset 2  - 20 bytes        - nombre titular
CUENTA_SALDO    EQU 22  ; offset 22 - DWord (4 bytes) - saldo x10000
CUENTA_ESTADO   EQU 26  ; offset 26 - Byte  (1 byte)  - 0=inact / 1=act

CUENTA_SIZE     EQU 28  ; tamano total del registro (multiplo de 4)

; Tamano total del bloque de memoria reservado para el arreglo
BLOQUE_CUENTAS  EQU CUENTA_SIZE * MAX_CUENTAS   ; 28 * 10 = 280 bytes

; =============================================================================
; SEGMENTO DE DATOS
; =============================================================================
.data

; --- Arreglo principal de cuentas ---
; Almacena hasta MAX_CUENTAS entradas de CUENTA_SIZE bytes cada una.
; Inicializado con '?' (valores sin definir, basura de memoria).
; Layout en memoria (ejemplo con 2 cuentas):
;
; [0..27]  -> Cuenta 0
; [28..55] -> Cuenta 1
; ...
; [252..279] -> Cuenta 9
cuentas         DB BLOQUE_CUENTAS DUP(?)

; --- Variables de control global ---
; Cantidad de cuentas registradas actualmente (0..MAX_CUENTAS)
cantidadCuentas DB 0

; Codigo de ultimo error ocurrido.
; Es un registro de proposito general: su significado depende del modulo
; que lo escribio. Cada procedimiento documenta sus propios codigos.
; Convencion global compartida:
;   0x00 = Sin error (siempre)
; Codigos de leerNumero:
;   0x01 = Entrada vacia (el usuario solo presiono Enter)
;   0x02 = Caracter no numerico encontrado
; Codigos de buscarCuentaPorNumero:
;   0x03 = Cuenta no encontrada en el arreglo
; Codigos de verificarCuentaActiva:
;   0x04 = Cuenta inactiva
; Codigos de crearCuenta:
;   0x05 = Numero de cuenta ya existe (duplicado)
;   0x06 = Limite de cuentas alcanzado (cantidadCuentas = MAX_CUENTAS)
; Codigos de modulos bancarios (uso futuro):
;   0x07 = Saldo insuficiente
codigoError     DB 0

; --- Buffer de entrada de usuario (numeros e inputs generales) ---
; Estructura requerida por INT 21h / AH=0Ah (Buffered Keyboard Input):
;   Byte 0 : capacidad maxima (escrita por nosotros antes de llamar a DOS)
;   Byte 1 : cantidad de caracteres efectivamente leidos (DOS lo llena al retornar)
;   Byte 2+: caracteres capturados, terminados en CR (0Dh)
MAX_BUFFER      EQU 30
bufferEntrada   DB MAX_BUFFER       ; [0] capacidad maxima del buffer
                DB 0                ; [1] contador de bytes leidos (DOS lo actualiza)
                DB MAX_BUFFER DUP(0); [2..31] area de datos, prerellenada con ceros

; --- Buffer especifico para leer el nombre del titular en crearCuenta ---
; Separado de bufferEntrada para evitar solapamiento cuando ambos se usan
; en el mismo flujo de llamadas.
MAX_NOMBRE_BUF  EQU 21              ; 1 byte capacidad + 1 byte cuenta + 19 datos
bufferNombre    DB 19               ; [0] capacidad maxima: max 19 chars utiles
                DB 0                ; [1] contador leido por DOS
                DB 19 DUP(0)        ; [2..20] datos del nombre

; Variable temporal para preservar el numero de cuenta entre llamadas
tempNumero      DW 0                ; guarda AX durante crearCuenta

; --- Datos de prueba para verificar I/O ---
; Cadena terminada en '$' (requerido por INT 21h / AH=09h)
msgPrueba       DB 'BankTec iniciado. Ingresa un texto: $'

; Salto de linea separado para reutilizacion en cualquier modulo
msgNuevaLinea       DB 0Dh, 0Ah, '$'            ; CR + LF + centinela DOS

; --- Mensajes para el modulo leerNumero ---
msgIngresarNum      DB 'Ingrese un numero: $'          ; prompt de solicitud
msgErrorVacio       DB 0Dh, 0Ah,
                    DB 'ERROR: entrada vacia.$'        ; error 01h
msgErrorNoNumerico  DB 0Dh, 0Ah,
                    DB 'ERROR: caracter no numerico.$' ; error 02h

; --- Mensajes para el modulo buscarCuentaPorNumero ---
msgPedirNroCuenta   DB 'Ingrese numero de cuenta: $'
msgCuentaEncontrada DB 0Dh, 0Ah,
                    DB 'Cuenta encontrada. Indice: $'  ; + indice al debuggear
msgCuentaNoExiste   DB 0Dh, 0Ah,
                    DB 'ERROR: cuenta no encontrada.$' ; error 03h

; --- Mensajes para el modulo verificarCuentaActiva ---
msgCuentaActiva     DB 0Dh, 0Ah,
                    DB 'Estado: ACTIVA.$'              ; codigoError = 0
msgCuentaInactiva   DB 0Dh, 0Ah,
                    DB 'Estado: INACTIVA.$'            ; error 04h

; --- Mensajes para el modulo consultarSaldo ---
msgPedirNroConsulta DB 'Ingrese numero de cuenta a consultar: $'
msgSaldoActual      DB 0Dh, 0Ah, 'Saldo actual: $'  ; prefijo antes del numero
msgErrInactiva      DB 0Dh, 0Ah,
                    DB 'ERROR: cuenta inactiva.$'       ; error 04h
msgErrNoExiste      DB 0Dh, 0Ah,
                    DB 'ERROR: cuenta no encontrada.$'  ; error 03h

; --- Mensajes para el modulo crearCuenta ---
msgCcPedirNro       DB 'Ingrese numero de cuenta: $'
msgCcPedirNombre    DB 'Ingrese nombre del titular: $'
msgCcPedirSaldo     DB 'Ingrese saldo inicial entero: $'
msgCcExito          DB 0Dh, 0Ah, 'Cuenta creada correctamente.$'
msgCcRepetido       DB 0Dh, 0Ah, 'ERROR: numero de cuenta repetido.$'    ; error 05h
msgCcLimite         DB 0Dh, 0Ah, 'ERROR: limite de cuentas alcanzado.$'  ; error 06h

; --- Mensajes para el modulo depositarDinero ---
msgDepPedirNro      DB 'Ingrese numero de cuenta: $'
msgDepPedirMonto    DB 'Ingrese monto entero a depositar: $'
msgDepExito         DB 0Dh, 0Ah, 'Deposito realizado correctamente.$'
msgDepNuevoSaldo    DB 0Dh, 0Ah, 'Nuevo saldo: $'
msgDepErrNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'         ; error 03h
msgDepErrInactiva   DB 0Dh, 0Ah, 'ERROR: cuenta inactiva.$'              ; error 04h
msgDepErrMonto      DB 0Dh, 0Ah, 'ERROR: monto invalido (debe ser > 0).$' ; error 07h

; --- Mensajes para el modulo retirarDinero ---
msgRetPedirNro      DB 'Ingrese numero de cuenta: $'
msgRetPedirMonto    DB 'Ingrese monto entero a retirar: $'
msgRetExito         DB 0Dh, 0Ah, 'Retiro realizado correctamente.$'
msgRetNuevoSaldo    DB 0Dh, 0Ah, 'Nuevo saldo: $'
msgRetErrNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'          ; error 03h
msgRetErrInactiva   DB 0Dh, 0Ah, 'ERROR: cuenta inactiva.$'               ; error 04h
msgRetErrMonto      DB 0Dh, 0Ah, 'ERROR: monto invalido (debe ser > 0).$'  ; error 07h
msgRetErrFondos     DB 0Dh, 0Ah, 'ERROR: fondos insuficientes.$'           ; error 08h

; --- Mensajes para el modulo desactivarCuenta ---
msgDesPedirNro      DB 'Ingrese numero de cuenta: $'
msgDesExito         DB 0Dh, 0Ah, 'Cuenta desactivada correctamente.$'
msgDesErrNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'       ; error 03h
msgDesErrYaInactiva DB 0Dh, 0Ah, 'ERROR: cuenta ya inactiva.$'          ; error 04h (reutilizado)

; --- Recursos para el modulo numeroAAscii ---
; Buffer de salida: max 5 digitos para WORD (0..65535) + '$' + 1 byte de guarda
BUF_NUMERO_SIZE     EQU 7
bufferNumero        DB BUF_NUMERO_SIZE DUP(0)   ; destino de numeroAAscii

; Buffer temporal para dÃ­gitos en orden inverso (maximo 5 digitos de un WORD)
bufferDigitos       DB 5 DUP(0)

msgMostrarNumero    DB 'Numero convertido: $'
msgIndiceEncontrado DB 'Indice encontrado: $'

; --- Recursos para imprimirSaldoEscalado ---
; 4 digitos decimales + centinela '$'
bufferDecimal4  DB 6 DUP(0)
msgPunto        DB '.$'             ; punto decimal como cadena para mostrarCadena
msgSaldoMostrar DB 'Saldo: $'

; --- Mensajes del harness de prueba (main) ---
msgInicio       DB 'BankTec OK - Num: $'  ; prefijo prueba imprimirNumeroWord
msgSaldoPrueba  DB 'Saldo: $'             ; prefijo prueba imprimirSaldoEscalado

; =============================================================================
; SEGMENTO DE CODIGO
; =============================================================================
.code

; =============================================================================
; mostrarCadena
; PROPOSITO  : Imprime en stdout una cadena terminada en '$' via DOS.
; ENTRADA    : DX = offset de la cadena (debe terminar en '$')
; SALIDA     : Ninguna. Pantalla modificada.
; MODIFICA   : AH (push/pop de AX preserva el resto)
; PRESERVA   : AX, BX, CX, DI, SI
; ERRORES    : Ninguno. Si DX apunta a cadena sin '$', DOS imprimira hasta
;              encontrar uno (comportamiento indefinido del sistema).
; USO        : lea dx, miCadena
;              call mostrarCadena
; =============================================================================
mostrarCadena PROC
    push ax                 ; preservar AX antes de modificarlo
    mov  ah, 09h            ; funcion 09h: imprimir cadena terminada en '$'
    int  21h                ; llamada a DOS
    pop  ax                 ; restaurar AX
    ret
mostrarCadena ENDP

; =============================================================================
; leerCadena
; PROPOSITO  : Lee una cadena del teclado usando buffer estructurado DOS 0Ah.
;              Bloquea hasta que el usuario presiona Enter (CR = 0Dh).
; ENTRADA    : DX = offset de un buffer con estructura DOS 0Ah:
;                  byte 0 = capacidad maxima [inicializado por el llamador]
;                  byte 1 = contador de chars leidos [DOS lo sobreescribe]
;                  byte 2+ = area de datos (chars sin CR final)
; SALIDA     : El buffer queda relleno. byte 1 = cantidad chars leidos.
; MODIFICA   : AH (push/pop de AX preserva el resto)
; PRESERVA   : AX, BX, CX, DX, SI, DI
; ERRORES    : Ninguno directo. Si byte 0 = 0, DOS no lee nada.
; USO        : lea dx, bufferEntrada
;              call leerCadena
; =============================================================================
leerCadena PROC
    push ax                 ; preservar AX
    mov  ah, 0Ah            ; funcion 0Ah: entrada de cadena con buffer
    int  21h                ; llamada a DOS - bloquea hasta que el usuario presiona Enter
    pop  ax                 ; restaurar AX
    ret
leerCadena ENDP

; =============================================================================
; leerNumero
; PROPOSITO  : Lee un entero sin signo desde teclado, valida que solo
;              contenga digitos ASCII y lo convierte a binario en AX.
;              Algoritmo: AX = AX * 10 + (digito - '0') por cada char.
;              Usa bufferEntrada global (estructura DOS 0Ah).
; ENTRADA    : Ninguna. La lectura se hace internamente via leerCadena.
; SALIDA     : AX = numero convertido (valido SOLO si codigoError = 00h)
;              codigoError (variable global):
;                00h = exito, AX contiene el numero
;                01h = entrada vacia (usuario solo presiono Enter)
;                02h = caracter no numerico encontrado
; MODIFICA   : AX, BX, CX, SI, codigoError
; PRESERVA   : DX
; LIMITACION : Maximo 65535 (16 bits sin signo). Sin deteccion de overflow.
; USO        : call leerNumero
;              cmp  byte ptr [codigoError], 00h
;              jne  manejarError
;              ; AX tiene el numero
; =============================================================================
leerNumero PROC
    push dx                     ; preservar DX (no lo usamos pero es buena practica)
    push si                     ; SI apuntara al inicio de los datos del buffer

    ; --- Paso 1: llamar a leerCadena para capturar la entrada ---
    ; bufferEntrada ya tiene MAX_BUFFER en byte 0; DOS llena byte 1 con el conteo.
    lea  dx, bufferEntrada
    call leerCadena

    ; Emitir salto de linea despues del Enter del usuario
    lea  dx, msgNuevaLinea
    call mostrarCadena

    ; --- Paso 2: leer el conteo de caracteres ingresados ---
    ; bufferEntrada+1 contiene la cantidad de bytes leidos (sin incluir CR)
    mov  cl, [bufferEntrada+1]  ; CL = cantidad de caracteres
    xor  ch, ch                 ; CH = 0 -> CX = extension de CL a 16 bits

    ; --- Paso 3: verificar que no sea entrada vacia ---
    cmp  cx, 0
    jne  lnValidarDigitos       ; si CX > 0, hay caracteres: ir a validar
    ; entrada vacia: marcar error 01h y salir
    mov  byte ptr [codigoError], 01h
    xor  ax, ax                 ; AX = 0 (resultado indefinido)
    jmp  lnFin

lnValidarDigitos:
    ; --- Paso 4: apuntar SI al primer caracter de datos (bufferEntrada+2) ---
    lea  si, bufferEntrada
    add  si, 2                  ; SI ahora apunta a bufferEntrada[2]

    xor  ax, ax                 ; AX = acumulador del resultado (empieza en 0)
    mov  byte ptr [codigoError], 00h ; asumir exito hasta encontrar error

lnBucle:
    ; --- Paso 5: recorrer cada caracter y validar ---
    cmp  cx, 0
    je   lnExito                ; si CX = 0 recorrimos todo: salir con exito

    mov  bl, [si]               ; BL = caracter actual
    xor  bh, bh                 ; BH = 0 -> BX = extension de BL

    ; Validar rango '0' (30h) a '9' (39h)
    cmp  bl, '0'
    jb   lnErrorNoNumerico      ; caracter < '0': no es digito
    cmp  bl, '9'
    ja   lnErrorNoNumerico      ; caracter > '9': no es digito

    ; --- Paso 6: conversion ASCII -> valor entero ---
    ; d = BL - '0'  (convierte caracter ASCII a valor 0..9)
    sub  bl, '0'

    ; AX = AX * 10
    mov  dx, 10                 ; multiplicador
    mul  dx                     ; DX:AX = AX * 10 (mul usa DX, por eso lo resguardamos)
    ; Nota: si AX > 6553 aqui, DX != 0 (desbordamiento). Para esta etapa
    ; no validamos overflow; se controlara cuando se implemente rango de montos.

    ; AX = AX + digito
    add  ax, bx                 ; AX += (valor del digito)

    inc  si                     ; avanzar al siguiente caracter
    dec  cx                     ; decrementar contador
    jmp  lnBucle

lnExito:
    mov  byte ptr [codigoError], 00h ; confirmar exito
    jmp  lnFin

lnErrorNoNumerico:
    mov  byte ptr [codigoError], 02h ; error: caracter invalido
    xor  ax, ax                     ; AX = 0 (resultado invalido)

lnFin:
    pop  si                     ; restaurar SI
    pop  dx                     ; restaurar DX
    ret
leerNumero ENDP

; =============================================================================
; buscarCuentaPorNumero
; PROPOSITO  : Busqueda lineal en el arreglo 'cuentas'. Compara
;              CUENTA_NUMERO (Word en offset 0) de cada registro contra AX.
;              SI queda apuntando al registro si se encuentra.
;
; CONTRATO DE SI (CRITICO para modulos dependientes):
;   codigoError=00h -> SI VALIDO, apunta a base del registro encontrado.
;                      El llamador puede usar [SI+CUENTA_NOMBRE],
;                      [SI+CUENTA_SALDO], [SI+CUENTA_ESTADO] directamente.
;   codigoError=03h -> SI INVALIDO. El llamador NO debe usarlo.
;
; ENTRADA    : AX = numero de cuenta a buscar
; SALIDA     : BL = indice 0-based del registro encontrado
;                   BL = 0FFh si no se encontro (centinela)
;              SI = puntero al registro (valido SOLO si codigoError=00h)
;              codigoError:
;                00h = cuenta encontrada, SI valido
;                03h = cuenta no encontrada, SI invalido
; MODIFICA   : BX, CX, SI
; PRESERVA   : AX, DX
; ERRORES    : 03h = cuenta no encontrada
; =============================================================================
buscarCuentaPorNumero PROC
    push ax                         ; preservar AX (numero buscado entra por AX)
    push dx                         ; preservar DX
    ; NOTA: SI NO se preserva. Es intencionalmente un valor de retorno
    ;       cuando codigoError = 00h.

    ; --- Paso 1: cargar el numero de iteraciones a recorrer ---
    xor  cx, cx
    mov  cl, [cantidadCuentas]      ; CX = cantidad de cuentas activas
    cmp  cx, 0
    je   bcpNoEncontrado            ; arreglo vacio: salir de inmediato

    ; --- Paso 2: apuntar SI a la base del primer registro ---
    lea  si, cuentas                ; SI = &cuentas[0]
    xor  bx, bx                     ; BL = indice actual (empieza en 0)

bcpBucle:
    ; --- Paso 3: comparar CUENTA_NUMERO del registro actual con AX ---
    mov  dx, word ptr [si + CUENTA_NUMERO]  ; leer numero de esta cuenta
    cmp  dx, ax
    je   bcpEncontrado

    ; --- Paso 4: avanzar al registro siguiente ---
    add  si, CUENTA_SIZE            ; SI -> siguiente registro
    inc  bl                         ; siguiente indice
    dec  cx
    jnz  bcpBucle

bcpNoEncontrado:
    mov  byte ptr [codigoError], 03h
    mov  bl, 0FFh                   ; centinela: indice invalido
    ; SI queda en estado indefinido; el llamador no debe usarlo
    jmp  bcpFin

bcpEncontrado:
    ; SI ya apunta a la base del registro coincidente -> no se restaura
    mov  byte ptr [codigoError], 00h

bcpFin:
    pop  dx
    pop  ax
    ret
buscarCuentaPorNumero ENDP

; =============================================================================
; verificarCuentaActiva
; PROPOSITO  : Comprueba si la cuenta apuntada por SI esta activa.
;              Debe llamarse SOLO tras buscarCuentaPorNumero con codigoError=00h,
;              ya que depende del contrato de SI.
; ENTRADA    : SI = direccion base del registro (de buscarCuentaPorNumero).
;              Lectura: byte ptr [SI + CUENTA_ESTADO].
;                1 = activa / 0 = inactiva
; SALIDA     : codigoError:
;                00h = cuenta activa
;                04h = cuenta inactiva
; MODIFICA   : AL, codigoError
; PRESERVA   : AX (via push/pop), BX, CX, DX, SI
; ERRORES    : 04h = cuenta inactiva
; =============================================================================
verificarCuentaActiva PROC
    push ax                             ; preservar AX completo

    mov  al, byte ptr [si + CUENTA_ESTADO]  ; leer campo ESTADO del registro
    cmp  al, 1                              ; 1 = activa
    je   vcaActiva

    ; Estado != 1 -> cuenta inactiva
    mov  byte ptr [codigoError], 04h
    jmp  vcaFin

vcaActiva:
    mov  byte ptr [codigoError], 00h    ; cuenta activa: sin error

vcaFin:
    pop  ax
    ret
verificarCuentaActiva ENDP

; -----------------------------------------------------------------------------
; consultarSaldo
; Busca una cuenta por numero, verifica que este activa y accede a su saldo.
; Encapsula la secuencia: buscar -> verificar -> leer DWORD campo SALDO.
;
; El saldo esta almacenado como DWORD (4 bytes) escalado por 10000.
; Ejemplo: saldo real $12.3456 se almacena como 123456 (00h 01h E2h 40h en memoria).
;
; Acceso al DWORD en 8086 (sin instrucciones de 32 bits):
;   La CPU 8086 no tiene registros de 32 bits nativos.
;   Se accede en dos partes:
;     palabra baja  -> word ptr [SI + CUENTA_SALDO]     -> AX
;     palabra alta  -> word ptr [SI + CUENTA_SALDO + 2] -> DX
;   El valor completo es DX:AX (DX = 16 bits altos, AX = 16 bits bajos).
;
; Entrada : AX = numero de cuenta a consultar
; Salida  : codigoError:
;             00h = cuenta encontrada y activa; DX:AX = saldo bruto (x10000)
;             03h = cuenta no encontrada
;             04h = cuenta inactiva
;           (SI queda valido si codigoError = 00h, herencia de buscarCuentaPorNumero)
; Modifica: AX, DX (saldo), BX, CX, SI
; Preserva: nada adicional (AX y DX son valores de retorno)
; -----------------------------------------------------------------------------
consultarSaldo PROC
    ; --- Paso 1: buscar la cuenta por numero ---
    ; AX entra como parametro; buscarCuentaPorNumero lo preserva internamente.
    call buscarCuentaPorNumero

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  csFin                      ; si error 03h: cuenta no existe, salir

    ; --- Paso 2: verificar que la cuenta este activa ---
    ; SI apunta al registro (contrato de buscarCuentaPorNumero con codigoError=00h)
    call verificarCuentaActiva

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  csFin                      ; si error 04h: cuenta inactiva, salir

    ; --- Paso 3: leer el DWORD de saldo ---
    ; DWORD = 4 bytes. En 8086 se accede como dos Words consecutivos.
    ; AX = palabra baja del saldo  (bits 0-15)
    ; DX = palabra alta del saldo  (bits 16-31)
    ; --- Paso 3: leer el DWORD de saldo y mostrarlo ---
    ; El DWORD se accede como dos Words: baja (bits 0-15) y alta (bits 16-31).
    ; El orden importa: primero baja, luego alta, para formar DX:AX correctamente.
    mov  ax, word ptr [si + CUENTA_SALDO]       ; AX = word baja (bits 0-15)
    mov  dx, word ptr [si + CUENTA_SALDO + 2]   ; DX = word alta (bits 16-31)
    ; DX:AX ahora tiene el saldo bruto escalado x10000

    ; Mostrar etiqueta antes del numero
    push ax                             ; preservar AX (imprimirSaldoActual destruye DX)
    push dx
    lea  dx, msgSaldoActual
    call mostrarCadena
    pop  dx
    pop  ax

    ; Delegar el formato decimal a imprimirSaldoEscalado
    call imprimirSaldoEscalado          ; consume DX:AX, imprime "entero.DDDD"

    ; Salto de linea tras el saldo
    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  byte ptr [codigoError], 00h    ; confirmar exito

csFin:
    ret
consultarSaldo ENDP

; -----------------------------------------------------------------------------
; crearCuenta
; Registra una nueva cuenta en el arreglo 'cuentas'.
; Flujo:
;   1. Verificar capacidad (cantidadCuentas < MAX_CUENTAS)
;   2. Pedir y leer numero de cuenta
;   3. Verificar que no exista duplicado (buscarCuentaPorNumero)
;   4. Pedir y copiar nombre del titular (max 19 chars, zero-pad a 20)
;   5. Pedir saldo inicial entero y escalarlo x10000 con MUL
;   6. Escribir todos los campos en el slot [cantidadCuentas]
;   7. Incrementar cantidadCuentas
;
; Entrada : ninguna
; Salida  : codigoError:
;             00h = cuenta creada con exito
;             01h/02h = error de lectura numerica (de leerNumero)
;             05h = numero de cuenta ya existe
;             06h = limite MAX_CUENTAS alcanzado
; Modifica: AX, BX, CX, DX, SI, DI
; Preserva: nada
; -----------------------------------------------------------------------------
crearCuenta PROC

    ; ==========================================================================
    ; BLOQUE 1: Verificar si hay espacio disponible
    ; ==========================================================================
    mov  al, [cantidadCuentas]
    cmp  al, MAX_CUENTAS
    jb   ccHayEspacio
    ; sin espacio: marcar error y salir
    mov  byte ptr [codigoError], 06h
    lea  dx, msgCcLimite
    call mostrarCadena
    jmp  ccFin

ccHayEspacio:
    ; ==========================================================================
    ; BLOQUE 2: Pedir y leer numero de cuenta
    ; ==========================================================================
    lea  dx, msgCcPedirNro
    call mostrarCadena
    call leerNumero                 ; AX = numero ingresado

    ; Verificar que leerNumero no haya fallado
    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  ccFin                      ; error 01h o 02h: salir propagando codigoError

    ; Guardar numero en variable temporal para sobrevivir llamadas posteriores
    mov  [tempNumero], ax

    ; ==========================================================================
    ; BLOQUE 3: Verificar que el numero no exista ya
    ; buscarCuentaPorNumero: preserva AX internamente, lo usa como parametro.
    ; ==========================================================================
    call buscarCuentaPorNumero      ; AX = numero (aun valido)

    mov  bl, [codigoError]
    cmp  bl, 03h                    ; 03h = NO ENCONTRADO = bueno, podemos crear
    je   ccNumeroLibre
    ; si codigoError = 00h significa que SI existe -> duplicado
    mov  byte ptr [codigoError], 05h
    lea  dx, msgCcRepetido
    call mostrarCadena
    jmp  ccFin

ccNumeroLibre:
    ; ==========================================================================
    ; BLOQUE 4: Calcular direccion base del nuevo slot en el arreglo
    ; Indice = cantidadCuentas (apuntara al primer slot libre).
    ; offset = indice * CUENTA_SIZE
    ; SI = &cuentas[indice]
    ; ==========================================================================
    xor  ax, ax
    mov  al, [cantidadCuentas]      ; AL = indice del nuevo registro
    mov  bx, CUENTA_SIZE            ; BX = 28
    mul  bx                         ; AX = indice * 28 (cabe en Word, max = 9*28=252)
    lea  si, cuentas
    add  si, ax                     ; SI apunta al slot libre

    ; Escribir numero de cuenta (recuperar de tempNumero)
    mov  ax, [tempNumero]
    mov  word ptr [si + CUENTA_NUMERO], ax

    ; Marcar cuenta como activa desde el principio
    mov  byte ptr [si + CUENTA_ESTADO], 1

    ; ==========================================================================
    ; BLOQUE 5: Pedir y copiar nombre del titular
    ; ==========================================================================
    lea  dx, msgCcPedirNombre
    call mostrarCadena

    ; leerCadena usa el buffer apuntado por DX (estructura DOS 0Ah)
    lea  dx, bufferNombre
    call leerCadena
    lea  dx, msgNuevaLinea
    call mostrarCadena

    ; --- Copiar nombre al campo CUENTA_NOMBRE (20 bytes, max 19 utiles + null) ---
    ; DI = destino en el registro (SI + CUENTA_NOMBRE)
    ; Source apunta a bufferNombre+2 (datos efectivos)
    push si                         ; preservar base del registro durante la copia

    mov  di, si
    add  di, CUENTA_NOMBRE          ; DI = &registro.nombre

    lea  si, bufferNombre
    add  si, 2                      ; SI = primer byte del nombre leido

    xor  cx, cx
    mov  cl, [bufferNombre+1]       ; CX = cantidad de chars leidos por DOS
    cmp  cx, 19
    jbe  ccCopiar
    mov  cx, 19                     ; truncar a 19 para respetar el campo

ccCopiar:
    mov  bx, cx                     ; BX = chars a copiar (para calculo de padding)

ccCopyLoop:
    cmp  cx, 0
    je   ccPad
    mov  al, [si]
    mov  [di], al
    inc  si
    inc  di
    dec  cx
    jmp  ccCopyLoop

ccPad:
    ; Rellenar el resto del campo de 20 bytes con 0h
    mov  cx, 20
    sub  cx, bx                     ; CX = bytes de padding necesarios

ccPadLoop:
    cmp  cx, 0
    je   ccNombreListo
    mov  byte ptr [di], 0
    inc  di
    dec  cx
    jmp  ccPadLoop

ccNombreListo:
    pop  si                         ; restaurar base del registro

    ; ==========================================================================
    ; BLOQUE 6: Pedir saldo inicial y escalarlo x10000
    ; ==========================================================================
    lea  dx, msgCcPedirSaldo
    call mostrarCadena
    call leerNumero                 ; AX = saldo entero ingresado

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  ccFin                      ; error de lectura: propagar codigoError

    ; Escalar: AX * 10000 -> DX:AX (DWORD de 32 bits)
    ; MUL de 16 bits: AX * BX -> DX:AX
    ; Maximo: 65535 * 10000 = 655,350,000 < 4,294,967,295 -> sin overflow de DWORD
    mov  bx, 10000
    mul  bx                         ; DX:AX = AX * 10000

    ; Guardar DWORD en CUENTA_SALDO (little-endian: low word primero)
    mov  word ptr [si + CUENTA_SALDO],     ax   ; bits 0-15
    mov  word ptr [si + CUENTA_SALDO + 2], dx   ; bits 16-31

    ; ==========================================================================
    ; BLOQUE 7: Registrar la nueva cuenta
    ; ==========================================================================
    inc  byte ptr [cantidadCuentas] ; una cuenta mas en el sistema

    lea  dx, msgCcExito
    call mostrarCadena

    mov  byte ptr [codigoError], 00h

ccFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
crearCuenta ENDP

; =============================================================================
; numeroAAscii
; PROPOSITO  : Convierte un entero sin signo de 16 bits a representacion
;              ASCII decimal en el buffer DI, terminada con '$'.
;              Algoritmo: division sucesiva entre 10 extrae digitos de menor
;              a mayor peso -> se invierten al copiar al buffer final.
;              Caso especial: AX=0 escribe directamente '0$'.
; ENTRADA    : AX = numero a convertir (0..65535)
;              DI = offset del buffer de salida (minimo 7 bytes disponibles)
; SALIDA     : [DI..] = cadena ASCII decimal terminada en '$'
; MODIFICA   : AX, BX, CX, DX, SI, DI
; PRESERVA   : Nada. El llamador debe preservar DI si lo necesita despues.
; ERRORES    : Ninguno. Rango valido 0..65535.
; USO        : lea di, bufferNumero
;              mov ax, 1234
;              call numeroAAscii
;              lea dx, bufferNumero
;              call mostrarCadena
; =============================================================================
numeroAAscii PROC
    push si                         ; SI se usa como puntero al buffer temporal

    ; --- Caso especial: AX = 0 ---
    ; El bucle de division genera 0 iteraciones para AX=0, produciendo
    ; una cadena vacia. Se maneja de forma explicita.
    cmp  ax, 0
    jne  naaBucle
    mov  byte ptr [di],   '0'       ; escribir caracter '0'
    mov  byte ptr [di+1], '$'       ; terminar cadena
    jmp  naaFin

naaBucle:
    ; --- Generar digitos en orden inverso en bufferDigitos ---
    ; Inicializar SI al inicio del buffer temporal y CX como contador de digitos
    lea  si, bufferDigitos          ; SI = inicio del buffer temporal
    xor  cx, cx                     ; CX = 0 (contador de digitos generados)

naaExtraer:
    ; Si AX = 0, ya no hay mas digitos que extraer
    cmp  ax, 0
    je   naaInvertir

    xor  dx, dx                     ; DX:AX = AX (extension a 32 bits para DIV)
    mov  bx, 10                     ; divisor = 10
    div  bx                         ; AX = AX / 10, DX = AX MOD 10

    ; DX contiene el digito (0..9). Convertir a ASCII sumando '0' (30h)
    add  dl, '0'                    ; DL = caracter ASCII del digito
    mov  [si], dl                   ; guardar en buffer temporal
    inc  si                         ; avanzar puntero temporal
    inc  cx                         ; un digito mas
    jmp  naaExtraer

naaInvertir:
    ; --- Copiar digitos en orden inverso hacia el buffer de salida DI ---
    ; bufferDigitos tiene los digitos del menos significativo al mas significativo.
    ; Hay que escribirlos al reves en DI para obtener el orden correcto.
    ;   SI apunta al byte DESPUES del ultimo digito guardado.
    ;   Decrementamos SI antes de leer cada digito.
    ; CX = cantidad total de digitos a copiar.

naaCopiaBucle:
    cmp  cx, 0
    je   naaTerminar
    dec  si                         ; retroceder al ultimo digito no copiado
    mov  al, [si]                   ; leer digito
    mov  [di], al                   ; escribir en buffer de salida
    inc  di                         ; avanzar puntero de salida
    dec  cx
    jmp  naaCopiaBucle

naaTerminar:
    mov  byte ptr [di], '$'         ; centinela DOS para mostrarCadena

naaFin:
    pop  si
    ret
numeroAAscii ENDP

; =============================================================================
; imprimirNumeroWord
; PROPOSITO  : Muestra en pantalla un entero sin signo de 16 bits en decimal.
;              Wrapper sobre numeroAAscii + mostrarCadena.
;              Separacion de responsabilidades:
;                numeroAAscii  = utilidad pura (bits -> texto, sin I/O)
;                imprimirNumeroWord = accion de salida (imprime y listo)
; ENTRADA    : AX = numero a imprimir (0..65535)
; SALIDA     : Ninguna. Pantalla modificada.
; MODIFICA   : DX, DI y todo lo que modifica numeroAAscii (AX, BX, CX, SI)
; PRESERVA   : Nada adicional
; ERRORES    : Ninguno
; USO        : mov ax, miNumero
;              call imprimirNumeroWord
; =============================================================================
imprimirNumeroWord PROC
    ; Paso 1: convertir AX a cadena ASCII en bufferNumero
    ; DI debe apuntar al buffer antes de llamar a numeroAAscii.
    lea  di, bufferNumero
    call numeroAAscii               ; bufferNumero queda con la cadena + '$'

    ; Paso 2: imprimir la cadena resultante
    lea  dx, bufferNumero
    call mostrarCadena
    ret
imprimirNumeroWord ENDP

; =============================================================================
; imprimirDecimal4
; PROPOSITO  : Imprime exactamente 4 digitos decimales con ceros a la
;              izquierda. Usado para la parte fraccionaria de un saldo
;              escalado x10000. Ej: 42 -> "0042" | 1000 -> "1000".
;              Algoritmo: 4 divisiones fijas entre 10, genera digitos
;              del menos al mas significativo, los escribe en bufferDecimal4
;              con indices directos (sin inversion en bucle).
; ENTRADA    : DX = parte decimal (0..9999). Valor de DX:AX mod 10000.
; SALIDA     : Imprime 4 caracteres ASCII en pantalla.
; MODIFICA   : AX, BX, CX, DX, SI, DI
; PRESERVA   : Nada
; ERRORES    : Ninguno. Si DX > 9999, el resultado visual es incorrecto.
; =============================================================================
imprimirDecimal4 PROC
    push si

    ; --- Extraer 4 digitos en orden inverso ---
    ; bufferDecimal4 recibe los digitos de menor a mayor peso.
    lea  si, bufferDecimal4
    mov  ax, dx                     ; AX = parte decimal (0..9999)
    xor  dx, dx                     ; limpiar DX para las divisiones

    ; Digito 0 (unidades) : AX mod 10
    mov  bx, 10
    div  bx                         ; AX = AX/10, DX = AX%10
    add  dl, '0'
    mov  [si+3], dl                 ; posicion 3 (menos significativo, va al final)
    xor  dx, dx

    ; Digito 1 (decenas)
    div  bx
    add  dl, '0'
    mov  [si+2], dl
    xor  dx, dx

    ; Digito 2 (centenas)
    div  bx
    add  dl, '0'
    mov  [si+1], dl
    xor  dx, dx

    ; Digito 3 (millares) : lo que quede en AX es el digito mas significativo
    div  bx
    add  dl, '0'
    mov  [si+0], dl

    ; Terminar cadena con centinela DOS
    mov  byte ptr [si+4], '$'

    ; Imprimir los 4 digitos
    lea  dx, bufferDecimal4
    call mostrarCadena

    pop  si
    ret
imprimirDecimal4 ENDP

; =============================================================================
; imprimirSaldoEscalado
; PROPOSITO  : Muestra en pantalla un saldo DWORD escalado x10000 en el
;              formato legible "entero.DDDD".
;              Ejemplo: DX:AX = 123456 -> imprime "12.3456"
;
;              Division de 32 bits en dos pasos (8086 sin div32):
;              Paso A: dividir word alta (DX / 10000)
;                DX = DX_high, AX = 0 -> DIV 10000
;                resultado: AX=cociente alto (ignorado para saldos<$65535),
;                           DX=resto -> extension para paso B.
;              Paso B: dividir word baja con extension del paso A
;                AX = AX_low original, DX = resto del paso A
;                DIV 10000 -> AX=parte entera, DX=decimales (0..9999)
;
; ENTRADA    : DX:AX = saldo bruto (DWORD escalado x10000)
; SALIDA     : Imprime "entero.DDDD" en pantalla
; MODIFICA   : AX, BX, CX, DX, SI, DI
; PRESERVA   : Nada
; ERRORES    : Overflow si parte entera > 65535 (saldo > $65535.9999).
;              Esta version soporta hasta $65535.9999.
; =============================================================================
imprimirSaldoEscalado PROC
    mov  bx, 10000                  ; divisor constante

    ; --- Paso A: dividir la mitad alta (DX / 10000) ---
    mov  cx, ax                     ; CX = guardar word baja de DX:AX
    mov  ax, dx                     ; AX = word alta
    xor  dx, dx                     ; DX = 0 para division de solo 16 bits
    div  bx                         ; AX = DX_high / 10000 (cociente alto, ignorado)
                                    ; DX = DX_high % 10000 (resto -> extension para paso B)

    ; --- Paso B: dividir la mitad baja con el resto como extension ---
    mov  ax, cx                     ; AX = low word original
    div  bx                         ; DX:AX / 10000
                                    ; AX = parte entera del saldo
                                    ; DX = parte decimal (0..9999)

    ; --- Imprimir parte entera ---
    ; AX tiene la parte entera; imprimirNumeroWord la consume.
    ; Guardar DX (parte decimal) antes de que imprimirNumeroWord lo destruya.
    push dx                         ; preservar parte decimal en pila
    call imprimirNumeroWord         ; imprime AX como decimal

    ; --- Imprimir punto decimal ---
    push dx                         ; DX fue restaurado por mostrarCadena; guardarlo
    lea  dx, msgPunto
    call mostrarCadena
    pop  dx                         ; restaurar lo que teniamos

    ; --- Imprimir 4 digitos decimales con ceros a la izquierda ---
    pop  dx                         ; recuperar la parte decimal de la pila
    call imprimirDecimal4

    ret
imprimirSaldoEscalado ENDP

; -----------------------------------------------------------------------------
; depositarDinero
; Deposita un monto entero positivo en una cuenta existente y activa.
; El monto se escala x10000 y se suma al DWORD saldo con propagacion de carry.
;
; Flujo:
;   1. Pedir numero de cuenta -> buscarCuentaPorNumero
;   2. verificarCuentaActiva  (usa SI heredado de la busqueda)
;   3. Pedir monto entero -> validar > 0 -> escalar x10000 (MUL)
;   4. Sumar DWORD: ADD low word + ADC high word
;   5. Mostrar saldo actualizado con imprimirSaldoEscalado
;
; Suma DWORD de 32 bits en 8086 (sin instrucciones de 32 bits):
;   add word ptr [si + CUENTA_SALDO],     ax_low   ; CF = carry del word bajo
;   adc word ptr [si + CUENTA_SALDO + 2], dx_high  ; suma high + CF del paso anterior
; ADC (Add with Carry) propaga automaticamente el acarreo de la suma baja.
;
; Entrada : ninguna
; Salida  : codigoError:
;             00h = deposito exitoso
;             01h/02h = error de leerNumero
;             03h = cuenta no encontrada
;             04h = cuenta inactiva
;             07h = monto invalido (cero ingresado)
; Modifica: AX, BX, CX, DX, SI, DI
; Preserva: nada
; -----------------------------------------------------------------------------
depositarDinero PROC

    ; ==========================================================================
    ; BLOQUE 1: Pedir y buscar la cuenta
    ; ==========================================================================
    lea  dx, msgDepPedirNro
    call mostrarCadena
    call leerNumero                 ; AX = numero de cuenta

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  depFin                     ; error 01h/02h: propagar y salir

    ; Buscar la cuenta; si existe, SI queda apuntando al registro
    call buscarCuentaPorNumero

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   depVerificar
    lea  dx, msgDepErrNoExiste      ; error 03h
    call mostrarCadena
    jmp  depFin

depVerificar:
    ; ==========================================================================
    ; BLOQUE 2: Verificar que la cuenta este activa
    ; SI sigue apuntando al registro (contrato de buscarCuentaPorNumero)
    ; ==========================================================================
    call verificarCuentaActiva

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   depPedirMonto
    lea  dx, msgDepErrInactiva      ; error 04h
    call mostrarCadena
    jmp  depFin

depPedirMonto:
    ; ==========================================================================
    ; BLOQUE 3: Pedir monto y validarlo
    ; ==========================================================================
    lea  dx, msgDepPedirMonto
    call mostrarCadena
    call leerNumero                 ; AX = monto entero

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  depFin                     ; error 01h/02h

    ; Validar: monto debe ser mayor que 0
    cmp  ax, 0
    jne  depEscalar
    mov  byte ptr [codigoError], 07h
    lea  dx, msgDepErrMonto
    call mostrarCadena
    jmp  depFin

depEscalar:
    ; ==========================================================================
    ; BLOQUE 4: Escalar monto x10000 -> DX:AX
    ; AX * 10000 usando MUL de 16 bits; resultado en DX:AX (32 bits).
    ; SI podria haber sido modificado por leerNumero? No: leerNumero no toca SI.
    ; ==========================================================================
    mov  bx, 10000
    mul  bx                         ; DX:AX = monto * 10000

    ; ==========================================================================
    ; BLOQUE 5: Sumar DWORD monto al DWORD saldo de la cuenta
    ; Tecnica ADD + ADC para propagacion de carry entre words:
    ;   ADD: suma word baja, puede generar carry (CF = 1 si hay desbordamiento)
    ;   ADC: suma word alta + CF del paso anterior
    ; ==========================================================================
    add  word ptr [si + CUENTA_SALDO],     ax   ; low word: saldo_low += monto_low
    adc  word ptr [si + CUENTA_SALDO + 2], dx   ; high word: saldo_high += monto_high + CF

    ; ==========================================================================
    ; BLOQUE 6: Mostrar resultado
    ; ==========================================================================
    lea  dx, msgDepExito
    call mostrarCadena

    ; Mostrar nuevo saldo (recargar DX:AX desde memoria porque ADD/ADC no lo devuelven)
    lea  dx, msgDepNuevoSaldo
    call mostrarCadena

    mov  ax, word ptr [si + CUENTA_SALDO]       ; recargar low word
    mov  dx, word ptr [si + CUENTA_SALDO + 2]   ; recargar high word
    call imprimirSaldoEscalado

    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  byte ptr [codigoError], 00h

depFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
depositarDinero ENDP

; -----------------------------------------------------------------------------
; retirarDinero
; Retira un monto entero positivo de una cuenta existente y activa.
; Valida que el saldo sea mayor o igual al monto antes de restar.
;
; Comparacion DWORD en 8086 (monto vs saldo actual):
;   El 8086 no puede comparar dos valores de memoria de 32 bits en una sola
;   instruccion. Se compara word por word, de mayor a menor peso:
;     1. Comparar high words: si monto_high > saldo_high -> fondos insuficientes
;     2. Si high words son iguales, comparar low words:
;        si monto_low > saldo_low -> fondos insuficientes
;     3. Si monto_low == saldo_low y monto_high == saldo_high -> saldo exacto (ok)
;
; Resta DWORD de 32 bits con SBB:
;   sub word ptr [si + CUENTA_SALDO],     ax  ; resta low word; BF=1 si hay borrow
;   sbb word ptr [si + CUENTA_SALDO + 2], dx  ; resta high word y sustrae BF anterior
; SBB (Subtract with Borrow) propaga el borrow igual que ADC propaga el carry.
;
; Entrada : ninguna
; Salida  : codigoError:
;             00h = retiro exitoso
;             01h/02h = error de leerNumero
;             03h = cuenta no encontrada
;             04h = cuenta inactiva
;             07h = monto invalido (cero ingresado)
;             08h = fondos insuficientes
; Modifica: AX, BX, CX, DX, SI
; Preserva: nada
; -----------------------------------------------------------------------------
retirarDinero PROC

    ; ==========================================================================
    ; BLOQUE 1: Pedir y buscar la cuenta
    ; ==========================================================================
    lea  dx, msgRetPedirNro
    call mostrarCadena
    call leerNumero                 ; AX = numero de cuenta

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  retFin                     ; error 01h/02h: propagar

    call buscarCuentaPorNumero      ; SI -> registro si codigoError=00h

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   retVerificar
    lea  dx, msgRetErrNoExiste      ; error 03h
    call mostrarCadena
    jmp  retFin

retVerificar:
    ; ==========================================================================
    ; BLOQUE 2: Verificar que la cuenta este activa
    ; ==========================================================================
    call verificarCuentaActiva

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   retPedirMonto
    lea  dx, msgRetErrInactiva      ; error 04h
    call mostrarCadena
    jmp  retFin

retPedirMonto:
    ; ==========================================================================
    ; BLOQUE 3: Pedir y validar monto
    ; ==========================================================================
    lea  dx, msgRetPedirMonto
    call mostrarCadena
    call leerNumero                 ; AX = monto entero

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  retFin                     ; error 01h/02h

    cmp  ax, 0
    jne  retEscalar
    mov  byte ptr [codigoError], 07h
    lea  dx, msgRetErrMonto
    call mostrarCadena
    jmp  retFin

retEscalar:
    ; ==========================================================================
    ; BLOQUE 4: Escalar monto x10000 -> DX:AX
    ; leerNumero no modifica SI, por lo que SI sigue apuntando al registro.
    ; ==========================================================================
    mov  bx, 10000
    mul  bx                         ; DX:AX = monto * 10000

    ; ==========================================================================
    ; BLOQUE 5: Comparar DWORD monto (DX:AX) vs DWORD saldo ([SI+CUENTA_SALDO])
    ; Estrategia: comparar high words primero; si son iguales, comparar low words.
    ; Se usan registros temporales para no destruir DX:AX antes de la resta.
    ; ==========================================================================

    ; Cargar saldo en CX (high word) y BX (low word) para comparar sin destruir DX:AX
    mov  bx, word ptr [si + CUENTA_SALDO]       ; bx = saldo_low
    mov  cx, word ptr [si + CUENTA_SALDO + 2]   ; cx = saldo_high

    ; Comparar high words: monto_high (DX) vs saldo_high (CX)
    cmp  dx, cx
    jb   retRestar                  ; monto_high < saldo_high: con certeza alcanza
    ja   retErrFondos               ; monto_high > saldo_high: fondos insuficientes

    ; High words iguales -> comparar low words: monto_low (AX) vs saldo_low (BX)
    cmp  ax, bx
    jbe  retRestar                  ; monto_low <= saldo_low: alcanza (retiro exacto ok)

retErrFondos:
    mov  byte ptr [codigoError], 08h
    lea  dx, msgRetErrFondos
    call mostrarCadena
    jmp  retFin

retRestar:
    ; ==========================================================================
    ; BLOQUE 6: Restar DWORD usando SUB + SBB
    ; SUB: resta low words; si hay borrow (resultado negativo de 16 bits), BF=1
    ; SBB: resta high words y ademas resta BF -> propaga el borrow automaticamente
    ; ==========================================================================
    sub  word ptr [si + CUENTA_SALDO],     ax   ; saldo_low -= monto_low
    sbb  word ptr [si + CUENTA_SALDO + 2], dx   ; saldo_high -= monto_high - BF

    ; ==========================================================================
    ; BLOQUE 7: Mostrar resultado
    ; ==========================================================================
    lea  dx, msgRetExito
    call mostrarCadena

    lea  dx, msgRetNuevoSaldo
    call mostrarCadena

    mov  ax, word ptr [si + CUENTA_SALDO]       ; recargar saldo actualizado
    mov  dx, word ptr [si + CUENTA_SALDO + 2]
    call imprimirSaldoEscalado

    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  byte ptr [codigoError], 00h

retFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
retirarDinero ENDP

; -----------------------------------------------------------------------------
; desactivarCuenta
; Cambia el estado de una cuenta activa a inactiva poniendo CUENTA_ESTADO = 0.
;
; Por que revisar el estado directamente en memoria en lugar de llamar
; a verificarCuentaActiva:
;   - verificarCuentaActiva sirve para RECHAZAR operaciones en cuentas inactivas.
;     Aqui el objetivo es el opuesto: queremos ESCRIBIR el campo, y necesitamos
;     saber primero si ya esta inactiva para devolver el error correcto.
;   - Ademas, verificarCuentaActiva escribe codigoError = 04h cuando la cuenta
;     esta inactiva, que es exactamente lo que nos conviene devolver aqui tambien.
;     Sin embargo, llamarla no revelaria si la cuenta era activa antes o ya estaba
;     inactiva, asi que leemos directamente el byte para tomar la decision.
;
; Entrada : ninguna
; Salida  : codigoError:
;             00h = cuenta desactivada con exito
;             01h/02h = error de leerNumero
;             03h = cuenta no encontrada
;             04h = cuenta ya estaba inactiva
; Modifica: AX, BX, DX, SI
; Preserva: CX (no se usa)
; -----------------------------------------------------------------------------
desactivarCuenta PROC

    ; ==========================================================================
    ; BLOQUE 1: Pedir y buscar la cuenta
    ; buscarCuentaPorNumero deja SI apuntando al registro si codigoError = 00h.
    ; ==========================================================================
    lea  dx, msgDesPedirNro
    call mostrarCadena
    call leerNumero                 ; AX = numero de cuenta

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  desFin                     ; error 01h/02h: propagar

    call buscarCuentaPorNumero      ; SI -> registro si codigoError=00h

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   desRevisarEstado
    lea  dx, msgDesErrNoExiste      ; error 03h
    call mostrarCadena
    jmp  desFin

desRevisarEstado:
    ; ==========================================================================
    ; BLOQUE 2: Verificar que la cuenta no este ya inactiva
    ; Se lee directamente el byte CUENTA_ESTADO del registro.
    ; Convencion: 1 = activa, 0 = inactiva.
    ; No se llama a verificarCuentaActiva porque aqui el rol es diferente:
    ; necesitamos distinguir "ya inactiva" de "activa" para actuar en consecuencia.
    ; ==========================================================================
    mov  al, byte ptr [si + CUENTA_ESTADO]
    cmp  al, 0
    jne  desHacerBaja               ; estado = 1 -> puede desactivarse

    ; Estado ya es 0 -> ya estaba inactiva: error
    mov  byte ptr [codigoError], 04h
    lea  dx, msgDesErrYaInactiva
    call mostrarCadena
    jmp  desFin

desHacerBaja:
    ; ==========================================================================
    ; BLOQUE 3: Desactivar la cuenta
    ; Una sola instruccion escribe el nuevo estado en memoria.
    ; ==========================================================================
    mov  byte ptr [si + CUENTA_ESTADO], 0   ; marcar como inactiva

    lea  dx, msgDesExito
    call mostrarCadena

    mov  byte ptr [codigoError], 00h

desFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
desactivarCuenta ENDP

; =============================================================================
; main - Harness de prueba de infraestructura (PERSONA 1)
;
; PROPOSITO : Valida que el nucleo del sistema (I/O numerica y conversion
;             de saldo) funciona correctamente en EMU8086.
;             NO contiene logica bancaria. NO tiene menu.
;             Es el punto de entrada para que PERSONA 2 y PERSONA 3
;             puedan reemplazar este bloque con sus modulos.
;
; PRUEBAS INCLUIDAS:
;   1. imprimirNumeroWord     -> muestra 12345 en pantalla
;   2. imprimirSaldoEscalado  -> muestra 1.2500 (DWORD 12500 = $1.25 x10000)
;
; Para agregar nuevas pruebas: insertar antes de mainFin.
; =============================================================================
main PROC
    ; --- Inicializar el segmento de datos ---
    ; OBLIGATORIO en .model small: DS no apunta a .data hasta asignarlo.
    mov  ax, @data
    mov  ds, ax

    ; =========================================================================
    ; PRUEBA 1: imprimirNumeroWord
    ; Esperado en pantalla: "BankTec OK - Num: 12345"
    ; =========================================================================
    lea  dx, msgInicio
    call mostrarCadena          ; prefijo informativo

    mov  ax, 12345
    call imprimirNumeroWord     ; imprime "12345"

    lea  dx, msgNuevaLinea
    call mostrarCadena

    ; =========================================================================
    ; PRUEBA 2: imprimirSaldoEscalado
    ; DWORD = 12500 (= $1.2500 escalado x10000)
    ; Esperado en pantalla: "Saldo: 1.2500"
    ; =========================================================================
    lea  dx, msgSaldoPrueba
    call mostrarCadena          ; etiqueta "Saldo: "

    mov  ax, 12500              ; word baja del DWORD (12500 < 65535: DX=0)
    xor  dx, dx                 ; word alta = 0 (saldo < $6.5535 millones)
    call imprimirSaldoEscalado  ; imprime "1.2500"

    lea  dx, msgNuevaLinea
    call mostrarCadena

    ; =========================================================================
    ; FIN: salida limpia via DOS
    ; =========================================================================
mainFin:
    mov  ah, 4Ch
    mov  al, 00h                ; codigo de salida 0 = exito
    int  21h
main ENDP  


; ==========================================================
; OPERACIONES BANCARIAS - IMPLEMENTADAS POR INTEGRANTE 2
; ==========================================================

; --- PROCEDIMIENTO: crear_cuenta ---
; REGLAS: Validar cuenta repetida y limite de 10 cuentas (MAX_CUENTAS)
crear_cuenta proc
    push ax
    push bx
    push cx
    push dx

    ; 1. Pedir el numero de cuenta
    call leerNumero          
    
    ; 2. VALIDAR CUENTA REPETIDA
    call buscarCuentaPorNumero 
    cmp si, 0FFFFh           
    jne fin_crear_error      ; Si se encontro (SI != FFFFh), no se crea

    ; 3. BUSCAR ESPACIO (Limite 10 cuentas)
    lea si, arregloCuentas   
    mov cx, MAX_CUENTAS      ; CX = 10 (Restriccion de cantidad)

buscar_vacio:
    cmp byte ptr [si + 36], 0 ; Offset 36 es CUENTA_ESTADO (0 = libre)
    je espacio_encontrado
    add si, 40               ; Tamaño de cada estructura de cuenta
    loop buscar_vacio
    jmp fin_crear_error      ; Si llega aqui, el banco esta lleno (10/10)

espacio_encontrado:
    ; 4. ACTUALIZAR DATOS DE CUENTA
    mov [si + 0], ax         ; Guardar numero de cuenta
    mov byte ptr [si + 36], 1 ; Cambiar estado a ACTIVA
    mov word ptr [si + 32], 0 ; Inicializar saldo bajo en 0
    mov word ptr [si + 34], 0 ; Inicializar saldo alto en 0

fin_crear_ok:
fin_crear_error:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
crear_cuenta endp

; --- PROCEDIMIENTO: depositar_dinero ---
; REGLAS: Validar monto positivo y actualizar saldo
depositar_dinero proc
    push ax
    push bx
    push dx

    call leerNumero
    call buscarCuentaPorNumero
    cmp si, 0FFFFh
    je dep_fin

    call verificarCuentaActiva
    cmp al, 0                
    jne dep_fin

    ; 1. VALIDAR MONTO POSITIVO
    call leerNumero
    cmp ax, 0
    jle dep_fin              ; Si es 0 o menos, se ignora

    ; 2. ESCALAR Y ACTUALIZAR SALDO
    mov bx, FACTOR_ESCALADO
    mul bx                   ; DX:AX tiene el monto escalado
    add [si + 32], ax        ; Suma parte baja
    adc [si + 34], dx        ; Suma parte alta con acarreo

dep_fin:
    pop dx
    pop bx
    pop ax
    ret
depositar_dinero endp

; --- PROCEDIMIENTO: retirar_dinero ---
; REGLAS: Validar monto positivo y SALDO SUFICIENTE
retirar_dinero proc
    push ax
    push bx
    push dx

    call leerNumero
    call buscarCuentaPorNumero
    cmp si, 0FFFFh
    je ret_fin

    call verificarCuentaActiva
    cmp al, 0
    jne ret_fin

    ; 1. VALIDAR MONTO POSITIVO
    call leerNumero
    cmp ax, 0
    jle ret_fin

    mov bx, FACTOR_ESCALADO
    mul bx                   ; DX:AX monto a retirar

    ; 2. VALIDAR SALDO SUFICIENTE (Comparacion 32 bits)
    cmp [si + 34], dx        ; Comparar parte alta
    jb ret_error_fondos      
    ja procede_resta         
    cmp [si + 32], ax        ; Si altas son iguales, comparar bajas
    jb ret_error_fondos

procede_resta:
    ; 3. ACTUALIZAR SALDO (Resta 32 bits)
    sub [si + 32], ax        
    sbb [si + 34], dx        

    jmp ret_fin

ret_error_fondos:
    ; No se realiza la operacion si no alcanza el dinero
ret_fin:
    pop dx
    pop bx
    pop ax
    ret
retirar_dinero endp

END main
