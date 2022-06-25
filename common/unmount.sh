#!/sbin/sh

begin_unmounting() {
  $BOOTMODE && return 1;
  ui_print " "
  ui_print "--> Unmounting partitions for fresh install"
  $BB mount -o bind /dev/urandom /dev/random;
  if [ -L /etc ]; then
    setup_mountpoint /etc;
    $BB cp -af /etc_link/* /etc;
    $BB sed -i 's; / ; /system_root ;' /etc/fstab;
  fi;
  umount_all;
}

# Unmount all partitions on recovery clean up and for a fresh install
umount_all() {
  local mount;
  (if [ ! -d /postinstall/tmp ]; then
    ui_print "- Unmounting /system"
    $BB umount /system;
    $BB umount -l /system;
  fi) 2>/dev/null;
  umount_apex;
  (if [ ! -d /postinstall/tmp ]; then
    ui_print "- Unmounting /system_root"
    $BB umount /system_root;
    $BB umount -l /system_root;
  fi;
  ui_print "- Unmounting /vendor"
  umount /vendor; # busybox umount /vendor breaks recovery on some hacky devices
  umount -l /vendor;
  for mount in /mnt/system /mnt/vendor /product /mnt/product /system_ext /mnt/system_ext /persist; do
    addToLog "- Unmounting $mount"
    $BB umount $mount;
    $BB umount -l $mount;
  done;
  if [ "$UMOUNT_DATA" ]; then
    ui_print "- Unmounting /data"
    $BB umount /data;
    $BB umount -l /data;
  fi
  if [ "$UMOUNT_CACHE" ]; then
    $BB umount /cache
    $BB umount -l /cache
  fi) 2>/dev/null;
}

# Unmount apex partition upon recovery cleanup
umount_apex() {
  [ -d /apex ] || return 1;
  local dest loop var;
  for var in $($BB grep -o 'export .* /.*' /system_root/init.environ.rc 2>/dev/null | $BB awk '{ print $2 }'); do
    if [ "$(eval echo \$OLD_$var)" ]; then
      eval $var=\$OLD_${var};
    else
      eval unset $var;
    fi;
    unset OLD_${var};
  done;
  for dest in $($BB find /apex -type d -mindepth 1 -maxdepth 1); do
    loop=$($BB mount | $BB grep $dest | $BB grep loop | $BB cut -d\  -f1);
    $BB umount -l $dest;
    [ "$loop" ] && $BB losetup -d $loop;
  done;
  [ -f /apex/apextmp ] && $BB umount /apex;
  $BB rm -rf /apex 2>/dev/null;
}
