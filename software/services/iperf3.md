# Port 5432 Service
While port 5432 is normally associated with Postgresql, this was the TCP port that Vilo chose to use to host their custom TCP service that communicates with the mobile app. This means when a customer connects their mobile phone to the Vilo router, the app communicates with the router through this port. An example of captured traffic between the mobile app (`192.168.58.100`) and the Vilo router (`192.168.58.1`) using port 5432 is in [port5432.pcapng](./resources/port5432.pcapng).

All messages follow the same format, with a 15-byte header followed by a variable-length payload. The maximum message size (header + payload) is 1024 bytes. The app will normally communicate setting changes through the AWS IoT infrastructure, but in cases when the router needs to get setup or doesn't have internet access, the app falls back to communicating here. Because of this, message streams are initiated by the app. 

Each message stream corresponds to a single TCP stream. The app first sends a message with the 0x2a opcode, which requests a key used to encrypt/decrypt all future messages for that stream. The router responds with the 16-byte randomly-generated key (encrypted with a hard-coded key), and then the app makes all future requests with the message payload encrypted using the key. Each message the app sends elicits a response from the router. All payloads (except opcode 0x2b) uses JSON, no matter who is sending the message.

This service does not use any sort of authentication or authorization, meaning *anyone* connected to the WiFi has the ability to fully interact with this service.

## Message Header Format
| Bytes   | Name            | Description  |
|---------|-----------------|--------------|
| 0x0-0x8 | Phone Signature | An 9-byte signature identifying the Operating System of the phone with the app. Values include `'HLandrUS1'` (for Android) and `'HLIOS0US\x01'` (for iOS). |
| 0x9     | Opcode          | A single byte opcode signifies what purpose the message has. See the section below for a comprehensive list of values |
| 0xa     | NULL            | Null byte    |
| 0xb-0xc | Payload Length  | Two bytes denoting the length of the proceeding payload, with the LSB (Least Significant Byte) first |
| 0xd-0xe | NULL            | Null bytes   |

*Notes about headers*:
* Only the `HL` and `US` values are actually checked to be correct. If the `HL` or `US` values are not correct, no response is returned.
* Whenever the router sends a response to the app, the signature is copied from the app's message. For example, if the app sends `HLxxxxUSx`, then the router's response message will also have the signature `HLxxxxUSx`.

## Opcodes
| Opcode    | Payload | Encrypted | Sender | Function Name |
|-----------|---------|-----------|--------|---------------|
| 0x18      | N       | N/A       | App    | `local_app_set_router_wifi_work` |
| 0x19      | N       | N/A       | Router | N/A |
| 0x1c      | Y       | Y         | App    | `local_app_set_router_wifi_SSID_PWD` |
| 0x1d      | Y       | Y         | Router | N/A |
| 0x22      | Y       | Y         | App    | `local_app_set_router_pppoe` |
| 0x23      | Y       | Y         | Router | N/A |
| 0x24      | Y       | Y         | App    | `local_app_set_router_wan` |
| 0x25      | Y       | Y         | Router | N/A |
| 0x26      | ?       | ?         | App    | `local_app_get_router_wan_info` |
| 0x2a      | Y       | N         | App    | `local_app_get_random_key` |
| 0x2b      | Y       | N         | Router | N/A |
| 0x34      | ?       | ?         | App    | `local_app_get_router_ip_list` |
| 0x38      | N       | N/A       | App    | `local_app_export_pppoe` |
| 0x39      | Y       | Y         | Router | N/A |
| 0x3e      | Y       | Y         | App    | `local_app_set_router_token` |
| 0x42      | ?       | ?         | App    | `local_app_auto_detect_router_wan_status` |
| 0x48      | Y       | Y         | App    | `local_app_upload_log_when_router_online` |
| 0x4a      | ?       | ?         | App    | `local_app_get_router_current_wan_state` |
| 0x58      | N       | N/A       | App    | `local_app_get_router_info` |
| 0x59      | Y       | Y         | Router | N/A |
| 0x5e      | N       | N/A       | App    | `local_app_get_router_current_state` |
| 0x5f      | Y       | Y         | Router | N/A |
| 0x60      | ?       | ???       | App    | `local_app_sync_ping_para_to_child` |
| 0x62      | ?       | ???       | App    | `test_router_speed` |
| 0x64      | ?       | ???       | App    | `local_app_open_boa_web_server` |
| 0x66      | ?       | ???       | App    | `local_app_close_web_server` |
| 0x68      | ?       | ???       | App    | `local_app_debug_log` |
| 0x6c      | ?       | ???       | App    | `local_app_parse_actionId` |
| 0x6e      | ?       | ???       | App    | `local_app_parse_plugin_list` |

### Opcode 0x18 (`local_app_set_router_wifi_work`)
The app signals the router restarts both the normal and guest WiFi networks (not rebooting the router). No payload is passed.

### Opcode 0x19
The router sends no response payload.

### Opcode 0x1c (`local_app_set_router_wifi_SSID_PWD`)
The app sends JSON like `{"ssid":"...","password":"..."}` which changes the WiFi SSID and password fields, then restarts the WiFi. The `ssid` parameter is limited to 32 characters.

### Opcode 0x1d
The router sends JSON like `{"code":0}` with a status code to indicate the success of opcode 0x1c.

### Opcode 0x22 (`local_app_set_router_pppoe`)
The app sends JSON like `{"pppoe_account":"...","pppoe_password":"..."}`, and the router attempts to connect to the WAN by sending those credentials out. The account and password are limited to 128 characters each.

### Opcode 0x23
The router sends JSON like `{"code":0}` with a status code to indicate the success of opcode 0x22.

### Opcode 0x24 (`local_app_set_router_wan`)
The app sends JSON to the router with information about how to get the WAN connection up and working. There are 3 options for the WAN:

* `3` - set a static IP
    * You must also pass in the `flag_dns`, `ipaddr`, `netmask`, and `gw` fields. `ipaddr`, `netmask`, and `gw` fields must all be set to IP addresses. `flag_dns` is an integer set to `1` (meaning you want to set new DNS servers), `0` (meaning you want to clear the current DNS servers), or anything else (meaning you want to keep the current DNS servers). If `flag_dns` is set to `1`, then the `dns1` and/or `dns2` fields can be included.
    * An example JSON payload for this would be `{"type":"3", "ipaddr":"2.2.2.2", "netmask":"255.255.255.255", "gw": "1.1.1.1", "flag_dns":"1", "dns1":"8.8.8.8"}`
* `2` - use PPPoE
    * You must also pass in the `pppoe_username` and `pppoe_password` fields. These fields are first XORed with 0x77 (the char `'w'`), then base64 encoded. The application will base64 decode these fields, then XOR them with 0x77 before using them to try to connect to the WAN.
    * An example JSON payload would be `{"type":"2", "pppoe_username":"AgQSBRkWGhI=", "pppoe_password":"BxYEBAAYBRM="}` (the username value is `username` and the password value is `password`).
* `1` - use DHCP
    * No other parameters are passed here. An example JSON payload would be `{"type":"1"}`.

### Opcode 0x25
The router sends JSON like `{"code":0}` with a status code to indicate the success of opcode 0x24.

### Opcode 0x2a (`local_app_get_random_key`)
Sends Phone ID and type like `{"PhoneID": "3D1141BB", "Type": 1}`. Type is hard-coded in the app as 1, phone ID is first 8 bytes of phone UUID.

### Opcode 0x2b
The last 16 bytes of the payload are a randomly-generated key from the router that will be used to encrypt all further communication from the router for that TCP session. See details below on how that key is transmitted and used in subsequent encryption.

### Opcode 0x38
The app tells the router to attempt to retrieve PPPoE credentials from an old router connected on the WAN interface. The router will respond with a 57 opcode, if the results do not accurately send the info, this message is sent again to retry the process every 5 seconds until it has been attempted 12 times.

### Opcode 0x39
After PPPoE credentials have been imported from the old router to the current Vilo router, the Vilo router sends these credentials back to the app for storage.

### Opcode 0x48
This sends a JSON payload to the router with the fields `operation`, `user_name` (Vilo username??), and `error_code`. When/why is this called? What does operation mean? And what does the error code convey?

### Opcode 0x58
This is a generic "ACK" packet sent by the app acknowledging the successful reception and processing of the instruction from the router.

### Opcode 0x59
This message conveys the router's current state to the app, such as whether it is connected to the Internet, already bound, using DHCP, etc. An example message is `{"ssid":"Vilo_c6b7", "model":"", "type":"Router", "name":"Vilo_c6b7", "mac":"e8da000fc6b7", "pt_ver":"1.0.0", "fw_ver":"1.1.1.3237", "all_ver":"5.16.0.206", "state":"Uninitialized", "wan_type":"dhcp", "code":0, "net_state":0, "enr":""}`

### Opcode 0x5e
This message tells the router the app wants to start setting up the router.

### Opcode 0x5f
As a response to opcode 94, the router sends the new state like `{"state":"PreBound"}`.

## Message Encryption
All messages sent with payloads have their payloads encrypted (with the exception of the 0x2a opcode message). When the app starts a new stream and sends a 0x2a opcode message, the router responds with an encrypted, 16-byte randomly-generated key. To derive the actual key from the encrypted key, a custom "deobfuscation" function is used in conjunction with the BTEA encryption algorithm and a hard-coded key `routerLocalWhoAr`. This script relies on Python 3.11 and the `xxtea` pip3 module. The process (in Python syntax) looks like the following:

```python
key = deobfuscate(btea.decrypt(payload=deobfuscate(bytes_from_packet), key=deobfuscate(b'routerLocalWhoAr')))
```

After the key is derived, it is used to encrypt and decrypt all future messages in that TCP stream using the symmetric XXTEA algorithm. All of this is scripted in Python using our custom `Vilo` class (see below for details).

## Python Script
To simplify our interactions with this service, we created a custom Python class called `Vilo` defined in [`vilo.py`](./resources/vilo.py). Using this class is *super* easy, it's just as simple as:

```python
from vilo import Vilo

v = Vilo(debug=True)
print(v.send_message(0x58))
print(v.send_message(0x24, b'{"type":"1"}'))
```

Initializing the class causes the script to automatically reach out to the server and derive the encryption key. The `send_message()` function can then be used to send messages with specific opcodes and payloads, with the decrypted response returned.

### `Vilo` Class Documentation
```python
def __init__(self, ip_address : str = '192.168.58.1', 
                 port : int = 5432, 
                 signature : bytes = b'HLandrUS1', 
                 timeout : int = 10, 
                 debug : bool = False)
```

When initializing a `Vilo` class like `v = Vilo()`, a socket is established to the `ip_address` and `port` parameters (or defaults). A 0x2a opcode message is sent, and the XXTEA encryption key is automatically derived from the response. If the `debug` parameter is set to `True`, then more information is printed out during initialization and each subsequent message.

```python
def send_message(self, opcode : int, payload : bytes = b'', encrypted : bool = True) -> bytes
```

The only required argument is `opcode`, which should be passed in as an integer (like `0x58`). If no payload is supplied, then it's assumed there is no payload to send; otherwise, a `bytes` object with a valid JSON payload should be supplied. The `send_message()` function will automatically encrypt the payload and decrypt the response. It also automatically tacks on and removes the necessary header, using the `signature` supplied when the class was initialized.

```python
def encrypt(self, payload : bytes) -> bytes
```

This helper function uses the current key and XXTEA to encrypt the payload of messages sent to the router.

```python
def decrypt(self, payload : bytes) -> bytes
```

This helper function uses the current key and XXTEA to decrypt the payload of messages received from the router.

```python
def derive_key(self, encrypted_key : bytes) -> bytes
```

This helper function uses the `deobfuscate()` function, the BTEA encryption algorithm, and a hard-coded key to recover the actual key from the encrypted bytes sent by the router. 

```python
def deobfuscate(self, b_arr : bytes) -> bytes
```

This simple helper function implements a custom "obfuscation" function used while decrypting the XXTEA key.


## Unprocessed Notes
Valid opcodes from the app:
- 0x26 (responds with {"type":"1","flag_dns":"0"}) - get WAN info
- 0x2a (responds with no payload) - get key
- 0x34 (in binary) - get IP list
- 0x38 (responds with {"code":2,"pppoe_username":"","pppoe_pwd":""}) - export PPPoE
- 0x3e (no response, prob expecting payload) - set router token
- 0x42 (responds with {"type":"0"}) - auto detect router wan status
- 0x48 (responds with {"code":0}) - upload log when router online
- 0x4a (responds with {"net_state":0}) - get router current WAN state
- 0x58 (responds with all info) - get router info
- 0x5e (responds with state only) - get router current state

It doesn't matter what opcode we send first, as long as it's an above opcode, the server will respond with a key + the opcode+1 because it just assumes we're sending 0x2a as our opcode.

If the "Type" field is not 1 but still a number, it responds with (num%256) + 32 null bytes. If it is 1, it responds with 1 + 32 random bytes. If it's not 1 AND not a number, it responds with 33 null bytes.

If the "Type" field is not 1, then the server will still send the "key" message but the message after that with the normal JSON data won't be sent. (type 2 is AES, any other is no encryption. These are included in the binary but not actually implemented so they don't work)

As long as the length specified is as long as the JSON payload provided, you can put extra stuff afterwards and it doesn't care (and the length can be wrong too, including longer than the entire payload sent).