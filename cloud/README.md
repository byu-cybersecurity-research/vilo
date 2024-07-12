## AWS Infrastructure
We connected the router to the internet through a managed switch and enabled port mirroring in order to capture all the traffic outbound from the router (see [`routersetup.pcapng`](./resources/routersetup.pcapng)). In this capture, the router has the IP `172.16.0.15`. A description of the traffic in the capture is below:

* The router pings the gateway and 8.8.8.8 continuously until it checks for Internet connectivity through Google (packet 144)
* The router reaches out to `app-api.kivolabs.com` through HTTPS for approximately 1 HTTP request
* The router connects to `clock.fmt.he.net` for NTP
* The router reaches out to `device-api.kivolabs.com` multiple times through HTTPS
* The router reaches out to `shiro-iot-files.s3.us-west-2.amazonaws.com` through HTTPS
* Finally, the router reaches out to `a368k6zybw30wc.iot.us-west-2.amazonaws.com` to connect to the AWS IoT infrastructure and register with their system through TLS-encrypted MQTT.

### AWS IoT Infrastructure
The router connects to the AWS IoT infrastructure at `a368k6zybw30wc.iot.us-west-2.amazonaws.com`. The infrastructure uses the [AWS IoT Device Shadow Service](https://docs.aws.amazon.com/iot/latest/developerguide/iot-device-shadows.html). By decompiling the `hl_client` binary, we found that the router uses the following MQTT topics:
- `$aws/things/<thingName>/shadow/get`
- `$aws/things/<thingName>/shadow/update`
- `$aws/things/<thingName>/shadow/get/accepted`
- `$aws/things/<thingName>/shadow/update/accepted`
- `$aws/things/<thingName>/shadow/update/delta`

These are the [standard topics](https://docs.aws.amazon.com/iot/latest/developerguide/device-shadow-mqtt.html) associated with unnamed shadows.

#### Connecting
A certificate, private key, and root certificate are required in order to connect to the infrastructure.

In addition, both the `thingName` and `clientId` used to connect must be the MAC address of the device associated with the certificates. Using the [AWSIoTPythonSDK](https://s3.amazonaws.com/aws-iot-device-sdk-python-docs/html/index.html), we wrote [a script](./resources/aws.py) to automate the connection process.
