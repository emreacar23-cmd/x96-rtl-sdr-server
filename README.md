# X96 RTL-SDR Server

On-demand RTL-TCP sharing for a rooted Android TV box running Termux.

## Target hardware

- X96 Max Plus Q2 (reported Android 9, `armv7l`)
- Nooelec NESDR SMArt v5 (USB ID `0bda:2838`, R820T tuner)
- Termux-built Osmocom `rtl-sdr` tools

## Architecture

A small TCP proxy listens on port 1234 without opening the USB dongle. When a client connects, it launches `rtl_tcp` bound to loopback port 1235 and relays the RTL-TCP stream. When the client disconnects, it stops that child process and releases the dongle.

## Current state

- Osmocom RTL-SDR was built in Termux.
- NESDR is visible in Android sysfs.
- A previous test reported `usb_claim_interface error -6`.
- The diagnostic script is read-only and does not start `rtl_test`.
- The on-demand proxy and build script are implemented in this repository, but still need compilation and validation on the X96.

## Setup

See [docs/SETUP.md](docs/SETUP.md).

## Safety

1. Only one process may own the RTL-SDR USB interface at a time.
2. Stop SDR Driver before starting this service.
3. Do not run `rtl_test` during an active client session.
4. A TCP connection alone does not prove IQ streaming; test with a real RTL-TCP client.

## Next validation

Compile `src/sdr_proxy.c` on the X96 Termux installation and test one client. Boot auto-start and wake-lock management are deferred until this works reliably.
