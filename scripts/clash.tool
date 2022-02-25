#!/system/bin/sh

scripts=`realpath $0`
scripts_dir=`dirname ${scripts}`
. /${scripts_dir}/clash.config

monitor_local_ipv4() {
    local_ipv4=$(ip a | awk '$1~/inet$/{print $2}')
    local_ipv4_number=$(ip a | awk '$1~/inet$/{print $2}' | wc -l)
    rules_ipv4=$(${iptables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $9}')
    rules_number=$(${iptables_wait} -t mangle -L FILTER_LOCAL_IP | grep "ACCEPT" | wc -l)

    if [ ${local_ipv4_number} -ne ${rules_number} ] ; then
        for rules_subnet in ${rules_ipv4[*]} ; do
            wait_count=0
            a_subnet=$(ipcalc -n ${rules_subnet} | awk -F '=' '{print $2}')
            for local_subnet in ${local_ipv4[*]} ; do
                b_subnet=$(ipcalc -n ${local_subnet} | awk -F '=' '{print $2}')

                if [ "${a_subnet}" != "${b_subnet}" ] ; then
                    wait_count=$((${wait_count} + 1))
                    
                    if [ ${wait_count} -ge ${local_ipv4_number} ] ; then
                        ${iptables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet} -j ACCEPT
                    fi
                fi
            done
        done

        for subnet in ${local_ipv4[*]} ; do
            if ! (${iptables_wait} -t mangle -C FILTER_LOCAL_IP -d ${subnet} -j ACCEPT > /dev/null 2>&1) ; then
                ${iptables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet} -j ACCEPT
            fi
        done

        unset a_subnet
        unset b_subnet

        echo "[info] : aturan iptables untuk melewati ip lokal diperbarui." >> ${CFM_logs_file}
    else
        echo "[info] : tidak ada perubahan ip lokal dan tidak ada proses yang dilakukan." >> ${CFM_logs_file}
        exit 0
    fi

    unset local_ipv4
    unset local_ipv4_number
    unset rules_ipv4
    unset rules_number
    unset wait_count
}

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

            echo "[info] : ${file} pembaruan selesai." >> ${CFM_logs_file}
        else
            mv ${file_bak} ${file}
            echo "[war] : ${file} pembaruan gagal, file telah dipulihkan." >> ${CFM_logs_file}
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

subscription() {
    if [ "${auto_subscription}" = "true" ] ; then
        mv -f ${Clash_config_file} ${Clash_data_dir}/config.yaml.backup
        curl -L -A 'clash' ${subscription_url} -o ${Clash_config_file} >> /dev/null 2>&1

        sleep 20

        if [ -f "${Clash_config_file}" ]; then
            ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.tproxy -k
            rm -rf ${Clash_data_dir}/config.yaml.backup
            sleep 1
            ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.tproxy -s
            if [ "$?" = "0" ] ; then
                echo "[info] : pembaruan berlangganan berhasil, restart cfm." >> ${CFM_logs_file}
            else
                echo "[error] : Pembaruan berlangganan berhasil, tapi restart CFM gagal." >> ${CFM_logs_file}
            fi
        else
            mv ${Clash_data_dir}/config.yaml.backup ${Clash_config_file}
            echo "[war] : pembaruan berlangganan gagal dan file konfigurasi telah dipulihkan..." >> ${CFM_logs_file}
        fi
    else
        exit 0
    fi
}

find_packages_uid() {
    echo "" > ${appuid_file}
    for package in `cat ${filter_packages_file} | sort -u` ; do
        awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
        if [ "${mode}" = "blacklist" ] ; then
            echo "[info] : ${package} difilter." >> ${CFM_logs_file}
        elif [ "${mode}" = "whitelist" ] ; then
            echo "[info] : ${package} telah diproksi." >> ${CFM_logs_file}
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

    for sub_port in ${clash_port[*]} ; do
        sleep 0.5
        echo "[info] : port terdeteksi:${sub_port}" >> ${CFM_logs_file}
        if [ "${sub_port}" = ${Clash_tproxy_port} ] || [ "${sub_port}" = ${Clash_dns_port} ] ; then
            match_count=$((${match_count} + 1))
        fi
    done

    if [ ${match_count} -ge 2 ] ; then
        echo "[info] : port Tproxy dan DNS dimulai." >> ${CFM_logs_file}
        exit 0
    else
        echo "[error] : port Tproxy dan DNS tidak dimulai." >> ${CFM_logs_file}
        exit 1
    fi
}

while getopts ":ukfmpsc" signal ; do
    case ${signal} in
        u)
            if [ "${auto_updateGeoIP}" = "true" ] ; then
                updateGeox ${Clash_GeoIP_file} ${GeoIP_url}
            fi

            if [ "${auto_updateGeoSide}" = "true" ] ; then
                updateGeox ${Clash_GeoSite_file} ${GeoSide_url}
            fi

            if [ -f "${Clash_pid_file}" ] ; then
                ${scripts_dir}/clash.service -k
                ${scripts_dir}/clash.service -s
                if [ "$?" = "0" ] ; then
                   echo "[info] : Clash berhasil dimulai ulang." >> ${CFM_logs_file}
                   echo "[info] : GeoX Update." >> ${CFM_logs_file}
                else
                    echo "[err] : clash restart gagal." >> ${CFM_logs_file}
                fi
            fi
            ;;
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
        c)
            keep_dns
            exit 0
            ;;
        ?)
            echo ""
            ;;
    esac
done