# Skip unzip so it won't set default perms
SKIPUNZIP=1
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH >&2
rm -f $NVBASE/service.d/overlay_fix.sh $NVBASE/service.d/india_fix.sh

perm_set() {
  local src=$1 dest=$2
  case $i in
    */vendor/app*) context=u:object_r:vendor_app_file:s0;;
    */vendor/etc*) context=u:object_r:vendor_configs_file:s0;;
    */vendor/overlay*) context=u:object_r:vendor_overlay_file:s0;;
    */vendor*) context=u:object_r:vendor_file:s0;;
    */system*) ;;
    *) context="$(toybox ls -Z $i | head -n2 | tail -n1 | awk '{print $1}')";;
  esac
  usergroup="$(toybox ls -l $src | head -n2 | tail -n1 | awk '{print $3 " " $4}')"
  set_perm_recursive $dest $usergroup 0755 0644 $context
}

overlays="$(cat /proc/mounts | grep "^overlay " | awk '{print $2}' | tr '\n' ' ')"
dirs="$(cat /proc/mounts | grep "^overlay " | awk '{print $4}' | sed 's|.*lowerdir=||' | cut -d , -f1 | tr '\n' ' ')"
if [ -z "$overlays" ] && [ -f $NVBASE/modules/$MODID/.overlays ]; then
  overlays="$(head -n1 $NVBASE/modules/$MODID/.overlays)"
  dirs="$(head -n2 $NVBASE/modules/$MODID/.overlays | tail -n1)"
fi

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
    for j in $dir; do
      [ "$(readlink -f $j)" == "$i" -o "$(echo $j | grep "$NVBASE/modules" 2>/dev/null)" -o "$(echo $j | grep "/sbin/.magisk/modules" 2>/dev/null)" ] && continue
      cp -af $j/* $dest
      for k in $(find $dest -mindepth 1 -type d 2>/dev/null); do
        perm_set $j/$(echo $k | sed "s|$dest/||") $k
      done
    done
    num=$((num+1))
  done
else
  rm -rf $MODPATH 2>/dev/null
  $BOOTMODE || abort "Only flashing in magisk manager supported. Aborting!"
  ui_print "No overlay mounts detected!"
  abort "No need for this mod! Aborting!"
fi
