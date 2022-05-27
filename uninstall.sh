#!/system/bin/sh

remove_clash_data_dir() {
  rm -rf /data/adb/clash
}

remove_clash_data_dir
rm -rf /data/adb/service.d/cfm_service.sh