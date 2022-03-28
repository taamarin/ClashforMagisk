#!/bin/sh

MODDIR="/data/adb/modules/ClashforMagisk"
if [ -n "$(magisk -v | grep lite)" ]; then
  MODDIR=/data/adb/lite_modules/ClashforMagisk
fi

SCRIPTS_DIR="/data/adb/clash/scripts"
BUSYBOX_PATH="/data/adb/magisk/busybox"
CLASH_RUN_PATH="/data/adb/clash/run"
CLASH_PID_FILE="${CLASH_RUN_PATH}/clash.pid"

if [ -f ${CLASH_PID_FILE} ] ; then
    rm -rf ${CLASH_PID_FILE}
fi

nohup ${BUSYBOX_PATH} crond -c ${CLASH_RUN_PATH} > /dev/null 2>&1 &

start_tproxy () {
  ${SCRIPTS_DIR}/clash.service -s
  if [ -f /data/adb/clash/run/clash.pid ] ; then
    ${SCRIPTS_DIR}/clash.tproxy -s
  fi
}

if [ ! -f /data/adb/clash/manual ] ; then
  echo -n "" > /data/adb/clash/run/service.log
  if [ ! -f ${MODDIR}/disable ] ; then
      start_tproxy
  fi
  inotifyd ${SCRIPTS_DIR}/clash.inotify ${MODDIR} &>> /dev/null &
fi