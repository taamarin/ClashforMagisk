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
clash_service_dir="/data/adb"
clash_service="/data/adb/service.d"
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
  abort "error: silahkan install di magisk manager"
fi

# prepare clash execute environment
ui_print "- Membuat folder Clash."
mkdir -p ${clash_data_dir}
mkdir -p ${clash_data_dir_core}
mkdir -p ${MODPATH}${ca_path}
mkdir -p ${clash_data_dir}/yacd-gh-pages
mkdir -p ${MODPATH}/system/bin
mkdir -p ${clash_data_dir}/run
mkdir -p ${clash_data_dir}/scripts

download_clash_zip="${clash_data_dir}/run/clash-core.zip"
download_yacd_zip="${clash_data_dir}/yacd-gh-pages.zip"
download_scripts_zip="${clash_data_dir}/master.zip"
official_yacd_link="https://github.com/taamarin/yacd/releases/download/v0.3.4/yacd-gh-pages.zip"
official_scripts_link="https://github.com/taamarin/ClashforMagisk/archive/refs/heads/master.zip"
custom="${sdcard_dir}/clash-core.zip"

if [ -f "${custom}" ]; then
  cp "${custom}" "${download_clash_zip}"
  ui_print "- Info: clash-core khusus ditemukan, memulai penginstal"
  latest_clash_version=custom
else
  case "${ARCH}" in
    arm)
      version="clash-linux-arm32-v7a.zip"
      ;;
    arm64)
      version="clash-linux-arm64-v8a.zip"
      ;;
    x86)
      version="clash-linux-32.zip"
      ;;
    x64)
      version="clash-linux-64.zip"
      ;;
  esac
  ui_print "- Menggunakan versi: ${version}"
  if [ -f ${sdcard_dir}/"${version}" ]; then
    cp ${sdcard_dir}/"${version}" "${download_clash_zip}"
    ui_print "- Info: clash-core sudah diunduh, mulai penginstal"
    latest_clash_version=custom
  else
    # download latest clash core from official link
    ui_print "- Hubungkan tautan unduhan forks-clash."
    
    forks_clash_link="https://github.com/taamarin/MetaforCfm/releases"

    if [ -x "$(which wget)" ] ; then
      latest_clash_version=`wget -qO- https://api.github.com/repos/taamarin/MetaforCfm/releases | grep -m 1 "tag_name" | grep -o "v[0-9.]*"`
    elif [ -x "$(which curl)" ]; then
      latest_clash_version=`curl -ks https://api.github.com/repos/taamarin/MetaforCfm/releases | grep -m 1 "tag_name" | grep -o "v[0-9.]*"`
    elif [ -x "/data/adb/magisk/busybox" ] ; then
      latest_clash_version=`${busybox_data_dir} wget -qO- https://api.github.com/repos/taamarin/MetaforCfm/releases | grep -m 1 "tag_name" | grep -o "v[0-9.]*"`
    else
      ui_print "- Error: Tidak dapat menemukan curl atau wget, silakan instal."
      abort
    fi

    if [ "${latest_clash_version}" = "" ] ; then
      ui_print "- Error: Sambungkan tautan unduhan clash resmi gagal."
      ui_print "- Tips: You can download clash core manually,"
      ui_print "      dan taruh di /sdcard/Download"
      abort
    fi
    ui_print "- Unduh inti clash terbaru ${latest_clash_version}-${ARCH}"

    if [ -x "$(which wget)" ] ; then
      wget "${forks_clash_link}/download/${latest_clash_version}/${version}" -O "${download_clash_zip}" >&2
    elif [ -x "$(which curl)" ]; then
      curl "${forks_clash_link}/download/${latest_clash_version}/${version}" -kLo "${download_clash_zip}" >&2
    elif [ -x "/data/adb/magisk/busybox" ] ; then
      ${busybox_data_dir} wget "${forks_clash_link}/download/${latest_clash_version}/${version}" -O "${download_clash_zip}" >&2
    else
      ui_print "- Error: tidak dapat menemukan curl atau wget, silakan instal."
      abort
    fi

    if [ "$?" != "0" ] ; then
      ui_print "- Error: Unduh inti clash gagal."
      ui_print "- Tips: anda dapat mengunduh clash core secara manual,"
      ui_print "      dan taruh di /sdcard/Download"
      abort
    fi
  fi
fi

ui_print "- Unduh Yet Another Clash Dashboard"
${busybox_data_dir} wget ${official_yacd_link} -O ${download_yacd_zip}
rm -rf "${clash_data_dir}/yacd-gh-pages/*"
unzip -o "${download_yacd_zip}" -d ${clash_data_dir}/yacd-gh-pages/ >&2

ui_print "- Unduh Scripts Clash"
${busybox_data_dir} wget ${official_scripts_link} -O ${download_scripts_zip}
rm -rf "${clash_data_dir}/scripts/*"
unzip -j -o "${download_scripts_zip}" "ClashforMagisk-master/scripts/*" -d ${clash_data_dir}/scripts/ >&2

if [ ! -f "${clash_service_dir}/service.d" ] ; then
    mkdir ${clash_service_dir}/service.d
fi

ui_print "- Unduh Selesai"
unzip -j -o "${ZIPFILE}" 'service.sh' -d ${MODPATH} >&2
unzip -j -o "${ZIPFILE}" 'uninstall.sh' -d ${MODPATH} >&2
rm -rf ${clash_data_dir_core}/clash
set_perm  ${MODPATH}/service.sh    0  0  0755

# install clash execute file
ui_print "- Proses Core $ARCH execute files"
unzip -j -o "${download_clash_zip}" "GeoIP.dat" -d ${clash_data_dir} >&2
unzip -j -o "${download_clash_zip}" "GeoSite.dat" -d ${clash_data_dir} >&2
unzip -j -o "${download_clash_zip}" "clash" -d ${clash_data_dir_core} >&2
unzip -j -o "${download_clash_zip}" "setcap" -d ${MODPATH}${bin_path} >&2
unzip -j -o "${download_clash_zip}" "getcap" -d ${MODPATH}${bin_path} >&2
unzip -j -o "${download_clash_zip}" "getpcaps" -d ${MODPATH}${bin_path} >&2
unzip -j -o "${download_clash_zip}" "ss" -d ${MODPATH}${bin_path} >&2
unzip -j -o "${download_clash_zip}" "resolv.conf" -d ${MODPATH}${dns_path} >&2
unzip -j -o "${download_clash_zip}" "cacert.pem" -d ${MODPATH}${ca_path} >&2
MODPATH
rm "${download_clash_zip}"
rm "${download_yacd_zip}"
rm "${download_scripts_zip}"

# copy clash data and config
ui_print "- Salin konfigurasi Clash dan file data"
unzip -o "${ZIPFILE}" -x 'META-INF/*' -d ${MODPATH} >&2

if [ ! -f "${clash_data_dir}/config.yaml" ] ; then
    mv ${clash_data_dir}/scripts/config.yaml ${clash_data_dir}
fi

rm -rf ${MODPATH}/scripts
rm -rf ${clash_data_dir}/scripts/config.yaml
sleep 1

# generate module.prop
ui_print "- Create module.prop"
rm -rf ${MODPATH}/module.prop
touch ${MODPATH}/module.prop
echo "id=ClashforMagisk" > ${MODPATH}/module.prop
echo "name=Clash for Magisk" >> ${MODPATH}/module.prop
echo -n "version=Module v1.9.1, Core " >> ${MODPATH}/module.prop
echo ${latest_clash_version} >> ${MODPATH}/module.prop
echo "versionCode=20220225" >> ${MODPATH}/module.prop
echo "author=Taamarin" >> ${MODPATH}/module.prop
echo "description=Clash core with service scripts for Android" >> ${MODPATH}/module.prop

ui_print "- Mengatur Permissons"
set_perm_recursive ${MODPATH} 0 0 0755 0644
set_perm_recursive ${clash_service} 0 0 0755
set_perm_recursive ${clash_data_dir} ${system_uid} ${system_gid} 0755 0644
set_perm_recursive ${clash_data_dir}/scripts ${system_uid} ${system_gid} 0755 0755
set_perm_recursive ${clash_data_dir}/core ${system_uid} ${system_gid} 0755 0755
set_perm_recursive ${clash_data_dir}/yacd-gh-pages ${system_uid} ${system_gid} 0755 0644
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
set_perm  ${clash_data_dir}/clash.config ${system_uid} ${system_gid} 0755



