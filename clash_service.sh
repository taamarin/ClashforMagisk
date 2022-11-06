#!/system/bin/sh

(
until [ $(getprop init.svc.bootanim) = "stopped" ] ; do
    sleep 5
done

chmod 755 /data/clash/scripts/start.sh
/data/clash/scripts/start.sh
)&

# Clash Service 