from AWSIoTPythonSDK.MQTTLib import AWSIoTMQTTShadowClient
import time
import json

# AWS connection info
host = "a368k6zybw30wc.iot.us-west-2.amazonaws.com"
port = 8883

# Certs and private key
rootCAPath = "rootCA.crt"
certificatePath = "cert.pem"
privateKeyPath = "privkey.pem"

# These have to be the router MAC address
thingName = "e8da000a7487"
clientId = "e8da000a7487"

# Custom callback for shadow actions
def customCallback(payload, responseStatus, token):
    print("PAYLOAD:", payload)
    print("RESPONSE STATUS:", responseStatus)
    print("TOKEN:", token)

# Init AWSIoTMQTTShadowClient
myClient = AWSIoTMQTTShadowClient(clientId)

# AWSIoTMQTTShadowClient connection configuration
myClient.configureEndpoint(host, port)
myClient.configureCredentials(rootCAPath, privateKeyPath, certificatePath)
myClient.configureAutoReconnectBackoffTime(1, 32, 20)
myClient.configureConnectDisconnectTimeout(10) # 10 sec
myClient.configureMQTTOperationTimeout(5) # 5 sec

# Connect to AWS IoT
if myClient.connect():
    print("[*] Connected successfully")
else:
    print("[*] An unknown error occurred while trying to connect.")
    exit()

# Create a device shadow handler, use this to update and delete shadow document
deviceShadowHandler = myClient.createShadowHandlerWithName(thingName, True)

#### TOPICS ####
# $aws/things/%s/shadow/get
# $aws/things/%s/shadow/update
# $aws/things/%s/shadow/get/accepted
# $aws/things/%s/shadow/update/accepted
# $aws/things/%s/shadow/update/delta

# Testing
print("[*] Running shadowUpdate...")
token = deviceShadowHandler.shadowUpdate(json.dumps({"state":{"reported":{},"desired": None}}), customCallback, 5)
print("TOKEN:", token)
print("[*] Action completed")
print()

print("[*] Running shadowGet...")
token = deviceShadowHandler.shadowGet(customCallback, 10)
print("TOKEN:", token)
print("[*] Action completed")
print()
