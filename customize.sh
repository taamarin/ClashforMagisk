SKIPUNZIP=1
ASH_STANDALONE=1

status=""
architecture=""
uid="0"
gid="3005"
clash_data_dir="/data/clash"
modules_dir="/data/adb/modules"
bin_path="/system/bin/"
dns_path="/system/etc"
clash_adb_dir="/data/adb"
clash_service_dir="/data/adb/service.d"
busybox_data_dir="/data/adb/magisk/busybox"
ca_path="${dns_path}/security/cacerts"
clash_data_dir_kernel="${clash_data_dir}/kernel"
clash_data_sc="${clash_data_dir}/scripts"
mod_config="${clash_data_sc}/clash.config"
yacd_dir="${clash_data_dir}/dashboard"
latest=$(date +%Y%m%d%H%M)

if [ $BOOTMODE ! = true ] ; then
	ui_print "- Installing through TWRP Not supported"
	ui_print "- Intsall this module via Magisk Manager"
	abort "- ! Aborting installation !"
fi

ui_print "- Installing Clash for Magisk"

if [ -d "${clash_data_dir}" ] ; then
    ui_print "- Backup Clash"
    mkdir -p ${clash_data_dir}/${latest}
    mv ${clash_data_dir}/* ${clash_data_dir}/${latest}/
fi

if [ -f ${clash_data_dir}/${latest}/*.yaml ] ; then
    ui_print "- Restore config.yaml"
    cp ${clash_data_dir}/${latest}/*.yaml ${clash_data_dir}/
fi

ui_print "- Create folder Clash."
mkdir -p ${clash_data_dir}
mkdir -p ${clash_data_dir_kernel}
mkdir -p ${MODPATH}${ca_path}
mkdir -p ${clash_data_dir}/dashboard
mkdir -p ${MODPATH}/system/bin
mkdir -p ${clash_data_dir}/run
mkdir -p ${clash_data_dir}/scripts
mkdir -p ${clash_data_dir}/mosdns
mkdir -p ${clash_data_dir}/assets

case "${ARCH}" in
    arm)
        architecture="armv7"
        ;;
    arm64)
        architecture="armv8"
        ;;
    x86)
        architecture="386"
        ;;
    x64)
        architecture="amd64"
        ;;
esac

unzip -o "${ZIPFILE}" -x 'META-INF/*' -d $MODPATH >&2

ui_print "- Extract Dashboard"
unzip -o ${MODPATH}/dashboard.zip -d ${clash_data_dir}/dashboard/ >&2

ui_print "- Move Scripts Clash"
mv ${MODPATH}/scripts/* ${clash_data_dir}/scripts/
mv ${clash_data_dir}/scripts/template ${clash_data_dir}/

ui_print "- Move Cert&Geo"
mv ${clash_data_dir}/scripts/cacert.pem ${MODPATH}${ca_path}
mv ${MODPATH}/geo/* ${clash_data_dir}/

if [ ! -d /data/adb/service.d ] ; then
    ui_print "- Make folder service"
    mkdir -p /data/adb/service.d
fi

ui_print "- Create resolv.conf"
if [ ! -f "${dns_path}/resolv.conf" ] ; then
    touch ${MODPATH}${dns_path}/resolv.conf
    echo nameserver 8.8.8.8 > ${MODPATH}${dns_path}/resolv.conf
    echo nameserver 1.1.1.1 >> ${MODPATH}${dns_path}/resolv.conf
    echo nameserver 9.9.9.9 >> ${MODPATH}${dns_path}/resolv.conf
    echo nameserver 149.112.112.112 >> ${MODPATH}${dns_path}/resolv.conf
fi

ui_print "- Make packages.list"
if [ ! -f "${clash_data_dir}/scripts/packages.list" ] ; then
    touch ${clash_data_dir}/packages.list
fi

unzip -j -o "${ZIPFILE}" 'service.sh' -d ${MODPATH} >&2
unzip -j -o "${ZIPFILE}" 'uninstall.sh' -d ${MODPATH} >&2
unzip -j -o "${ZIPFILE}" 'clash_service.sh' -d ${clash_service_dir} >&2

ui_print "- Extract binary-$ARCH "
tar -xjf ${MODPATH}/binary/${ARCH}.tar.bz2 -C ${clash_data_dir_kernel}/&& echo "- extar kernel Succes" || echo "- extar kernel gagal"
mv ${clash_data_dir_kernel}/setcap ${MODPATH}${bin_path}/
mv ${clash_data_dir_kernel}/getpcaps ${MODPATH}${bin_path}/
mv ${clash_data_dir_kernel}/getcap ${MODPATH}${bin_path}/
mv ${clash_data_dir}/scripts/clash.config ${clash_data_dir}/
mv ${clash_data_dir}/scripts/mosdns ${clash_data_dir}/
mv ${clash_data_dir}/mosdns/mosdns ${clash_data_dir_kernel}/
mv ${clash_data_dir}/mosdns/dnstt-client ${clash_data_dir_kernel}/

if [ ! -f "${bin_path}/ss" ] ; then
    mv ${clash_data_dir_kernel}/ss ${MODPATH}${bin_path}/
else
    rm -rf ${clash_data_dir_kernel}/ss
fi

rm -rf ${MODPATH}/dashboard.zip
rm -rf ${MODPATH}/scripts
rm -rf ${MODPATH}/geo
rm -rf ${MODPATH}/binary
rm -rf ${MODPATH}/clash_service.sh
rm -rf ${clash_data_dir}/scripts/config.yaml
rm -rf ${clash_data_dir_kernel}/curl

sleep 1

ui_print "- Set Permissons"
set_perm_recursive ${MODPATH} 0 0 0755 0644
set_perm_recursive ${clash_service_dir} 0 0 0755 0755
set_perm_recursive ${clash_data_dir} ${uid} ${gid} 0755 0644
set_perm_recursive ${clash_data_dir}/scripts ${uid} ${gid} 0755 0755
set_perm_recursive ${clash_data_dir}/kernel ${uid} ${gid} 0755 0755
set_perm_recursive ${clash_data_dir}/dashboard ${uid} ${gid} 0755 0644
set_perm  ${MODPATH}/service.sh  0  0  0755
set_perm  ${MODPATH}/uninstall.sh  0  0  0755
set_perm  ${MODPATH}/system/bin/setcap  0  0  0755
set_perm  ${MODPATH}/system/bin/getcap  0  0  0755
set_perm  ${MODPATH}/system/bin/getpcaps  0  0  0755
set_perm  ${MODPATH}/system/bin/ss 0 0 0755
set_perm  ${MODPATH}/system/bin/clash 0 0 6755
set_perm  ${MODPATH}${ca_path}/cacert.pem 0 0 0644
set_perm  ${MODPATH}${dns_path}/resolv.conf 0 0 0755
set_perm  ${clash_data_dir}/scripts/clash.iptables 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.tool 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.inotify 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.service 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.cron 0  0  0755
set_perm  ${clash_data_dir}/scripts/start.sh 0  0  0755
set_perm  ${clash_data_dir}/scripts/usage.sh 0  0  0755
set_perm  ${clash_data_dir}/clash.config ${uid} ${gid} 0755
set_perm  ${clash_data_dir}/kernel/mosdns  0  0  0755
set_perm  ${clash_data_dir}/kernel/dnstt-client  0  0  0755
set_perm  ${clash_service_dir}/clash_service.sh  0  0  0755
sleep 1
ui_print "- Installation is complete, reboot your device"
