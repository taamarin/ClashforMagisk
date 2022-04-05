#!/system/bin/sh

scripts=`realpath $0`
scripts_dir=`dirname ${scripts}`
. ${scripts_dir}/clash.config

updateGeox() {
        file="$1"
        file_bak="${file}.bak"
        update_url="$2"

        mv -f ${file} ${file_bak}
        echo "curl -L -A 'clash' ${update_url} -o ${file} "
        curl -L -A 'clash' ${update_url} -o ${file} 2>&1 # >> /dev/null 2>&1

        sleep 1

        if [ -f "${file}" ] ; then
            rm -rf ${file_bak}
            echo "info msg= ${file} Pembaruan selesai." >> ${Clash_run_path}/clash.logs
        else
            mv ${file_bak} ${file}
            echo "warning msg= ${file} Pembaruan gagal, file telah dipulihkan." >> ${Clash_run_path}/clash.logs
          fi
}

monitor_local_ipv4() {
    local_ipv4=$(ip a | awk '$1~/inet$/{print $2}')
    local_ipv6=$(ip -6 a | awk '$1~/inet6$/{print $2}')
    rules_ipv4=$(${iptables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $9}'  2>&1)
    rules_ipv6=$(${ip6tables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $8}'  2>&1)

    change=0

    wifistatus=$(dumpsys connectivity | grep "WIFI" | grep "state:" | awk -F ", " '{print $2}' | awk -F "=" '{print $2}' 2>&1)

    if test ! -z "${wifistatus}" ; then
        if test ! "${wifistatus}" = "$(cat ${Clash_run_path}/lastwifi)" ; then
            change=$((${change} + 1))
            echo "${wifistatus}" > ${Clash_run_path}/lastwifi
		elif [ "$(ip route get 1.2.3.4 | awk '{print $5}' 2>&1)" != "wlan0"  ] ; then
			change=$((${change} + 1))
			echo "${wifistatus}" >  ${Clash_run_path}/lastwifi
        fi
    else    
        echo "" > ${Clash_run_path}/lastwifi
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
            echo "${mobilestatus}" > ${Clash_run_path}/lastmobile
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
    echo "" # "info msg= aturan iptables untuk melewati ip lokal telah diperbarui." >> ${CFM_logs_file}
    else
    echo "" # "error msg= Tidak ada perubahan di ip lokal, tidak ada pemrosesan yang akan dilakukan" >> ${CFM_logs_file}
    fi

    if test "${change}" -ne 0 ; then
        for rules_subnet6 in ${rules_ipv6[*]} ; do
            ${ip6tables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet6} -j ACCEPT
        done

        for subnet6 in ${local_ipv6[*]} ; do
            if ! (${ip6tables_wait} -t mangle -C FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT > /dev/null 2>&1) ; then
                ${ip6tables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT
            fi
        done
    echo "info msg= aturan iptables untuk melewati ipv4/ipv6 lokal telah diperbarui." >> ${CFM_logs_file}
    else
    echo "info msg= tidak ada perubahan di ipv4/ipv6 lokal, tidak ada pemrosesan yang akan dilakukan" >> ${CFM_logs_file}
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


find_packages_uid() {
    echo -n "" > ${appuid_file}
    for package in `cat ${filter_packages_file} | sort -u` ; do
        awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
        if [ "${mode}" = "blacklist" ] ; then
            echo "info msg= ${package} di filter." >> ${CFM_logs_file}
        elif [ "${mode}" = "whitelist" ] ; then
            echo "info msg= ${package} proksi." >> ${CFM_logs_file}
        fi
    done
}

port_detection() {
    clash_pid=`cat ${Clash_pid_file}`
    match_count=0

    if ! (ss -h > /dev/null 2>&1) ; then
        clash_port=$(netstat -anlp | grep -v p6 | grep "clash" | awk '$6~/'"${clash_pid}"*'/{print $4}' | awk -F ':' '{print $2}' | sort -u)
    else
        clash_port=$(ss -antup | grep "clash" | awk '$7~/'pid="${clash_pid}"*'/{print $5}' | awk -F ':' '{print $2}' | sort -u)
    fi

    echo "port: detection" >> ${CFM_logs_file}

    for sub_port in ${clash_port[*]} ; do
        sleep 0.5
        echo "   • port: ${sub_port}" >> ${CFM_logs_file}
        if [ "${sub_port}" = ${Clash_tproxy_port} ] || [ "${sub_port}" = ${Clash_dns_port} ] ; then
            match_count=$((${match_count} + 1))
        fi
    done

    if [ ${match_count} -ge 2 ] ; then
        echo "info msg= port tproxy & dns terdeteksi" >> ${CFM_logs_file}
        exit 0
    else
        echo "info msg= port tproxy & dns tidak terdeteksi" >> ${CFM_logs_file}
        exit 1
    fi
}

ui_start() {
    local pid=`cat ${Ui_pid} 2> /dev/null`
    if (cat /proc/${pid}/cmdline | grep -q php) ; then
        echo "info msg= mendeteksi bahwa PHP telah dimulai." > ${Clash_run_path}/ui.logs
        exit 1
    fi

    if [ -f "${Ui}" ] ; then
        chown 0:3005 ${Ui}
        chmod 0755 ${Ui}
        nohup ${busybox_path} setuidgid 0:3005 ${Ui} -S 127.0.0.1:9999 -t ${Clash_data_dir} > /dev/null 2>&1 &
        echo -n $! > ${Ui_pid}
        echo "info msg= Ui Online." > ${Clash_run_path}/ui.logs
    else
       echo "error msg= Ui Offline, PHP tidak terdeteksi" >> ${Clash_run_path}/ui.logs
       exit 1
    fi
}

ui_stop() {
    kill -15 `cat ${Ui_pid}`
    rm -rf ${Ui_pid}
    echo "info msg= Ui dihentikan." >> ${Clash_run_path}/ui.logs
}

limit_clash() {
    if [ "${Cgroup_memory_limit}" == "" ]; then
        return
    fi

    if [ "${Cgroup_memory_path}" == "" ]; then
        Cgroup_memory_path=$(mount | grep cgroup | awk '/memory/{print $3}' | head -1)
    fi

    if [ ! -d "${Cgroup_memory_path}/clash" ]; then
        mkdir -p "${Cgroup_memory_path}/clash"
    fi
    echo $(cat ${Clash_pid_file}) > "${Cgroup_memory_path}/clash/cgroup.procs"
    echo "${Cgroup_memory_limit}" > "${Cgroup_memory_path}/clash/memory.limit_in_bytes"

    echo "info msg= batasi Memori: ${Cgroup_memory_limit}." >> ${CFM_logs_file}
}

while getopts ":rskfumpl" signal ; do
    case ${signal} in
        k)
            if [ "${mode}" = "blacklist" ] || [ "${mode}" = "whitelist" ] ; then
                keep_dns
            else
                exit 0
            fi
            ;;
        f)
            find_packages_uid
            ;;
        u)
            if [ "${auto_updateGeoIP}" = "true" ] ; then
                updateGeox ${Clash_GeoIP_file} ${GeoIP_url}
            fi

            if [ "${auto_updateGeoSide}" = "true" ] ; then
                updateGeox ${Clash_GeoSite_file} ${GeoSide_url}
            fi
            ;;
        m)
            if [ "${mode}" = "blacklist" ] && [ -f "${Clash_pid_file}" ] ; then
                monitor_local_ipv4
            else
                exit 0
            fi
            ;;
        p)
            sleep 0.5
            port_detection
            ;;
        r)
            ui_start
            ;;
        s)
            ui_stop
            ;;
        l)
            limit_clash
            ;;
        ?)
            echo ""
            ;;
    esac
done