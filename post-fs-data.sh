#!/system/bin/sh
[ -d "/sbin/.magisk" ] && MODPATH="/sbin/.magisk/modules/overlayfix" || MODPATH="$(find /dev -mindepth 2 -maxdepth 2 -type d -name ".magisk")/modules/overlayfix"
overlays="$(head -n1 $MODPATH/.overlays)"
rm -f $MODPATH/.loops
exec 2>$MODPATH/pfsdoverlaydebug.log
set -x
# Need to handle loop mount umounting here - happen before magisk mount
for i in $overlays; do
  loop="$(cat /proc/mounts | grep "^/dev/block/loop[0-9]* " | grep "$i")"
  if [ "$(echo $loop | awk '{print $2}')" == "$i" ]; then
    umount -l $i
    echo "$loop" >> $MODPATH/.loops
  fi
done
