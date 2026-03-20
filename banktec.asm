; =============================================================================
; BANKTEC - Sistema Bancario en Assembly x86 (.386)
; Curso: Paradigmas de Programacion - ITCR
; Archivo: banktec.asm
;
; Los saldos se almacenan escalados x10000 como DWORD (sin punto flotante).
; Se usa .386 para acceder a registros de 32 bits (EAX, EBX, ECX, EDX)
; en modelo small de 16 bits.
; =============================================================================

.model small
.386
.stack 100h

; =============================================================================
; CONSTANTES
; =============================================================================

MAX_CUENTAS     EQU 10

; Estructura CUENTA (28 bytes):
;   +0  NUMERO  2B  ID de cuenta (Word)
;   +2  NOMBRE 20B  Nombre del titular (ASCII, relleno con ceros)
;  +22  SALDO   4B  Saldo x10000 (DWord)
;  +26  ESTADO  1B  0=inactiva / 1=activa
;  +27  (pad)   1B  Alineacion a 28 bytes
CUENTA_NUMERO   EQU 0
CUENTA_NOMBRE   EQU 2
CUENTA_SALDO    EQU 22
CUENTA_ESTADO   EQU 26

CUENTA_SIZE     EQU 28
BLOQUE_CUENTAS  EQU CUENTA_SIZE * MAX_CUENTAS

; =============================================================================
; SEGMENTO DE DATOS
; =============================================================================
.data

cuentas         DB BLOQUE_CUENTAS DUP(?)
cantidadCuentas DB 0

; Codigos de error:
;   00h = Sin error        01h = Entrada vacia      02h = No numerico
;   03h = No encontrada    04h = Inactiva            05h = Duplicado
;   06h = Limite lleno     07h = Monto invalido      08h = Fondos insuficientes
;   09h = Overflow         0Ah = ID > 65535          0Bh = ID = 0
;   0Ch = Desborde saldo
codigoError     DB 0

MAX_BUFFER      EQU 30
bufferEntrada   DB MAX_BUFFER
                DB 0
                DB MAX_BUFFER DUP(0)

MAX_NOMBRE_BUF  EQU 21
bufferNombre    DB 19
                DB 0
                DB 19 DUP(0)

tempNumero      DW 0

msgPrueba       DB 'BankTec iniciado. Ingresa un texto: $'
msgNuevaLinea       DB 0Dh, 0Ah, '$'

msgIngresarNum      DB 'Ingrese un numero: $'
msgErrorVacio       DB 0Dh, 0Ah, 'ERROR: entrada vacia.$'
msgErrorNoNumerico  DB 0Dh, 0Ah, 'ERROR: caracter no numerico.$'
msgErrorOverflow    DB 0Dh, 0Ah, 'ERROR: excede el limite maximo permitido.$'
msgErrorCuentaCero  DB 0Dh, 0Ah, 'ERROR: el numero de cuenta no puede ser 0.$'
msgError16Bits      DB 0Dh, 0Ah, 'ERROR: El ID de cuenta no puede ser mayor a 65535.$'

msgPedirNroCuenta   DB 'Ingrese numero de cuenta: $'
msgCuentaEncontrada DB 0Dh, 0Ah, 'Cuenta encontrada. Indice: $'
msgCuentaNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'

msgCuentaActiva     DB 0Dh, 0Ah, 'Estado: ACTIVA.$'
msgCuentaInactiva   DB 0Dh, 0Ah, 'Estado: INACTIVA.$'

msgPedirNroConsulta DB 'Ingrese numero de cuenta a consultar: $'
msgSaldoActual      DB 0Dh, 0Ah, 'Saldo actual: $'
msgErrInactiva      DB 0Dh, 0Ah, 'ERROR: cuenta inactiva.$'
msgErrNoExiste      DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'

msgCcPedirNro       DB 'Ingrese numero de cuenta: $'
msgCcPedirNombre    DB 'Ingrese nombre del titular: $'
msgCcPedirSaldo     DB 'Ingrese saldo inicial entero: $'
msgCcExito          DB 0Dh, 0Ah, 'Cuenta creada correctamente.$'
msgCcRepetido       DB 0Dh, 0Ah, 'ERROR: numero de cuenta repetido.$'
msgCcLimite         DB 0Dh, 0Ah, 'ERROR: limite de cuentas alcanzado.$'

msgDepPedirNro      DB 'Ingrese numero de cuenta: $'
msgDepPedirMonto    DB 'Ingrese monto entero a depositar: $'
msgDepExito         DB 0Dh, 0Ah, 'Deposito realizado correctamente.$'
msgDepNuevoSaldo    DB 0Dh, 0Ah, 'Nuevo saldo: $'
msgDepErrNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'
msgDepErrInactiva   DB 0Dh, 0Ah, 'ERROR: cuenta inactiva.$'
msgDepErrMonto      DB 0Dh, 0Ah, 'ERROR: monto invalido (debe ser > 0).$'
msgDepErrDesborde   DB 0Dh, 0Ah, 'ERROR: el deposito excede el saldo maximo permitido.$'

msgRetPedirNro      DB 'Ingrese numero de cuenta: $'
msgRetPedirMonto    DB 'Ingrese monto entero a retirar: $'
msgRetExito         DB 0Dh, 0Ah, 'Retiro realizado correctamente.$'
msgRetNuevoSaldo    DB 0Dh, 0Ah, 'Nuevo saldo: $'
msgRetErrNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'
msgRetErrInactiva   DB 0Dh, 0Ah, 'ERROR: cuenta inactiva.$'
msgRetErrMonto      DB 0Dh, 0Ah, 'ERROR: monto invalido (debe ser > 0).$'
msgRetErrFondos     DB 0Dh, 0Ah, 'ERROR: fondos insuficientes.$'

msgDesPedirNro      DB 'Ingrese numero de cuenta: $'
msgDesExito         DB 0Dh, 0Ah, 'Cuenta desactivada correctamente.$'
msgDesErrNoExiste   DB 0Dh, 0Ah, 'ERROR: cuenta no encontrada.$'
msgDesErrYaInactiva DB 0Dh, 0Ah, 'ERROR: cuenta ya inactiva.$'

BUF_NUMERO_SIZE     EQU 7
bufferNumero        DB BUF_NUMERO_SIZE DUP(0)
bufferDigitos       DB 5 DUP(0)

bufferDigitosDword  DB 12 DUP(0)
bufferNumeroDword   DB 15 DUP(0)

msgMostrarNumero    DB 'Numero convertido: $'
msgIndiceEncontrado DB 'Indice encontrado: $'

bufferDecimal4  DB 6 DUP(0)
msgPunto        DB '.$'
msgSaldoMostrar DB 'Saldo: $'

msgInicio       DB 'BankTec OK - Num: $'
msgSaldoPrueba  DB 'Saldo: $'

msgMenuPrincipal DB 0Dh,0Ah,'====== BANKTEC MENU ======',0Dh,0Ah
                 DB '1. Crear cuenta',0Dh,0Ah
                 DB '2. Depositar dinero',0Dh,0Ah
                 DB '3. Retirar dinero',0Dh,0Ah
                 DB '4. Consultar saldo',0Dh,0Ah
                 DB '5. Mostrar reporte general',0Dh,0Ah
                 DB '6. Desactivar cuenta',0Dh,0Ah
                 DB '7. Salir',0Dh,0Ah
                 DB 'Seleccione una opcion: $'

repActivas      dw 0
repInactivas    dw 0
repSaldoBajo    dd 0        ; Parte baja (32 bits) del total acumulado
repSaldoAlto    dd 0        ; Parte alta (32 bits) del total acumulado (acarreo)
repMaxSaldo     dd 0
repMaxNro       dw 0
repMinSaldo     dd 0FFFFFFFFh
repMinNro       dw 0

msgRepTitulo    db 13,10,"=== REPORTE GENERAL DEL BANCO ===",13,10,"$"
msgRepActivas   db "Total cuentas activas: $"
msgRepInactivas db "Total cuentas inactivas: $"
msgRepSaldoTotal db "Saldo total del banco: $"
msgRepMayor     db "Cuenta con mayor saldo - Nro: $"
msgRepMenor     db "Cuenta con menor saldo - Nro: $"
msgRepSaldo     db " Saldo: $"

; =============================================================================
; SEGMENTO DE CODIGO
; =============================================================================
.code

; mostrarCadena - Imprime una cadena terminada en '$' (INT 21h / AH=09h)
; Entrada: DX = offset de la cadena
mostrarCadena PROC
    push ax
    mov  ah, 09h
    int  21h
    pop  ax
    ret
mostrarCadena ENDP

; leerCadena - Lee una cadena con buffer DOS 0Ah (INT 21h / AH=0Ah)
; Entrada: DX = offset del buffer
leerCadena PROC
    push ax
    mov  ah, 0Ah
    int  21h
    pop  ax
    ret
leerCadena ENDP

; leerNumero - Lee un entero sin signo desde teclado y lo retorna en EAX
; Algoritmo: EAX = EAX*10 + digito por cada caracter leido
; Salida: EAX = numero, codigoError = 00h ok / 01h vacio / 02h no numerico / 09h overflow
leerNumero PROC
    push si

    lea  dx, bufferEntrada
    call leerCadena

    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  cl, [bufferEntrada+1]      ; CL = cantidad de caracteres leidos
    xor  ch, ch

    cmp  cx, 0
    jne  lnValidarDigitos
    mov  byte ptr [codigoError], 01h
    lea  dx, msgErrorVacio
    call mostrarCadena
    xor  eax, eax
    jmp  lnFin

lnValidarDigitos:
    lea  si, bufferEntrada
    add  si, 2                      ; SI apunta al primer caracter
    xor  eax, eax
    mov  byte ptr [codigoError], 00h

lnBucle:
    cmp  cx, 0
    je   lnExito

    movzx ebx, byte ptr [si]        ; EBX = caracter actual (extendido a 32 bits)

    cmp  bl, '0'
    jb   lnErrorNoNumerico
    cmp  bl, '9'
    ja   lnErrorNoNumerico

    sub  bl, '0'                    ; Convertir ASCII a valor numerico

    mov  edx, 10
    mul  edx                        ; EDX:EAX = EAX * 10
    test edx, edx                   ; EDX != 0 => desbordamiento de 32 bits
    jnz  lnErrorOverflow

    add  eax, ebx
    jc   lnErrorOverflow

    inc  si
    dec  cx
    jmp  lnBucle

lnExito:
    mov  byte ptr [codigoError], 00h
    jmp  lnFin

lnErrorOverflow:
    mov  byte ptr [codigoError], 09h
    lea  dx, msgErrorOverflow
    call mostrarCadena
    xor  eax, eax
    jmp  lnFin

lnErrorNoNumerico:
    mov  byte ptr [codigoError], 02h
    lea  dx, msgErrorNoNumerico
    call mostrarCadena
    xor  eax, eax

lnFin:
    pop  si
    ret
leerNumero ENDP

; escalarSaldo - Multiplica EAX por 10000 para convertir entero a saldo escalado
; Usa MUL de 32 bits; si EDX != 0 tras la multiplicacion hay overflow
; Salida: EAX = EAX * 10000, codigoError = 09h si desborde
escalarSaldo PROC
    push ebx
    push edx

    mov  ebx, 10000
    mul  ebx                        ; EDX:EAX = EAX * 10000
    test edx, edx                   ; Desbordamiento si la parte alta != 0
    jnz  esOverflow

    pop  edx
    pop  ebx
    ret

esOverflow:
    pop  edx
    pop  ebx
    mov  byte ptr [codigoError], 09h
    lea  dx, msgErrorOverflow
    call mostrarCadena
    xor  eax, eax
    ret
escalarSaldo ENDP

; buscarCuentaPorNumero - Busca una cuenta por su ID recorriendo el arreglo
; Entrada: AX = numero de cuenta
; Salida: BL = indice (0FFh si no encontrado), SI = puntero al registro
;         codigoError = 00h encontrado / 03h no encontrado
buscarCuentaPorNumero PROC
    push ax
    push dx

    xor  cx, cx
    mov  cl, [cantidadCuentas]
    cmp  cx, 0
    je   bcpNoEncontrado

    lea  si, cuentas
    xor  bx, bx

bcpBucle:
    mov  dx, word ptr [si + CUENTA_NUMERO]
    cmp  dx, ax
    je   bcpEncontrado

    add  si, CUENTA_SIZE
    inc  bl
    dec  cx
    jnz  bcpBucle

bcpNoEncontrado:
    mov  byte ptr [codigoError], 03h
    mov  bl, 0FFh
    jmp  bcpFin

bcpEncontrado:
    mov  byte ptr [codigoError], 00h

bcpFin:
    pop  dx
    pop  ax
    ret
buscarCuentaPorNumero ENDP

; verificarCuentaActiva - Comprueba si CUENTA_ESTADO == 1 en el registro apuntado por SI
; Salida: codigoError = 00h activa / 04h inactiva
verificarCuentaActiva PROC
    push ax
    mov  al, byte ptr [si + CUENTA_ESTADO]
    cmp  al, 1
    je   vcaActiva
    mov  byte ptr [codigoError], 04h
    jmp  vcaFin
vcaActiva:
    mov  byte ptr [codigoError], 00h
vcaFin:
    pop  ax
    ret
verificarCuentaActiva ENDP

; consultarSaldo - Busca una cuenta y muestra su saldo en formato "entero.DDDD"
; Entrada: AX = numero de cuenta
consultarSaldo PROC
    call buscarCuentaPorNumero

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   csVerificarActiva
    lea  dx, msgErrNoExiste
    call mostrarCadena
    jmp  csFin

csVerificarActiva:
    call verificarCuentaActiva

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   csLeerSaldo
    lea  dx, msgErrInactiva
    call mostrarCadena
    jmp  csFin

csLeerSaldo:
    lea  dx, msgSaldoActual
    call mostrarCadena

    mov  eax, dword ptr [si + CUENTA_SALDO]
    call imprimirSaldoEscalado

    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  byte ptr [codigoError], 00h

csFin:
    ret
consultarSaldo ENDP

; crearCuenta - Pide numero, nombre y saldo inicial para registrar una nueva cuenta
; Valida duplicados, limite de cuentas, overflow y rango de ID (1..65535)
crearCuenta PROC

    mov  al, [cantidadCuentas]
    cmp  al, MAX_CUENTAS
    jb   ccHayEspacio
    mov  byte ptr [codigoError], 06h
    lea  dx, msgCcLimite
    call mostrarCadena
    jmp  ccFin

ccHayEspacio:
    lea  dx, msgCcPedirNro
    call mostrarCadena
    call leerNumero                 ; EAX = numero ingresado

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  ccFin

    cmp  eax, 0
    jne  ccVerificar16Bits
    mov  byte ptr [codigoError], 0Bh
    lea  dx, msgErrorCuentaCero
    call mostrarCadena
    jmp  ccFin

ccVerificar16Bits:
    ; ID valido solo en 16 bits; los bits 16-31 deben ser 0
    test eax, 0FFFF0000h
    jz   ccNumeroOk
    mov  byte ptr [codigoError], 0Ah
    lea  dx, msgError16Bits
    call mostrarCadena
    jmp  ccFin

ccNumeroOk:
    mov  [tempNumero], ax

    call buscarCuentaPorNumero      ; AX contiene el ID a buscar

    mov  bl, [codigoError]
    cmp  bl, 03h
    je   ccNumeroLibre
    mov  byte ptr [codigoError], 05h
    lea  dx, msgCcRepetido
    call mostrarCadena
    jmp  ccFin

ccNumeroLibre:
    ; Calcular desplazamiento del espacio libre: indice * CUENTA_SIZE
    movzx eax, byte ptr [cantidadCuentas]
    mov  ebx, CUENTA_SIZE
    mul  ebx
    lea  si, cuentas
    add  si, ax

    mov  ax, [tempNumero]
    mov  word ptr [si + CUENTA_NUMERO], ax
    mov  byte ptr [si + CUENTA_ESTADO], 1

    lea  dx, msgCcPedirNombre
    call mostrarCadena

    lea  dx, bufferNombre
    call leerCadena
    lea  dx, msgNuevaLinea
    call mostrarCadena

    ; Copiar nombre al registro (maximo 19 caracteres, relleno con ceros)
    push si
    mov  di, si
    add  di, CUENTA_NOMBRE

    lea  si, bufferNombre
    add  si, 2

    xor  cx, cx
    mov  cl, [bufferNombre+1]
    cmp  cx, 19
    jbe  ccCopiar
    mov  cx, 19

ccCopiar:
    mov  bx, cx

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
    mov  cx, 20
    sub  cx, bx

ccPadLoop:
    cmp  cx, 0
    je   ccNombreListo
    mov  byte ptr [di], 0
    inc  di
    dec  cx
    jmp  ccPadLoop

ccNombreListo:
    pop  si

    lea  dx, msgCcPedirSaldo
    call mostrarCadena
    call leerNumero                 ; EAX = saldo inicial entero

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  ccFin

    call escalarSaldo               ; EAX = saldo * 10000

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  ccFin

    mov  dword ptr [si + CUENTA_SALDO], eax

    inc  byte ptr [cantidadCuentas]

    lea  dx, msgCcExito
    call mostrarCadena

    mov  byte ptr [codigoError], 00h

ccFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
crearCuenta ENDP

; numeroAAscii - Convierte AX (Word) a cadena ASCII decimal terminada en '$'
; Extrae digitos con DIV 16 bits, los invierte y escribe en el buffer DI
; Entrada: AX = numero, DI = buffer destino (min 7 bytes)
numeroAAscii PROC
    push si

    cmp  ax, 0
    jne  naaBucle
    mov  byte ptr [di],   '0'
    mov  byte ptr [di+1], '$'
    jmp  naaFin

naaBucle:
    lea  si, bufferDigitos
    xor  cx, cx

naaExtraer:
    cmp  ax, 0
    je   naaInvertir

    xor  dx, dx
    mov  bx, 10
    div  bx
    add  dl, '0'
    mov  [si], dl
    inc  si
    inc  cx
    jmp  naaExtraer

naaInvertir:
naaCopiaBucle:
    cmp  cx, 0
    je   naaTerminar
    dec  si
    mov  al, [si]
    mov  [di], al
    inc  di
    dec  cx
    jmp  naaCopiaBucle

naaTerminar:
    mov  byte ptr [di], '$'

naaFin:
    pop  si
    ret
numeroAAscii ENDP

; imprimirNumeroWord - Convierte AX a ASCII y lo imprime por pantalla
imprimirNumeroWord PROC
    lea  di, bufferNumero
    call numeroAAscii
    lea  dx, bufferNumero
    call mostrarCadena
    ret
imprimirNumeroWord ENDP

; numeroDwordAAscii - Convierte EAX (DWord, 32 bits) a cadena ASCII en buffer DI
; Usa DIV de 32 bits nativo (.386); misma logica que numeroAAscii pero con EAX
; Entrada: EAX = numero, DI = buffer destino
numeroDwordAAscii PROC
    push eax
    push ebx
    push ecx
    push edx
    push si

    lea  si, bufferDigitosDword
    xor  ecx, ecx

    test eax, eax
    jnz  ndaBucle
    mov  byte ptr [di], '0'
    mov  byte ptr [di+1], '$'
    jmp  ndaFin

ndaBucle:
    test eax, eax
    je   ndaInvertir

    xor  edx, edx
    mov  ebx, 10
    div  ebx                    ; EAX = cociente, EDX = digito
    add  dl, '0'
    mov  [si], dl
    inc  si
    inc  ecx
    jmp  ndaBucle

ndaInvertir:
    test ecx, ecx
    je   ndaTerminar

ndaCopiaLoop:
    dec  si
    mov  al, [si]
    mov  [di], al
    inc  di
    dec  ecx
    jnz  ndaCopiaLoop

ndaTerminar:
    mov  byte ptr [di], '$'

ndaFin:
    pop  si
    pop  edx
    pop  ecx
    pop  ebx
    pop  eax
    ret
numeroDwordAAscii ENDP

; imprimirNumeroDword - Convierte EAX a ASCII y lo imprime por pantalla
imprimirNumeroDword PROC
    lea  di, bufferNumeroDword
    call numeroDwordAAscii
    lea  dx, bufferNumeroDword
    call mostrarCadena
    ret
imprimirNumeroDword ENDP

; imprimirDecimal4 - Imprime DX como 4 digitos con ceros a la izquierda (0000-9999)
; Usa divisiones sucesivas por 10 para extraer cada digito de derecha a izquierda
; Entrada: DX = valor decimal (0..9999)
imprimirDecimal4 PROC
    push si

    lea  si, bufferDecimal4
    mov  ax, dx
    xor  dx, dx

    mov  bx, 10
    div  bx
    add  dl, '0'
    mov  [si+3], dl
    xor  dx, dx

    div  bx
    add  dl, '0'
    mov  [si+2], dl
    xor  dx, dx

    div  bx
    add  dl, '0'
    mov  [si+1], dl
    xor  dx, dx

    div  bx
    add  dl, '0'
    mov  [si+0], dl

    mov  byte ptr [si+4], '$'

    lea  dx, bufferDecimal4
    call mostrarCadena

    pop  si
    ret
imprimirDecimal4 ENDP

; imprimirSaldoEscalado - Imprime EAX (saldo x10000) en formato "entero.DDDD"
; Divide EAX entre 10000: cociente = parte entera, resto = 4 decimales
; Entrada: EAX = saldo escalado x10000
imprimirSaldoEscalado PROC
    push edx
    push ebx

    mov  ebx, 10000
    xor  edx, edx
    div  ebx                    ; EAX = parte entera, EDX = decimales (0..9999)

    push edx
    call imprimirNumeroDword    ; Imprime parte entera

    lea  dx, msgPunto
    call mostrarCadena

    pop  edx
    call imprimirDecimal4       ; Imprime 4 decimales con ceros a la izquierda

    pop  ebx
    pop  edx
    ret
imprimirSaldoEscalado ENDP

; depositarDinero - Suma un monto al saldo de una cuenta activa
; Usa ADD de 32 bits; detecta desborde con la bandera de acarreo
depositarDinero PROC

    lea  dx, msgDepPedirNro
    call mostrarCadena
    call leerNumero             ; EAX = numero de cuenta

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  depFin

    call buscarCuentaPorNumero

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   depVerificar
    lea  dx, msgDepErrNoExiste
    call mostrarCadena
    jmp  depFin

depVerificar:
    call verificarCuentaActiva

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   depPedirMonto
    lea  dx, msgDepErrInactiva
    call mostrarCadena
    jmp  depFin

depPedirMonto:
    lea  dx, msgDepPedirMonto
    call mostrarCadena
    call leerNumero             ; EAX = monto entero

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  depFin

    test eax, eax               ; Monto debe ser > 0
    jnz  depEscalar
    mov  byte ptr [codigoError], 07h
    lea  dx, msgDepErrMonto
    call mostrarCadena
    jmp  depFin

depEscalar:
    call escalarSaldo           ; EAX = monto * 10000

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  depFin

    mov  ebx, dword ptr [si + CUENTA_SALDO]
    add  ebx, eax               ; Sumar monto al saldo
    jc   depErrDesborde         ; Acarreo = desborde de 32 bits

    mov  dword ptr [si + CUENTA_SALDO], ebx

    lea  dx, msgDepExito
    call mostrarCadena

    lea  dx, msgDepNuevoSaldo
    call mostrarCadena

    mov  eax, dword ptr [si + CUENTA_SALDO]
    call imprimirSaldoEscalado

    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  byte ptr [codigoError], 00h
    jmp  depFin

depErrDesborde:
    mov  byte ptr [codigoError], 0Ch
    lea  dx, msgDepErrDesborde
    call mostrarCadena

depFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
depositarDinero ENDP

; retirarDinero - Resta un monto del saldo de una cuenta activa
; Verifica fondos con CMP de 32 bits antes de restar para evitar saldo negativo
retirarDinero PROC

    lea  dx, msgRetPedirNro
    call mostrarCadena
    call leerNumero             ; EAX = numero de cuenta

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  retFin

    call buscarCuentaPorNumero

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   retVerificar
    lea  dx, msgRetErrNoExiste
    call mostrarCadena
    jmp  retFin

retVerificar:
    call verificarCuentaActiva

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   retPedirMonto
    lea  dx, msgRetErrInactiva
    call mostrarCadena
    jmp  retFin

retPedirMonto:
    lea  dx, msgRetPedirMonto
    call mostrarCadena
    call leerNumero             ; EAX = monto entero

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  retFin

    test eax, eax               ; Monto debe ser > 0
    jnz  retEscalar
    mov  byte ptr [codigoError], 07h
    lea  dx, msgRetErrMonto
    call mostrarCadena
    jmp  retFin

retEscalar:
    call escalarSaldo           ; EAX = monto * 10000

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  retFin

    mov  ebx, dword ptr [si + CUENTA_SALDO]
    cmp  ebx, eax               ; Verificar saldo >= monto
    jb   retErrFondos

    sub  ebx, eax               ; Restar monto al saldo
    mov  dword ptr [si + CUENTA_SALDO], ebx

    lea  dx, msgRetExito
    call mostrarCadena

    lea  dx, msgRetNuevoSaldo
    call mostrarCadena

    mov  eax, dword ptr [si + CUENTA_SALDO]
    call imprimirSaldoEscalado

    lea  dx, msgNuevaLinea
    call mostrarCadena

    mov  byte ptr [codigoError], 00h
    jmp  retFin

retErrFondos:
    mov  byte ptr [codigoError], 08h
    lea  dx, msgRetErrFondos
    call mostrarCadena

retFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
retirarDinero ENDP

; desactivarCuenta - Marca el ESTADO de una cuenta como 0 (inactiva)
desactivarCuenta PROC

    lea  dx, msgDesPedirNro
    call mostrarCadena
    call leerNumero             ; EAX = numero de cuenta

    mov  bl, [codigoError]
    cmp  bl, 00h
    jne  desFin

    call buscarCuentaPorNumero

    mov  bl, [codigoError]
    cmp  bl, 00h
    je   desRevisarEstado
    lea  dx, msgDesErrNoExiste
    call mostrarCadena
    jmp  desFin

desRevisarEstado:
    mov  al, byte ptr [si + CUENTA_ESTADO]
    cmp  al, 0
    jne  desHacerBaja
    mov  byte ptr [codigoError], 04h
    lea  dx, msgDesErrYaInactiva
    call mostrarCadena
    jmp  desFin

desHacerBaja:
    mov  byte ptr [si + CUENTA_ESTADO], 0
    lea  dx, msgDesExito
    call mostrarCadena
    mov  byte ptr [codigoError], 00h

desFin:
    lea  dx, msgNuevaLinea
    call mostrarCadena
    ret
desactivarCuenta ENDP

; menuPrincipal - Muestra el menu en bucle y despacha cada opcion a su modulo
; Lee un caracter con INT 21h / AH=01h; opcion 7 sale del bucle y retorna a main
menuPrincipal PROC
menuLoop:
    lea dx, msgMenuPrincipal
    call mostrarCadena

    mov ah, 01h
    int 21h

    lea dx, msgNuevaLinea
    call mostrarCadena

    sub al, '0'                 ; Convertir ASCII a indice numerico

    cmp al, 1
    je mCrear
    cmp al, 2
    je mDep
    cmp al, 3
    je mRet
    cmp al, 4
    je mCon
    cmp al, 5
    je mRep
    cmp al, 6
    je mDes
    cmp al, 7
    je mSal
    jmp menuLoop

mCrear: call crearCuenta
    jmp menuLoop
mDep:   call depositarDinero
    jmp menuLoop
mRet:   call retirarDinero
    jmp menuLoop
mCon:
    lea dx, msgPedirNroConsulta
    call mostrarCadena
    call leerNumero
    cmp byte ptr [codigoError], 0
    jne menuLoop
    call consultarSaldo
    jmp menuLoop
mRep:   call mostrarReporteGeneral
    jmp menuLoop
mDes:   call desactivarCuenta
    jmp menuLoop
mSal:   ret
menuPrincipal ENDP

; imprimirSaldo64 - Imprime el saldo total del banco en formato "entero.DDDD"
; El total se guarda en 64 bits [repSaldoAlto:repSaldoBajo] para soportar
; sumas que superen 2^32 (ej: 10 cuentas con saldos grandes).
; Division en dos pasos:
;   Paso 1: repSaldoAlto / 10000 -> resto_alto (el cociente siempre es 0)
;   Paso 2: (resto_alto:repSaldoBajo) / 10000 -> parte entera y 4 decimales
imprimirSaldo64 PROC
    push eax
    push ecx
    push edx

    mov  ecx, 10000

    ; Paso 1: dividir la parte alta (el resto queda en EDX para el paso 2)
    mov  eax, dword ptr [repSaldoAlto]
    xor  edx, edx
    div  ecx

    ; Paso 2: EDX:EAX = resto_alto:bajo32 -> division completa de 64 bits
    mov  eax, dword ptr [repSaldoBajo]
    div  ecx                            ; EAX = parte entera, EDX = decimales

    push edx
    call imprimirNumeroDword
    lea  dx, msgPunto
    call mostrarCadena
    pop  edx
    call imprimirDecimal4

    pop  edx
    pop  ecx
    pop  eax
    ret
imprimirSaldo64 ENDP

; mostrarReporteGeneral - Calcula y muestra estadisticas de todas las cuentas
; Acumula el saldo total en 64 bits usando ADD + ADC (EBX=low, EDX=high)
; para evitar desborde cuando la suma supera 2^32.
; Determina cuentas activas/inactivas y el saldo maximo y minimo.
mostrarReporteGeneral PROC
    push eax
    push ebx
    push ecx
    push edx
    push si
    push di

    mov word ptr [repActivas],   0
    mov word ptr [repInactivas], 0
    mov dword ptr [repSaldoBajo], 0
    mov dword ptr [repSaldoAlto], 0
    mov dword ptr [repMaxSaldo],  0
    mov word ptr  [repMaxNro],    0
    mov dword ptr [repMinSaldo],  0FFFFFFFFh
    mov word ptr  [repMinNro],    0

    xor  ebx, ebx               ; EBX = acumulador parte baja (32 bits)
    xor  edx, edx               ; EDX = acumulador parte alta (32 bits, acarreos)

    lea  si, cuentas
    mov  cl, [cantidadCuentas]
    xor  ch, ch
    test cx, cx
    jz   bucleRepFin

bucleReporte:
    push cx

    cmp byte ptr [si + CUENTA_ESTADO], 1
    jne cuentaInactiva

    inc word ptr [repActivas]

    mov  eax, dword ptr [si + CUENTA_SALDO]

    ; Acumulacion de 64 bits: ADD propaga el acarreo, ADC lo suma a la parte alta
    add  ebx, eax
    adc  edx, 0

    ; Actualizar maximo
    cmp  eax, dword ptr [repMaxSaldo]
    jbe  revisarMinimo
esNuevoMax:
    mov  dword ptr [repMaxSaldo], eax
    push di
    mov  di, [si + CUENTA_NUMERO]
    mov  [repMaxNro], di
    pop  di

revisarMinimo:
    ; Actualizar minimo
    cmp  eax, dword ptr [repMinSaldo]
    jae  sigCuenta
esNuevoMin:
    mov  dword ptr [repMinSaldo], eax
    push di
    mov  di, [si + CUENTA_NUMERO]
    mov  [repMinNro], di
    pop  di
    jmp  sigCuenta

cuentaInactiva:
    inc word ptr [repInactivas]

sigCuenta:
    pop  cx
    add  si, CUENTA_SIZE
    loop bucleReporte

bucleRepFin:
    ; Guardar total 64 bits antes de que DX se use para mensajes
    mov  dword ptr [repSaldoBajo], ebx
    mov  dword ptr [repSaldoAlto], edx

imprimirResultados:
    cmp word ptr [repActivas], 0
    jne repImprimirBloque
    ; Sin cuentas activas: reiniciar minimo para no mostrar 0xFFFFFFFF
    mov dword ptr [repMinSaldo], 0
    mov word ptr  [repMinNro],   0

repImprimirBloque:
    lea dx, msgRepTitulo
    call mostrarCadena

    lea dx, msgRepActivas
    call mostrarCadena
    mov ax, [repActivas]
    call imprimirNumeroWord
    lea dx, msgNuevaLinea
    call mostrarCadena

    lea dx, msgRepInactivas
    call mostrarCadena
    mov ax, [repInactivas]
    call imprimirNumeroWord
    lea dx, msgNuevaLinea
    call mostrarCadena

    lea dx, msgRepSaldoTotal
    call mostrarCadena
    call imprimirSaldo64        ; Maneja el total de 64 bits
    lea dx, msgNuevaLinea
    call mostrarCadena

    lea dx, msgRepMayor
    call mostrarCadena
    mov ax, [repMaxNro]
    call imprimirNumeroWord
    lea dx, msgRepSaldo
    call mostrarCadena
    mov eax, dword ptr [repMaxSaldo]
    call imprimirSaldoEscalado
    lea dx, msgNuevaLinea
    call mostrarCadena

    lea dx, msgRepMenor
    call mostrarCadena
    mov ax, [repMinNro]
    call imprimirNumeroWord
    lea dx, msgRepSaldo
    call mostrarCadena
    mov eax, dword ptr [repMinSaldo]
    call imprimirSaldoEscalado
    lea dx, msgNuevaLinea
    call mostrarCadena

    pop  di
    pop  si
    pop  edx
    pop  ecx
    pop  ebx
    pop  eax
    ret
mostrarReporteGeneral ENDP

; main - Punto de entrada: inicializa DS y lanza el menu principal
main PROC
    mov  ax, @data
    mov  ds, ax
    call menuPrincipal
mainFin:
    mov  ah, 4Ch
    mov  al, 00h
    int  21h
main ENDP

END main
