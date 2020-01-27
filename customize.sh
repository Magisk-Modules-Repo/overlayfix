rm -f $NVBASE/service.d/overlay_fix.sh $NVBASE/service.d/india_fix.sh
if [ "`cat /proc/mounts | grep "^overlay "`" ] && $BOOTMODE; then
  sed -i -e "1aNVBASE=$NVBASE" -e "1aMODPATH=\$NVBASE/modules/$MODID" $MODPATH/overlay_fix.sh
  install -m 0755 $MODPATH/overlay_fix.sh $NVBASE/service.d/overlay_fix.sh
  touch $MODPATH/skip_mount
else
  rm -rf $MODPATH 2>/dev/null
  $BOOTMODE || abort "Only flashing in magisk manager supported. Aborting!"
  ui_print "No overlay mounts detected!"
  abort "No need for this mod! Aborting!"
fi
