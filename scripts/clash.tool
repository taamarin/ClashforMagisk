#!/system/bin/sh

scripts=`realpath $0`
scripts_dir=`dirname ${scripts}`
. /${scripts_dir}/clash.config

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


while getopts ":uc" signal ; do
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
        c)
            keep_dns
            exit 0
            ;;
        ?)
            echo ""
            ;;
    esac
done