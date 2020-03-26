# Skip unzip so it won't set default perms
SKIPUNZIP=1
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH >&2
rm -f $NVBASE/service.d/overlay_fix.sh $NVBASE/service.d/india_fix.sh

perm_set() {
  local src=$1 dest=$2
  case $i in
    */vendor/app*) local context=u:object_r:vendor_app_file:s0;;
    */vendor/etc*) local context=u:object_r:vendor_configs_file:s0;;
    */vendor/overlay*) local context=u:object_r:vendor_overlay_file:s0;;
    */vendor*) local context=u:object_r:vendor_file:s0;;
    */system*) ;;
    *) local context="$(/system/bin/toybox ls -Z $i | head -n2 | tail -n1 | awk '{print $1}')";;
  esac
  local usergroup="$(/system/bin/toybox ls -l $src | head -n2 | tail -n1 | awk '{print $3 " " $4}')"
  set_perm_recursive $dest $usergroup 0755 0644 $context
}

overlays="$(cat /proc/mounts | grep "^overlay " | awk '{print $2}' | tr '\n' ' ')"
dirs="$(cat /proc/mounts | grep "^overlay " | awk '{print $4}' | sed 's|.*lowerdir=||' | cut -d , -f1 | tr '\n' ' ')"
if [ -z "$overlays" ] && [ -f $NVBASE/modules/$MODID/.overlays ]; then
  overlays="$(head -n1 $NVBASE/modules/$MODID/.overlays)"
  dirs="$(head -n2 $NVBASE/modules/$MODID/.overlays | tail -n1)"
fi
echo -e "$overlays\n$dirs" > $MODPATH/.overlays

# Copy all overlayed files to module
if [ "$overlays" ] && $BOOTMODE; then
  ui_print "- Copying overlayed files to module directory"
  mkdir $MODPATH/system
  set_perm_recursive $MODPATH/system 0 0 0755 0644
  num=1
  for i in $overlays; do
    [ "$(echo $i | cut -d / -f2)" == "system" ] && dest=$MODPATH$i || dest=$MODPATH/system$i
    mkdir -p $i $dest
    perm_set $i $dest
    dir="$(echo $dirs | awk -v num=$num '{print $num}' | tr ':' ' ')"
    num=$((num+1))
    for j in $dir; do
      loopmount=false
      # Unmount tmpfs magisk mount over top loop mount (like reserve on oos) so files are accessible for copying
      if [ "$(readlink -f $j)" == "$i" ] && [ "$(cat /proc/mounts | grep "^/dev/block/loop[0-9]* " | grep "$i" | awk '{print $2}')" == "$i" ]; then
        loopmount=true
        [ "$(cat /proc/mounts | grep "^tmpfs " | grep "$i" | awk '{print $2}')" == "$i" ] && umount -l $i
      # Remount loop mount to get files if needed
      elif [ "$(readlink -f $j)" == "$i" ] && [ "$(awk '{print $2}' $NVBASE/modules/$MODID/.loops | grep -x "$i" 2>/dev/null)" ]; then
        loopmount=true
        loopline="$(grep -w "$i" $NVBASE/modules/$MODID/.loops)"
        mount -t $(echo $loopline | awk '{print $3}') -o $(echo $loopline | awk '{print $4}') $(echo $loopline | awk '{print $1}') $i
      fi
      # Ignore magisk or non-mounted files
      if [ "$(echo $j | grep -E "$NVBASE/modules|/sbin/.magisk/modules" 2>/dev/null)" ] || ([ "$(readlink -f $j)" == "$i" ] && ! $loopmount); then
        continue
      fi
      cp -af $j/* $dest
      rm -rf $dest/"lost+found" 2>/dev/null
      for k in $(find $dest -mindepth 1 -type d 2>/dev/null); do
        perm_set $j/$(echo $k | sed "s|$dest/||") $k
      done
    done
  done
else
  rm -rf $MODPATH 2>/dev/null
  $BOOTMODE || abort "Only flashing in magisk manager supported. Aborting!"
  ui_print "No overlay mounts detected!"
  abort "No need for this mod! Aborting!"
fi
