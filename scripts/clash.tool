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
       # echo $date_log"info: aturan iptables untuk meneruskan ip lokal telah diperbarui." >> ${CFM_logs_file}
    else
       # echo $date_log"warn: tidak ada pembaruan ip local" >> ${CFM_logs_file}
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
                echo $date_log"info: ${package} di filter " >> ${CFM_logs_file}
            elif [ "${mode}" = "whitelist" ] ; then
                echo $date_log"info: ${package} diproksi." >> ${CFM_logs_file}
            fi
        done
    else
        echo $date_log"warn: bypass apps turn off" >> ${CFM_logs_file}
        echo $date_log"warn: set [redir-host] to activate bypass apps (no recommend)" >> ${CFM_logs_file}
    fi
}

restart_clash() {
    ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k
    echo -n "disable" > /data/clash/run/root
    sleep 0.5
    ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.iptables -s
    if [ "$?" == "0" ]; then
        echo $date_log"warn: Clash berhasil dimulai ulang." >>${CFM_logs_file}
    else
        echo $date_log"err: Clash Gagal dimulai ulang." >>${CFM_logs_file}
    fi
}

update_file() {
        file="$1"
        file_bak="${file}.bak"
        update_url="$2"
        if [ -f ${file} ]; then
            mv -f ${file} ${file_bak}
            # echo $date_log"warn: backup file ${file_bak}" >> ${CFM_logs_file}
        fi
        echo "curl -k --insecure -L -A 'clash' ${update_url} -o ${file}"
        curl -k --insecure -L -A 'clash' ${update_url} -o ${file} 2>&1
        sleep 0.5
        if [ -f "${file}" ] ; then
            echo "" # $date_log"info: `date` Update ${file} done." >> ${CFM_logs_file}
        else
            # echo $date_log"err: `date` Update ${file} failed." >> ${CFM_logs_file}
            if [ -f "${file_bak}" ]; then
                mv ${file_bak} ${file}
                # echo $date_log"warn: `date` restore ${file}." >> ${CFM_logs_file}
            fi
        fi
}

auto_update() {
    if [ "${auto_updateGeoX}" == "true" ] ; then
       update_file ${Clash_GeoIP_file} ${GeoIP_dat_url} > /dev/null 2>&1
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ "${auto_updateGeoX}" == "true" ] ; then
       update_file ${Clash_GeoSite_file} ${GeoSite_url} >> /dev/null 2>&1
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ ${auto_updateSubcript} == "true" ]; then
       update_file ${Clash_config_file} ${Subcript_url} > /dev/null 2>&1
       if [ "$?" = "0" ]; then
          flag=true
       fi
    fi

    if [ -f "${Clash_pid_file}" ] && [ ${flag} == true ]; then
        if [ "${restart_clash}" == "true" ] ; then
            restart_clash
        fi
    else
        echo "" # $date_log"warn: Clash tidak dimulai ulang" >> ${CFM_logs_file}
    fi
}

config_online() {
    clash_pid=`cat ${Clash_pid_file}`
    match_count=0

    echo $date_log"warn: Download Config online" > ${CFM_logs_file}
    update_file ${Clash_config_file} ${Subcript_url} >> ${CFM_logs_file}

    sleep 0.5

    if [ -f "${Clash_config_file}" ] ; then
        match_count=$((${match_count} + 1))
    fi

    if [ ${match_count} -ge 1 ] ; then
        echo $date_log"info: download succes." >> ${CFM_logs_file}
        exit 0
    else
        echo $date_log"err: download failed, pastikan Url Tidak kosong" >> ${CFM_logs_file}
        exit 1
    fi
}

port_detection() {
    sleep 2.5
    clash_pid=`cat ${Clash_pid_file}`
    match_count=0
    
    if (ss -h > /dev/null 2>&1) ; then
        clash_port=$(ss -antup | grep "clash" | ${busybox_path} awk '$7~/'pid="${clash_pid}"*'/{print $5}' | ${busybox_path} awk -F ':' '{print $2}' | sort -u)
    else
        echo $date_log"info: skip port detected" >> ${CFM_logs_file}
        exit 0
    fi

    echo -n $date_log"info: port detected: " >> ${CFM_logs_file}
    for sub_port in ${clash_port[*]} ; do
        sleep 1
        echo -n "${sub_port} " >> ${CFM_logs_file}
    done
        echo "" >> ${CFM_logs_file} 
}

file_start() {
    local PID=`cat /data/clash/run/filemanager.pid 2> /dev/null`
    if (cat /proc/${PID}/cmdline | grep -q php) ; then
        echo $date_log"info: file manager service is running." > /data/clash/run/filemanager.log
        exit 1
    fi

    php_bin_path="/data/data/com.termux/files/usr/bin/php"
    if [ -f ${php_bin_path} ] ; then
        chown 0:3005 /data/data/com.termux/files/usr/bin/php
        chmod 0755 /data/data/com.termux/files/usr/bin/php
        nohup ${busybox_path} setuidgid 0:3005 /data/data/com.termux/files/usr/bin/php -S 0.0.0.0:9999 -t /data/clash > /dev/null 2>&1 &
        echo -n $! > /data/clash/run/filemanager.pid
        echo $date_log"info: file manager service is running (PID: `cat /data/clash/run/filemanager.pid`)" > ${Clash_run_path}/filemanager.log
    else
       echo $date_log"err: php binary not detected." >> /data/clash/run/filemanager.log
       exit 1
    fi
}

file_stop() {
    kill -9 `cat /data/clash/run/filemanager.pid`
    rm -rf /data/clash/run/filemanager.pid
    echo $date_log"info: file manager service is  stopped." >> /data/clash/run/filemanager.log
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

update_kernel() {
    if [ "${use_premium}" == "false" ]; then
        if [ "${meta_alpha}" == "false" ]; then
            tag_meta=$(curl -fsSL ${url_meta} | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | head -1)
            filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
            update_file /data/clash/${file_kernel}.gz ${url_meta}/download/${tag_meta}/${filename}.gz > /dev/null 2>&1
                if [ "$?" = "0" ]; then
                    flag=false
                fi
        else
            tag_meta=$(curl -fsSL ${url_meta} | grep -oE "${tag_name}" | head -1)
            filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
            update_file /data/clash/${file_kernel}.gz ${url_meta}/download/${tag}/${filename}.gz > /dev/null 2>&1
                if [ "$?" = "0" ]; then
                    flag=false
                fi
        fi
    else
        filename=$(curl -fsSL ${url_premium}/tag/premium | grep -oE "clash-${platform}-${arch}-[0-9]+.[0-9]+.[0-9]+" | head -1)
        update_file /data/clash/"${file_kernel}".gz ${url_premium}/download/premium/${filename}.gz > /dev/null 2>&1
            if [ "$?" = "0" ]; then
                flag=false
            fi
    fi

    if [ ${flag} == false ]; then
        if (gunzip --help > /dev/null 2>&1) ; then
           if [ -f /data/clash/"${file_kernel}".gz ]; then
                if (gunzip /data/clash/"${file_kernel}".gz) ; then
                    echo ""
                else
                    echo $date_log"err: gunzip ${file_kernel}.gz failed"  > ${CFM_logs_file}
                    echo $date_log"warn: periksa kembali url" >> ${CFM_logs_file}
                    if [ -f /data/clash/"${file_kernel}".gz.bak ]; then
                        rm -rf /data/clash/"${file_kernel}".gz.bak
                    else
                        rm -rf /data/clash/"${file_kernel}".gz
                    fi
                    if [ -f /data/clash/run/clash.pid ]; then
                        echo $date_log"info: Clash service is running (PID: `cat ${Clash_pid_file}`)" >> ${CFM_logs_file}
                        echo $date_log"info: Connect" >> ${CFM_logs_file}
                    fi
                    exit 1
                fi
           else
                echo $date_log"warn: gunzip ${file_kernel}.gz failed"  >> ${CFM_logs_file}
                echo $date_log"warn: pastikan ada koneksi internet"  >> ${CFM_logs_file}
                exit 1
            fi
        else
            echo $date_log"err: gunzip not found"  >> ${CFM_logs_file}
            exit 1
        fi
    fi

    mv -f /data/clash/"${file_kernel}" /data/clash/kernel/lib

    if [ "$?" = "0" ]; then
        flag=true
    fi

    if [ -f "${Clash_pid_file}" ] && [ ${flag} == true ]; then
        restart_clash
    else
       echo $date_log"warn: Clash tidak dimulai ulang" >> ${CFM_logs_file}
    fi
}

update_dashboard() {
    url_dashboard="https://github.com/taamarin/yacd/archive/refs/heads/gh-pages.zip"
    file_dasboard="/data/clash/dashboard.zip"
    rm -rf /data/clash/dashboard/dist

    curl -L -A 'clash' ${url_dashboard} -o ${file_dasboard} 2>&1
    unzip -o  "${file_dasboard}" "yacd-gh-pages/*" -d /data/clash/dashboard >&2
    mv -f /data/clash/dashboard/yacd-gh-pages /data/clash/dashboard/dist 
    rm -rf ${file_dasboard}
}

while getopts ":afmupoxced" signal ; do
    case ${signal} in
        a)
            clash_cron
            ;;
        f)
            find_packages_uid
            ;;
        m)
            if [ "${mode}" = "blacklist" ] && [ -f "${Clash_pid_file}" ] ; then
                monitor_local_ipv4 &>> $CFM_logs_service
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
                rm -rf /data/clash/*dat.bak
                exit 1
            fi
            rm -rf /data/clash/*dat.bak
            exit 1
            ;;
        p)
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
            echo "proses download"
            update_kernel
            ;;
        d)
            update_dashboard
            ;;
        ?)
            echo ""
            ;;
    esac
done