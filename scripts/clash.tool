#!/system/bin/sh

scripts=`realpath $0`
scripts_dir=`dirname ${scripts}`
. /data/clash/clash.config

monitor_local_ipv4() {
    change=false

    wifistatus=$(dumpsys connectivity | grep "WIFI" | grep "state:" | /data/adb/magisk/busybox awk -F ", " '{print $2}' | /data/adb/magisk/busybox awk -F "=" '{print $2}' 2>&1)

    if [ ! -z "${wifistatus}" ]; then
    echo "" >${Clash_run_path}/lastmobile
        if test ! "${wifistatus}" = "$(cat ${Clash_run_path}/lastwifi)"; then
            change=true
            echo "${wifistatus}" >${Clash_run_path}/lastwifi
        elif [ "$(ip route get 1.2.3.4 | awk '{print $5}' 2>&1)" != "wlan0" ]; then
            change=true
            echo "${wifistatus}" >${Clash_run_path}/lastwifi
        fi
    else
        echo "" >${Clash_run_path}/lastwifi
    fi

    if [ "$(settings get global mobile_data 2>&1)" -eq 1 ] && [ -z "${wifistatus}" ] ; then
        echo "" >${Clash_run_path}/lastwifi
        card1="$(settings get global mobile_data1 2>&1)"
        card2="$(settings get global mobile_data2 2>&1)"
        if [ "${card1}" = 1 ] ; then
            mobilestatus=1
        fi
        if [ "${card2}" = 1 ] ; then
            mobilestatus=2
        fi
        if [ ! "${mobilestatus}" = "$(cat ${Clash_run_path}/lastmobile)" ]; then
            change=true
            echo "${mobilestatus}" >${Clash_run_path}/lastmobile
        fi
    else
        echo "" >${Clash_run_path}/lastmobile
    fi

    if [ "${change}" == true ]; then
        local_ipv4=$(ip a | /data/adb/magisk/busybox awk '$1~/inet$/{print $2}')
        local_ipv6=$(ip -6 a | /data/adb/magisk/busybox awk '$1~/inet6$/{print $2}' | grep '^2')
        rules_ipv4=$(${iptables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $9}' 2>&1)
        rules_ipv6=$(${ip6tables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $8}' 2>&1)

        for rules_subnet in ${rules_ipv4[*]}; do
            ${iptables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet} -j ACCEPT
        done

        for subnet in ${local_ipv4[*]}; do
        	${iptables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet} -j ACCEPT
        done

        for rules_subnet6 in ${rules_ipv6[*]}; do
            ${ip6tables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet6} -j ACCEPT
        done

        for subnet6 in ${local_ipv6[*]}; do
            ${ip6tables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT
        done
       # echo "info msg= aturan iptables untuk meneruskan ip lokal telah diperbarui." >> ${CFM_logs_file}
    else
       # echo "warning msg= tidak ada pembaruan ip local" >> ${CFM_logs_file}
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
    if [ "${Clash_enhanced_mode}" == "redir-host" ] ; then
        echo -n "" > ${appuid_file} 
        for package in `cat ${filter_packages_file} | sort -u` ; do
            ${busybox_path} awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
            if [ "${mode}" = "blacklist" ] ; then
                echo "info msg= ${package} di filter " >> ${CFM_logs_file}
            elif [ "${mode}" = "whitelist" ] ; then
                echo "info msg= ${package} diproksi." >> ${CFM_logs_file}
            fi
        done
    else
        echo "warning msg= filter/bypass dimatikan" >> ${CFM_logs_file}
        echo "warning msg= set (enhanced-mode: redir-host) to activate the filter" >> ${CFM_logs_file}
    fi
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
        echo "info msg= Clash cgroup activated | status: [${Cgroup_memory}]" >> ${CFM_logs_file}
    elif [ ! -d "${Cgroup_memory_path}/clash" ]; then
        echo "warning msg= Cgroup failed" >> ${CFM_logs_file}
    fi
}

restart_clash() {
    ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k

    echo -n "disable" > /data/clash/run/root
    sleep 0.5

    ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.iptables -s
    if [ "$?" == "0" ]; then
        echo "warning msg= Clash berhasil dimulai ulang." >>${CFM_logs_file}
    else
        echo "error msg= Clash Gagal dimulai ulang." >>${CFM_logs_file}
    fi
}

update_file() {
        file="$1"
        file_bak="${file}.bak"
        update_url="$2"

        if [ -f ${file} ]; then
            mv -f ${file} ${file_bak}
            echo "warning msg= backup file ${file_bak}" >> ${CFM_logs_file}
        fi
        echo "curl -L -A 'clash' ${update_url} -o ${file} "
        curl -L -A 'clash' ${update_url} -o ${file} 2>&1

        sleep 0.5

        if [ -f "${file}" ] ; then
            echo "info msg= `date` Update ${file} done." >> ${CFM_logs_file}
        else
            echo "error msg= `date` Update ${file} failed." >> ${CFM_logs_file}
            if [ -f "${file_bak}" ]; then
                mv ${file_bak} ${file}
                echo "warning msg= `date` restore ${file}." >> ${CFM_logs_file}
            fi
        fi
}

auto_update() {
    if [ "${auto_updateGeoX}" == "true" ] ; then
       update_file ${Clash_GeoIP_file} ${GeoIP_dat_url} >> ${CFM_logs_file}
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ "${auto_updateGeoX}" == "true" ] ; then
       update_file ${Clash_GeoSite_file} ${GeoSite_url} >> ${CFM_logs_file}
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ ${auto_updateSubcript} == "true" ]; then
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

    echo "warning msg= Download Config online" > ${CFM_logs_file}
    update_file ${Clash_config_file} ${Subcript_url} >> ${CFM_logs_file}

    sleep 0.5

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
    exit 0
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
        sleep 1
        echo -n "${sub_port} " >> ${CFM_logs_file}
    done
        echo "" >> ${CFM_logs_file} 
}

file_start() {
    local PID=`cat /data/clash/run/filemanager.pid 2> /dev/null`
    if (cat /proc/${PID}/cmdline | grep -q php) ; then
        echo "info msg= file manager service is running." > /data/clash/run/filemanager.log
        exit 1
    fi

    if [ -f ${php_bin_path} ] ; then
        chown 0:3005 /data/data/com.termux/files/usr/bin/php
        chmod 0755 /data/data/com.termux/files/usr/bin/php
        nohup ${busybox_path} setuidgid 0:3005 /data/data/com.termux/files/usr/bin/php -S 0.0.0.0:9999 -t /data/clash > /dev/null 2>&1 &
        echo -n $! > /data/clash/run/filemanager.pid
        echo "info msg= file manager service is running (PID: `cat /data/clash/run/filemanager.pid`)" > ${Clash_run_path}/filemanager.log
    else
       echo "error msg= PHP binary not detected." >> /data/clash/run/filemanager.log
       exit 1
    fi
}

file_stop() {
    kill -9 `cat /data/clash/run/filemanager.pid`
    rm -rf /data/clash/run/filemanager.pid
    echo "info msg= file manager service is  stopped." >> /data/clash/run/filemanager.log
}

clash_cron() {
step=5
i=0
    while ((i < 60)) ; do  
        i=$i+step
        ${scripts_dir}/clash.tool -m
        sleep $step
    done  
    exit 0
}

update_core() {
    if [ "${use_premium}" == "false" ]; then
        #latest_meta_version=`curl -ks https://api.github.com/repos/taamarin/Clash.Meta/releases | grep -m 1 "tag_name" | grep -o "Prerelease-Alpha"`
        latest_meta_version="Prerelease-Alpha"
        version_meta="Clash.Meta-android-arm64-alpha.gz"
        file_core="Clash.Meta"
        url_meta="${official_link_meta}/${latest_meta_version}/${version_meta}"
        update_file /data/clash/"${file_core}".gz ${url_meta} > ${CFM_logs_file}
    else
        file_core="Clash.Premium"
        update_file /data/clash/"${file_core}".gz ${official_link_premium} > ${CFM_logs_file}
    fi

    if (gunzip --help > /dev/null 2>&1) ; then
        if [ -f /data/clash/"${file_core}".gz ]; then
            gunzip /data/clash/"${file_core}".gz
        else
            echo "gunzip failed"
            exit 1
        fi
    else
        echo "error msg= gunzip not found"
        exit 1
    fi

    mv -f /data/clash/"${file_core}" /data/clash/core/lib
    if [ "$?" = "0" ]; then
        flag=true
    fi

    if [ -f "${Clash_pid_file}" ] && [ ${flag} == true ]; then
        restart_clash
    else
        echo "warning msg= Clash tidak dimulai ulang" >> ${CFM_logs_file}
    fi
}

update_dashboard() {
    file_dasboard="/data/clash/dashboard.zip"
    rm -rf /data/clash/dashboard/dist

    curl -L -A 'clash' ${url_dashboard} -o ${file_dasboard} 2>&1
    unzip -o  "${file_dasboard}" "yacd-meta-gh-pages/*" -d /data/clash/dashboard >&2
    mv -f /data/clash/dashboard/yacd-meta-gh-pages /data/clash/dashboard/dist 
    rm -rf ${file_dasboard}
}

while getopts ":afklmupoxced" signal ; do
    case ${signal} in
        a)
            clash_cron
            ;;
        f)
            find_packages_uid
            ;;
        k)
            keep_dns
            ;;
        l)
            sleep 0.5
            cgroup_limit
            ;;
        m)
            if [ "${mode}" = "blacklist" ] && [ -f "${Clash_pid_file}" ] ; then
                monitor_local_ipv4
            else
                exit 0
            fi
            ;;
        u)
            if [ "${auto_updateSubcript}" == "true" ] && [ "${auto_updateGeoX}" == "true" ]; then 
                auto_update
            elif [ "${auto_updateSubcript}" == "true" ] && "${auto_updateGeoX}" == "false" ]; then 
                auto_update
            elif [ "${auto_updateSubcript}" == "false" ] && [ "${auto_updateGeoX}" == "true" ]; then
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
        x)
            file_start
            ;;
        c)
            file_stop
            ;;
        e)
            update_core
            ;;
        d)
            update_dashboard
            ;;
        ?)
            echo ""
            ;;
    esac
done