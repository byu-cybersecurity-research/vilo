# Vilo Firmware and Network Services

## Firmware
Firmware can be a tricky thing to document due to its fluid nature. For example, there are several versions of the firmware, and most of it is stripped, compiled executables. While extensive work has been done to reverse engineer these executables in our local shared Ghidra server, documenting it in a repository like this is still a major challenge. We have organized the firmware in the [`firmware/` folder](./firmware/) by making a folder called [`filesystem/`](./firmware/filesystem/) (which contains the entirety of the read-only Linux filesystem), a folder called [`hualai/`](./firmware/hualai/) (the only writable, persistent folder in the filesystem), and a folder called [`old/`](./firmware/old/) which hosts `.bin` files of previous firmware versions. Updates only affect the `/hualai` directory, and so only the most recent version of that folder is stored in this repo's [`hualai/`](./firmware/hualai/) folder.

For more documentation, see:
* [`Emulation.md`](Emulation.md) for info about how to emulate the MIPS binaries on an x86 machine
* [`Compilation.md`](Compilation.md) for info about how to compile C code into a binary that can be run on Vilo routers
* [`Exfiltration.md`](Exfiltration.md) for info about how to exfiltrate files from the Vilo router using only existing binaries
* [`Pwn.md`](Pwn.md) for guidelines on how to develop working PoCs for binary exploitation vulnerabilities

## Router Network Services
After getting a remote shell on the router through exploiting some vulnerabilities we found, we were able to look at the process list and open sockets to create a full list of running services on this router, both through TCP and UDP. More in-depth documentation on each running service can be found by clicking on the process name associated with the open port number. Note that some services are exposed on multiple ports.

**TCP services by port**:
* 5432 - [`./iperf3`](./services/iperf3.md)
* 8023 - boa (not ran on startup)
* 8058 - `chdeviceservice /web`
* 52881 - [`wscd -start -c /var/wsc-wlan0-wlan1.conf -w wlan0 -w2`](./services/wscd.md)

**UDP services by port**:
* 53 - `dnrd --cache=off -s 192.168.8.1`
* 67 - `udhcpd /var/udhcpd.conf`
* 1900 - [`wscd -start -c /var/wsc-wlan0-wlan1.conf -w wlan0 -w2`](./services/wscd.md)
* 2313 - `iapp br0 wlan0 wlan1`
* 3517 - `iapp br0 wlan0 wlan1`
* 5246 - `AC /etc/capwap`
* 5247 - `AC /etc/capwap` (localhost only)
* 6665 - `nms`
* 37211 - [`wscd -start -c /var/wsc-wlan0-wlan1.conf -w wlan0 -w2`](./services/wscd.md) (192.168.58.1 interface only)
* 47538 - `AC /etc/capwap`
* 54150 - `AC /etc/capwap`