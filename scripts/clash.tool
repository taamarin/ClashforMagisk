#!/system/bin/sh

scripts=$(realpath $0)
scripts_dir=$(dirname ${scripts})
user_agent="ClashForMagisk"
source /data/clash/clash.config

find_packages_uid() {
  echo -n "" > ${appuid_file} 
  if [ "${clash_enhanced_mode}" = "redir-host" ] ; then
    for package in $(cat ${filter_packages_file} | sort -u) ; do
      ${busybox_path} awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
    done
  else
    log "[info] enhanced-mode: ${clash_enhanced_mode} "
    log "[info] if you want to use whitelist and blacklist, use enhanced-mode: redr-host"
  fi
}

restart_clash() {
  ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k
  echo -n "disable" > ${clash_run_path}/root
  sleep 0.5
  ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.iptables -s
  [ "$?" = "0" ] && log "[info] $(date), clash restart" || log "[error] $(date), clash Failed to restart."
}

update_file() {
    file="$1"
    file_bak="${file}.bak"
    update_url="$2"
    [ -f ${file} ] && mv -f ${file} ${file_bak}
    request="/data/adb/magisk/busybox wget"
    request+=" --no-check-certificate"
    request+=" --user-agent ${user_agent}"
    request+=" -O ${file}"
    request+=" ${update_url}"
    echo $request
    $request 2>&1
    sleep 0.5
    if [ -f "${file}" ] ; then
      echo ""
    else
      [ -f "${file_bak}" ] && mv ${file_bak} ${file}
    fi
}

update_geo() {
  if [ "${auto_updategeox}" = "true" ] ; then
     update_file ${clash_geoip_file} ${geoip_dat_url}
     update_file ${clash_geosite_file} ${geosite_url}
     [ "$?" = "0" ] && flag=false
  fi
  if [ ${auto_updateSubcript} = "true" ] ; then
     update_file ${clash_config_file} ${subcript_url}
     [ "$?" = "0" ] && flag=true
  fi
  if [ -f "${clash_pid_file}" ] && [ ${flag} = true ] ; then
    restart_clash
  fi
}

config_online() {
  clash_pid=$(cat ${clash_pid_file})
  match_count=0
  log "[warning] Download Config online" > ${cfm_logs_file}
  update_file ${clash_config_file} ${Subcript_url}
  sleep 0.5
  if [ -f "${clash_config_file}" ] ; then
    match_count=$((${match_count} + 1))
  fi

  if [ ${match_count} -ge 1 ] ; then
    log "[info] download succes."
    exit 0
  else
    log "[error] download failed, Make sure the Url is not empty"
    exit 1
  fi
}

port_detection() {
  clash_pid=$(cat ${clash_pid_file})
  match_count=0
  
  if (ss -h > /dev/null 2>&1) ; then
    clash_port=$(ss -antup | grep "clash" | ${busybox_path} awk '$7~/'pid="${clash_pid}"*'/{print $5}' | ${busybox_path} awk -F ':' '{print $2}' | sort -u)
  else
    logs "[info] skip port detected"
    exit 0
  fi

  logs "[info] port detected: "
  for sub_port in ${clash_port[*]} ; do
    sleep 0.5
    echo -n "${sub_port} " >> ${cfm_logs_file}
  done
    echo "" >> ${cfm_logs_file}
}

update_kernel() {
  arm=$(uname -m)
  if [ "${use_premium}" = "false" ] ; then
    file_kernel="clash.meta"
    meta_alpha="true"
    tag="Prerelease-Alpha"
    tag_name="alpha-[0-9,a-z]+"
    if [ "${arm}" = "aarch64" ] ; then
      platform="android"
      arch="arm64"
    else 
      platform="linux"
      arch="armv7"
    fi
  else
    file_kernel="clash.premium"
    platform="linux"
    if [ "${arm}" = "aarch64" ] ; then
      arch="arm64"
    else
      arch="armv7"
    fi
  fi

  if [ "${use_premium}" = "false" ] ; then
    if [ "${meta_alpha}" = "false" ] ; then
      tag_meta=$(/data/adb/magisk/busybox wget --no-check-certificate -qO- ${url_meta} | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | head -1)
      filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
      update_file "${clash_data_dir}/${file_kernel}.gz" "${url_meta}/download/${tag_meta}/${filename}.gz"
      [ "$?" = "0" ] && flag=false
    else
      tag_meta=$(/data/adb/magisk/busybox wget --no-check-certificate -qO- ${url_meta}/expanded_assets/${tag} | grep -oE "${tag_name}" | head -1)
      filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
      update_file "${clash_data_dir}/${file_kernel}.gz" "${url_meta}/download/${tag}/${filename}.gz"
      [ "$?" = "0" ] && flag=false
    fi
  else
    filename=$(/data/adb/magisk/busybox wget --no-check-certificate -qO- "${url_premium}/expanded_assets/premium" | grep -oE "clash-${platform}-${arch}-[0-9]+.[0-9]+.[0-9]+" | head -1)
    update_file "${clash_data_dir}/${file_kernel}.gz" "${url_premium}/download/premium/${filename}.gz"
    [ "$?" = "0" ] && flag=false
  fi

  if [ "${flag}" = "false" ] ; then
    if (gunzip --help > /dev/null 2>&1); then
       if [ -f "${clash_data_dir}/${file_kernel}.gz" ] ; then
        if (gunzip "${clash_data_dir}/${file_kernel}.gz"); then
          echo ""
        else
          log "[error] gunzip ${file_kernel}.gz failed"  > ${cfm_logs_file}
          log "[warning] periksa kembali url"
          if [ -f "${clash_data_dir}/${file_kernel}.gz.bak" ] ; then
            rm -rf "${clash_data_dir}/${file_kernel}.gz.bak"
          else
            rm -rf "${clash_data_dir}/${file_kernel}.gz"
          fi
          if [ -f ${clash_run_path}/clash.pid ] ; then
            log "[info] clash service is running (PID: $(cat ${clash_pid_file}))"
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

  mv -f "${clash_data_dir}/${file_kernel}" ${clash_data_dir}/kernel/lib
  [ "$?" = "0" ] && flag=true

  if [ -f "${clash_pid_file}" ] && [ ${flag} = true ] ; then
    restart_clash
  else
     log "[warning] clash tidak dimulai ulang"
  fi
}

cgroup_limit() {
  if [ "${cgroup_memory_limit}" = "" ] ; then
    return
  fi
  if [ "${cgroup_memory_path}" = "" ] ; then
    cgroup_memory_path=$(mount | grep cgroup | ${busybox_path} awk '/memory/{print $3}' | head -1)
  fi

  mkdir -p "${cgroup_memory_path}/clash"
  echo $(cat ${clash_pid_file}) > "${cgroup_memory_path}/clash/cgroup.procs" \
  && log "[info] ${cgroup_memory_path}/clash/cgroup.procs"  

  echo "${cgroup_memory_limit}" > "${cgroup_memory_path}/clash/memory.limit_in_bytes" \
  && log "[info] ${cgroup_memory_path}/clash/memory.limit_in_bytes"
}

update_dashboard () {
  url_dashboard="https://github.com/taamarin/yacd/archive/refs/heads/gh-pages.zip"
  file_dasboard="${clash_data_dir}/dashboard.zip"
  rm -rf ${clash_data_dir}/dashboard/dist

  /data/adb/magisk/busybox wget --no-check-certificate ${url_dashboard} -o ${file_dasboard} 2>&1
  unzip -o  "${file_dasboard}" "yacd-gh-pages/*" -d ${clash_data_dir}/dashboard >&2
  mv -f ${clash_data_dir}/dashboard/yacd-gh-pages ${clash_data_dir}/dashboard/dist 
  rm -rf ${file_dasboard}
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
      ;;
    ?)
      echo ""
      ;;
  esac
done