# Pinshift

Android mock GPS using the official test-provider APIs. 
## Setup on a phone

1. Enable Developer options (tap Build number seven times).
2. Developer options → **Select mock location app** → Pinshift.
3. Grant location (and notifications on Android 13+).
4. Drop a pin or paste `lat, lng`, then **Start simulation**.

## In-app browser

Opens sites in a WebView that uses the same mock GPS. Optional Chrome UA. It does **not** hide WebView TLS, `X-Requested-With`, or IP.

Use it to observe how a site or WAF treats an embedded browser — not to auto clock-in.

## AIM

- VPN / IP geolocation
- Hide mock-location flags from other apps
- Build a spoof-harden app
- Collect logs for training a GAN anomaly detection tool for monitoring 1000 attendance checking

Other apps can still refuse a mock provider.

## Run

```bash
cd /Users/ish/codes/flutter/pinshift
flutter run
```
