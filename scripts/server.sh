#!/system/bin/sh
# Root-only single-instance manager for the Termux-built rtl_tcp.
# Usage: su -c "sh /sdcard/Download/server.sh start|stop|status"

RTL_HOME="/data/data/com.termux/files/home/rtl-sdr"
RTL_TCP="$RTL_HOME/build/src/rtl_tcp"
LIB_DIR="$RTL_HOME/build/src"
PREFIX="/data/data/com.termux/files/usr"
STATE_DIR="/data/local/tmp/x96-rtl-sdr"
PID_FILE="$STATE_DIR/rtl_tcp.pid"
LOG_FILE="$STATE_DIR/rtl_tcp.log"
PORT="1234"
ADDRESS="0.0.0.0"

mkdir -p "$STATE_DIR" || exit 1

is_running() {
  [ -f "$PID_FILE" ] || return 1
  PID="$(cat "$PID_FILE" 2>/dev/null)"
  case "$PID" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$PID" 2>/dev/null
}

start_server() {
  if is_running; then
    echo "rtl_tcp already running (PID $(cat "$PID_FILE"))."
    exit 0
  fi
  rm -f "$PID_FILE"

  if [ ! -x "$RTL_TCP" ]; then
    echo "ERROR: rtl_tcp executable not found: $RTL_TCP"
    exit 1
  fi

  export LD_LIBRARY_PATH="$LIB_DIR:$PREFIX/lib:$LD_LIBRARY_PATH"
  nohup "$RTL_TCP" -a "$ADDRESS" -p "$PORT" >> "$LOG_FILE" 2>&1 </dev/null &
  PID=$!
  echo "$PID" > "$PID_FILE"
  sleep 2

  if kill -0 "$PID" 2>/dev/null; then
    echo "rtl_tcp started. PID=$PID"
    echo "Listen address: $ADDRESS:$PORT"
    echo "Log: $LOG_FILE"
  else
    rm -f "$PID_FILE"
    echo "ERROR: rtl_tcp failed to start. Last log lines:"
    tail -n 40 "$LOG_FILE" 2>/dev/null
    exit 1
  fi
}

stop_server() {
  if ! is_running; then
    rm -f "$PID_FILE"
    echo "rtl_tcp is not running (no managed PID)."
    exit 0
  fi
  PID="$(cat "$PID_FILE")"
  kill "$PID" 2>/dev/null
  sleep 2
  if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID" 2>/dev/null
    sleep 1
  fi
  rm -f "$PID_FILE"
  echo "Stop signal sent to managed rtl_tcp PID $PID."
}

status_server() {
  if is_running; then
    echo "RUNNING: PID $(cat "$PID_FILE")"
    echo "Address: $ADDRESS:$PORT"
    echo "Log: $LOG_FILE"
  else
    echo "STOPPED (no managed rtl_tcp process)."
  fi
}

if [ "$(id -u)" != "0" ]; then
  echo "ERROR: run as root, for example:"
  echo 'su -c "sh /sdcard/Download/server.sh status"'
  exit 1
fi

case "$1" in
  start) start_server ;;
  stop) stop_server ;;
  status) status_server ;;
  log) tail -n 80 "$LOG_FILE" 2>/dev/null ;;
  *)
    echo "Usage: $0 {start|stop|status|log}"
    exit 2
    ;;
esac
