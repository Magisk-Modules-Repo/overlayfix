#!/system/bin/sh
[ -d $MODPATH ] || { rm -f $0; exit 0; }
(
# Wait till boot is completed - overlays are mounted at this point
while [ $(getprop sys.boot_completed) -ne 1 ]; do
  sleep 1
done
# Iterate through each overlay mounted after magisk mount
rm -rf $MODPATH/.upper $MODPATH/.work
for i in $(cat /proc/mounts | tac | sed -n '\|/sbin/.magisk/block|q;p' | tac | grep "^overlay " | awk '{print $2}'); do
  unset REPLACE
  # Get mount arguments
  FLAGS="$(cat /proc/mounts | grep -E "^overlay .*$i" | awk '{print $4}' | sed -e 's|lowerdir.*||' -e 's|ro,|rw,|')"
  DIRS="$(cat /proc/mounts | grep -E "^overlay .*$i" | awk '{print $4}' | sed 's|.*lowerdir=||')"
  # Unmount existing overlay
  umount -l $i
  # Unmount any related magisk mounts - no need for them
  for j in $(cat /proc/mounts | grep -E "^/sbin/.magisk/block.*$i" | awk '{print $2}'); do 
    umount -l $j
  done
  # Get list of magisk modules to mount
  for j in $(find $NVBASE/modules/*$i -maxdepth 0 -type d 2>/dev/null); do
    DIRS="$j:$DIRS"
    for k in $(find $j -type f -name '.replace' 2>/dev/null); do
      REPLACE="$(dirname $k) $REPLACE"
    done
  done
  # Remount overlay as rw with all magisk modules included
  mkdir -p $MODPATH/.upper$i $MODPATH/.work$i
  mount -t overlay -o $FLAGS\lowerdir=$DIRS,upperdir=$MODPATH/.upper$i,workdir=$MODPATH/.work$i overlay $i
  # Process magisk replacements since it won't work through magisk
  for j in $REPLACE; do
    DEST="/$(echo $REPLACE | cut -d / -f6-)"
    rm -rf $DEST
    cp -rf $REPLACE $DEST
  done
  mount -o remount,ro $i
done
)&
