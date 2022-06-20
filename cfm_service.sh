#!/system/bin/sh

(
until [ $(getprop init.svc.bootanim) = "stopped" ] ; do
    sleep 5
done

chmod 755 /data/adb/clash/scripts/start.sh
/data/adb/clash/scripts/start.sh
)&
