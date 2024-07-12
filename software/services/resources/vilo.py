class Vilo():
    NULL = b'\x00'
    NULL2 = b'\x00\x00'

    def __init__(self, ip_address : str = '192.168.58.1', 
                 port : int = 5432, 
                 signature : bytes = b'HLandrUS1', 
                 timeout : int = 10, 
                 debug : bool = False):
        # initializations
        import socket
        self.ip_address = ip_address
        self.port = port
        self.signature = signature
        self.debug = debug

        # set up socket
        if self.debug:
            print(f"[+] Connecting to {self.ip_address}:{self.port}...")
        self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.s.settimeout(timeout)
        self.s.connect((self.ip_address, self.port))

        # set up encryption
        if self.debug:
            print("[+] Setting up encryption...")
        out = self.send_message(0x2a, b'{"PhoneID":"AAAAAAAA", "Type": 1}', False)

        encrypted_key = out[1:]
        assert len(encrypted_key) == 16
        self.key = self.derive_key(encrypted_key)
        if self.debug:
            print(f"[+] Key = {self.key}")

    def send_message(self, opcode : int, payload : bytes = b'', encrypted : bool = True) -> bytes:
        if encrypted:
            payload = self.encrypt(payload)

        # send message
        msg = self.signature + int.to_bytes(opcode) + self.NULL + (len(payload)).to_bytes(2, byteorder='little') + self.NULL2 + payload
        if self.debug:
            print(f"[+] Sending message = {msg}")
        self.s.send(msg)

        # parse response
        response = self.s.recv(1024)
        if self.debug:
            print(f"[+] Received response = {response}")
        header = response[:15]
        payload = response[15:]

        if encrypted:
            return self.decrypt(payload).decode('utf-8')

        return payload
    
    def encrypt(self, payload : bytes) -> bytes:
        import xxtea
        return xxtea.encrypt(payload, self.key)
    
    def decrypt(self, payload : bytes) -> bytes:
        import xxtea
        return xxtea.decrypt(payload, self.key)

    def derive_key(self, encrypted_key : bytes) -> bytes:
        OLD_KEY = b'routerLocalWhoAr'
        import subprocess, binascii

        # get payload for Java file
        arg = binascii.hexlify(self.deobfuscate(encrypted_key)).decode()

        # subprocess
        out = subprocess.getoutput(f'javac btea.java && java btea {arg}')

        # get output
        new = self.deobfuscate(bytes.fromhex(out))
        return new

    def deobfuscate(self, b_arr : bytes) -> bytes:
        retval = bytearray(16)
        for i in range(4):
            retval[i] = b_arr[3 - i]
            retval[i + 4] = b_arr[7 - i]
            retval[i + 8] = b_arr[11 - i]
            retval[i + 12] = b_arr[15 - i]
        return bytes(retval)
    

if __name__ == '__main__':
    print("[+] Testing connection...")
    vilo = Vilo(debug=True)