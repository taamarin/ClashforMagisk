# Clash for Magisk
<h1 align="center">
  <img src="https://github.com/taamarin/ClashforMagisk/blob/master/docs/logo.png" alt="Clash" width="200">
  <br>Clash<br>
</h1>
<h4 align="center">Proxy Transparan for android.</h4>


<div align="center">

[![ANDROID](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)]()
[![RELEASES](https://img.shields.io/github/downloads/taamarin/ClashforMagisk/total.svg?style=for-the-badge)](https://github.com/taamarin/ClashforMagisk/releases)
[![TELEGRAM CHANNEL](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/nothing_taamarin)
[![TELEGRAM](https://img.shields.io/badge/Telegram%20-Grups%20-blue?style=for-the-badge)](https://t.me/taamarin)
[![MAGISK](https://img.shields.io/badge/Magisk%20-v20.4+-brightgreen?style=for-the-badge)](https://github.com/topjohnwu/Magisk)
[![API](https://img.shields.io/badge/API-19%2B-brightgreen.svg?style=for-the-badge)](https://android-arsenal.com/api?level=19)
  <a href="https://github.com/taamarin/ClashforMagisk/releases">
    <img src="https://img.shields.io/github/release/taamarin/ClashforMagisk/all.svg?style=for-the-badge">
  </a>

</div>

A fork of [ClashForMagisk](https://github.com/kalasutra/Clash_For_Magisk)

This is a Clash module for Magisk, and includes binaries for arm, arm64, x86, x64.

## Manager Apps CFM
- [ClashForMagisk_Manager](https://t.me/taamarin/26137) EN
- [ClashForMagisk_Manager](https://t.me/MagiskChangeKing/159) CN

## Install
You can download the release [installer zip](https://github.com/taamarin/ClashforMagisk/releases) file and install it via the Magisk Manager App.

#### Config
- Clash config files `/data/clash/*`
- config.yaml `/data/clash/config.yaml`
- template `/data/clash/template`

#### temporary config
- **config.yaml** and **template** will be merged `/data/clash/run/config.yaml`

## Usage
### Normal usage ( Default and Recommended )
##### Manage service start / stop
- Clash service is auto-run after system boot up by default.
- You can use Magisk Manager App to manage it. Be patient to wait it take effect (about 3 second).

### Advanced usage
> MODDIR= "/data/clash"

##### Change proxy mode
- Clash uses `TPROXY` transparent proxy `TCP + UDP` by default, if it detects that the device does not support `TPROXY`, it will automatically use `REDIRECT` to proxy only `TCP`

- Open `${MODDIR}/scripts/clash.config` file line [17-18](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L17-#L18), modify the value of `network_mode` to `TCP` or `MIXED `to use `REDIRECT` to proxy `TCP`, and `UDP` will not be proxied when `TUN` is not enabled in the Clash kernel

##### Bypass transparent proxy when connected to Wi-Fi or open a hotspot
Clash default transparent proxy local and hotspot, line [20-23](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L20-#L23)

- Open the `${MODDIR}/scripts/clash.config` file, modify the `ignore_out_list` array and add the `wlan+` element, the transparent proxy will `bypass` the `WLAN`, and the hotspot will not be affected

- Open the `${MODDIR}/scripts/clash.config` file, modify the ap_list array and delete the `wlan+` element to opaque proxy `WLAN` and hotspot (the `MediaTek` model may be `ap+` instead of `wlan+`)

##### Select which packages to proxy
- If you expect all Apps proxy by Clash with transparent proxy EXCEPT specific Apps, write down bypass at the first line then these Apps' packages separated as above in file `/data/clash/packages.list`
- clash.config line [14-15](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L14-#L15)
- `blacklist` & `whitelits`, not working on `fake-ip`

      - dns:
          - enable: true
          - enhanced-mode: redir-host

##### Manage service start / stop
- clash service script is `${MODDIR}/scripts/clash.service.`
    - Start service :
    > ${MODDIR}/scripts/clash.service -s

    - Stop service :
    > ${MODDIR}/scripts/clash.service -k

##### Manage transparent proxy enable / disable
- clash proxy script is `${MODDIR}/scripts/clash.iptables.`
    - Start service :
    > ${MODDIR}/scripts/clash.iptables -s

    - Stop service :
    > ${MODDIR}/scripts/clash.iptables -k

##### subscription
you can use SubScription
- open `/data/clash/clash.config` line [30-35](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L30-#L35)
  - update_interval="interval contab"
  - Subcript_url="your_link"
  - auto_updateSubcript="true"

Running manual command
```shell
${MODDIR}/scripts/clash.tool -s
```

##### Config Online
- **clash.config** line [37-38](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L37-#L38), If true,
- use it to download the subscription configuration, when starting Clash , So no need to type `${MODDIR}/scripts/clash.tool -s` anymore

##### Change Clash kernel
You can use Clash.Premium and Clash.Meta
- Clash Meta 
  - `/data/clash/kernel/lib/Clash.Meta`
- Clash Premium 
  - `/data/clash/kernel/lib/Clash.Premium`

you can download the Kernel automatically, for the settings in the **clash.config** line [85-109](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L85-#L109)
```shell
${MODDIR}/scripts/clash.tool -k
```

##### GeoSite, GeoIP, and Mmdb
- settings are in clash.config line [111-135](https://github.com/taamarin/ClashforMagisk/blob/master/scripts/clash.config#L111-#L135)
- if true, will be updated every day at 00.00
- you can change the URL

## Uninstall
- Uninstall the module via Magisk Manager App.
- You can clean Clash data dir by running command 
```shell
rm -rf /data/clash && rm -rf /data/adb/service.d/clash_service.sh
```

## Tutorial Clash For Magisk
  > Tutorial [Tap Here](https://telegra.ph/%F0%9D%93%92%F0%9D%93%B5%F0%9D%93%AA%F0%9D%93%BC%F0%9D%93%B1%F0%9D%93%95%F0%9D%93%B8%F0%9D%93%BB%F0%9D%93%9C%F0%9D%93%AA%F0%9D%93%B0%F0%9D%93%B2%F0%9D%93%BC%F0%9D%93%B4-11-28)

## Credits
This is a repo fork
  - [kalasutra/Clash_for_magisk](https://github.com/kalasutra/Clash_For_Magisk)
  - [CHIZI-0618/box4magisk](https://github.com/CHIZI-0618/box4magisk)
  - [Asterisk4Magisk/Xray4Magisk](https://github.com/Asterisk4Magisk/Xray4Magisk)
  - [MagiskChangeKing](https://t.me/MagiskChangeKing)
  - [e58695](https://t.me/e58695)
