# Vilo 0day Research
Watch our DEFCON talk [here](https://www.youtube.com/watch?v=IyInMgXj4k4&t=1167s)!

## Background
[Vilo Living](https://store.viloliving.com/) is a startup founded in 2021 that creates cheap mesh network WiFi routers for consumer and ISP use. Currently, they only have 2 devices on the market: a regular mesh system, and a mesh system that supports WiFi 6. After initial research, we haven't found a single mention of any CVEs or vulnerabilities found in any Vilo routers. Looking through their website, we weren't super impressed with how they made their security sound. However, we discovered that they have a [Bug Bounty Program](https://support.viloliving.com/hc/en-us/articles/7150613338519-Vilo-Bug-Bounty-Program-Terms-and-Conditions-), but it requires you be enrolled in their Beta Testing program protected by an NDA, and only swag "prizes" were given out. 

The Vilo router is setup using a more modern method. The router is turned on, connected to the Internet on the WAN port, and the [Vilo](https://play.google.com/store/apps/details?id=com.viloliving.vilo) app must be installed to communicate with it (no web GUI). Once a Vilo account is created, you are instructed to connect to the WiFi network created by the router and activate it. When you activate it, the router reaches out to Vilo's [AWS IoT](https://aws.amazon.com/iot/) infrastructure where it registers itself. From this point onward, all changes made to the router go through the AWS IoT link. Whenever the user interacts with the Vilo app, messages are sent to the AWS IoT infrastructure where it's interpreted, and a second message is sent from the AWS IoT infrastructure to the actual router using encrypted MQTT.

## Attack Surfaces
We have found 4 main attack surfaces:

1. [The physical router](./hardware/)
2. [The router's firmware and active network services](./software/)
3. The Android/iOS client app
4. [Communications with the AWS infrastructure](./cloud/)

In an attempt to more fully organize our documentation, a folder for each attack surface has been created where documentation is contained. Click on the links above to learn more about each of those surfaces. 

## Vulnerabilities
All found vulnerabilities are documented in the [vulns folder](./vulns/) with a Markdown file for each one. Each file contains a thorough description of the vulnerability, where it's located, the impact, and oftentimes a relevant Proof of Concept (PoC). 

* [CVE-2024-40083](https://www.cve.org/CVERecord?id=CVE-2024-40083) - [Buffer Overflow in `local_app_set_router_token()`](./vulns/CVE-2024-40083.md) (9.6 Critical)
* [CVE-2024-40084](https://www.cve.org/CVERecord?id=CVE-2024-40084) - [Buffer Overflow in Boa Webserver](./vulns/CVE-2024-40084.md) (9.6 Critical)
* [CVE-2024-40085](https://www.cve.org/CVERecord?id=CVE-2024-40085) - [Buffer Overflow in `local_app_set_router_wan()`](./vulns/CVE-2024-40085.md) (9.6 Critical)
* [CVE-2024-40086](https://www.cve.org/CVERecord?id=CVE-2024-40086) - [Buffer Overflow in `local_app_set_router_wifi_SSID_PWD()`](./vulns/CVE-2024-40086.md) (9.6 Critical)
* [CVE-2024-40087](https://www.cve.org/CVERecord?id=CVE-2024-40087) - [No Authentication in Custom Port 5432 Service](./vulns/CVE-2024-40087.md) (9.6 Critical)
* [CVE-2024-40088](https://www.cve.org/CVERecord?id=CVE-2024-40088) - [Arbitrary File Enumeration in Boa Webserver](./vulns/CVE-2024-40088.md) (4.7 Medium)
* [CVE-2024-40089](https://www.cve.org/CVERecord?id=CVE-2024-40089) - [Blind Authenticated Command Injection in Vilo Name](./vulns/CVE-2024-40089.md) (9.1 Critical)
* [CVE-2024-40090](https://www.cve.org/CVERecord?id=CVE-2024-40090) - [Info Leak in Boa Webserver](./vulns/CVE-2024-40090.md) (4.3 Medium)
* [CVE-2024-40091](https://www.cve.org/CVERecord?id=CVE-2024-40091) - [No Authentication in Boa Webserver](./vulns/CVE-2024-40091.md) (5.3 Medium)

## Future Research
You may notice there are holes in our documentation, like opcodes we haven't documented or attack surfaces unexplored. This research project was a semester-long, so we didn't have time to explore everything we would have liked. To all you vulnerability researchers out there, we hope this repo helps you pick up where we left off and continue finding vulnerabilities in places we haven't looked at. 
