# X96 setup notes

## Requirements already established on this device

- Android 9, ARMv7
- Root access through SuperSU
- Termux installed
- Osmocom RTL-SDR built under:
  `/data/data/com.termux/files/home/rtl-sdr`
- NESDR SMArt v5 directly attached to the X96 USB port

## Copying scripts to the box

Download `scripts/diagnose.sh` and `scripts/server.sh` from this repository and place both in `/sdcard/Download/`.

## Read-only diagnosis

Stop SDR Driver first. Then run from Termux:

```sh
su -c "sh /sdcard/Download/diagnose.sh"
```

The report is saved in `/sdcard/Download/`. This script does not start, stop, or open any RTL-SDR process.

## Server management

Stop SDR Driver before starting the standalone server. Run:

```sh
su -c "sh /sdcard/Download/server.sh start"
```

Check status:

```sh
su -c "sh /sdcard/Download/server.sh status"
```

Read recent log output:

```sh
su -c "sh /sdcard/Download/server.sh log"
```

Stop the managed server:

```sh
su -c "sh /sdcard/Download/server.sh stop"
```

The server listens on TCP port 1234 on all interfaces. Use the X96's LAN IP and port 1234 in an RTL-TCP-compatible client.

## Important limitation of this first server manager

This version provides controlled start/stop/status and prevents duplicate starts of the process it manages. It does **not yet** stop the server automatically when a phone disconnects, nor does it install boot startup or a wake lock. Those features will be added only after a stable single-client connection is verified.

## USB ownership

Only one program can claim the RTL-SDR USB interface at a time. Fully stop SDR Driver before starting this service. Do not run `rtl_test` while `rtl_tcp` is active.
