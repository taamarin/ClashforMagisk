#!/system/bin/sh

getmemory(){
  clash_pid=$(cat /data/clash/run/clash.pid)
  clash_alive=$(grep VmRSS /proc/${clash_pid}/status | /data/adb/magisk/busybox awk -F':' '{print $2}' | /data/adb/magisk/busybox awk '{print $1}')
  if [ ${clash_alive} -ge 1024 ]
  then
    clash_res="$(expr ${clash_alive} / 1024)Mb"
  else
    clash_res="${clash_alive}Kb"
  fi
  clash_cpu=$(ps -p ${clash_pid} -o pcpu | grep -v %CPU | awk '{print $1}' )%
  log_usage="CPU: ${clash_cpu} | RES: ${clash_res}" 
  sed -i "s/CPU:.*/${log_usage}/" /data/clash/run/run.logs
}

usage() {
    interval="1"
    while [ -f /data/clash/run/clash.pid ]
    do
        getmemory &> /dev/null
        [ ! -f /data/clash/run/clash.pid ] && break
        now=$(date +%s)
        sleep $(( $interval - $now % $interval ))
    done
}

usage
