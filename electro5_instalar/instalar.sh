#!/usr/bin/env bash
# Arma ~/electro5 con el entorno de simulacion del ERV26 (risvV_E5).
# Uso, desde la terminal de Ubuntu (WSL):
#   bash /mnt/c/Users/matia/Desktop/risvV_E5/electro5_instalar/instalar.sh
set -e
DEST="$HOME/electro5"
PAQ="$(cd "$(dirname "$0")" && pwd)/electro5.tar.gz"
[ -f "$PAQ" ] || { echo "No encuentro $PAQ"; exit 1; }

if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
    echo "Se va a BORRAR todo lo que hay en $DEST ($(du -sh "$DEST" | cut -f1)):"
    ls -A "$DEST" | head -40 | sed 's/^/    /'
    n=$(ls -A "$DEST" | wc -l); [ "$n" -gt 40 ] && echo "    ... ($n en total)"
    read -r -p "Borrar y reemplazar? [s/N] " r
    case "$r" in s|S|si|SI|Si) ;; *) echo "Cancelado, no se toco nada."; exit 1;; esac
fi
rm -rf "$DEST"
mkdir -p "$DEST"
tar -xzf "$PAQ" -C "$DEST"
echo "Entorno copiado en $DEST"
echo

if ! command -v iverilog >/dev/null || ! command -v gtkwave >/dev/null || \
   ! command -v riscv64-unknown-elf-gcc >/dev/null; then
    echo "Faltan herramientas; se instalan con apt (pide la clave de sudo)."
    bash "$DEST/instalar_dependencias.sh"
else
    make -C "$DEST" entorno
fi
echo
echo "Para empezar:"
echo "    cd ~/electro5"
echo "    make            # menu"
echo "    make pipeline   # ondas del pipeline"
