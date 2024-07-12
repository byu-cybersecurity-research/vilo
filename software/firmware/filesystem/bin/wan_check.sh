#!/bin/sh
TOOL=flash
GETMIB="$TOOL get"
WAN_CONNECT_STATUS_FILE="/tmp/wan_connect_status"
GW_CONNECT_STATUS_FILE="/tmp/gw_connect_status"
WAN_CONNECT_STATUS_FILE_TMP="/tmp/wan_connect_status.tmp"
WAN_NETWORK_STATUS="/tmp/wan_network_status"

WAN_PING_SERVER_1="8.8.8.8"
WAN_PING_SERVER_2="8.8.4.4"
WAN_PING_SERVER_3="www.apple.com"
WAN_PING_SERVER_4="www.github.com"

do_ping_server() {
	local server_ping=$1
	local result_ping=$2
	#echo "server_ping=[$server_ping], result_ping=[$result_ping]"
	ping -c 3 -w 5 $server_ping 1>/dev/null 2>&1 && echo 1 > $result_ping || echo 0 > $result_ping
}

do_ping_servers() {
	local result_ping=$1
	local result
	
	ping -c 3 -w 5 $WAN_PING_SERVER_1 1>/tmp/ping_result 2>&1 && echo 1 > $WAN_CONNECT_STATUS_FILE_TMP || echo 0 > $WAN_CONNECT_STATUS_FILE_TMP
	result=`cat $WAN_CONNECT_STATUS_FILE_TMP`
		
	if [ $result != 1 ]; then
	
		ping -c 3 -w 5 $WAN_PING_SERVER_2 1>/tmp/ping_result 2>&1 && echo 1 > $WAN_CONNECT_STATUS_FILE_TMP || echo 0 > $WAN_CONNECT_STATUS_FILE_TMP
	
	else
		echo 1 > $result_ping
		return
	fi
	
	result=`cat $WAN_CONNECT_STATUS_FILE_TMP`
	
	if [ $result != 1 ]; then
		
		ping -c 3 -w 5 $WAN_PING_SERVER_3 1>/tmp/ping_result 2>&1 && echo 1 > $WAN_CONNECT_STATUS_FILE_TMP || echo 0 > $WAN_CONNECT_STATUS_FILE_TMP
		result=`cat $WAN_CONNECT_STATUS_FILE_TMP`
			
		if [ $result != 1 ]; then
			
			ping -c 3 -w 5 $WAN_PING_SERVER_4 1>/tmp/ping_result 2>&1 && echo 1 > $result_ping || echo 0 > $result_ping
			
		else
			echo 1 > $result_ping
			return
		fi
	else
		echo 1 > $result_ping
		return
	fi
}

get_ping_addr(){
	eval `$GETMIB HUALAI_PING_ADDR1_IP`
	if [ -n "$HUALAI_PING_ADDR1_IP" ]; then
		WAN_PING_SERVER_1=$HUALAI_PING_ADDR1_IP;
	fi
	
	eval `$GETMIB HUALAI_PING_ADDR2_IP`
	if [ -n "$HUALAI_PING_ADDR2_IP" ]; then
		WAN_PING_SERVER_2=$HUALAI_PING_ADDR2_IP;
	fi
	
	eval `$GETMIB HUALAI_PING_ADDR3_IP`
	if [ -n "$HUALAI_PING_ADDR3_IP" ]; then
		WAN_PING_SERVER_3=$HUALAI_PING_ADDR3_IP;
	fi
	
	eval `$GETMIB HUALAI_PING_ADDR4_IP`
	if [ -n "$HUALAI_PING_ADDR4_IP" ]; then
		WAN_PING_SERVER_4=$HUALAI_PING_ADDR4_IP;
	fi
}

check_wan_connect_status() {
	local default_gw=
	local ping_result
	local ping_avg
	local count=0
	get_ping_addr
	while true; do
		default_gw=$(route | awk '/default/ {print $2}')
		if [[ -n "$default_gw" ]]; then
			#echo "default_gw=[$default_gw]"
			do_ping_server $default_gw $GW_CONNECT_STATUS_FILE
		else
			echo 0 > $GW_CONNECT_STATUS_FILE
		fi
		#do_ping_server $HUALAI_PING_ADDR1_IP $WAN_CONNECT_STATUS_FILE
		do_ping_servers $WAN_CONNECT_STATUS_FILE
		ping_result=`cat $WAN_CONNECT_STATUS_FILE`
		if [ $ping_result = 1 ]; then
			ping_avg=`cat /tmp/ping_result | grep round-trip | cut -d ' ' -f 4 | cut -d '/' -f 2 | cut -d '.' -f 1`
			if [ $ping_avg -gt 150 ]; then
				if [ $count = 0 ]; then
					echo [`date "+%Y-%m-%d %H:%M:%S"`] bad network > $WAN_NETWORK_STATUS
				else
					echo [`date "+%Y-%m-%d %H:%M:%S"`] bad network >> $WAN_NETWORK_STATUS
				fi

				count=`expr $count + 1`
			fi
		else
			if [ $count = 0 ]; then
				echo [`date "+%Y-%m-%d %H:%M:%S"`] network disconnect > $WAN_NETWORK_STATUS
			else
				echo [`date "+%Y-%m-%d %H:%M:%S"`] network disconnect >> $WAN_NETWORK_STATUS
			fi

			count=`expr $count + 1`
		fi
		if [ $count -gt 1000 ]; then
			count=0
		fi
		sleep 5
	done
}

check_wan_connect_status
