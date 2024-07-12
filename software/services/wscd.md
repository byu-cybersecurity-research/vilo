# WSCD
Port 52881 is associated with a UPnP service running on the router. Using the Python [UPnPy](https://pypi.org/project/UPnPy/) library, we were able to get a list of available UPnP services and actions for each service. We discovered that the router offers a UPnP service named `WFAWLANConfig` with the following actions:
- GetDeviceInfo
- PutMessage
- GetAPSettings
- SetAPSettings
- DelAPSettings
- GetSTASettings
- SetSTASettings
- DelSTASettings
- PutWLANResponse
- SetSelectedRegistrar
- RebootAP
- ResetAP
- RebootSTA
- ResetSTA

A more detailed report of each action and their respective arguments can be found in [upnp_actions.txt](./resources/upnp_actions.txt)

We found documentation of these actions for the WFAWLANConfig service [here](https://www.wi-fi.org/system/files/WFA_WLANConfig_1_0_Template_1_01.pdf). Values use TLV format and the [Wi-Fi Simple Config specification](https://ndeflib.readthedocs.io/en/stable/records/wifi.html), otherwise known as [Wi-Fi Protected Setup](https://en.wikipedia.org/wiki/Wi-Fi_Protected_Setup), or WPS.

We were able to decode the output from the `GetDeviceInfo` action using the codes defined in [this header file](https://android.googlesource.com/kernel/common.git/+/bcmdhd-3.10/drivers/net/wireless/bcmdhd/include/proto/wps.h), resulting in the following information:

```
Device Info:
        Version: b'\x10'
        Message Type: b'\x04'
        UUID_E: b'\x11"3DUfw\x88\x99\xaa\xe8\xda\x00\nt\x82'
        MAC Address: e8:da:00:0a:74:84
        Nonce: b'xPWDKwu4A8zhrsAuP8zwtA=='
        Public Key: b'0BQbFWVulrhfzq0ujnYzDSsawVdrsCbnoyjA4br4z5FmQ3EXTAjuEuySsFGcVIefISVb5ah3Dh+hiARw70I8kONNeEem/LSSRWPRrx2wxIHq2YUsUZvx3UKcFjlRz2kYGxMq6io2hMrzW8VKyhsgyIuztzOf99VuCROdd/CsWAeQl5OCUdu+dehnFcxrfAypRfqN2NZhvrc7QUAyeY2t7jK13WG/EF8Y2JIXdgt1xdlmpaSQRyzrqeO0Ik89ifsr'
        Auth Type Flags: b'\x00a'
        Encr Type Flags: b'\x00\t'
        Conn Type Flags: b'\x01'
        Config Methods: b'\x07\x84'
        SC State: b'\x02'
        Manufacturer: b'Realtek Semiconductor Corp.'
        Model Name: b'RTL8xxx'
        Model Number: b'EV-2010-09-20'
        Serial Number: b'123456789012347'
        Prim Dev Type: b'\x00\x06\x00P\xf2\x04\x00\x01'
        Device Name: b'Realtek Wireless AP'
        RF Band: b'\x01'
        Assoc State: b'\x00\x00'
        Device Pwd ID: b'\x00\x00'
        Config Error: b'\x00\x00'
        OS Version: b'\x10\x00\x00\x00'
        Vendor Ext: b'\x007*\x00\x01 '
```

(see [upnp.py](./resources/upnp.py) for the script used to obtain this information)