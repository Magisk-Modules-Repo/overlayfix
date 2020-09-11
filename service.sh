#!/system/bin/sh
[ "$(magisk --path 2>/dev/null)" ] && MODPATH="$(magisk --path 2>/dev/null)/.magisk/modules/overlayfix" || MODPATH="/sbin/.magisk/modules/overlayfix"
overlays="$(cat /proc/mounts | grep "^overlay " | awk '{print $2}' | tr '\n' ' ')"
dirs="$(cat /proc/mounts | grep "^overlay " | awk '{print $4}' | sed 's|.*lowerdir=||' | cut -d , -f1 | tr '\n' ' ')"
echo -e "$overlays\n$dirs" > $MODPATH/.overlays
exec 2>$MODPATH/overlaydebug.log
set -x

# Iterate through each overlay mounted after magisk mount
num=1
for i in $overlays; do
  # Get overlay mounted directories
  dir="$(echo $dirs | awk -v num=$num '{print $num}' | tr ':' ' ')"
  num=$((num+1))
  for j in $dir; do
    [ "$(readlink -f $j)" == "$i" ] && dirs="$(echo $dirs | sed "s| *$j *| |")"
  done
  
  # Unmount overlay mount
  umount -l $i

  # Gather magisk mounts
  unset modfiles files replace
  for j in $(find $MODPATH$i -maxdepth 0 -type d 2>/dev/null); do
    for k in $(find $j -type f 2>/dev/null); do
      k="$(echo $k | sed "s|$MODPATH||")"
      modfiles="$k $modfiles"
    done
  done
  for j in $(find $(dirname $MODPATH)/*$i -maxdepth 0 -type d ! -path "$MODPATH/*" 2>/dev/null | sort -u); do
    for k in $(find $j -type f 2>/dev/null | sort -u); do
      if [ "$(echo "$modfiles" | grep -w "$(echo $k | sed -e "s|^.*/system/|/system/|" -e "s|/.replace$||")")" ]; then
        [ "$(basename $k)" == ".replace" ] && replace="$k $replace" || files="$k $files"
      fi
    done
  done

  # Handle replacements
  for j in $replace; do
    dest="$i$(echo "$j" | sed -e "s|.*/$(basename $i)||" -e "s|/.replace$||")"
    while [ "$(mount | grep "$dest")" ]; do
      umount -l $dest
    done
    mount -t tmpfs tmpfs $dest
  done
  # Unmount all copies and remount only other module copy
  for j in $files; do
    dest="$i$(echo "$j" | sed "s|.*/$(basename $i)||")"
    while [ "$(mount | grep "$dest")" ]; do
      umount -l $dest
    done
    touch $dest 2>/dev/null
    mount -o bind $j $dest
  done
done
