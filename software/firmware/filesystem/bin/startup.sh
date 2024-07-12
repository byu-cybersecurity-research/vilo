#!/bin/sh
#
# script file to startup
TOOL=flash
GETMIB="$TOOL get"
LOADDEF="$TOOL default"
LOADDEFBLUETOOTHHW="$TOOL default-bluetoothhw"
LOADDEFCUSTOMERHW="$TOOL default-customerhw"
LOADDEFDPKHW="$TOOL default-dpk"
LOADDEFSW="$TOOL default-sw"
LOADDS="$TOOL reset"
# See if flash data is valid
$TOOL virtual_flash_init
$TOOL test-hwconf
if [ $? != 0 ]; then
	echo 'HW configuration invalid, reset default!'
	#$LOADDEF
	echo "Use changhong backup mib: hs"
	flash mib_backup_restore_hs
	if [ $? != 0 ]; then
		echo 'HW configuration invalid, reset default 2!'
		$LOADDEF
	fi
fi
$TOOL test-bluetoothhwconf
if [ $? != 0 ]; then
        echo 'BLUETOOTH HW configuration invalid, reset default!'
        $LOADDEFBLUETOOTHHW
fi
$TOOL test-customerhwconf
if [ $? != 0 ]; then
        echo 'CUSTOMER HW configuration invalid, reset default!'
        $LOADDEFCUSTOMERHW
fi

$TOOL test-dpkconf
if [ $? != 0 ];then
        echo 'RF DPK configuration invalid, reset default'
        $LOADDEFDPKHW
fi

$TOOL test-dsconf
if [ $? != 0 ]; then
	echo 'Default configuration invalid, reset default!'
	#$LOADDEFSW
	echo "Use changhong backup mib: ds"
	flash mib_backup_restore_ds
	if [ $? != 0 ]; then
		echo 'Default configuration invalid, reset default 2!'
		$LOADDEFSW
	fi
fi

$TOOL test-csconf
if [ $? != 0 ]; then
	echo 'Current configuration invalid, reset to default configuration!'
	#$LOADDS
	echo "Use changhong backup mib: cs"
	flash mib_backup_restore_cs
	if [ $? != 0 ]; then
		echo 'Current configuration invalid, reset default 2!'
		$LOADDS
	fi
fi
$TOOL test-alignment
if [ $? != 0 ]; then
        echo 'Please refine linux/.config change offset to fit flash erease size!!!!!!!!!!!!!!!!!'
fi

# voip flash check
if [ "$VOIP_SUPPORT" != "" ]; then
$TOOL voip check
fi

#if [ ! -e "$SET_TIME" ]; then
#	flash settime
#fi

# Generate WPS PIN number
eval `$GETMIB HW_WLAN0_WSC_PIN`
if [ "$HW_WLAN0_WSC_PIN" = "" ]; then
	$TOOL gen-pin
fi

cflash test_crimib

# Enable Multicast and Broadcast Strom control and disable it in post_startup.sh
echo "1 3" > /proc/StormCtrl
