# X96 setup notes

## Target device

- Android 9, ARMv7
- Root through SuperSU
- Termux installed
- Osmocom RTL-SDR tools already built at `/data/data/com.termux/files/home/rtl-sdr/build/src/`
- Nooelec NESDR SMArt v5 directly attached to an X96 USB port

## 1. Get the project

Open the Termux app and run:

```sh
git clone https://github.com/emreacar23-cmd/x96-rtl-sdr-server.git
```

## 2. Build the on-demand proxy

Still in Termux, as the normal Termux user:

```sh
sh ~/x96-rtl-sdr-server/scripts/build-proxy.sh
```

This creates `~/rtl-sdr/build/src/sdr_proxy`. It requires the existing `rtl_tcp` binary and Termux clang.

## 3. Start and manage

Stop SDR Driver fully before starting the standalone service.

Start:

```sh
su -c "sh /data/data/com.termux/files/home/x96-rtl-sdr-server/scripts/server.sh start"
```

Status:

```sh
su -c "sh /data/data/com.termux/files/home/x96-rtl-sdr-server/scripts/server.sh status"
```

Log:

```sh
su -c "sh /data/data/com.termux/files/home/x96-rtl-sdr-server/scripts/server.sh log"
```

Stop:

```sh
su -c "sh /data/data/com.termux/files/home/x96-rtl-sdr-server/scripts/server.sh stop"
```

Connect an RTL-TCP-compatible client to the X96 LAN IP on TCP port 1234.

## On-demand behavior

- The proxy listens on port 1234 without opening the USB dongle.
- When a client connects, it launches `rtl_tcp` on loopback port 1235.
- It relays the RTL-TCP byte stream in both directions.
- When the client disconnects, it stops its `rtl_tcp` child, releasing the dongle.
- The proxy remains ready for the next client.

This first implementation supports one active client at a time.

## USB ownership

Only one process can claim the RTL-SDR USB interface at a time. Stop SDR Driver before starting the service. Do not run `rtl_test` while a client session is active.

## Deferred

Boot auto-start, partial wake lock, automatic USB recovery, and multi-client support will be added only after the single-client on-demand service is verified on the box.
