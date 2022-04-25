# until [ $(getprop init.svc.bootanim) = "stopped" ] ; do
#     sleep 5
# done

# service_path=`realpath $0`
# $module_dir=`dirname ${service_path}`
# scripts_dir="${module_dir}/../../clash/scripts"
# Clash_data_dir="/data/adb/clash"
# busybox_path="/data/adb/magisk/busybox"
# Clash_scripts_dir="${Clash_data_dir}/scripts"
# Clash_run_path="${Clash_data_dir}/run"
# Clash_pid_file="${Clash_run_path}/clash.pid"

# if [ -f ${Clash_pid_file} ] ; then
#    rm -rf ${Clash_pid_file}
# fi

# nohup ${busybox_path} crond -c ${Clash_run_path} > /dev/null 2>&1 &

# ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.tproxy -s
# inotifyd ${scripts_dir}/clash.inotify ${module_dir} >> /dev/null &