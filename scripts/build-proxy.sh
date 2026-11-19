#!/data/data/com.termux/files/usr/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SRC_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../src" && pwd)"
RTL_HOME="/data/data/com.termux/files/home/rtl-sdr"
OUT_DIR="$RTL_HOME/build/src"
CC="/data/data/com.termux/files/usr/bin/clang"

if [ ! -x "$CC" ]; then
  echo "clang not found: $CC"
  echo "Install it in Termux with: pkg install clang"
  exit 1
fi
if [ ! -x "$OUT_DIR/rtl_tcp" ]; then
  echo "rtl_tcp not found: $OUT_DIR/rtl_tcp"
  exit 1
fi

"$CC" -O2 -Wall -Wextra "$SRC_DIR/sdr_proxy.c" -o "$OUT_DIR/sdr_proxy"
chmod 755 "$OUT_DIR/sdr_proxy"
echo "Built: $OUT_DIR/sdr_proxy"
