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

        echo "info msg= iptables untuk melewati ip lokal telah diperbarui." >> ${CFM_logs_file}
    else
        echo "info msg= ip lokal tidak berubah dan tidak akan diproses." >> ${CFM_logs_file}
        exit 0
    fi

    unset local_ipv4
    unset local_ipv4_number
    unset rules_ipv4
    unset rules_number
    unset wait_count
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


while getopts ":kfum" signal ; do
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
        ?)
            echo ""
            ;;
    esac
done