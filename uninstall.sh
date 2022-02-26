Clash_data_dir="/data/adb/clash"
Clash_sc_dir="/data/adb/service.d"

rm_data() {
    rm -rf ${Clash_data_dir}
    rm -rf ${Clash_sc_dir}/cfm_service.sh

}

rm_data