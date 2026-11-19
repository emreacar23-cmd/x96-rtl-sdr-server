# X96 RTL-SDR Server

Rooted Android 9 / ARMv7 setup for sharing a locally attached RTL-SDR dongle over the LAN with an `rtl_tcp`-compatible client.

## Target hardware

- X96 Max Plus Q2 (reported Android 9, `armv7l`)
- Nooelec NESDR SMArt v5 (USB ID `0bda:2838`, R820T tuner)
- Termux-built Osmocom `rtl-sdr` tools

## Current state

- The Osmocom RTL-SDR source was built in Termux.
- `rtl_tcp` was observed listening on TCP port 1234.
- The dongle is visible in Android sysfs.
- A diagnostic run reported `usb_claim_interface error -6`.

**Important correction:** the first diagnostic script itself ran `rtl_test`. Therefore, seeing a new `rtl_test` process after running that diagnostic does not prove that Android or another app restarted it. Future diagnostic scripts must be read-only and must not launch `rtl_test` automatically.

## Safety rules

1. Only one process may own the RTL-SDR USB interface at a time.
2. Do not run `rtl_test` while `rtl_tcp` or SDR Driver is using the dongle.
3. Stop SDR Driver before starting the standalone server.
4. Do not kill Android's `android.hardware.usb@1.0-service`; it is a system service.
5. Do not assume that a successful TCP connection means IQ samples are flowing. The `RTL0` greeting confirms only the initial RTL-TCP handshake.

## Planned layout

- `scripts/diagnose.sh` — read-only system, USB, and process report
- `scripts/server.sh` — single-instance server start/stop/status wrapper
- `docs/SETUP.md` — installation and operation instructions

## Current diagnostic finding

The reported `usb_claim_interface error -6` is consistent with a busy USB interface (`LIBUSB_ERROR_BUSY`). It does not by itself prove a hardware fault. The exact owner of the interface is not yet established.

## License

Project scripts and documentation: MIT. The separately built Osmocom RTL-SDR project retains its own license and copyright.
