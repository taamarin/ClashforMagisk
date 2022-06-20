#!/system/bin/sh

moddir="/data/adb/modules/ClashForMagisk"
if [ -n "$(magisk -v | grep lite)" ]; then
  moddir=/data/adb/lite_modules/ClashForMagisk
fi

scripts_dir="/data/clash/scripts"
busybox_path="/data/adb/magisk/busybox"
Clash_run_path="/data/clash/run"
Clash_pid_file="${clash_run_path}/clash.pid"

if [ -f ${Clash_pid_file} ] ; then
    kill -15 `cat ${Clash_pid_file}`
    ${scripts_dir}/clash.iptables -k
    rm -rf ${Clash_pid_file}
fi

start_service() {
  ${scripts_dir}/clash.service -s
  if [ -f /data/clash/run/clash.pid ] ; then
    ${scripts_dir}/clash.iptables -s
  fi
}

if [ ! -f /data/clash/manual ] ; then
  echo -n "" > /data/clash/run/service.log
  if [ ! -f ${moddir}/disable ] ; then
      start_service
  fi
  if [ "$?" = 0 ] ; then
     ulimit -SHn 1000000
     inotifyd ${scripts_dir}/clash.inotify ${moddir} &>> /dev/null &
     echo -n $! > /data/clash/run/inotifyd.pid
  fi
  nohup /data/adb/magisk/busybox crond -c /data/clash/run > /dev/null 2>&1 &
fi