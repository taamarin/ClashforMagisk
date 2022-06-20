<<<<<<< HEAD
Clash_data_dir="/data/clash"

rm_data() {
    rm -rf ${Clash_data_dir}
    rm -rf /data/adb/service.d/clash_service.sh
}

rm_data
=======
#!/system/bin/sh

remove_clash_data_dir() {
  rm -rf /data/adb/clash
}

remove_clash_data_dir
rm -rf /data/adb/service.d/cfm_service.sh
>>>>>>> 957413e (beta)
