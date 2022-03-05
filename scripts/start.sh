#!/bin/sh

service_path=`realpath $0`
module_dir=`dirname ${service_path}`
scripts_dir="${module_dir}/../../modules/ClashforMagisk"
Clash_data_dir="/data/adb/clash"
busybox_path="/data/adb/magisk/busybox"
Clash_scripts_dir="${Clash_data_dir}/scripts"
Clash_run_path="${Clash_data_dir}/run"
Clash_pid_file="${Clash_run_path}/clash.pid"

if [ -f ${Clash_pid_file} ] ; then
    rm -rf ${Clash_pid_file}
fi

until [ -f ${module_dir}/clash.config ] ; do
    sleep 1
done

nohup ${busybox_path} crond -c ${Clash_run_path} > /dev/null 2>&1 &

if [ ! -f ${scripts_dir}/disable ] ; then
  ${module_dir}/clash.service -s && ${module_dir}/clash.tproxy -s
fi
inotifyd ${module_dir}/clash.inotify ${scripts_dir} >> /dev/null &
