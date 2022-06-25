#!/sbin/sh

#################
# Initialization
#################

ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true || BOOTMODE=false
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true

umask 022

OUTFD=$2
ZIPFILE=$3
TMPDIR=/dev/tmp
COMMONDIR=$TMPDIR/NikGappsScripts
nikGappsLog=$TMPDIR/NikGapps.log

# echo before loading util_functions
ui_print() {
  echo "$1" >> "$nikGappsLog"
  if $BOOTMODE; then
    echo "$1"
  else
    echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
  fi
}

# show_progress <amount> <time>
show_progress() { echo "progress $1 $2" >>"$OUTFD"; }
# set_progress <amount>
set_progress() { echo "set_progress $1" >>"$OUTFD"; }

require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v20.4+! "
  ui_print "*******************************"
  exit 1
}

if $BOOTMODE; then

  #########################
  # Load util_functions.sh
  #########################

  mount /data 2>/dev/null

  [ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
  . /data/adb/magisk/util_functions.sh
  [ $MAGISK_VER_CODE -lt 20400 ] && require_new_magisk
  install_module
  exit 0
else
  mkdir -p "$COMMONDIR"
  stock_busybox_version=$(busybox | head -1)
  unzip -o "$ZIPFILE" busybox -d $COMMONDIR >&2
  BBInstaller=$COMMONDIR/busybox
  if [ -f $BBInstaller ]; then
    chmod +x $BBInstaller
    export BB=$BBInstaller
  fi
  [ -z "$BBDIR" ] && BBDIR=$TMPDIR/bin
  mkdir -p $BBDIR
  ln -s "$BBInstaller" $BBDIR/busybox
  $BBInstaller --install -s $BBDIR
  if [ $? != 0 ] || [ -z "$(ls $BBDIR)" ]; then
    abort "Busybox setup failed. Aborting..."
  fi
  BB=$BBDIR/busybox
  version=$($BB | head -1)
  [ -z "$version" ] && version=$(busybox | head -1) && BB=busybox
  [ -z "$version" ] && abort "- Cannot find busybox, Installation Failed!"
  echo "$PATH" | grep -q "^$BBDIR" || export PATH=$BBDIR:$PATH
  $BB unzip -o "$ZIPFILE" customize.sh -d $COMMONDIR >&2
  [ -f $COMMONDIR/customize.sh ] && . $COMMONDIR/customize.sh
fi