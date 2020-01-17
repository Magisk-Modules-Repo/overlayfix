#!/system/bin/sh
[ -d /data/adb/modules/overlayfix ] || { rm -f $0; exit 0; }
(
# Wait till boot is completed - overlays are mounted at this point
while [ $(getprop sys.boot_completed) -ne 1 ]; do
  sleep 1
done
# Iterate through each overlay mounted after magisk mount
for i in $(cat /proc/mounts | tac | sed -n '\|/sbin/.magisk/block|q;p' | tac | grep "^overlay " | awk '{print $2}'); do
  # Get mount arguments
  FLAGS="$(cat /proc/mounts | grep -E "^overlay .*$i" | awk '{print $4}' | sed 's|lowerdir.*||')"
  DIRS="$(cat /proc/mounts | grep -E "^overlay .*$i" | awk '{print $4}' | sed 's|.*lowerdir=||')"
  # Unmount existing overlay
  umount -l $i
  # Unmount any related magisk mounts - no need for them
  for j in $(cat /proc/mounts | grep -E "^/sbin/.magisk/block.*$i" | awk '{print $2}'); do 
    umount -l $j
  done
  # Get list of magisk modules to mount
  for j in /data/adb/modules/*; do
    [ -d $j$i ] && DIRS="$j$i:$DIRS"
  done
  # Remount overlay with all magisk modules included
  mount -t overlay -o $FLAGS\lowerdir=$DIRS overlay $i
done
)&