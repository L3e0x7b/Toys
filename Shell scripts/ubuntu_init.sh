#!/bin/bash
##
## Description: An initialization script for Ubuntu Server 16.04+.
##
## Author: l3e0x7b, <lyq0x7b@foxmail.com>
##

clear
date=`date +%Y%m%d%H%M%S`
log_file="/var/log/init_err_${date}.log"
red_fg_prefix="\e[31m"
green_fg_prefix="\e[32m"
yello_fg_prefix="\e[33m"
magenta_fg_prefix="\e[35m"
cyan_fg_prefix="\e[36m"
fg_suffix="\e[0m"
failed_flag="${red_fg_prefix}....................[FAILED]${fg_suffix}"
ok_flag="${green_fg_prefix}....................[OK]${fg_suffix}"
skip_flag="${yello_fg_prefix}....................[SKIP]${fg_suffix}"

echo "Testing network connection..."
ping -c 4 223.5.5.5 &> /dev/null
if [[ $? -ne 0 ]]; then
	echo "Can not connect to Internet, please check network connection."
	exit
fi

echo && echo -e "${cyan_fg_prefix}####################### Task List #######################
# 1) Hostname Configuration  2) Network Configuration   #
# 3) Timezone Configuration  4) Apt Repo Configuration  #
# 5) Time Configuration      6) Tools installation      #
# 7) Vim Configuration                                  #
# *Tasks Check               *Reboot                    #
#########################################################${fg_suffix}" && echo

read -n 1 -p "Press any key to start: "

# exec 3>&1
# exec 1>${log_file}
exec 4>&2
exec 2>${log_file}

func_hostname () {
	echo && echo -e "${cyan_fg_prefix}#################### Hostname Configuration ####################${fg_suffix}" && echo

	hostname="localhost"	# Can be replaced by whatever you like.

	grep "${hostname}" /etc/hostname &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${yello_fg_prefix}Hostname is ${hostname}${skip_flag}${fg_suffix}"
	else
		echo -e "${magenta_fg_prefix}Hostname will be set to \"${hostname}\"...${fg_suffix}"
		hostname ${hostname}
		hostnamectl set-hostname ${hostname}
	fi
}

func_network () {
	echo && echo -e "${cyan_fg_prefix}#################### Network Configuration ####################${fg_suffix}" && echo

	nic=$(ls /sys/class/net/ | grep "en\|eth" | head -n1)
	
	grep "^auto ${nic}" /etc/network/interfaces &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${yello_fg_prefix}Network is configured${skip_flag}${fg_suffix}"
	else
		echo -e "${magenta_fg_prefix}Network will be set to start on system boot...${fg_suffix}" && echo
		sed -i "s/\(iface ${nic}\)/auto ${nic}\n\1/" /etc/network/interfaces
	fi
}

func_timezone() {
	echo && echo -e "${cyan_fg_prefix}#################### Timezone Configuration ####################${fg_suffix}" && echo

	timezone="Asia/Shanghai"	# Can be replaced by any other time zone if needed.

	timezone_old=`timedatectl | grep "Time zone" | awk '{print $3}'`
	if [[ ${timezone_old} = "${timezone}" ]]; then
		echo -e "${yello_fg_prefix}Current time zone is \"${timezone}\"${skip_flag}${fg_suffix}"
	else
		echo -e "${magenta_fg_prefix}Time zone will be set to \"${timezone}\"...${fg_suffix}"
		timedatectl set-timezone ${timezone}
	fi
}

func_apt() {
	echo && echo -e "${cyan_fg_prefix}#################### Apt Repo Configuration ####################${fg_suffix}" && echo

	grep "aliyun" /etc/apt/sources.list &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${yello_fg_prefix}Apt repo is configured${skip_flag}${fg_suffix}"
	else
		echo -e "${magenta_fg_prefix}The default repo will be replaced by Aliyun Repo...${fg_suffix}"

		mv -f /etc/apt/sources.list /etc/apt/sources.list.bak
		cat <<-EOF > /etc/apt/sources.list
			deb http://mirrors.aliyun.com/ubuntu/ xenial main
			deb-src http://mirrors.aliyun.com/ubuntu/ xenial main
			
			deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main
			deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main
			
			deb http://mirrors.aliyun.com/ubuntu/ xenial universe
			deb-src http://mirrors.aliyun.com/ubuntu/ xenial universe
			deb http://mirrors.aliyun.com/ubuntu/ xenial-updates universe
			deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates universe
			
			deb http://mirrors.aliyun.com/ubuntu/ xenial-security main
			deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main
			deb http://mirrors.aliyun.com/ubuntu/ xenial-security universe
			deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security universe
EOF

		apt update && apt upgrade -y
	fi
}

func_ntp() {
	echo && echo -e "${cyan_fg_prefix}#################### Time Configuration ####################${fg_suffix}" && echo

	dpkg -s ntpdate &> /dev/null
	if [[ $? -eq 0 ]]; then
		grep "ntpdate" /etc/crontab &> /dev/null
		if [[ $? -eq 0 ]]; then
			echo -e "${yello_fg_prefix}Ntpdate is installed, synchronizing system time with cn.pool.ntp.org...${fg_suffix}"
			ntpdate -u cn.pool.ntp.org
		else
			echo -e "${magenta_fg_prefix}Ntpdate is installed, setting time synchronization plan...${fg_suffix}"
			echo "0 0 1 * * root /usr/sbin/ntpdate -su cn.pool.ntp.org 2>&1 /dev/null" >> /etc/crontab
			systemctl restart cron
		fi
	else
		echo -e "${magenta_fg_prefix}Installing ntpdate and set time synchronization plan...${fg_suffix}" && echo
	
		apt install -y ntpdate
		ntpdate -u cn.pool.ntp.org

		echo "0 0 1 * * root /usr/sbin/ntpdate -su cn.pool.ntp.org 2>&1 /dev/null" >> /etc/crontab
		systemctl restart cron
	fi
}

func_tools() {
	echo && echo -e "${cyan_fg_prefix}#################### Tools installation ####################${fg_suffix}" && echo

	# Add/delete as needed
	tools="git wget net-tools vim bash-completion mlocate lrzsz tcpdump lsof"
	
	for tool in ${tools}; do
		dpkg -s "${tool}" &> /dev/null
		if [[ $? -eq 0 ]]; then
			continue
		else
			echo "${tool}" >> /tmp/tools.txt
		fi
	done

	if [[ -s /tmp/tools.txt ]]; then
		ntools=`cat /tmp/tools.txt | xargs`
		echo -e "${magenta_fg_prefix}Expected tools will be installed...${fg_suffix}" && echo
		apt update && apt install -y ${ntools}

		rm -f /tmp/tools.txt &> /dev/null
	else
		echo -e "${yello_fg_prefix}All expected tools are installed${skip_flag}${fg_suffix}"
	fi
}

func_vim() {
	echo && echo -e "${cyan_fg_prefix}#################### Vim Configuration ####################${fg_suffix}" && echo

	IFS_OLD=$IFS
	IFS=';'

	# Add/delete as needed, separated by ';'.
	vim_conf_list="set nocompatible;set fileformats=unix,dos;set go=;syntax on;set number;set fileencodings=ucs-bom,utf-8,utf-16,gbk,big5,gb18030,latin1;set fileencoding=utf-8;set encoding=utf-8;set shortmess=atI;autocmd InsertEnter * se cul;autocmd InsertEnter * se nocul;set completeopt=preview,menu;set tabstop=4;set softtabstop=4;set shiftwidth=4;set noexpandtab;set ignorecase;set showmatch;set matchtime=0;set wildmenu;set hlsearch;set incsearch;set noerrorbells;set backspace=indent,eol,start"

	vim_conf_list=`echo "${vim_conf_list}" | sed 's/\\*/\\\*/g'`

	for vim_conf in ${vim_conf_list}; do
		grep "^\s*${vim_conf}" /etc/vim/* &> /dev/null

		if [[ $? -eq 0 ]]; then
			continue
		else
			echo "${vim_conf}" | sed 's/\\\*/*/' >> /tmp/vimrc
		fi
	done
	IFS=$IFS_OLD

	if [[ -s /tmp/vimrc ]]; then
		echo -e "${magenta_fg_prefix}Configuring Vim...${fg_suffix}"
		cat /tmp/vimrc >> /etc/vim/vimrc.local

		rm -f /tmp/vimrc
	else
		echo -e "${yello_fg_prefix}Vim is configured${skip_flag}${fg_suffix}"
	fi
}

func_check() {
	echo && echo -e "${cyan_fg_prefix}#################### Tasks Check ####################${fg_suffix}" && echo

	echo -e "${magenta_fg_prefix}[Check Hostname]${fg_suffix}"
	grep "${hostname}" /etc/hostname &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${ok_flag}"
	else
		echo -e "${failed_flag}"
	fi

	##############################

	echo -e "${magenta_fg_prefix}[Check Network]${fg_suffix}"
	grep "^auto ${nic}" /etc/network/interfaces &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${ok_flag}"
	else
		echo -e "${failed_flag}"
	fi

	##############################

	echo -e "${magenta_fg_prefix}[Check Timezone]${fg_suffix}"
	timedatectl | grep "Asia/Shanghai" &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${ok_flag}"
	else
		echo -e "${failed_flag}"
	fi

	##############################

	echo -e "${magenta_fg_prefix}[Check Apt]${fg_suffix}"
	grep "aliyun" /etc/apt/sources.list &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${ok_flag}"
	else
		echo -e "${failed_flag}"
	fi

	##############################

	echo -e "${magenta_fg_prefix}[Check NTP]${fg_suffix}"
	dpkg -s ntpdate &> /dev/null
	if [[ $? -eq 0 ]]; then
		grep "ntpdate" /etc/crontab &> /dev/null
		if [[ $? -eq 0 ]]; then
			echo -e "${ok_flag}"
		else
			echo -e "${failed_flag}"
		fi
	else
		echo -e "${failed_flag}"
	fi

	##############################

	echo -e "${magenta_fg_prefix}[Check Tools]${fg_suffix}"
	for tool in ${tools}; do
		dpkg -s "${tool}" &> /dev/null
		if [[ $? -eq 0 ]]; then
			echo -e "\t${green_fg_prefix}[${tool}]${fg_suffix}${ok_flag}"
		else
			echo -e "\t${red_fg_prefix}[${tool}]${fg_suffix}${failed_flag}"
		fi
	done

	##############################

	echo -e "${magenta_fg_prefix}[Check Vim]${fg_suffix}"
	IFS_OLD=$IFS
	IFS=';'

	for vim_conf in ${vim_conf_list}; do
		grep "^\s*${vim_conf}" /etc/vim/* &> /dev/null

		if [[ $? -eq 0 ]]; then
			vim_conf=`echo "${vim_conf}" | sed 's/\\\\\*/*/'`
			echo -e "\t${green_fg_prefix}[${vim_conf}]${fg_suffix}${ok_flag}"
		else
			vim_conf=`echo "${vim_conf}" | sed 's/\\\\\*/*/'`
			echo -e "\t${red_fg_prefix}[${vim_conf}]${fg_suffix}${failed_flag}"
		fi
	done
	IFS=$IFS_OLD

	echo
}

func_reboot() {
	echo -e "${cyan_fg_prefix}################################################################################${fg_suffix}" && echo
	echo -e "${magenta_fg_prefix}Errors has been saved to [/var/log/init_err_${date}.log].${fg_suffix}" && echo

	read -p "All tasks completed! Reboot immediately(recommended)[Y/y] or later[Enter]? " reboot_ans

	if [[ ${reboot_ans} = "Y" || ${reboot_ans} = "y" ]]; then
		echo && echo -e "${magenta_fg_prefix}Now reboot...${fg_suffix}"
		reboot
	else
		echo && echo -e "${magenta_fg_prefix}Now exit...${fg_suffix}"
	fi
}

func_hostname
func_network
func_timezone
func_apt
func_ntp
func_tools
func_vim
func_check

# exec 1>&3
# exec 3>&-
exec 2>&4
exec 4>&-

func_reboot