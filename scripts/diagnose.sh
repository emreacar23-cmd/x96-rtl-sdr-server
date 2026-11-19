#!/system/bin/sh
# Read-only diagnostic. Does NOT open the RTL-SDR device or start rtl_test.
OUTDIR="/sdcard/Download"
STAMP="$(date '+%Y%m%d_%H%M%S' 2>/dev/null)"
[ -n "$STAMP" ] || STAMP="latest"
REPORT="$OUTDIR/sdr_report_$STAMP.txt"
RTL_HOME="/data/data/com.termux/files/home/rtl-sdr"

mkdir -p "$OUTDIR"
{
  echo "===== X96 RTL-SDR READ-ONLY DIAGNOSTIC ====="
  date 2>&1
  echo "Device: $(getprop ro.product.model 2>/dev/null)"
  echo "Android: $(getprop ro.build.version.release 2>/dev/null)"
  echo "Kernel: $(uname -a 2>&1)"
  echo "Architecture: $(uname -m 2>&1)"
  id 2>&1
  echo

  echo "===== RTL-SDR USB DEVICE ====="
  FOUND=0
  for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    V="$(cat "$d/idVendor" 2>/dev/null)"
    P="$(cat "$d/idProduct" 2>/dev/null)"
    if [ "$V" = "0bda" ] && [ "$P" = "2838" ]; then
      FOUND=1
      echo "Path: $d"
      echo "USB ID: $V:$P"
      echo "Manufacturer: $(cat "$d/manufacturer" 2>/dev/null)"
      echo "Product: $(cat "$d/product" 2>/dev/null)"
      echo "Serial: $(cat "$d/serial" 2>/dev/null)"
      echo "Bus/device: $(cat "$d/busnum" 2>/dev/null)/$(cat "$d/devnum" 2>/dev/null)"
      for i in "$d":*; do
        [ -e "$i" ] || continue
        echo "Interface: $i"
        echo "Driver: $(readlink "$i/driver" 2>/dev/null)"
      done
    fi
  done
  [ "$FOUND" = "1" ] || echo "NESDR 0bda:2838 NOT FOUND"
  echo

  echo "===== SDR PROCESSES ====="
  ps -A 2>&1 | grep -i -E 'rtl_tcp|rtl_test|rtl_fm|sdr_driver|rtl_tcp_andro|tmp-mksh' | grep -v grep
  echo

  echo "===== RTL-SDR BINARIES ====="
  ls -l "$RTL_HOME/build/src/rtl_tcp" "$RTL_HOME/build/src/rtl_test" "$RTL_HOME/build/src/librtlsdr.so"* 2>&1
  echo

  echo "===== PROCESS DETAILS (if /proc access permits) ====="
  for p in $(ps -A 2>/dev/null | grep -E 'rtl_tcp|rtl_test' | awk '{print $2}'); do
    echo "--- PID $p ---"
    tr '\000' ' ' < "/proc/$p/cmdline" 2>/dev/null
    echo
    grep -E '^(Name|State|Pid|PPid|Uid):' "/proc/$p/status" 2>/dev/null
  done
  echo

  echo "===== END ====="
  echo "This report did not start or stop any SDR process."
} > "$REPORT" 2>&1

echo "Report saved: $REPORT"
