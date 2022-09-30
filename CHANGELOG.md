## Changelog v1.13.4
- Remove iptables TUN, and when enable/use TUN, `auto-route` & `auto-detect-interface` will be set to `true`
- tun:
  - enable: true
  - auto-route: true
  - auto-detect-interface: true
#### Changelog v1.13.3
- fix: schedule update **GeoX & SubScription**
##### NOTES:
manual command : 
```shell
su -c /data/clash/scripts/clash.tool -s
```
- `auto_updateSubcript`**clash.config line 31**
- `Subcript_url`**clash.config line 33**
- `auto_updateGeoX`**clash.config line 118**
- or use [APK](https://github.com/taamarin/ClashforMagisk/releases/download/v1.13.2/ClashforMagisk-v1.6.0.apk)

[![RELEASES](https://img.shields.io/github/downloads/taamarin/ClashforMagisk/total.svg)](https://github.com/taamarin/ClashforMagisk/releases)
[![TELEGRAM](https://img.shields.io/badge/Telegram%20-Join%20Channel%20-blue)](https://t.me/nothing_taamarin)