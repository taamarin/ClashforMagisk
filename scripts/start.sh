#!/system/bin/sh

moddir="/data/adb/modules/ClashForMagisk"
if [ -n "$(magisk -v | grep lite)" ]
then
  moddir=/data/adb/lite_modules/ClashForMagisk
fi

scripts_dir="/data/clash/scripts"
busybox_path="/data/adb/magisk/busybox"
Clash_run_path="/data/clash/run"
Clash_pid_file="${Clash_run_path}/clash.pid"

start_service() {
    ${scripts_dir}/clash.service -s
    if [ -f /data/clash/run/clash.pid ]
    then
        ${scripts_dir}/clash.iptables -s
    fi
}

start_clash() {
if [ -f ${Clash_pid_file} ]
then
    ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k
fi
}

start_run() {
if [ ! -f /data/clash/manual ]
then
    echo -n "" > /data/clash/run/service.log
    if [ ! -f ${moddir}/disable ]
    then
        start_service
    fi
    if [ "$?" = 0 ]
    then
       ulimit -SHn 1000000
       inotifyd ${scripts_dir}/clash.inotify ${moddir} &>> /dev/null &
    fi
fi
}

start_clash
start_run