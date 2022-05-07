SKIPUNZIP=1
ASH_STANDALONE=1

status=""
architecture=""
system_gid="1000"
system_uid="1000"
clash_data_dir="/data/adb/clash"
modules_dir="/data/adb/modules"
bin_path="/system/bin/"
dns_path="/system/etc"
clash_adb_dir="/data/adb"
clash_service_dir="/data/adb/service.d"
sdcard_dir="/sdcard/Download"
busybox_data_dir="/data/adb/magisk/busybox"
ca_path="${dns_path}/security/cacerts"
clash_data_dir_core="${clash_data_dir}/core"
CPFM_mode_dir="${modules_dir}/clash_premium"
clash_data_sc="${clash_data_dir}/scripts"
mod_config="${clash_data_sc}/clash.config"
geoip_file_path="${clash_data_dir}/Country.mmdb"
yacd_dir="${clash_data_dir}/yacd-gh-pages"

if [ $BOOTMODE ! = true ] ; then
  abort "Error: silahkan install di magisk manager"
fi

if [ -d "${clash_data_dir}" ] ; then
    ui_print "- folder Clash di temukan, Membuat Backup"
    if [ -d "${clash_data_dir}" ] ; then
        rm -rf ${clash_data_dir}/clash.old
    fi
    mkdir -p ${clash_data_dir}/clash.old
    mv ${clash_data_dir}/* ${clash_data_dir}/clash.old
fi

ui_print "- Prepare clash execute environment"
ui_print "- Membuat folder Clash."
mkdir -p ${clash_data_dir}
mkdir -p ${clash_data_dir_core}
mkdir -p ${MODPATH}${ca_path}
mkdir -p ${clash_data_dir}/yacd-gh-pages
mkdir -p ${MODPATH}/system/bin
mkdir -p ${clash_data_dir}/run
mkdir -p ${clash_data_dir}/scripts
mkdir -p ${clash_data_dir}/switch

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

ui_print "- Unzip Yacd"
${busybox_data_dir} wget ${official_yacd_link} -O ${download_yacd_zip}
if [ ! -d /data/adb/yacd-gh-pages ] ; then
    rm -rf "${clash_data_dir}/yacd-gh-pages/*"
fi
unzip -o ${MODPATH}/yacd-gh-pages.zip -d ${clash_data_dir}/yacd-gh-pages/ >&2

ui_print "- Move Scripts Clash"
rm -rf "${clash_data_dir}/scripts/*"
mv ${MODPATH}/scripts/* ${clash_data_dir}/scripts/
mv ${clash_data_dir}/scripts/template ${clash_data_dir}/
mv ${clash_data_dir}/scripts/cacert.pem ${MODPATH}${ca_path}
mv ${MODPATH}/GeoX/* ${clash_data_dir}/

ui_print "- Konfigurasi folder service"
if [ ! -d /data/adb/service.d ] ; then
    mkdir -p /data/adb/service.d
fi

ui_print "- Membuat DNS resolv.conf"
if [ ! -f "${dns_path}/resolv.conf" ] ; then
    touch ${MODPATH}${dns_path}/resolv.conf
    echo nameserver 8.8.8.8 > ${MODPATH}${dns_path}/resolv.conf
    echo nameserver 1.1.1.1 >> ${MODPATH}${dns_path}/resolv.conf
fi

ui_print "- Execute Scripts Service"
if [ ! -f "${clash_data_dir}/packages.list" ] ; then
    touch ${clash_data_dir}/packages.list
fi
if [ ! -f "${MODPATH}/service.sh" ] ; then
    unzip -j -o "${ZIPFILE}" 'service.sh' -d ${MODPATH} >&2
fi
if [ ! -f "${MODPATH}/uninstall.sh" ] ; then
    unzip -j -o "${ZIPFILE}" 'uninstall.sh' -d ${MODPATH} >&2
fi
if [ ! -f "${clash_service_dir}/cfm_service.sh" ] ; then
    unzip -j -o "${ZIPFILE}" 'cfm_service.sh' -d ${clash_service_dir} >&2
fi

ui_print "- Proses Core $ARCH execute files"
tar -xjf ${MODPATH}/binary/${ARCH}.tar.bz2 -C ${clash_data_dir_core}/&& echo "- extar Core Succes" || echo "- extar Core gagal"
mv ${clash_data_dir_core}/setcap ${MODPATH}${bin_path}/
mv ${clash_data_dir_core}/getpcaps ${MODPATH}${bin_path}/
mv ${clash_data_dir_core}/getcap ${MODPATH}${bin_path}/
mv ${clash_data_dir}/scripts/config.yaml ${clash_data_dir}/
if [ ! -f "${bin_path}/ss" ] ; then
    mv ${clash_data_dir_core}/ss ${MODPATH}${bin_path}/
else
    rm -rf ${clash_data_dir_core}/ss
fi

rm -rf ${MODPATH}/yacd-gh-pages.zip
rm -rf ${MODPATH}/scripts
rm -rf ${MODPATH}/GeoX
rm -rf ${MODPATH}/binary
rm -rf ${MODPATH}/cfm_service.sh
rm -rf ${clash_data_dir}/scripts/config.yaml
sleep 1

ui_print "- Create module.prop"
rm -rf ${MODPATH}/module.prop
touch ${MODPATH}/module.prop
echo "id=ClashforMagisk" > ${MODPATH}/module.prop
echo "name=Clash for Magisk" >> ${MODPATH}/module.prop
echo -n "version=Module v1.9.5 " >> ${MODPATH}/module.prop
# echo ${latest_clash_version} >> ${MODPATH}/module.prop
echo "versionCode=20220225" >> ${MODPATH}/module.prop
echo "author=Taamarin" >> ${MODPATH}/module.prop
echo "description=Clash core with service scripts for Android" >> ${MODPATH}/module.prop

ui_print "- Mengatur Permissons"
set_perm_recursive ${MODPATH} 0 0 0755 0644
set_perm_recursive ${clash_service_dir} 0 0 0755 0755
set_perm_recursive ${clash_data_dir} ${system_uid} ${system_gid} 0755 0644
set_perm_recursive ${clash_data_dir}/scripts ${system_uid} ${system_gid} 0755 0755
set_perm_recursive ${clash_data_dir}/core ${system_uid} ${system_gid} 0755 0755
set_perm_recursive ${clash_data_dir}/yacd-gh-pages ${system_uid} ${system_gid} 0755 0644
set_perm  ${MODPATH}/service.sh  0  0  0755
set_perm  ${MODPATH}/uninstall.sh  0  0  0755
set_perm  ${MODPATH}/system/bin/setcap  0  0  0755
set_perm  ${MODPATH}/system/bin/getcap  0  0  0755
set_perm  ${MODPATH}/system/bin/getpcaps  0  0  0755
set_perm  ${MODPATH}/system/bin/ss 0 0 0755
set_perm  ${MODPATH}/system/bin/clash 0 0 6755
set_perm  ${MODPATH}${ca_path}/cacert.pem 0 0 0644
set_perm  ${MODPATH}${dns_path}/resolv.conf 0 0 0755
set_perm  ${clash_data_dir}/scripts/clash.tproxy 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.tool 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.inotify 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.service 0  0  0755
set_perm  ${clash_data_dir}/scripts/start.sh 0  0  0755
set_perm  ${clash_data_dir}/scripts/clash.config ${system_uid} ${system_gid} 0755
set_perm  ${clash_service_dir}/cfm_service.sh   0  0  0755
