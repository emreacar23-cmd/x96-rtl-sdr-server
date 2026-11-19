#!/system/bin/sh
RTL_HOME="/data/data/com.termux/files/home/rtl-sdr"
RTL_TCP="$RTL_HOME/build/src/rtl_tcp"
PROXY="$RTL_HOME/build/src/sdr_proxy"
LIB_DIR="$RTL_HOME/build/src"
PREFIX="/data/data/com.termux/files/usr"
STATE_DIR="/data/local/tmp/x96-rtl-sdr"
PID_FILE="$STATE_DIR/proxy.pid"
LOG_FILE="$STATE_DIR/proxy.log"
PORT="1234"
BACKEND_PORT="1235"
mkdir -p "$STATE_DIR" || exit 1
is_running() {
  [ -f "$PID_FILE" ] || return 1
  PID="$(cat "$PID_FILE" 2>/dev/null)"
  case "$PID" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$PID" 2>/dev/null
}
start_server() {
  if is_running; then echo "Proxy already running (PID $(cat "$PID_FILE"))."; exit 0; fi
  rm -f "$PID_FILE"
  if [ ! -x "$RTL_TCP" ]; then echo "ERROR: rtl_tcp not found: $RTL_TCP"; exit 1; fi
  if [ ! -x "$PROXY" ]; then echo "ERROR: sdr_proxy not found: $PROXY"; echo "Build it in Termux using scripts/build-proxy.sh"; exit 1; fi
  export LD_LIBRARY_PATH="$LIB_DIR:$PREFIX/lib:$LD_LIBRARY_PATH"
  nohup "$PROXY" "$RTL_TCP" "$PORT" "$BACKEND_PORT" >> "$LOG_FILE" 2>&1 </dev/null &
  PID=$!
  echo "$PID" > "$PID_FILE"
  sleep 1
  if kill -0 "$PID" 2>/dev/null; then
    echo "On-demand proxy started. PID=$PID"
    echo "Client endpoint: X96_IP:$PORT"
    echo "rtl_tcp will run only while a client session is active (loopback port $BACKEND_PORT)."
    echo "Log: $LOG_FILE"
  else
    rm -f "$PID_FILE"
    echo "ERROR: proxy failed to start. Last log lines:"
    tail -n 50 "$LOG_FILE" 2>/dev/null
    exit 1
  fi
}
stop_server() {
  if ! is_running; then rm -f "$PID_FILE"; echo "Proxy is not running."; exit 0; fi
  PID="$(cat "$PID_FILE")"
  kill -TERM "$PID" 2>/dev/null
  COUNT=0
  while [ "$COUNT" -lt 5 ] && kill -0 "$PID" 2>/dev/null; do sleep 1; COUNT=$((COUNT + 1)); done
  if kill -0 "$PID" 2>/dev/null; then echo "WARNING: proxy still running; PID file retained. Check log."; exit 1; fi
  rm -f "$PID_FILE"
  echo "Proxy stopped."
}
status_server() {
  if is_running; then echo "RUNNING: proxy PID $(cat "$PID_FILE")"; echo "Listening on 0.0.0.0:$PORT"; echo "RTL-TCP is spawned only for an active client."
  else echo "STOPPED"; fi
}
if [ "$(id -u)" != "0" ]; then echo 'Run as root: su -c "sh /sdcard/Download/server.sh status"'; exit 1; fi
case "$1" in
  start) start_server ;;
  stop) stop_server ;;
  status) status_server ;;
  log) tail -n 100 "$LOG_FILE" 2>/dev/null ;;
  *) echo "Usage: $0 {start|stop|status|log}"; exit 2 ;;
esac
