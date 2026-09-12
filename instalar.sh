#!/bin/bash
# Instala (o quita, con --quitar) el salto de contraseña en wifi de confianza.
# Toca un único archivo del sistema: /etc/pam.d/cosmic-greeter, y siempre
# guarda copia antes. Si la edición no queda exactamente como se espera,
# se revierte sola.
set -euo pipefail

PAMFILE=/etc/pam.d/cosmic-greeter
LINEA='auth	sufficient			pam_exec.so quiet /usr/local/sbin/wifi-confiable'
MARCA='pam_exec.so quiet /usr/local/sbin/wifi-confiable'
ORIGEN="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" = 0 ] || { echo "Ejecútame con sudo."; exit 1; }
[ -f "$PAMFILE" ] || { echo "No existe $PAMFILE — ¿este equipo no usa cosmic-greeter?"; exit 1; }

backup() {
    local b="${PAMFILE}.bak-$(date +%Y%m%d-%H%M%S)"
    cp -a "$PAMFILE" "$b"
    echo "$b"
}

# Comprueba que el archivo resultante, quitándole nuestras líneas, es idéntico
# al que había antes. Si no, revierte y aborta.
verificar_o_revertir() {
    local b="$1"
    if ! diff -q <(grep -Fv "$MARCA" "$PAMFILE") "$b" >/dev/null; then
        echo "!! La edición de $PAMFILE no cuadra. Revirtiendo."
        cp -a "$b" "$PAMFILE"
        exit 1
    fi
}

if [ "${1:-}" = "--quitar" ]; then
    if ! grep -qF "$MARCA" "$PAMFILE"; then
        echo "No estaba instalado en $PAMFILE."
    else
        b=$(backup)
        grep -Fv "$MARCA" "$b" > "$PAMFILE"
        echo "Línea quitada de $PAMFILE (copia en $b)."
    fi
    rm -f /usr/local/sbin/wifi-confiable
    echo "Borrado /usr/local/sbin/wifi-confiable."
    echo "Dejo /etc/wifi-confiable.conf por si lo quieres reutilizar; bórralo a mano si no."
    exit 0
fi

# --- instalar ---
install -o root -g root -m 0755 "$ORIGEN/wifi-confiable" /usr/local/sbin/wifi-confiable
if [ -f /etc/wifi-confiable.conf ]; then
    echo "Ya existe /etc/wifi-confiable.conf: lo respeto tal cual está."
else
    # El repo solo trae el ejemplo: la config real lleva el BSSID del router,
    # que identifica dónde vives. Se usa la propia si la hay; si no, el ejemplo.
    if [ -f "$ORIGEN/wifi-confiable.conf" ]; then
        ORIGEN_CONF="$ORIGEN/wifi-confiable.conf"
    elif [ -f "$ORIGEN/wifi-confiable.conf.ejemplo" ]; then
        ORIGEN_CONF="$ORIGEN/wifi-confiable.conf.ejemplo"
        FALTA_CONFIGURAR=1
    else
        echo "No encuentro ni wifi-confiable.conf ni wifi-confiable.conf.ejemplo."; exit 1
    fi
    install -o root -g root -m 0644 "$ORIGEN_CONF" /etc/wifi-confiable.conf
    if [ "${FALTA_CONFIGURAR:-0}" = 1 ]; then
        echo
        echo ">> /etc/wifi-confiable.conf se instaló con valores de EJEMPLO."
        echo "   Edítalo con los tuyos antes de que sirva de algo:"
        echo "     iw dev                          -> tu interfaz"
        echo "     iw dev <iface> link             -> tu SSID y BSSID"
        echo
    fi
fi

# El script tiene que decir que sí AHORA mismo, o no tiene sentido seguir.
if ! PAM_USER="${SUDO_USER:-root}" /usr/local/sbin/wifi-confiable >/dev/null 2>&1; then
    echo "Aviso: ahora mismo el chequeo NO pasa. Motivo:"
    PAM_USER="${SUDO_USER:-root}" /usr/local/sbin/wifi-confiable --test "${SUDO_USER:-root}" || true
    echo "(Instalo igual: mientras no pase, simplemente te pedirá la contraseña de siempre.)"
fi

if grep -qF "$MARCA" "$PAMFILE"; then
    echo "$PAMFILE ya tenía la línea. Nada que cambiar."
else
    b=$(backup)
    awk -v linea="$LINEA" '
        !hecho && /^@include[ \t]+common-auth/ { print linea; hecho=1 }
        { print }
        END { if (!hecho) { print "ERROR: no encontré @include common-auth" > "/dev/stderr"; exit 3 } }
    ' "$b" > "${PAMFILE}.nuevo"
    mv "${PAMFILE}.nuevo" "$PAMFILE"
    chmod --reference="$b" "$PAMFILE"
    verificar_o_revertir "$b"
    echo "Línea añadida a $PAMFILE (copia en $b)."
fi

echo
echo "Listo. Estado actual del chequeo:"
PAM_USER="${SUDO_USER:-root}" /usr/local/sbin/wifi-confiable --test "${SUDO_USER:-root}" || true
echo
echo "Pruébalo: bloquea la pantalla y pulsa Intro con el campo vacío."
echo "Si algo va mal, la contraseña de siempre sigue funcionando, y en una TTY"
echo "(Ctrl+Alt+F3) el login no está tocado. Para deshacer: sudo $0 --quitar"
