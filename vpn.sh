#!/bin/bash

E="mcedit"
PM="apt"
ipsec="strongswan"
l2tp="xl2tpd"

cf_ppp_secrets="/etc/ppp/chap-secrets"
cf_l2tp="/etc/xl2tpd/xl2tpd.conf"
cf_l2tp_options="/etc/ppp/options.xl2tpd"
cf_ipsec="/etc/ipsec.conf"
cf_ipsec_secrets="/etc/ipsec.secrets"
cf_sysctl="/etc/sysctl.conf"

cfurl_ppp_secrets="https://raw.githubusercontent.com/minlearnminlearn/l2tp-ipsec-vpn_fixed/master/configs/etc/ppp/chap-secrets"
cfurl_l2tp="https://raw.githubusercontent.com/minlearnminlearn/l2tp-ipsec-vpn_fixed/master/configs/etc/xl2tpd/xl2tpd.conf"
cfurl_l2tp_options="https://raw.githubusercontent.com/minlearnminlearn/l2tp-ipsec-vpn_fixed/master/configs/etc/ppp/options.xl2tpd"
cfurl_ipsec="https://raw.githubusercontent.com/minlearnminlearn/l2tp-ipsec-vpn_fixed/master/configs/etc/ipsec.conf"
cfurl_ipsec_secrets="https://raw.githubusercontent.com/minlearnminlearn/l2tp-ipsec-vpn_fixed/master/configs/etc/ipsec.secrets"
cfurl_sysctl="https://raw.githubusercontent.com/minlearnminlearn/l2tp-ipsec-vpn_fixed/master/configs/etc/sysctl.conf"

msg_cmd_control="$0 control start|stop|restart|status"
msg_cmd_editconfig="$0 edit-config secrets|l2tp|l2tp-options|ipsec|ipsec-secrets|sysctl"
msg_cmd_installconfigs="$0 install-config all|secrets|l2tp|l2tp-options|ipsec|ipsec-secrets"
msg_cmd_server="$0 server install|reinstall|remove|purge"

function showAreYouShure() {
    read -p "Are you sure? [y/n] " -n 1 -r </dev/tty
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
	exit 1
    fi
}

function doControl(){
    case $1 in
        start)
	    echo "Trying to start ${ipsec}-starter & $l2tp"
	    eval "systemctl start ${ipsec}-starter $l2tp"
	;;
	stop)
	    echo "Trying to stop ${ipsec}-starter & $l2tp"
	    eval "systemctl stop ${ipsec}-starter $l2tp"
	;;
	restart)
	    echo "Trying to restart ${ipsec}-starter & $l2tp"
	    eval "systemctl restart ${ipsec}-starter $l2tp"
	;;
	status)
	    echo "Services status:"
	    eval "systemctl status ${ipsec}-starter $l2tp"
	;;
	*)
	    echo "Usage: $msg_cmd_control"
	;;
    esac
}


function clearFirewall(){
    echo "clearing firewall"
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
}


function setupFirewall(){
    echo "Allow nat and masquerading in firewall"
    iptables --table nat --append POSTROUTING --jump MASQUERADE
}

function allowIpForward(){
    echo "Allow ip forwarding"
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/* 
    do
	echo 0 > $each/accept_redirects
	echo 0 > $each/send_redirects
    done
}

function doSetupNetwork() {
    # ToDo
    # uncomment row "net.ipv4.ip_forward = 1" in /etc/sysctl.conf
    setupFirewall
    allowIpForward
}

function doAddStandip() {

  echo "switching to multiple ip and multiple process mode"
  eval "systemctl stop $l2tp"
  eval "systemctl disable $l2tp"
  xl2tpd -c /etc/xl2tpd/xl2tpd.conf -p /var/run/xl2tpd.pid

  lastfilenum=`echo $(find /etc/xl2tpd/xl2tpd*|while read LINE; do echo ${LINE%%.conf}|grep -Eo '[0-9]+$';done|sort -r|head -n1)`;
  [[ $lastfilenum == '' ]] && lastfilenum=0;
  lastfilenumadded=`expr $lastfilenum + 1`;
  wget -O /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf "$cfurl_l2tp"
  read -p "give a newip:" myIP </dev/tty
  sed -e "s/yourip/$myIP/g" -e "s/rangestart/$lastfilenumadded/g" -i /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf
  xl2tpd -c /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf -p /var/run/xl2tpd"$lastfilenumadded".pid

  clearFirewall
  iptables -t nat -A POSTROUTING -s 10.19.0.0/24 -o eth0 -j SNAT --to-source `echo $(ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'|head -n1)`
  iptables -t nat -A POSTROUTING -s 10.19."$lastfilenumadded".0/24 -o eth0 -j SNAT --to-source $myIP

  #eval "systemctl restart ${ipsec}-starter"
}

function doEditConfig(){
    case $1 in
	secrets)
	    eval "$E $cf_ppp_secrets"
	;;
	l2tp)
	    eval "$E $cf_l2tp"
	;;
	l2tp-options)
	    eval "$E $cf_l2tp_options"
	;;
	ipsec)
	    eval "$E $cf_ipsec"
	;;
	ipsec-secrets)
	    eval "$E $cf_ipsec_secrets"
	;;
	sysctl)
	    eval "$E $cf_sysctl"
	;;
	*)
	    echo "Usage: $msg_cmd_editconfig"
	;;
    esac
}

function doInstallConfigAll(){
    doInstallConfig secrets
    #doInstallConfig l2tp
    doInstallConfig l2tp-options
    doInstallConfig ipsec
    doInstallConfig ipsec-secrets
}

function sayInstallConfig(){
    echo "Install preconfigured file: $1"
}

function doInstallConfig(){
    echo "Install wget if not installed"
    apt install -y wget
    case $1 in
	all)
	    doInstallConfigAll
	;;
	secrets)
	    sayInstallConfig $cf_ppp_secrets
	    wget -O "$cf_ppp_secrets" "$cfurl_ppp_secrets"
	;;
	l2tp)
	    sayInstallConfig $cf_l2tp
	    wget -O "$cf_l2tp" "$cfurl_l2tp"
	;;
	l2tp-options)
	    sayInstallConfig $cf_l2tp_options
	    wget -O "$cf_l2tp_options" "$cfurl_l2tp_options"
	;;
	ipsec)
	    sayInstallConfig $cf_ipsec
	    wget -O "$cf_ipsec" "$cfurl_ipsec"
	;;
	ipsec-secrets)
	    sayInstallConfig $cf_ipsec_secrets
	    wget -O "$cf_ipsec_secrets" "$cfurl_ipsec_secrets"
	;;
	*)
	    echo " "
	    echo "---------------------------------------------------------------------"
	    echo "| WARNING!!! This action replace all data in choosen config file!!! |"
	    echo "---------------------------------------------------------------------"
	    echo " "
	    echo "Usage: $msg_cmd_installconfigs"
	;;
    esac
}

function askInstallConfigs(){
    while true; do
	read -p "Do you want to install preconfigured config files? [y/n] " yn </dev/tty
	case $yn in
	    [Yy]* ) 
		doInstallConfigAll 
		break
	    ;;
	    [Nn]* ) 
		exit
	    ;;
	    * ) 
		echo "Please answer y - yes or n - no"
	    ;;
	esac
    done
}

function doServer(){
    case $1 in
	install)
            doSetupNetwork
	    eval "$PM install -y $ipsec $l2tp"
            rm -rf /etc/xl2tpd/xl2tpd.conf
            eval "systemctl stop $l2tp"
            eval "systemctl disable $l2tp"

	    doInstallConfigAll
            read -p "give a user:" myUser </dev/tty
            read -p "give a pass:" myPass </dev/tty
            sed -e "s/testvpnuser/$myUser/g" -e "s/testvpnpassword/$myPass/g" -i "$cf_ppp_secrets"
            read -p "give a sharedpsk:" myPSK </dev/tty
            sed -i "s/PUT_YOUR_PSK_HERE/$myPSK/g" "$cf_ipsec_secrets"
            eval "systemctl restart ${ipsec}-starter"

            clearFirewall
            ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'|while read myIP; do

              lastfilenum=`echo $(find /etc/xl2tpd/xl2tpd*|while read LINE; do echo ${LINE%%.conf}|grep -Eo '[0-9]+$';done|sort -r|head -n1)`;
              [[ $lastfilenum == '' ]] && lastfilenum=0;
              lastfilenumadded=`expr $lastfilenum + 1`;
              wget -O /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf "$cfurl_l2tp"
              sed -e "s/yourip/$myIP/g" -e "s/rangestart/$lastfilenumadded/g" -i /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf
              xl2tpd -c /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf -p /var/run/xl2tpd"$lastfilenumadded".pid


              iptables -t nat -A POSTROUTING -s 10.19."$lastfilenumadded".0/24 -o eth0 -j SNAT --to-source $myIP

            done
	;;
	reinstall)
	    eval "$PM reinstall -y $ipsec $l2tp"
	    askInstallConfigs
	;;
	remove)
	    showAreYouShure
	    eval "$PM remove -y $ipsec $l2tp"
	;;
	purge)
	    showAreYouShure
	    eval "$PM purge -y $ipsec $l2tp"
            rm -rf /etc/xl2tpd/*
	;;
	*)
	    echo "Usage: $msg_cmd_server"
	;;
    esac
}

function showHelp(){
    echo "Usage:" 
    echo " "
    echo "- control your vpn server"
    echo "	$msg_cmd_control" 
    echo " "
    echo "- edit config files"
    echo "	$msg_cmd_editconfig" 
    echo " "
    echo "- install preconfigured config files (by iTeeLion)"
    echo "	$msg_cmd_installconfigs" 
    echo " "
    echo "- setup network (allow nat and masquerading in firewall and allow ip forwarding)"
    echo "	$0 setup-network" 
    echo " "
    echo "- Add standip (switch mode and add multiple standalone ip)"
    echo "	$0 add-standip" 
    echo " "
    echo "- install/remove server (Packages: $ipsec & $l2tp)"
    echo "	$msg_cmd_server" 
    echo " "
}

case $1 in
    control)
	doControl $2
    ;;
    setup-network)
	doSetupNetwork
    ;;
    add-standip)
	doAddStandip
    ;;
    edit-config)
	doEditConfig $2
    ;;
    install-configs)
	doInstallConfig $2
    ;;
    server)
	doServer $2
    ;;
    help)
	showHelp
    ;;
    *)
	showHelp
    ;;
esac
