Clash_data_dir="/data/clash"

rm_data() {
    rm -rf ${Clash_data_dir}
    rm -rf /data/adb/service.d/clash_service.sh
}

rm_data
# UNINSTALL 