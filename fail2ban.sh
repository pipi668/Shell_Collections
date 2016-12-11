#!/bin/sh
#
# Onekey install script for fail2ban
# Author: Char1sma
# Email: github-char1sma@woai.ru
MIN_CENTOS_VER=5
MIN_DEBIAN_VER=6
MIN_UBUNTU_VER=12
SSH_PORT=$(netstat -ntlp|grep sshd |awk -F: '{if($4!="")print $4}' | head -n 1 | sed 's/ //')
HOSTNAME=$(hostname)
linux_check(){
	if $(grep -qi "CentOS" /etc/issue) || $(grep -q "CentOS" /etc/*-release); then
		OS="CentOS"
	elif $(grep -qi "Ubuntu" /etc/issue) || $(grep -q "Ubuntu" /etc/*-release); then
		OS="Ubuntu"
	elif $(grep -qi "Debian" /etc/issue) || $(grep -q "Debian" /etc/*-release); then
		OS="Debian"
	else
		cat >&2 <<EOF
		This shell only support CentOS ${MIN_CENTOS_VER}+, Debian ${MIN_DEBIAN_VER}+ or Ubuntu ${MIN_UBUNTU_VER}+, if you want to run this shell on other system, please write shell by yourself.
EOF
		exit 1
	fi

	OS_VSRSION=$(grep -oEh "[0-9]+" /etc/*-release | head -n 1) || {
		cat >&2 <<-'EOF'
		Fail to detect os version, please feed back to author!
		EOF
		exit 1
	}
}
install(){
	linux_check
	if [ "$OS" = "CentOS" ]; then
		LOGPATH="/var/log/secure"
		centos_install

	elif [ "$OS" = "Debian" ]; then
		LOGPATH="/var/log/auth.log"
		debian_install

	else
		LOGPATH="/var/log/auth.log"
		ubuntu_install
	fi
	unset LOGPATH
	mkdir -p ~/bin
	wget https://raw.githubusercontent.com/Char1sma/Shell_Collections/master/fail2ban.sh -O ~/bin/fail2ban.sh
	chmod +x ~/bin/fail2ban.sh
}
write_conf(){
rm /etc/fail2ban/jail.conf -rf
cat > /etc/fail2ban/jail.conf <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 86400
maxretry = 3
findtime = 600
mta = sendmail
[ssh-iptables]
enabled = true
filter = sshd
action = iptables[name=SSH, port=${SSH_PORT}, protocol=tcp]
sendmail-whois[name=SSH, dest=root@${HOSTNAME}, sender=fail2ban@${HOSTNAME}]
logpath = ${LOGPATH}
maxretry = 3
EOF
}
centos_install(){
	rpm -ivh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$OS_VSRSION.noarch.rpm"
	yum -y install fail2ban
	write_conf
	if [ "$OS_VSRSION" -gt 6 ]; then
		systemctl restart fail2ban
		systemctl enable fail2ban
	else
		service fail2ban restart
		chkconfig fail2ban on
	fi
}
debian_install(){
	apt-get -y update
	apt-get -y install fail2ban
	write_conf
	service fail2ban restart
	update-rc.d fail2ban enable
}
ubuntu_install(){
	debian_install
}
unban(){
	fail2ban-client set ssh-iptables unbanip "$1"
}
show_log(){
	linux_check
	echo "Line UserName IP"
	if [ "$OS" = "CentOS" ]; then
		cat /var/log/secure* | grep 'Failed password' | awk 'BEGIN{sum=0;}{sum ++;if ($9 == "invalid") { print $11 "\t" $13 } else { print $9 "\t" $11; }}END{ print "SUM:" sum}' 
	else
		grep 'Failed password' /var/log/auth.log | awk 'BEGIN{sum=0;}{sum ++;if ($9 == "invalid") { print $11 "\t" $13 } else { print $9 "\t" $11; }}END{ print "SUM:" sum}' 
	fi
}
uninstall() {
	linux_check
	if [ "$OS" = "CentOS" ]; then
		yum -y remove fail2ban
	else
		apt-get -y remove fail2ban
	fi
	rm /etc/fail2ban/ -rf
	rm /var/run/fail2ban/ -rf
}
root_check() {
	if [ $(id -u) -ne 0 ]; then
		echo "Error:This script must be run as root!" 1>&2
		exit 1
	fi
}
#root_check
case $1 in
	h|H|help)
		echo "Usage: $0 [OPTION]"
		echo ""
		echo "Here are the options:"
		echo "install		install fail2ban"
		echo "uninstall	uninstall fail2ban"
		echo "showlog		show failed login logs"
		echo "unban <ip>		unban ip";;
	unban)
		unban "$2"
		;;
	showlog)
		show_log;;
	install)
		install;;
	uninstall)
		uninstall;;
	*)
		echo "$0 : invalid option -- '$1'"
		echo "Try '$0 help' for more infomation."
		exit 0;;
esac