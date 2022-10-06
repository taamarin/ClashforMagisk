#!/system/bin/sh

getmemory(){
  Clash_pid_file="/data/clash/run/clash.pid"
  clashpid=$(cat ${Clash_pid_file})
  clashres1=`grep VmRSS /proc/${clashpid}/status | awk -F':' '{print $2}' | awk '{print $1}'`
  if [ ${clashres1} -ge 1024 ]
  then
    clashres="`expr ${clashres1} / 1024`mb"
  else
    clashres="${clashres1}kb"
  fi
  clashcpu=`ps -p ${clashpid} -o pcpu | grep -v %CPU | awk '{print $1}' `%
  logres="CPU: ${clashcpu} | RES: ${clashres}" 
  sed -i "s/CPU:.*/$logres/" /data/clash/run/run.logs
}

usage() {
    local PID=`cat /data/clash/run/clash.pid 2> /dev/null`
    local interval=1
    while (cat /proc/${PID}/cmdline | grep -q clash)
    do
        getmemory &> /dev/null
        ( ! cat /proc/${PID}/cmdline | grep -q clash) && break
        local now=$(date +%s)
        sleep $(( interval - now % interval ))
    done
}

usage
