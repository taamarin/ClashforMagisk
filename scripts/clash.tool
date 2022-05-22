#!/system/bin/sh

scripts=`realpath $0`
scripts_dir=`dirname ${scripts}`
. /data/adb/clash/scripts/clash.config

monitor_local_ip() {
    local_ipv4=$(ip a | ${busybox_path} awk '$1~/inet$/{print $2}')
    local_ipv6=$(ip -6 a | awk '$1~/inet6$/{print $2}')
    rules_ipv4=$(${iptables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | ${busybox_path} awk '{print $9}'  2>&1)
    rules_ipv6=$(${ip6tables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | ${busybox_path} awk '{print $8}'  2>&1)

    change=0

    wifistatus=$(dumpsys connectivity | grep "WIFI" | grep "state:" | ${busybox_path} awk -F ", " '{print $2}' | ${busybox_path} awk -F "=" '{print $2}' 2>&1)

    if test ! -z "${wifistatus}" ; then
        if test ! "${wifistatus}" = "$(cat ${Clash_run_path}/lastwifi)" ; then
            change=$((${change} + 1))
            echo -n "${wifistatus}" > ${Clash_run_path}/lastwifi
		elif [ "$(ip route get 1.2.3.4 | ${busybox_path} awk '{print $5}' 2>&1)" != "wlan0"  ] ; then
			change=$((${change} + 1))
			echo -n "${wifistatus}" >  ${Clash_run_path}/lastwifi
        fi
    else    
        echo -n "" > ${Clash_run_path}/lastwifi
    fi

    if test "$(settings get global mobile_data 2>&1)" -eq 1 ; then
        if test "$(settings get global mobile_data1 2>&1)" -eq 1 ; then
            mobilestatus=1
        else
            mobilestatus=2
        fi
    else
        mobilestatus=0
    fi

    if test "${mobilestatus}" -ne 0 ; then
        if test ! "${mobilestatus}" = "$(cat ${Clash_run_path}/lastmobile)" ; then
            change=$((${change} + 1))
            echo -n "${mobilestatus}" > ${Clash_run_path}/lastmobile
        fi
    fi

    if test "${change}" -ne 0 ; then
        for rules_subnet in ${rules_ipv4[*]} ; do
            ${iptables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet} -j ACCEPT
        done
        for subnet in ${local_ipv4[*]} ; do
            if ! (${iptables_wait} -t mangle -C FILTER_LOCAL_IP -d ${subnet} -j ACCEPT > /dev/null 2>&1) ; then
                ${iptables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet} -j ACCEPT
            fi
        done

        ip4_local_port=$(ip a | ${busybox_path} awk '$1~/inet$/{print $2}' | sort -u)
        echo -n "info msg= Ipv4: | " >> ${CFM_logs_file}
            for loca_port in ${ip4_local_port[*]} ; do
                sleep 0.5
                echo -n "${loca_port} |  " >> ${CFM_logs_file}
            done
#        echo "info msg= Iptables untuk melewati ip lokal telah diperbarui." >> ${CFM_logs_file}
    else
        ip4_local_port=$(ip a | ${busybox_path} awk '$1~/inet$/{print $2}' | sort -u)
        echo -n "info msg= Ipv4: | " >> ${CFM_logs_file}
            for loca_port in ${ip4_local_port[*]} ; do
                sleep 0.5
                echo -n "${loca_port} | " >> ${CFM_logs_file}
            done
#        echo "info msg= tidak ada perubahan di ip lokal" >> ${CFM_logs_file}
    fi

    echo "" >> ${CFM_logs_file}

    if test "${change}" -ne 0 ; then
         for rules_subnet6 in ${rules_ipv6[*]} ; do
             ${ip6tables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet6} -j ACCEPT
         done

         for subnet6 in ${local_ipv6[*]} ; do
             if ! (${ip6tables_wait} -t mangle -C FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT > /dev/null 2>&1) ; then
                 ${ip6tables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT
             fi
         done

         ip6_local_port=$(ip -6 a | ${busybox_path} awk '$1~/inet6$/{print $2}' | sort -u)
         echo -n "info msg= Ipv6: | " >> ${CFM_logs_file}
             for loca_port in ${ip6_local_port[*]} ; do
                 sleep 0.5
                echo -n "${loca_port} | " >> ${CFM_logs_file}
             done
         echo "" >> ${CFM_logs_file}
         echo "info msg= Iptables untuk melewati ip lokal telah diperbarui." >> ${CFM_logs_file}
    else
         ip6_local_port=$(ip -6 a | ${busybox_path} awk '$1~/inet6$/{print $2}' | sort -u)
         echo -n "info msg= Ipv6: | " >> ${CFM_logs_file}
             for loca_port in ${ip6_local_port[*]} ; do
                sleep 0.5
                echo -n "${loca_port} | " >> ${CFM_logs_file}
             done
         echo "" >> ${CFM_logs_file}
         echo "info msg= tidak ada perubahan di ip lokal" >> ${CFM_logs_file}
         exit 0
    fi
 
    unset local_ipv4
    unset rules_ipv4
    unset local_ipv6
    unset rules_ipv6
    unset wifistatus
    unset mobilestatus
    unset change
}

find_packages_uid() {
    echo -n "" > ${appuid_file}
    for package in `cat ${filter_packages_file} | sort -u` ; do
        ${busybox_path} awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
        if [ "${mode}" = "blacklist" ] ; then
            echo "info msg= ${package} di filter " >> ${CFM_logs_file}
        else
            echo "info msg= • ${package} proksi." >> ${CFM_logs_file}
        fi
    done
}

cgroup_limit() {
    if [ "${Cgroup_memory_limit}" == "" ]; then
        return
    fi
    if [ "${Cgroup_memory_path}" == "" ]; then
        Cgroup_memory_path=$(mount | grep cgroup | ${busybox_path} awk '/memory/{print $3}' | head -1)
    fi

    mkdir -p "${Cgroup_memory_path}/clash" && echo "info msg= Cgroup memory limit: ${Cgroup_memory_limit}" >> ${CFM_logs_file} || echo "warning msg= failed, kernel tidak mendukung memory Cgroup" >> ${CFM_logs_file}

    echo $(cat ${Clash_pid_file}) > "${Cgroup_memory_path}/clash/cgroup.procs" && echo "info msg= create ${Cgroup_memory_path}/clash/cgroup.procs" >> ${CFM_logs_file} || echo "warning msg= can't create  ${Cgroup_memory_path}/clash/cgroup.procs" >> ${CFM_logs_file}

    echo "${Cgroup_memory_limit}" > "${Cgroup_memory_path}/clash/memory.limit_in_bytes" && echo "info msg= create ${Cgroup_memory_path}/clash/memory.limit_in_bytes" >> ${CFM_logs_file} || echo "warning msg= can't create  ${Cgroup_memory_path}/clash/memory.limit_in_bytes" >> ${CFM_logs_file}

    if [ -d "${Cgroup_memory_path}/clash" ]; then
        echo "info msg= Clash cgroup activated | status: ${Cgroup_memory} " >> ${CFM_logs_file}
    elif [ ! -d "${Cgroup_memory_path}/clash" ]; then
        echo "warning msg= Cgroup failed" >> ${CFM_logs_file}
    fi
}

restart_clash() {
    ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.tproxy -k

    echo -n "disable" > /data/adb/clash/run/root
    sleep 0.5

    ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.tproxy -s
    if [ "$?" == "0" ]; then
        echo "info msg= Clash berhasil dimulai ulang." >>${CFM_logs_file}
    else
        echo "error msg= Clash Gagal dimulai ulang." >>${CFM_logs_file}
    fi
}

update_file() {
        file="$1"
        file_bak="${file}.bak"
        update_url="$2"

        mv -f ${file} ${file_bak}
        echo ""  >> ${CFM_logs_file}
        echo "info warning= backup file ${file_bak}" >> ${CFM_logs_file}
        echo "curl -L -A 'clash' ${update_url} -o ${file} "
        curl -L -A 'clash' ${update_url} -o ${file} 2>&1 # >> /dev/null 2>&1

        sleep 1

        if [ -f "${file}" ] ; then
#            rm -rf ${file_bak}
            echo "info msg= `date "+%R %Z"` Update ${file} done." >> ${CFM_logs_file}
        else
            echo "error msg= `date "+%R %Z"` Update ${file} failed." >> ${CFM_logs_file}
            if [ -f "${file_bak}" ]; then
                mv ${file_bak} ${file}
                echo "warning msg= `date "+%R %Z"` restore ${file}." >> ${CFM_logs_file}
            fi
        fi
}

auto_update() {
    if [ "${auto_updateGeoX}" = "true" ] ; then
       update_file ${Clash_GeoIP_file} ${GeoIP_dat_url} >> ${CFM_logs_file}
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ "${auto_updateGeoX}" = "true" ] ; then
       update_file ${Clash_GeoSite_file} ${GeoSite_url} >> ${CFM_logs_file}
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ ${auto_updateSubcript} == "true" ]; then
#       cp -F ${Clash_config_file} ${Clash_config_file}.bak
       update_file ${Clash_config_file} ${Subcript_url} >> ${CFM_logs_file}
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ -f "${Clash_pid_file}" ] && [ ${flag} == true ]; then
        restart_clash
    else
        echo "warning msg= Clash tidak dimulai ulang" >> ${CFM_logs_file}
    fi
}

config_online() {
    clash_pid=`cat ${Clash_pid_file}`
    match_count=0

#    cp -F ${Clash_config_file} ${Clash_config_file}.bak
    echo "info msg= Download Config online" > ${CFM_logs_file}
    update_file ${Clash_config_file} ${Subcript_url} >> ${CFM_logs_file}
    sleep 1
    if [ -f "${Clash_config_file}" ] ; then
        match_count=$((${match_count} + 1))
    fi

    if [ ${match_count} -ge 1 ] ; then
        echo "info msg= download succes." >> ${CFM_logs_file}
        exit 0
    else
        echo "error msg= download failed, pastikan Url Tidak kosong" >> ${CFM_logs_file}
        exit 1
    fi
}

keep_dns() {
    local_dns=`getprop net.dns1`

    if [ "${local_dns}" != "${static_dns}" ] ; then
        for count in $(seq 1 $(getprop | grep dns | wc -l)); do
            setprop net.dns${count} ${static_dns}
        done
    fi

    if [ $(sysctl net.ipv4.ip_forward) != "1" ] ; then
        sysctl -w net.ipv4.ip_forward=1
    fi

    unset local_dns
}

port_detection() {
    clash_pid=`cat ${Clash_pid_file}`
    match_count=0
    
    if (ss -h > /dev/null 2>&1) ; then
        clash_port=$(ss -antup | grep "${Clash_bin_name}" | ${busybox_path} awk '$7~/'pid="${clash_pid}"*'/{print $5}' | ${busybox_path} awk -F ':' '{print $2}' | sort -u)
    else
        echo "info msg= skip port detected" >> ${CFM_logs_file}
        exit 0
    fi

    echo -n "info msg= port detected: " >> ${CFM_logs_file}
    for sub_port in ${clash_port[*]} ; do
        sleep 0.5
        echo -n "${sub_port}   " >> ${CFM_logs_file}
    done
        echo "" >>${CFM_logs_file} 
}

ui_start() {
    local pid=`cat ${ui_pid} 2> /dev/null`
    if (cat /proc/${pid}/cmdline | grep -q php) ; then
        echo "info msg= php(ui) service is running." > ${Clash_run_path}/ui.logs
        exit 1
    fi

    if [ -f "${ui}" ] ; then
        chown 0:3005 ${ui}
        chmod 0755 ${ui}
        nohup ${busybox_path} setuidgid 0:3005 ${ui} -S 127.0.0.1:9999 -t ${Clash_data_dir} > /dev/null 2>&1 &
        echo -n $! > ${ui_pid}
        echo "info msg= php(ui) service is running." > ${Clash_run_path}/ui.logs
    else
       echo "error msg= php binary not detected." >> ${Clash_run_path}/ui.logs
       exit 1
    fi
}

ui_stop() {
    kill -15 `cat ${ui_pid}`
    rm -rf ${ui_pid}
    echo "info msg= php(ui) stopped." >> ${Clash_run_path}/ui.logs
}
while getopts ":fklmupo" signal ; do
    case ${signal} in
        f)
            find_packages_uid
            ;;
        k)
            keep_dns
            ;;
        l)
            cgroup_limit
            ;;
        m)
            if [ "${mode}" = "blacklist" ] && [ -f "${Clash_pid_file}" ] ; then
                monitor_local_ip
            else
                exit 0
            fi
            ;;
        u)
            if [ "${auto_updateSubcript}" = "true" ] && [ "${auto_updateGeoX}" = "true" ]; then 
                auto_update
            elif [ "${auto_updateSubcript}" = "true" ] && "${auto_updateGeoX}" = "false" ]; then 
                auto_update
            elif [ "${auto_updateSubcript}" = "false" ] && [ "${auto_updateGeoX}" = "true" ]; then
                auto_update
            else
               exit 1
            fi
            exit 1
            ;;
        p)
            sleep 0.5
            port_detection
            ;;
        o)
            sleep 0.5
            config_online
            ;;
        ?)
            echo ""
            ;;
    esac
done