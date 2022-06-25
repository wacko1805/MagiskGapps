#!/sbin/sh

abort() {
  ui_print " "
  ui_print "----------------------------------------------------"
  ui_print "$@"
  ui_print "----------------------------------------------------"
  ui_print " "
  exit_install
  exit 1
}

beginswith() {
  case $2 in
    "$1"*) echo true ;;
    *) echo false ;;
  esac
}

# this is how we can use calc_progress
# index=1
# count=10
# for i in $package_list; do
#     temp_value=$(calc_progress $index/$count)
#     addToLog "- Progress Value=$temp_value"
#     index=`expr $index + 1`
# done
calc_progress() { awk "BEGIN{print $*}" | awk '{print sprintf("%.2f", $1)}'; }

calculate_space_after(){
  addToLog "----------------------------------------------------------------------------"
  addToLog "- calculating space after installing $1"
  size_before=$3
  case "$2" in
    "/product") size_left=$(get_available_size_again "/product");
      addToLog "- product_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
      addSizeToLog "/product" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
    ;;
    "/system_ext") size_left=$(get_available_size_again "/system_ext");
      addToLog "- system_ext_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
      addSizeToLog "/system_ext" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
    ;;
    "/system") size_left=$(get_available_size_again "/system");
      addToLog "- system_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
      addSizeToLog "/system" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
    ;;
    "/system/product")
      if [ -n "$PRODUCT_BLOCK" ]; then
        size_left=$(get_available_size_again "/product");
        addToLog "- product_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
        addSizeToLog "/product" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
      else
        size_left=$(get_available_size_again "/system");
        addToLog "- system_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
        addSizeToLog "/system" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
      fi
    ;;
    "/system/system_ext")
      if [ -n "$SYSTEM_EXT_BLOCK" ]; then
        size_left=$(get_available_size_again "/system_ext");
        addToLog "- system_ext_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
        addSizeToLog "/system_ext" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
      else
        size_left=$(get_available_size_again "/system");
        addToLog "- system_size ($size_before-$size_left) spent=$((size_before-size_left)) vs ($pkg_size)";
        addSizeToLog "/system" "$2" "$1" "$size_before" "$size_left" "$pkg_size" "$((size_before-size_left))"
      fi
    ;;
  esac
  addToLog "----------------------------------------------------------------------------"
  [ -z "$size_left" ] && size_left=0
  echo "$size_left"
}

calculate_space_before(){
  addToLog "----------------------------------------------------------------------------"
  addToLog "- calculating space before installing $1"
  size_left=0
  case "$2" in
    "/product")
      size_left=$(get_available_size_again "/product");
      addToLog "- product_size_left=$size_left" ;;
    "/system_ext")
      size_left=$(get_available_size_again "/system_ext");
      addToLog "- system_ext_size_left=$size_left" ;;
    "/system")
      size_left=$(get_available_size_again "/system");
      addToLog "- system_size_left=$size_left" ;;
    "/system/product")
      if [ -n "$PRODUCT_BLOCK" ]; then
        size_left=$(get_available_size_again "/product"); 
        addToLog "- product_size_left=$size_left";
      else
        size_left=$(get_available_size_again "/system"); 
        addToLog "- system_size_left=$size_left";
      fi
    ;;
    "/system/system_ext")
      if [ -n "$SYSTEM_EXT_BLOCK" ]; then
        size_left=$(get_available_size_again "/system_ext"); addToLog "- system_ext_size_left=$size_left"
      else
        size_left=$(get_available_size_again "/system"); addToLog "- system_size_left=$size_left"
      fi
    ;;
  esac
  addToLog "----------------------------------------------------------------------------"
  [ -z "$size_left" ] && size_left=0
  echo $size_left
}

calculate_space() {
  local partitions="$*"
  for partition in $partitions; do
    addToLog " "
    if ! is_mounted "/$partition"; then
      continue
    fi
    addToLog "--> Calculating space in /$partition"
    # Read and save system partition size details
    df=$(df -k /"$partition" | tail -n 1)
    addToLog "$df"
    case $df in
    /dev/block/*) df=$(echo "$df" | $BB awk '{ print substr($0, index($0,$2)) }') ;;
    esac
    total_system_size_kb=$(echo "$df" | $BB awk '{ print $1 }')
    used_system_size_kb=$(echo "$df" | $BB awk '{ print $2 }')
    free_system_size_kb=$(echo "$df" | $BB awk '{ print $3 }')
    addToLog "- Total System Size (KB) $total_system_size_kb"
    addToLog "- Used System Space (KB) $used_system_size_kb"
    addToLog "- Current Free Space (KB) $free_system_size_kb"
    size_fetched_again=$(get_available_size_again "/$partition")
  done
}

ch_con() {
  chcon -h u:object_r:"${1}"_file:s0 "$2"
  addToLog "- ch_con with ${1} for $2"
}

check_if_partitions_are_mounted_rw() {
  addToLog "- Bootmode: $BOOTMODE"
  $BOOTMODE and return
  addToLog "- Android version: $androidVersion"
  case "$androidVersion" in
    "10")
      system_ext="$product";
      [ ! "$is_system_writable" ] && [ ! "$is_product_writable" ] && abort "- Partitions not writable!"
    ;;
    "1"*)
      [ ! "$is_system_writable" ] && [ ! "$is_product_writable" ] && [ ! "$is_system_ext_writable" ] && abort "- Partitions not writable!"
    ;;
    *)
      product=""; system_ext="";
      [ ! "$is_system_writable" ] && abort "- Partitions not writable!"
    ;;
  esac
}

check_if_system_mounted_rw() {
  is_partition_mounted_flag="false"
  for partition in "system" "product" "system_ext"; do
    is_partition_mounted="$(is_mounted_rw "$partition" 2>/dev/null)"
    if [ "$is_partition_mounted" = "true" ]; then
      ui_print "- /$partition is properly mounted as rw"
      is_partition_mounted_flag="true"
    else
      addToLog "----------------------------------------------------------------------------"
      addToLog "- $partition is not mounted as rw, Installation failed!"
      addToLog "----------------------------------------------------------------------------"
    fi
  done
  [ "$is_partition_mounted_flag" = "false" ] && abort "- System is not mounted as rw, Installation failed!"
}

clean_recursive() {
  folders_that_exists=""
  func_result="$(beginswith / "$1")"
  addToLog "- Deleting $1 with func_result: $func_result"
  if [ "$func_result" = "true" ]; then
    if [ -e "$1" ]; then
       rm -rf "$1"
      folders_that_exists="$folders_that_exists":"$1"
    fi
  else
    for i in $(find "$system" "$product" "$system_ext" -name "$1" 2>/dev/null;); do
      if [ -d "$i" ]; then
        addToLog "- Deleting $i"
         rm -rf "$i"
        folders_that_exists="$folders_that_exists":"$i"
      fi
    done
    # some devices fail to find the folder using above method even when the folder exists
    if [ -z "$folders_that_exists" ]; then
      for sys in "/system" "" "/system_root"; do
        for subsys in "/system" "/product" "/system_ext"; do
          for folder in "/app" "/priv-app"; do
            if [ -d "$sys$subsys$folder/$1" ] && [ "$sys$subsys$folder/" != "$sys$subsys$folder/$1" ]; then
              addToLog "- Hardcoded and Deleting $sys$subsys$folder/$1"
              rm -rf "$sys$subsys$folder/$1"
              folders_that_exists="$folders_that_exists":"$sys$subsys$folder/$1"
            else
              addToLog "- Can't remove $sys$subsys$folder/$1"
            fi
          done
        done
      done
    else
      addToLog "- search finished, $folders_that_exists deleted"
    fi
  fi
  echo "$folders_that_exists"
}

# This is meant to copy the files safely from source to destination
copy_file() {
  if [ -f "$1" ]; then
    mkdir -p "$(dirname "$2")"
    cp -f "$1" "$2"
  else
    addToLog "- File $1 does not exist!"
  fi
}

contains() {
  case $2 in
    *"$1"*) echo true ;;
    *) echo false ;;
  esac
}

get_available_size_again() {
  input_data=$1
  case $1 in
    "/"*) addToLog "- fetching size for $1" ;;
    *) input_data="/$1" ;;
  esac
  tmp_file=$COMMONDIR/available.txt
  available_size=""
  if ! is_mounted "$1"; then
    addToLog "- $1 not mounted!"
  else
    df | grep -vE '^Filesystem|tmpfs|cdrom' | while read output;
    do
      mounted_on=$(echo $output | $BB awk '{ print $5 }' )
      available_size=$(echo $output | $BB awk '{ print $3 }' )
      case $mounted_on in
        *"%"*)
        mounted_on=$(echo $output | $BB awk '{ print $6 }' )
        available_size=$(echo $output | $BB awk '{ print $4 }' )
        ;;
      esac
      if [ "$mounted_on" = "$1" ] || ([ "/system" = "$input_data" ] && [ "$mounted_on" = "/system_root" ]); then
        addToLog "- $input_data($mounted_on) available size: $available_size KB"
        echo $available_size > $tmp_file
        break
      fi
    done
  fi
  [ -f $tmp_file ] && available_size=$(cat $tmp_file)
  rm -rf $tmp_file
  [ -z $available_size ] && available_size=0
  echo $available_size
}

copy_logs() {
  copy_file "$system/build.prop" "$logDir/propfiles/build.prop"
  # Store the size of partitions after installation starts
  df >"$COMMONDIR/size_after.txt"
  df -h >"$COMMONDIR/size_after_readable.txt"
  copy_file "/vendor/etc/fstab.qcom" "$logDir/fstab/fstab.qcom"
  copy_file "/etc/recovery.fstab" "$logDir/fstab/recovery.fstab"
  copy_file "/etc/fstab" "$logDir/fstab/fstab"
  copy_file "$COMMONDIR/size_after.txt" "$logDir/partitions/size_after.txt"
  copy_file "$COMMONDIR/size_after_readable.txt" "$logDir/partitions/size_after_readable.txt"
  ls -alR /system >"$logDir/partitions/System_Files_After.txt"
  ls -alR /product >"$logDir/partitions/Product_Files_After.txt"
  for f in $PROPFILES; do
    copy_file "$f" "$logDir/propfiles/$f"
  done
  for f in $addon_scripts_logDir; do
    copy_file "$f" "$logDir/addonscripts/$f"
  done
  calculate_space "system" "product" "system_ext"
  addToLog "- copying $debloater_config_file_name to log directory"
  copy_file "$debloater_config_file_name" "$logDir/configfiles/debloater.config"
  addToLog "- copying $nikgapps_config_file_name to log directory"
  copy_file "$nikgapps_config_file_name" "$logDir/configfiles/nikgapps.config"
  copy_file "$recoveryLog" "$logDir/logfiles/recovery.log"
  addToLog "- Start Time: $start_time"
  addToLog "- End Time: $(date +%Y_%m_%d_%H_%M_%S)"
  copy_file "$nikGappsLog" "$logDir/logfiles/NikGapps.log"
  copy_file "$busyboxLog" "$logDir/logfiles/busybox.log"
  copy_file "$installation_size_log" "$logDir/logfiles/installation_size.log"
  cd "$logDir" || return
  rm -rf "$nikGappsDir/logs"
  tar -cz -f "$TMPDIR/$nikGappsLogFile" *
  [ -z "$nikgapps_config_dir" ] && nikgapps_config_dir=/sdcard/NikGapps

  # if /userdata is encrypted, installer will copy the logs to system
  backup_logs_dir="$system/etc"
  OLD_IFS="$IFS"
  config_dir_list="$nikGappsDir:$nikgapps_config_dir:$nikgapps_log_dir:$backup_logs_dir"
  IFS=":"
  for dir in $config_dir_list; do
    if [ -d "$dir" ]; then
      archive_dir="$dir/nikgapps_logs_archive"
      mkdir -p "$archive_dir"
      mkdir -p "$dir/nikgapps_logs"
      mv "$dir/nikgapps_logs"/* "$archive_dir"
      copy_file "$TMPDIR/$nikGappsLogFile" "$dir/nikgapps_logs/$nikGappsLogFile"
    else
      ui_print "- $dir/nikgapps_logs not a directory"
    fi
  done
  IFS="$OLD_IFS"

  if [ -f "$nikgapps_log_dir/$nikGappsLogFile" ]; then
    ui_print "- Copying Logs at $nikgapps_log_dir/$nikGappsLogFile"
  elif [ -f "$nikgapps_config_dir/nikgapps_logs/$nikGappsLogFile" ]; then
    ui_print "- Copying Logs at $nikgapps_config_dir/nikgapps_logs/$nikGappsLogFile"
  elif [ -f "$nikGappsDir/nikgapps_logs/$nikGappsLogFile" ]; then
    ui_print "- Copying Logs at $nikGappsDir/nikgapps_logs/$nikGappsLogFile"
  else
    if [ -f "$backup_logs_dir/nikgapps_logs/$nikGappsLogFile" ]; then
      ui_print "- Copying Logs at $backup_logs_dir/nikgapps_logs/$nikGappsLogFile"
    else
      ui_print "- Couldn't copy logs, something went wrong!"
    fi
  fi
  
  ui_print " "
  cd /
}

debloat() {
  debloaterFilesPath="DebloaterFiles"
  debloaterRan=0
  if [ -f "$debloater_config_file_name" ]; then
    addToLog "- Debloater.config found!"
    g=$(sed -e '/^[[:blank:]]*#/d;s/[\t\n\r ]//g;/^$/d' "$debloater_config_file_name")
    for i in $g; do
      if [ $debloaterRan = 0 ]; then
        ui_print " "
        ui_print "--> Starting the debloating process"
      fi
      value=$($i | grep "^WipeDalvikCache=" | cut -d'=' -f 1)
      if [ "$i" != "WipeDalvikCache" ]; then
        addToLog "- Deleting $i"
        if [ -z "$i" ]; then
          ui_print "Cannot delete blank folder!"
        else
          debloaterRan=1
          startswith=$(beginswith / "$i")
          ui_print "x Removing $i"
          if [ "$startswith" = "false" ]; then
            addToLog "- value of i is $i"
            debloated_folders=$(clean_recursive "$i")
            if [ -n "$debloated_folders" ]; then
              addToLog "- Removed folders: $debloated_folders"
              OLD_IFS="$IFS"
              IFS=":"
              for j in $debloated_folders; do
                if [ -n "$j" ]; then
                  debloatPath=$(echo "$j" | sed "s|^$system/||")
                  if grep -q "debloat=$debloatPath" "$TMPDIR/addon/$debloaterFilesPath"; then
                    addToLog "- $debloatPath debloated already"
                  else
                    echo "debloat=$debloatPath" >>$TMPDIR/addon/$debloaterFilesPath
                    addToLog "- debloat=$debloatPath >> $TMPDIR/addon/$debloaterFilesPath"
                  fi
                fi
              done
              IFS="$OLD_IFS"
            else
              addToLog "- No $i folders to debloat"
            fi
          else
            rmv "$i"
            debloatPath=$(echo "$i" | sed "s|^$system/||")
            if grep -q "debloat=$debloatPath" "$TMPDIR/addon/$debloaterFilesPath"; then
              addToLog "- $debloatPath debloated already"
            else
              echo "debloat=$debloatPath" >>$TMPDIR/addon/$debloaterFilesPath
              addToLog "- debloat=$debloatPath >> $TMPDIR/addon/$debloaterFilesPath"
            fi
          fi
        fi
      else
        addToLog "- WipeDalvikCache config found!"
      fi
    done
    if [ $debloaterRan = 1 ]; then
      . $COMMONDIR/addon "$OFD" "Debloater" "" "" "$TMPDIR/addon/$debloaterFilesPath" ""
      copy_file "$system/addon.d/51-Debloater.sh" "$logDir/addonscripts/51-Debloater.sh"
      copy_file "$TMPDIR/addon/$debloaterFilesPath" "$logDir/addonfiles/Debloater.addon"
      rmv "$TMPDIR/addon/$debloaterFilesPath"
    fi
  else
    addToLog "- Debloater.config not found!"
    unpack "afzc/debloater.config" "/sdcard/NikGapps/debloater.config"
  fi
  if [ $debloaterRan = 1 ]; then
    ui_print " "
  fi
}

delete_package() {
  deleted_folders=$(clean_recursive "$1")
  addToLog "- Deleted $deleted_folders as part of package $1"
}

delete_package_data() {
  addToLog "- Deleting data of package $1"
  rm -rf "/data/data/${1}*"
}

delete_recursive() {
  rm -rf "$*"
}

extract_file() {
  mkdir -p "$(dirname "$3")"
  addToLog "- Unzipping $1"
  addToLog "  -> copying $2"
  addToLog "  -> to $3"
  $BB unzip -o "$1" "$2" -p >"$3"
}

exit_install() {
  ui_print " "
  wipedalvik=$(ReadConfigValue "WipeDalvikCache" "$nikgapps_config_file_name")
  addToLog "- WipeDalvikCache value: $wipedalvik"
  if [ "$wipedalvik" != 0 ]; then
    ui_print "- Wiping dalvik-cache"
    rm -rf "/data/dalvik-cache"
  fi
  ui_print "- Finished Installation"
  ui_print " "
  copy_logs
  restore_env
}

find_block() {
  local name="$1"
  local fstab_entry=$(get_block_for_mount_point "/$name")
  # P-SAR hacks
  [ -z "$fstab_entry" ] && [ "$name" = "system" ] && fstab_entry=$(get_block_for_mount_point "/")
  [ -z "$fstab_entry" ] && [ "$name" = "system" ] && fstab_entry=$(get_block_for_mount_point "/system_root")

  local dev
  if [ "$dynamic_partitions" = "true" ]; then
    if [ -n "$fstab_entry" ]; then
      dev="${BLK_PATH}/${fstab_entry}${SLOT_SUFFIX}"
    else
      dev="${BLK_PATH}/${name}${SLOT_SUFFIX}"
    fi
  else
    if [ -n "$fstab_entry" ]; then
      dev="${fstab_entry}${SLOT_SUFFIX}"
    else
      dev="${BLK_PATH}/${name}${SLOT_SUFFIX}"
    fi
  fi
  addToLog "- checking if $dev is block"
  if [ -b "$dev" ]; then
    addToLog "- Block Dev: $dev"
    echo "$dev"
  fi
}

find_config_path() {
  local config_dir_list="/tmp:$TMPDIR:$ZIPDIR:/sdcard1:/sdcard1/NikGapps:/sdcard:/sdcard/NikGapps:/storage/emulated:/storage/emulated/NikGapps:$COMMONDIR"
  local IFS=':'
  for location in $config_dir_list; do
    if [ -f "$location/$1" ]; then
      echo "$location/$1"
      return
    fi
  done
}

find_config() {
  mkdir -p "$nikGappsDir"
  mkdir -p "$addonDir"
  mkdir -p "$logDir"
  mkdir -p "$addon_scripts_logDir"
  mkdir -p "$TMPDIR/addon"
  ui_print " "
  ui_print "--> Finding config files"
  nikgapps_config_file_name="$nikGappsDir/nikgapps.config"
  unpack "afzc/nikgapps.config" "$COMMONDIR/nikgapps.config"
  unpack "afzc/debloater.config" "$COMMONDIR/debloater.config"
  use_zip_config=$(ReadConfigValue "use_zip_config" "$COMMONDIR/nikgapps.config")
  addToLog "- use_zip_config=$use_zip_config"
  if [ "$use_zip_config" = "1" ]; then
    ui_print "- Using config file from the zip"
    nikgapps_config_file_name="$COMMONDIR/nikgapps.config"
    debloater_config_file_name="$COMMONDIR/debloater.config"
  else
    found_config="$(find_config_path nikgapps.config)"
    if [ "$found_config" ]; then
      nikgapps_config_file_name="$found_config"
      addToLog "- Found custom location of nikgapps.config"
      copy_file "$found_config" "$nikGappsDir/nikgapps.config"
    fi
    nikgapps_config_dir=$(dirname "$nikgapps_config_file_name")
    debloater_config_file_name="/sdcard/NikGapps/debloater.config"
    found_config="$(find_config_path debloater.config)"
    if [ "$found_config" ]; then
      debloater_config_file_name="$found_config"
      addToLog "- Found custom location of debloater.config"
      copy_file "$found_config" "$nikGappsDir/debloater.config"
    fi
    nikgappsConfig="$sdcard/NikGapps/nikgapps.config"
    debloaterConfig="$sdcard/NikGapps/debloater.config"
    if [ ! -f $nikgappsConfig ]; then
      unpack "afzc/nikgapps.config" "/sdcard/NikGapps/nikgapps.config"
      [ ! -f "/sdcard/NikGapps/nikgapps.config" ] && unpack "afzc/nikgapps.config" "/storage/emulated/NikGapps/nikgapps.config"
      addToLog "nikgapps.config is copied to $nikgappsConfig"
    fi
    if [ ! -f $debloaterConfig ]; then
      unpack "afzc/debloater.config" "$COMMONDIR/debloater.config"
      unpack "afzc/debloater.config" "/sdcard/NikGapps/debloater.config"
      [ ! -f "/sdcard/NikGapps/debloater.config" ] && unpack "afzc/debloater.config" "/storage/emulated/NikGapps/debloater.config"
      addToLog "debloater.config is copied to $debloaterConfig"
    fi
  fi

  test "$zip_type" != "debloater" && ui_print "- nikgapps.config used from $nikgapps_config_file_name"
  test "$zip_type" = "debloater" && ui_print "- debloater.config used from $debloater_config_file_name"
}

find_device_block() {
  device_ab=$(getprop ro.build.ab_update 2>/dev/null)
  dynamic_partitions=$(getprop ro.boot.dynamic_partitions)
  [ -z "$dynamic_partitions" ] && dynamic_partitions="false"
  addToLog "- variable dynamic_partitions = $dynamic_partitions"
  BLK_PATH=/dev/block/bootdevice/by-name
  if [ -d /dev/block/mapper ]; then
    dynamic_partitions="true"
    BLK_PATH="/dev/block/mapper"
    addToLog "- Directory method! Device with dynamic partitions Found"
  else
    addToLog "- Device doesn't have dynamic partitions"
  fi


  SLOT=$(find_slot)
  if [ -n "$SLOT" ]; then
    if [ "$SLOT" = "_a" ]; then
      SLOT_SUFFIX="_a"
    else
      SLOT_SUFFIX="_b"
    fi
  fi
}

find_gapps_size() {
  file_value=$(cat $COMMONDIR/file_size)
  for i in $file_value; do
    install_pkg_title=$(echo "$i" | cut -d'=' -f 1)
    install_pkg_size=$(echo "$i" | cut -d'=' -f 2)
    if [ -f "$nikgapps_config_file_name" ]; then
      value=$(ReadConfigValue ">>$install_pkg_title" "$nikgapps_config_file_name")
      [ -z "$value" ] && value=$(ReadConfigValue "$install_pkg_title" "$nikgapps_config_file_name")
      [ "$value" != "0" ] && value=1
    else
      abort "NikGapps Config not found!"
    fi
    if [ "$value" = "1" ]; then
      gapps_size=$((gapps_size+install_pkg_size))
    fi
  done
  if [ "$zip_type" = "addon" ]; then
    ui_print "- Addon Size: $gapps_size KB"
  elif [ "$zip_type" = "gapps" ]; then
    ui_print "- Gapps Size: $gapps_size KB"
  elif [ "$zip_type" = "sideload" ]; then
    ui_print "- Package Size: $gapps_size KB"
  fi
}

find_install_mode() {
  if [ "$clean_flash_only" = "true" ] && [ "$install_type" = "dirty" ]; then
    prop_file_exists="false"
    for i in "$system/etc/permissions" "$system/product/etc/permissions" "$system/system_ext/etc/permissions"; do
      if [ -f "$i/$package_title.prop" ]; then
        addToLog "- Found $i/$package_title.prop"
        prop_file_exists="true"
        break
      fi
    done
    if [ "$prop_file_exists" = "false" ]; then
      test "$zip_type" = "gapps" && ui_print "- Can't dirty flash $package_title" && return
      test "$zip_type" = "addon" && abort "- Can't dirty flash $package_title, please clean flash!"
    fi
  fi
  addToLog "----------------------------------------------------------------------------"
  ui_print "- Installing $package_title"
  install_package
  delete_recursive "$pkgFile"  
}

find_install_type() {
  install_type="clean"
  for i in $(find /data -iname "runtime-permissions.xml" 2>/dev/null;); do
    if [ -e "$i" ]; then
      install_type="dirty"
      value=$(ReadConfigValue "WipeRuntimePermissions" "$nikgapps_config_file_name")
      [ -z "$value" ] && value=0
      addToLog "- runtime-permissions.xml found at $i with wipe permission $value"
      if [ "$value" = "1" ]; then
        rm -rf "$i"
      fi
    fi;
  done
  ui_print "- Install Type is $install_type"
}

find_install_partition() {
  addToLog "- default_partition=$1"
  install_partition="/system/product"
  # if partition doesn't exist or it is not mounted as rw, moving to secondary partition
  case $1 in
    "system_ext")
      [ -n "$SYSTEM_EXT_BLOCK" ] && [ $system_ext_size = 0 ] && system_ext=""
      if [ -z "$system_ext" ]; then
        [ -n "$product" ] && [ -n "$PRODUCT_BLOCK" ] && [ $product_size = 0 ] && product=""
        system_ext=$product
        if [ -z "$product" ]; then
          addToLog "- \$product is empty, hence installing it in $system"
          system_ext=$system
        fi
      fi
      install_partition=$system_ext
    ;;
    "product")
      [ -n "$product" ] && [ -n "$PRODUCT_BLOCK" ] && [ $product_size = 0 ] && product=""
      if [ -z "$product" ]; then
        addToLog "- \$product is empty, hence installing it in $system"
        product=$system
      fi
      install_partition=$product
    ;;
  esac
  if [ -f "$nikgapps_config_file_name" ]; then
    case "$install_partition_val" in
      "default") addToLog "- InstallPartition is default" ;;
      "system") install_partition=$system ;;
      "product") install_partition=$product ;;
      "system_ext") install_partition=$system_ext ;;
      "data") install_partition="/data/extra" ;;
      /*) install_partition=$install_partition_val ;;
    esac
    addToLog "- InstallPartition = $install_partition"
  else
    addToLog "- nikgapps.config file doesn't exist!"
  fi
  echo "$install_partition"
}

find_log_directory() {
  value=$(ReadConfigValue "LogDirectory" "$nikgapps_config_file_name")
  addToLog "- LogDirectory=$value"
  [ "$value" = "default" ] && value="$nikGappsDir"
  [ -z "$value" ] && value="$nikGappsDir"
  nikgapps_log_dir="$value"
}

find_partitions_type() {
  addToLog "- Finding partition type for /system"
  SYSTEM_BLOCK=$(find_block "system")
  [ -n "$SYSTEM_BLOCK" ] && addToLog "- Found block for /system"
  system="/system"
  system_size=$(get_available_size_again "/system")
  [ "$system_size" != "0" ] && ui_print "- /system is mounted as dedicated partition"
  is_system_writable="$(is_mounted_rw "$system" 2>/dev/null)"
  [ ! "$is_system_writable" ] && system=""
  addToLog "- system=$system is writable? $is_system_writable"
  [ -f "/system/build.prop" ] && addToLog "- /system/build.prop exists"

  for partition in "product" "system_ext"; do
    addToLog "----------------------------------------------------------------------------"
    addToLog "- Finding partition type for /$partition"
    mnt_point="/$partition"
    already_mounted=false
    already_symlinked=false
    mountpoint "$mnt_point" >/dev/null 2>&1 && already_mounted=true && addToLog "- $mnt_point already mounted!"
    [ -L "$system$mnt_point" ] && already_symlinked=true && addToLog "- $system$mnt_point symlinked!"
    case "$partition" in
      "product")
        # set the partition default to /system/$partition
        product="$system/product"
        product_size=0
        PRODUCT_BLOCK=$(find_block "$partition")
        # if block exists, set the partition to /$partition and get it's size
        if [ -n "$PRODUCT_BLOCK" ]; then
          addToLog "- Found block for $mnt_point"
          product="/product"
          product_size=$(get_available_size_again "/product")
          ui_print "- /$partition is a dedicated partition"
        else
          addToLog "- /$partition block not found in this device"
        fi
        # check if partition is symlinked, if it is, set the partition back to /system/$partition
        if [ -L "$system$mnt_point" ]; then
          addToLog "- $system$mnt_point symlinked!"
          product=$system$mnt_point
          ui_print "- /$partition is symlinked to $system$mnt_point"
        fi
        # check if the partitions are writable
        is_product_writable="$(is_mounted_rw "$product" 2>/dev/null)"
        [ ! "$is_product_writable" ] && product=""
        addToLog "- product=$product is writable? $is_product_writable"
      ;;
      "system_ext")
        # set the partition default to /system/$partition
        system_ext="$system/system_ext"
        system_ext_size=0
        SYSTEM_EXT_BLOCK=$(find_block "$partition")
        # if block exists, set the partition to /$partition and get it's size
        if [ -n "$SYSTEM_EXT_BLOCK" ]; then
          addToLog "- Found block for $mnt_point"
          system_ext="/system_ext"
          system_ext_size=$(get_available_size_again "/system_ext")
          ui_print "- /$partition is a dedicated partition"
        else
          addToLog "- /$partition block not found in this device"
        fi
        # check if partition is symlinked, if it is, set the partition back to /system/$partition
        if [ -L "$system$mnt_point" ]; then
          addToLog "- $system$mnt_point symlinked!"
          system_ext=$system$mnt_point
          ui_print "- /$partition is symlinked to $system$mnt_point"
        fi
        # check if the partitions are writable
        is_system_ext_writable="$(is_mounted_rw "$system_ext" 2>/dev/null)"
        [ ! "$is_system_ext_writable" ] && system_ext=""
        addToLog "- system_ext=$system_ext is writable? $is_system_ext_writable"
      ;;
    esac
  done
  # calculate gapps space and check if default partition has space
  # set a secondary partition to install if the space runs out
}

find_product_prefix() {
  case "$1" in
    *"/product") product_prefix="product/" ;;
    *"/system_ext") product_prefix="system_ext/" ;;
    *) product_prefix="" ;;
  esac
  addToLog "- product_prefix=$product_prefix"
  echo "$product_prefix"
}

find_slot() {
  slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  test "$slot" || slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
  if [ ! "$slot" ]; then
    slot=$(getprop ro.boot.slot 2>/dev/null)
    test "$slot" || slot=$(grep -o 'androidboot.slot=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
    test "$slot" && slot=_$slot
  fi
  test "$slot" && echo "$slot"
}

find_system_size() {
  ui_print " "
  ui_print "--> Fetching system size"
  [ "$system_size" != "0" ] && ui_print "- /system available size: $system_size KB"
  [ "$product_size" != "0" ] && ui_print "- /product available size: $product_size KB"
  [ "$system_ext_size" != "0" ] && ui_print "- /system_ext available size: $system_ext_size KB"
  total_size=$((system_size+product_size+system_ext_size))
  ui_print "- Total available size: $total_size KB"
  [ "$total_size" = "0" ] && addToLog "- No space left on device"
  [ "$total_size" = "0" ] && ui_print "- Unable to find space"
}

find_zip_type() {
  addToLog "- Finding zip type"
  if [ "$(contains "-arm64-" "$actual_file_name")" = "true" ]; then
    zip_type="gapps"
  elif [ "$(contains "Debloater" "$actual_file_name")" = "true" ]; then
    zip_type="debloater"
  elif [ "$(contains "Addon" "$actual_file_name")" = "true" ]; then
    zip_type="addon"
  elif [ "$(contains "package" "$actual_file_name")" = "true" ]; then
    zip_type="sideload"
  else
    zip_type="unknown"
  fi
  sideloading=false
  if [ "$(contains "package" "$ZIPNAME")" = "true" ]; then
    sideloading=true
  fi
  addToLog "- Zip Type is $zip_type"
  addToLog "- Sideloading is $sideloading"
}

get_available_size() {
    df=$(df -k /"$1" | tail -n 1)
    case $df in
        /dev/block/*) df=$(echo "$df" | awk '{ print substr($0, index($0,$2)) }');;
    esac
    free_size_kb=$(echo "$df" | awk '{ print $3 }')
    size_of_partition=$(echo "$df" | awk '{ print $5 }')
    addToLog "- free_size_kb: $free_size_kb for $size_of_partition which should be $1"
    [ "$free_size_kb" = "Used" ] && free_size_kb=0
    echo "$free_size_kb"
}

get_block_for_mount_point() {
  grep -v "^#" /etc/recovery.fstab | grep "[[:blank:]]$1[[:blank:]]" | tail -n1 | tr -s [:blank:] ' ' | cut -d' ' -f1
}

get_file_prop() {
  grep -m1 "^$2=" "$1" | cut -d= -f2
}

get_install_partition(){
  chain_partition=$2
  size_required=$3
  case $1 in
    system)
      install_partition="" 
      addToLog "- fetch the system size to check if it's enough"
      system_available_size=$(get_available_size_again "/system")
      if [ $system_available_size -gt $size_required ]; then
        addToLog "- it's big enough"
        install_partition="$system"
      else
        addToLog "- check if chain_partition contains -system"
        if [ "$(contains "-system" "$chain_partition")" = "true" ]; then
          addToLog "- we've reached a complete loop, no space available now"
          install_partition="-1"
        else
          addToLog "- system is too big, let's try the system_ext (which will loop through product and system to confirm no partitions are big enough)"
          if [ -n "$SYSTEM_EXT_BLOCK" ] || [ -n "$PRODUCT_BLOCK" ]; then
            install_partition="$(get_install_partition system_ext system_ext-$chain_partition $size_required)"
          else
            addToLog "- no space available"
            install_partition="-1"
          fi
        fi
      fi
    ;;
    product)
      install_partition="" 
      addToLog "- if product is a block, we will check if it's big enough"
      if [ -n "$PRODUCT_BLOCK" ]; then
        product_available_size=$(get_available_size_again "/product")
        if [ $product_available_size -gt $size_required ]; then
          addToLog "- it's big enough, we'll use it"
          install_partition="$product"
        else
          addToLog "- check if chain_partition ends with -product"
          if [ "$(contains "-product" "$chain_partition")" = "true" ]; then
            addToLog "- we've reached a complete loop, no space available now"
            install_partition="-1"
          else
            addToLog "- it's not, we'll try system"
            install_partition="$(get_install_partition system system-$chain_partition $size_required)"
          fi
        fi
      else
        addToLog "- product is not a block, we'll try system and install to /system/product as it will take up system space"
        system_available_size=$(get_available_size_again "/system")
        if [ $system_available_size -gt $size_required ]; then
          addToLog "- system is big enough, we'll use it"
          install_partition="/system/product"
        else
          addToLog "- if product is not a block and system is not big enough, we're out of options"
          install_partition="-1"
        fi
      fi
    ;;
    system_ext) 
      install_partition=""
      addToLog "- if system_ext is a block, we will check if it's big enough"
      if [ -n "$SYSTEM_EXT_BLOCK" ]; then
        system_ext_available_size=$(get_available_size_again "/system_ext")
        if [ $system_ext_available_size -gt $size_required ]; then
          addToLog "- it's big enough, we'll use it"
          install_partition="$system_ext"
        else
          addToLog "- check if chain_partition ends with -system_ext"
          if [ "$(contains "-system_ext" "$chain_partition")" = "true" ]; then
            addToLog "- we've reached a complete loop, no space available now"
            install_partition="-1"
          else
            install_partition="$(get_install_partition product product-$chain_partition $size_required)"
          fi
        fi
      else
        addToLog "- system_ext isn't a block, we'll try product and see if it has space"
        if [ -n "$PRODUCT_BLOCK" ]; then
          install_partition="$(get_install_partition product product-$chain_partition $size_required)"
        else
          addToLog "- product isn't a block, we'll try system and see if it has space"
          system_available_size=$(get_available_size_again "/system")
          if [ $system_available_size -gt $size_required ]; then
            addToLog "- system is big enough, we'll use it"
            install_partition="$system_ext"
          else
            addToLog "- if system_ext is not a block and system is not big enough, we're out of options"
            install_partition="-1"
          fi
        fi
      fi
    ;;
  esac
  if [ -f "$nikgapps_config_file_name" ]; then
    case "$install_partition_val" in
      "default") addToLog "- InstallPartition is default" ;;
      "system") install_partition=$system ;;
      "product") install_partition=$product ;;
      "system_ext") install_partition=$system_ext ;;
      "data") install_partition="/data/extra" ;;
      /*) install_partition=$install_partition_val ;;
    esac
    addToLog "- InstallPartition = $install_partition"
  else
    addToLog "- nikgapps.config file doesn't exist!"
  fi
  echo "$install_partition"
}

get_package_progress(){
  for i in $ProgressBarValues; do
      if [ $(echo $i | cut -d'=' -f1) = "$1" ]; then
          echo $i | cut -d'=' -f2
          return
      fi
  done
  echo 0
}

get_prop() {
  local propdir propfile propval
  for propdir in /system /vendor /odm /product /system/product /system/system_ext /system_root /; do
    for propfile in build.prop default.prop; do
      test "$propval" && break 2 || propval="$(get_file_prop $propdir/$propfile "$1" 2>/dev/null)"
    done
  done
  addToLog "- propvalue $1 = $propval"
  # if propval is no longer empty output current result; otherwise try to use recovery's built-in getprop method
  [ -z "$propval" ] && propval=$(getprop "$1")
  addToLog "- Recovery getprop used $1=$propval"
  test "$propval" && echo "$propval" || echo ""
}

get_total_available_size(){
  system_available_size=0
  product_available_size=0
  system_ext_available_size=0
  # system would always be block
  system_available_size=$(get_available_size_again "/system")
  [ -n "$SYSTEM_EXT_BLOCK" ] && system_ext_available_size=$(get_available_size_again "/system_ext")
  [ -n "$PRODUCT_BLOCK" ] && product_available_size=$(get_available_size_again "/product")
  addToLog "- total_available_size=$system_available_size + $product_available_size + $system_ext_available_size"
  total_available_size=$(($system_available_size + $product_available_size + $system_ext_available_size))
  addToLog "- total available size = $total_available_size"
  echo "$total_available_size"
}

install_app_set() {
  appset_name="$1"
  value=1
  if [ -f "$nikgapps_config_file_name" ]; then
    value=$(ReadConfigValue "$appset_name" "$nikgapps_config_file_name")
    if [ "$value" = "" ]; then
      value=1
    fi
  fi
  addToLog " "
  addToLog "- Current Appset=$appset_name, value=$value"
  if [ "$value" -eq 0 ]; then
    ui_print "x Skipping $appset_name"
  elif [ "$value" -eq -1 ]; then
    addToLog "- $appset_name is disabled"
    for i in "$2"; do
      current_package_title=$(echo $i | cut -d',' -f1)
      uninstall_the_package "$appset_name" "$current_package_title"
    done
  else
    package_list="$2"
    total_size_required=0
    for i in $package_list; do
      package_size=$(echo $i | cut -d',' -f2)
      total_size_required=$((total_size_required + package_size))
    done
    total_available_size=$(get_total_available_size)
    addToLog "- total size required by $appset_name = $total_size_required"
    if [ $total_size_required -gt $total_available_size ]; then
      ui_print "x Skipping $appset_name due to insufficient space"
      return
    fi
    for i in $package_list; do
      current_package_title=$(echo $i | cut -d',' -f1)
      addToLog " "
      addToLog "----------------------------------------------------------------------------"
      addToLog "- Working for $current_package_title"
      value=1
      if [ -f "$nikgapps_config_file_name" ]; then
        value=$(ReadConfigValue ">>$current_package_title" "$nikgapps_config_file_name")
        [ -z "$value" ] && value=$(ReadConfigValue "$current_package_title" "$nikgapps_config_file_name")
      fi
      [ -z "$value" ] && value=1
      addToLog "- Config Value is $value"
      if [ "$mode" = "uninstall" ]; then
        if [ "$value" -eq -1 ] ; then
          uninstall_the_package "$appset_name" "$current_package_title"
        fi
      elif [ "$mode" = "install" ]; then
        addToLog "- Config Value of $i is $value"
        if [ "$value" -ge 1 ] ; then
          package_size=$(echo $i | cut -d',' -f2)
          addToLog "- package_size = $package_size"
          default_partition=$(echo $i | cut -d',' -f3)
          addToLog "- default_partition = $default_partition"
          case "$default_partition" in
            "system_ext") 
            [ $androidVersion -le 10 ] && default_partition=product && addToLog "- default_partition is overridden"
            ;;
          esac
          install_partition=$(get_install_partition "$default_partition" "$default_partition" "$package_size")
          addToLog "- $current_package_title required size: $package_size Kb, installing to $install_partition ($default_partition)"
          if [ "$install_partition" != "-1" ]; then
            size_before=$(calculate_space_before "$current_package_title" "$install_partition")
            install_the_package "$appset_name" "$i" "$current_package_title" "$value" "$install_partition"
            size_after=$(calculate_space_after "$current_package_title" "$install_partition" "$size_before")
          else
            ui_print "x Skipping $current_package_title as no space is left"
          fi
        elif [ "$value" -eq -1 ] ; then
          addToLog "- uninstalling $current_package_title"
          uninstall_the_package "$appset_name" "$current_package_title"
        elif [ "$value" -eq 0 ] ; then
          ui_print "x Skipping $current_package_title"
        fi
      elif [ "$mode" = "uninstall_by_name" ]; then
        for i in "$2"; do
          uninstall_the_package "$appset_name" "$current_package_title"
        done
      else
        abort "- Unknown mode $mode"
      fi
    done
  fi
}

install_the_package() {
  extn="zip"
  appset_name="$1"
  default_partition=$(echo $2 | cut -d',' -f3)
  package_name="$3"
  config_value="$4"
  install_partition="$5"
  addToLog "- Install_Partition=$install_partition"
  pkgFile="$TMPDIR/$package_name.zip"
  pkgContent="pkgContent"
  unpack "AppSet/$1/$package_name.$extn" "$pkgFile"
  extract_file "$pkgFile" "installer.sh" "$TMPDIR/$pkgContent/installer.sh"
  chmod 755 "$TMPDIR/$pkgContent/installer.sh"
  # shellcheck source=src/installer.sh
  . "$TMPDIR/$pkgContent/installer.sh" "$config_value" "$nikgapps_config_file_name" "$install_partition"
  
  set_progress $(get_package_progress "$package_name")
}

install_file() {
  if [ "$mode" != "uninstall" ]; then
    # $1 will start with ___ which needs to be skipped so replacing it with blank value
    blank=""
    file_location=$(echo "$1" | sed "s/___/$blank/" | sed "s/___/\//g")
    # install_location is dynamic location where package would be installed (usually /system, /system/product)
    install_location="$install_partition/$file_location"
    # Make sure the directory exists, if not, copying the file would fail
    mkdir -p "$(dirname "$install_location")"
    set_perm 0 0 0755 "$(dirname "$install_location")"
    # unpacking of package
    addToLog "- Unzipping $pkgFile"
    addToLog "  -> copying $1"
    addToLog "  -> to $install_location"
    $BB unzip -o "$pkgFile" "$1" -p >"$install_location"
    # post unpack operations
    if [ -f "$install_location" ]; then
      addToLog "- File Successfully Written!"
      # It's important to set selinux policy
      case $install_location in
      *) ch_con system "$install_location" ;;
      esac
      set_perm 0 0 0644 "$install_location"
      # Addon stuff!
      case "$install_partition" in
          *"/product") installPath="product/$file_location" ;;
          *"/system_ext") installPath="system_ext/$file_location" ;;
          *) installPath="$file_location" ;;
      esac
      addToLog "- InstallPath=$installPath"
      echo "install=$installPath" >>"$TMPDIR/addon/$packagePath"
    else
      ui_print "- Failed to write $install_location"
      ui_print " "
      find_system_size
      abort "Installation Failed! Looks like Storage space is full!"
    fi
  fi
}

is_on_top_of_nikgapps() {
  nikgapps_present=false
  # shellcheck disable=SC2143
  if [ "$(grep 'allow-in-power-save package=\"com.mgoogle.android.gms\"' "$system"/etc/sysconfig/*.xml)" ] ||
        [ "$(grep 'allow-in-power-save package=\"com.mgoogle.android.gms\"' "$system"/product/etc/sysconfig/*.xml)" ]; then
    nikgapps_present=true
  fi
  addToLog "- Is on top of NikGapps: $nikgapps_present"
  if [ "$nikgapps_present" != "true" ]; then
    abort "This Addon can only be flashed on top of NikGapps"
  fi
}

# Check if the partition is mounted
is_mounted() {
  addToLog "- Checking if $1 is mounted"
  $BB mount | $BB grep -q " $1 ";
}

mount_system_source() {
  local system_source
  system_source=$(grep ' /system ' /etc/fstab | tail -n1 | cut -d' ' -f1)
  if [ -z "${system_source}" ]; then
    system_source=$(grep ' /system_root ' /etc/fstab | tail -n1 | cut -d' ' -f1)
  fi
  if [ -z "${system_source}" ]; then
    system_source=$(grep ' / ' /etc/fstab | tail -n1 | cut -d' ' -f1)
  fi
  addToLog "- system source is ${system_source}"
  addToLog "- fstab source is /etc/fstab"
  echo "${system_source}"
}

# Read the config file from (Thanks to xXx @xda)
ReadConfigValue() {
  value=$(sed -e '/^[[:blank:]]*#/d;s/[\t\n\r ]//g;/^$/d' "$2" | grep "^$1=" | cut -d'=' -f 2)
  echo "$value"
  return $?
}

RemoveAospAppsFromRom() {
  addToLog "- Removing AOSP App from Rom"
  if [ "$configValue" -eq 2 ]; then
    addToLog "- Not creating addon.d script for $*"
  else
    deleted_folders=$(clean_recursive "$1")
    if [ -n "$deleted_folders" ]; then
      addToLog "- Removed folders: $deleted_folders"
      OLD_IFS="$IFS"
      IFS=":"
      for i in $deleted_folders; do
        if [ -n "$i" ]; then
          deletePath=$(echo "$i" | sed "s|^$system/||")
          if [ -f "$2" ] && [ grep -q "delete=$deletePath" "$2" ]; then
            addToLog "- $deletePath deleted already"
          else
            echo "delete=$deletePath" >>$2
            addToLog "- DeletePath=$deletePath >> $2"
          fi
        fi
      done
      IFS="$OLD_IFS"
    else
      addToLog "- No $1 folders to remove"
    fi
  fi
}

rmv() {
  addToLog "- Removing $1"
  rm -rf "$1"
}

set_perm() {
  chown "$1:$2" "$4"
  chmod "$3" "$4"
}

set_prop() {
  property="$1"
  value="$2"
  test -z "$3" && file_location="${install_partition}/build.prop" || file_location="$3"
  test ! -f "$file_location" && touch "$file_location" && set_perm 0 0 0600 "$file_location"
  addToLog "- Setting Property ${1} to ${2} in ${file_location}"
  if grep -q "${property}" "${file_location}"; then
    addToLog "- Updating ${property} to ${value} in ${file_location}"
    sed -i "s/\(${property}\)=.*/\1=${value}/g" "${file_location}"
  else
    addToLog "- Adding ${property} to ${value} in ${file_location}"
    echo "${property}=${value}" >>"${file_location}"
  fi
}

show_device_info() {
  ui_print " "
  ui_print "--> Fetching Device Information"
  mount_system_source
  sdkVersion=$(get_prop "ro.build.version.sdk")
  androidVersion=$(get_prop "ro.build.version.release")
  model=$(get_prop "ro.product.system.model")
  series=$(get_prop "ro.display.series")
  # Device details
  for field in ro.product.device ro.build.product ro.product.name ro.product.model; do
    device_name="$(get_prop "$field")"
    addToLog "- Field Name: $field"
    addToLog "- Device name: $device_name"
    if [ "${#device_name}" -ge "2" ]; then
      break
    fi
  done
  device=$(get_file_prop "$system/build.prop" "ro.product.system.device")
  if [ -z "$device" ]; then
    addToLog "- Device code not found!"
    device=$device_name
    if [ -z "$device" ]; then
      abort "NikGapps not supported for your device yet!"
    fi
  fi
  ui_print "- SDK Version: $sdkVersion"
  ui_print "- Android Version: $androidVersion"
  addToLog "- Series: $series"
  [ -n "$model" ] && ui_print "- Device: $model"
  [ -z "$model" ] && ui_print "- Device: $device"
  [ -z "$SLOT" ] || ui_print "- Current boot slot: $SLOT"
  if [ "$device_ab" = "true" ]; then
    ui_print "- A/B Device Found"
  else
    ui_print "- A-Only Device Found"
  fi
  addToLog "- Dynamic Partitions is $dynamic_partitions"
  if [ "$dynamic_partitions" = "true" ]; then
    ui_print "- Device has Dynamic Partitions"
  else
    addToLog "- Devices doesn't have Dynamic Partitions"
  fi
  addToLog "- Block Path = $BLK_PATH"
}

# Setting up mount point
setup_mountpoint() {
  addToLog "- Setting up mount point $1 before actual mount"
  test -L "$1" && $BB mv -f "$1" "${1}"_link;
  if [ ! -d "$1" ]; then
    rm -f "$1";
    mkdir -p "$1";
  fi;
}

restore_env() {
  $BOOTMODE && return 1;
  local dir;
  unset -f getprop;
  [ "$OLD_LD_PATH" ] && export LD_LIBRARY_PATH=$OLD_LD_PATH;
  [ "$OLD_LD_PRE" ] && export LD_PRELOAD=$OLD_LD_PRE;
  [ "$OLD_LD_CFG" ] && export LD_CONFIG_FILE=$OLD_LD_CFG;
  unset OLD_LD_PATH OLD_LD_PRE OLD_LD_CFG;
  umount_all;
  [ -L /etc_link ] && $BB rm -rf /etc/*;
  (for dir in /etc /apex /system_root /system /vendor /product /system_ext /persist; do
    if [ -L "${dir}_link" ]; then
      rmdir $dir;
      $BB mv -f ${dir}_link $dir;
    fi;
  done;
  $BB umount -l /dev/random) 2>/dev/null;
}

uninstall_file() {
  addToLog "- Uninstalling $1"
  # $1 will start with ___ which needs to be skipped so replacing it with blank value
  blank=""
  file_location=$(echo "$1" | sed "s/___/$blank/" | sed "s/___/\//g")
  # For Devices having symlinked product and system_ext partition
  for sys in "/system"; do
    for subsys in "/system" "/product" "/system_ext"; do
      if [ -f "${sys}${subsys}/${file_location}" ]; then
        addToLog "- deleting ${sys}${subsys}/${file_location}"
        delete_recursive "${sys}${subsys}/${file_location}"
      fi;
    done
  done
  # For devices having dedicated product and system_ext partitions
  for subsys in "/system" "/product" "/system_ext"; do
    if [ -f "${subsys}/${file_location}" ]; then
      addToLog "- deleting ${subsys}/${file_location}"
      delete_recursive "${subsys}/${file_location}"
    fi
  done
}

uninstall_the_package() {
  extn="zip"
  package_name="$2"
  addToLog "- Uninstalling $package_name"
  pkgFile="$TMPDIR/$package_name.zip"
  pkgContent="pkgContent"
  unpack "AppSet/$1/$package_name.$extn" "$pkgFile"
  extract_file "$pkgFile" "uninstaller.sh" "$TMPDIR/$pkgContent/uninstaller.sh"
  chmod 755 "$TMPDIR/$pkgContent/uninstaller.sh"
  # shellcheck source=src/uninstaller.sh
  . "$TMPDIR/$pkgContent/uninstaller.sh"
  set_progress $(get_package_progress "$package_name")
}