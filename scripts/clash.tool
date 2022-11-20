#!/system/bin/sh

scripts=$(realpath $0)
scripts_dir=$(dirname ${scripts})
source /data/clash/clash.config

find_packages_uid() {
  echo -n "" > ${appuid_file} 
  if [ "${Clash_enhanced_mode}" == "redir-host" ]; then
    for package in $(cat ${filter_packages_file} | sort -u) ; do
      ${busybox_path} awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
    done
  else
    log "[info] enhanced-mode: ${Clash_enhanced_mode} "
    log "[info] if you want to use whitelist and blacklist, use enhanced-mode: redr-host"
  fi
}

restart_clash() {
  ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k
  echo -n "disable" > ${Clash_run_path}/root
  sleep 0.5
  ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.iptables -s
  if [ "$?" == "0" ]; then
    log "[info] $(date), Clash restart"
  else
    log "[error] $(date), Clash Failed to restart."
  fi
}

update_file() {
    file="$1"
    file_bak="${file}.bak"
    update_url="$2"
    if [ -f ${file} ]; then
      mv -f ${file} ${file_bak}
    fi
    echo "curl -k --insecure -L -A 'clash' ${update_url} -o ${file}"
    curl -k --insecure -L -A 'clash' ${update_url} -o ${file} 2>&1
    sleep 0.5
    if [ -f "${file}" ]; then
      echo ""
    else
      if [ -f "${file_bak}" ]; then
        mv ${file_bak} ${file}
      fi
    fi
}

update_geo() {
  if [ "${auto_updateGeoX}" == "true" ]; then
     update_file ${Clash_GeoIP_file} ${GeoIP_dat_url}
     update_file ${Clash_GeoSite_file} ${GeoSite_url}
     if [ "$?" = "0" ]; then
       flag=false
     fi
  fi

  if [ ${auto_updateSubcript} == "true" ]; then
     update_file ${Clash_config_file} ${Subcript_url}
     if [ "$?" = "0" ]; then
       flag=true
     fi
  fi

  if [ -f "${Clash_pid_file}" ] && [ ${flag} == true ]; then
    restart_clash
  fi
}

config_online() {
  clash_pid=$(cat ${Clash_pid_file})
  match_count=0
  log "[warning] Download Config online" > ${CFM_logs_file}
  update_file ${Clash_config_file} ${Subcript_url}
  sleep 0.5
  if [ -f "${Clash_config_file}" ]; then
    match_count=$((${match_count} + 1))
  fi

  if [ ${match_count} -ge 1 ]; then
    log "[info] download succes."
    exit 0
  else
    log "[error] download failed, Make sure the Url is not empty"
    exit 1
  fi
}

port_detection() {
  clash_pid=$(cat ${Clash_pid_file})
  match_count=0
  
  if (ss -h > /dev/null 2>&1)
  then
    clash_port=$(ss -antup | grep "clash" | ${busybox_path} awk '$7~/'pid="${clash_pid}"*'/{print $5}' | ${busybox_path} awk -F ':' '{print $2}' | sort -u)
  else
    logs "[info] skip port detected"
    exit 0
  fi

  logs "[info] port detected: "
  for sub_port in ${clash_port[*]} ; do
    sleep 0.5
    echo -n "${sub_port} / " >> ${CFM_logs_file}
  done
    echo "" >> ${CFM_logs_file}
}

update_kernel() {
  if [ "${use_premium}" == "false" ]; then
    if [ "${meta_alpha}" == "false" ]; then
      tag_meta=$(curl -fsSL ${url_meta} | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | head -1)
      filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
      update_file ${Clash_data_dir}/${file_kernel}.gz ${url_meta}/download/${tag_meta}/${filename}.gz
        if [ "$?" = "0" ]
        then
          flag=false
        fi
    else
      tag_meta=$(curl -fsSL ${url_meta}/expanded_assets/${tag} | grep -oE "${tag_name}" | head -1)
      filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
      update_file ${Clash_data_dir}/${file_kernel}.gz ${url_meta}/download/${tag}/${filename}.gz
        if [ "$?" = "0" ]
        then
          flag=false
        fi
    fi
  else
    filename=$(curl -fsSL ${url_premium}/expanded_assets/premium | grep -oE "clash-${platform}-${arch}-[0-9]+.[0-9]+.[0-9]+" | head -1)
    update_file ${Clash_data_dir}/${file_kernel}.gz ${url_premium}/download/premium/${filename}.gz
    if [ "$?" = "0" ]; then
      flag=false
    fi
  fi

  if [ ${flag} == false ]; then
    if (gunzip --help > /dev/null 2>&1); then
       if [ -f ${Clash_data_dir}/"${file_kernel}".gz ]; then
        if (gunzip ${Clash_data_dir}/"${file_kernel}".gz); then
          echo ""
        else
          log "[error] gunzip ${file_kernel}.gz failed"  > ${CFM_logs_file}
          log "[warning] periksa kembali url"
          if [ -f ${Clash_data_dir}/"${file_kernel}".gz.bak ]; then
            rm -rf ${Clash_data_dir}/"${file_kernel}".gz.bak
          else
            rm -rf ${Clash_data_dir}/"${file_kernel}".gz
          fi
          if [ -f ${Clash_run_path}/clash.pid ]; then
            log "[info] Clash service is running (PID: $(cat ${Clash_pid_file}))"
            log "[info] Connect"
          fi
          exit 1
        fi
       else
        log "[warning] gunzip ${file_kernel}.gz failed" 
        log "[warning] pastikan ada koneksi internet" 
        exit 1
      fi
    else
      log "[error] gunzip not found" 
      exit 1
    fi
  fi

  mv -f ${Clash_data_dir}/"${file_kernel}" ${Clash_data_dir}/kernel/lib

  if [ "$?" = "0" ]; then
    flag=true
  fi

  if [ -f "${Clash_pid_file}" ] && [ ${flag} == true ]; then
    restart_clash
  else
     log "[warning] Clash tidak dimulai ulang"
  fi
}

cgroup_limit() {
  if [ "${Cgroup_memory_limit}" == "" ]; then
    return
  fi
  if [ "${Cgroup_memory_path}" == "" ]; then
    Cgroup_memory_path=$(mount | grep cgroup | ${busybox_path} awk '/memory/{print $3}' | head -1)
  fi

  mkdir -p "${Cgroup_memory_path}/clash"
  echo $(cat ${Clash_pid_file}) > "${Cgroup_memory_path}/clash/cgroup.procs" \
  && log "[info] ${Cgroup_memory_path}/clash/cgroup.procs"  

  echo "${Cgroup_memory_limit}" > "${Cgroup_memory_path}/clash/memory.limit_in_bytes" \
  && log "[info] ${Cgroup_memory_path}/clash/memory.limit_in_bytes"
}

update_dashboard () {
  url_dashboard="https://github.com/taamarin/yacd/archive/refs/heads/gh-pages.zip"
  file_dasboard="${Clash_data_dir}/dashboard.zip"
  rm -rf ${Clash_data_dir}/dashboard/dist

  curl -L -A 'clash' ${url_dashboard} -o ${file_dasboard} 2>&1
  unzip -o  "${file_dasboard}" "yacd-gh-pages/*" -d ${Clash_data_dir}/dashboard >&2
  mv -f ${Clash_data_dir}/dashboard/yacd-gh-pages ${Clash_data_dir}/dashboard/dist 
  rm -rf ${file_dasboard}
}

dnstt_client() {
  if [ "${run_dnstt}" == "1" ]; then
    if [ -f ${dnstt_client_bin} ]; then
      chmod 0700 ${dnstt_client_bin}
      chown 0:3005 ${dnstt_client_bin}
      if [ ! ${nsdomain} == "" ] && [ ! ${pubkey} == "" ]; then
         nohup ${busybox_path} setuidgid 0:3005 ${dnstt_client_bin} -udp ${dns_for_dnstt}:53 -pubkey ${pubkey} ${nsdomain} 127.0.0.1:9553 > /dev/null 2>&1 &
         echo -n $! > ${Clash_run_path}/dnstt.pid

         sleep 1
         local dnstt_pid=$(cat ${Clash_run_path}/dnstt.pid 2> /dev/null)
         if (cat /proc/$dnstt_pid/cmdline | grep -q ${dnstt_bin_name}); then
           log "[info] ${dnstt_bin_name} is enable."
         else
           log "[error] ${dnstt_bin_name} The configuration is incorrect,"
           log "[error] the startup fails, and the following is the error"
           kill -9 $(cat ${Clash_run_path}/dnstt.pid)
         fi
      else
        log "[warning] ${dnstt_bin_name} tidak aktif," 
        log "[warning] 'nsdomain' & 'pubkey' kosong," 
      fi
    else
      log "[error] kernel ${dnstt_bin_name} tidak ada."
    fi
  fi
}

while getopts ":dfklopsv" signal ; do
  case ${signal} in
    d)
      update_dashboard 
      ;;
    f)
      find_packages_uid
      ;;
    k)
      update_kernel
      ;;
    l)
      cgroup_limit
      ;;
    o)
      config_online
      ;;
    p)
      port_detection
      ;;
    s)
      update_geo
      rm -rf ${Clash_data_dir}/*dat.bak && exit 1
      ;;
    v)
      dnstt_client
      ;;

    ?)
      echo ""
      ;;
  esac
done