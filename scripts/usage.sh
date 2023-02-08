#!/system/bin/sh

export PATH=$(magisk --path)/.magisk/busybox:$PATH:/system/bin

getmemory(){
  local clash_pid=$(cat /data/clash/run/clash.pid)
  clash_alive=$(grep VmRSS /proc/${clash_pid}/status | awk -F':' '{print $2}' | awk '{print $1}')
  if [ ${clash_alive} -ge 1024 ] ; then
    clash_res="$(expr ${clash_alive} / 1024)Mb"
  else
    clash_res="${clash_alive}Kb"
  fi
  clash_cpu=$(/system/bin/ps -p ${clash_pid} -o pcpu | grep -v %CPU | awk '{print $1}' )%
  log_usage="CPU: ${clash_cpu} | RES: ${clash_res}" 
  sed -i "s/CPU:.*/${log_usage}/" /data/clash/run/run.logs
}

usage() {
    local interval="1"
    while [ -f /data/clash/run/clash.pid ] ; do
        getmemory &> /dev/null
        [ ! -f /data/clash/run/clash.pid ] && break
        local now=$(date +%s)
        sleep $(( $interval - $now % $interval ))
    done
}

usage
