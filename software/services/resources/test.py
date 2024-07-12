from vilo import Vilo

v = Vilo(debug=True)
print(v.send_message(0x58))
print(v.send_message(0x24, b'{"type":"1"}'))
