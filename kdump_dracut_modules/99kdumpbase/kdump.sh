#!/bin/sh

. /lib/dracut-lib.sh

set -x
KDUMP_PATH="/var/crash"
CORE_COLLECTOR="makedumpfile -d 31 -c"
DEFAULT_ACTION="reboot -f"
DATEDIR=`date +%d.%m.%y-%T`
DUMP_INSTRUCTION=""

do_default_action()
{
    wait_for_loginit
    $DEFAULT_ACTION
}

add_dump_code()
{
    if [ -z "$DUMP_INSTRUCTION" ]
    then
        DUMP_INSTRUCTION="$1"
    else
        DUMP_INSTRUCTION="$DUMP_INSTRUCTION && $1"
    fi
}

dump_localfs()
{
    mount -o remount,rw $NEWROOT/ || return 1
    [ -d $NEWROOT/mnt ] || mkdir -p $NEWROOT/mnt
    mount -t $1 $2 $NEWROOT/mnt || return 1
    mkdir -p $NEWROOT/mnt/$KDUMP_PATH/$DATEDIR
    $CORE_COLLECTOR /proc/vmcore $NEWROOT/mnt/$KDUMP_PATH/$DATEDIR/vmcore || return 1
    umount /mnt || return 1
    return 0
}

dump_raw()
{
    CORE_COLLECTOR=`echo $CORE_COLLECTOR | sed -e's/\(^makedumpfile\)\(.*$\)/\1 -F \2/'`
    $CORE_COLLECTOR /proc/vmcore | dd of=$1 bs=512 || return 1
    return 0
}

dump_rootfs()
{
    mount -o remount,rw $NEWROOT/ || return 1
    mkdir -p $NEWROOT/$KDUMP_PATH/$DATEDIR
    $CORE_COLLECTOR /proc/vmcore $NEWROOT/$KDUMP_PATH/$DATEDIR/vmcore || return 1
    sync
    return 0
}

dump_nfs()
{
    mount -o remount,rw $NEWROOT/ || return 1
    [ -d $NEWROOT/mnt ] || mkdir -p $NEWROOT/mnt
    mount -o nolock -o tcp -t nfs $1 $NEWROOT/mnt/
    mkdir -p $NEWROOT/mnt/$KDUMP_PATH/$DATEDIR || return 1
    $CORE_COLLECTOR /proc/vmcore $NEWROOT/mnt/$KDUMP_PATH/$DATEDIR/vmcore || return 1
    umount $NEWROOT/mnt/ || return 1
    return 0
}

dump_ssh()
{
    ssh -q -o BatchMode=yes -o StrictHostKeyChecking=yes $1 mkdir -p $KDUMP_PATH/$DATEDIR || return 1
    scp -q -o BatchMode=yes -o StrictHostKeyChecking=yes /proc/vmcore "$1:$KDUMP_PATH/$DATEDIR"  || return 1
    return 0
}

to_dev_name()
{
    local _dev=$1
    local _is_uuid=`echo $1 | grep UUID`
    local _is_label=`echo $1 | grep LABEL`
    if [ -n "$_is_uuid" -o -n "$_is_label" ]
    then
        _dev=`findfs $1`
    fi
    echo $_dev
}

read_kdump_conf()
{
    local conf_file="/etc/kdump.conf"
    if [ -f "$conf_file" ]; then
        while read config_opt config_val;
        do
	    case "$config_opt" in
            ext[234]|xfs|btrfs|minix)
                add_dump_code "dump_localfs $config_opt "$(to_dev_name $config_val)" || do_default_action"
                ;;
            raw)
                add_dump_code "dump_raw $config_val || do_default_action"
                ;;
	    path)
                KDUMP_PATH="$config_val"
	        ;;
            core_collector)
		CORE_COLLECTOR="$config_val"
                ;;
            net)
                if [ -n "$(echo $config_val | grep @)" ]
                then
                    add_dump_code "dump_ssh $config_val || do_default_action"
                else
                    add_dump_code "dump_nfs $config_val || do_default_action"
                fi
                ;;
            default)
                case $config_val in
                    shell)
                        DEFAULT_ACTION="sh -i -l"
                        ;;
                    reboot)
                        DEFAULT_ACTION="reboot -f"
                        ;;
                    halt)
                        DEFAULT_ACTION="halt -f"
                        ;;
                    poweroff)
                        DEFAULT_ACTION="poweroff -f"
                        ;;
                esac
	        ;;
	    esac
        done < $conf_file
    fi
}

read_kdump_conf

if [ -n "$DUMP_INSTRUCTION" ]
then
    eval "$DUMP_INSTRUCTION"
else
    dump_rootfs
    do_default_action
fi


