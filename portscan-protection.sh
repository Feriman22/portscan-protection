#!/bin/bash
SCRIPTNAME="Portscan Protection"
VERSION="16-08-2022"
SCRIPTLOCATION="/usr/local/sbin/portscan-protection.sh"
WHITELISTLOCATION="/usr/local/sbin/portscan-protection-white.list"
CRONLOCATION="/etc/cron.d/portscan-protection"
GITHUBRAW="https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection.sh"
AUTOUPDATE="YES" # Edit this variable to "NO" if you don't want to auto update this script (NOT RECOMMENDED)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#
# Define some functions
#

IPSETCOMMANDCHECK()
{
	# Check the ipset command
	! which ipset > /dev/null && printf "\nipset command ${RED}not found${NC}.\n" && exit 6 || printf "ipset command found. ${GR}OK.${NC}"
}


IPTABLECOMMANDCHECK()
{
	# Check the iptables command
	! which iptables > /dev/null && printf "iptables command ${RED}not found${NC}.\n" && exit 7 || printf "iptables command found. ${GR}OK.${NC}"
}


SETCRONTAB()
{
	[ ! -f "$CRONLOCATION" ] || [ $(grep -c "reboot root sleep" "$CRONLOCATION") -lt 1 ] && printf "# $SCRIPTNAME installed at $(date)\n@reboot root sleep 30 && $SCRIPTLOCATION --cron" > "$CRONLOCATION" && printf "Crontab entry has been set. ${GR}OK.${NC}" || printf "Crontab entry ${GR}already set.${NC}"
}


WHITELIST()
{
	[ ! -f "$WHITELISTLOCATION" ] && printf "# This file is part of $SCRIPTNAME\n# Add one IP per line to this file. These IP addresses will be never blocked. Note: Only IPv4 addresses are supported.\n# More info on GitHub: https://github.com/Feriman22/portscan-protection\n# If you found it useful, please donate via PayPal: https://paypal.me/BajzaFerenc\n# Thank you!\n\n127.0.0.1" > $WHITELISTLOCATION
	for i in nano vi vim; do
		if which $i > /dev/null; then
			$i "$WHITELISTLOCATION"
			"$SCRIPTLOCATION" --cron
			printf "Whitelist has been activated if the file modified." ; FOUND="1"
			break
		fi
	done
	[ "$FOUND" != "1" ] && echo "nano, vi or vim not found. Edit manually the whitelist: $WHITELISTLOCATION"
}


UPDATE()
{
	# Getting info about the latest GitHub version
	NEW=$(curl -s "$GITHUBRAW" | awk -F'"' '/^VERSION/ {print $2}')

	# Compare the installed and the GitHub stored version - Only internal, not available by any argument
	if [[ "$1" == "ONLYCHECK" ]] && [[ "$NEW" != "$VERSION" ]]; then
		[ "$1" != '--cron' ] && printf "New version ${YL}available!${NC}"
	else
		[[ "$1" == "ONLYCHECK" ]] && [ "$1" != '--cron' ] && printf "$SCRIPTNAME is ${GR}up to date.${NC}"
	fi

	# Check the current installation
	if [[ "$1" != "ONLYCHECK" ]] && [ -f "$CRONLOCATION" ] && [ -x "$SCRIPTLOCATION" ]; then

		# Check the GitHub - Is it available? - Exit if not
		[ "$1" != '--cron' ] && [[ ! "$NEW" ]] && printf "GitHub is ${RED}not available now.${NC} Try again later." && exit 8
		[ "$1" == '--cron' ] && [[ ! "$NEW" ]] && exit 8

		# Compare the installed and the GitHub stored version
		if [[ "$NEW" != "$VERSION" ]]; then
			curl -s -o "$SCRIPTLOCATION" "$GITHUBRAW"
			SETCRONTAB
			[ "$1" != '--cron' ] && printf "Script has been ${GR}updated.${NC}"
		else
			[ "$1" != '--cron' ] && printf "$SCRIPTNAME is ${GR}up to date.${NC}"
		fi
	else
		[[ "$1" != "ONLYCHECK" ]] && [ "$1" != '--cron' ] && printf "Script ${RED}not installed.${NC} Install first then you can update it."
	fi
}


if [ "$1" != '--cron' ]; then
	# Coloring
	RED='\033[0;31m' # Red Color
	GR='\033[0;32m' # Green Color
	YL='\033[0;33m' # Yellow Color
	NC='\033[0m' # No Color

	printf "\n$SCRIPTNAME\n"
	echo "Author: Feriman"
	echo "URL: https://github.com/Feriman22/portscan-protection"
	echo "Open GitHub page to read the manual and check new releases"
	echo "Current version: $VERSION"
	UPDATE ONLYCHECK # Check new version
	printf "${GR}If you found it useful${NC}, please donate via PayPal: https://paypal.me/BajzaFerenc\n"
fi

# Check the root permission
[ ! $(id -u) = 0 ] && printf "${RED}Run as root!${NC}\n" && exit 5

# Check curl, ipset, iptables commands
for i in curl ipset iptables; do ! which ipset > /dev/null && echo "$i command ${RED}not found${NC}" && NOT_FOUND="1"; done
[ "$NOT_FOUND" == "1" ] && exit 10

# Define ipset and iptable rules - Used at magic and uninstall part
IPSET1='port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600'
IPSET2='scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60'
IPTABLE1='INPUT -m state --state INVALID -j DROP'
IPTABLE2='INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist'
IPTABLE3='INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP'
IPTABLE4='INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst'

# Enter in this section only if run by cron - It will do the magic
if [ "$1" == '--cron' ]; then

	# Add Whitelist IPs if any
	if [ -f $WHITELISTLOCATION ]; then
		while read WHILELISTIP; do
			# Validate IP address
			if [[ "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]] && [ $(iptables -S | grep -cF -- "-A INPUT -s $WHILELISTIP/32 -j ACCEPT") -lt 1 ]; then
				iptables -I INPUT -s $WHILELISTIP -j ACCEPT
			fi
		done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
	fi

	[ $(ipset list | grep -c port_scanners) -lt 1 ] && ipset create $IPSET1
	[ $(ipset list | grep -c scanned_ports) -lt 1 ] && ipset create $IPSET2
	[ $(iptables -S | grep -cF -- "-A $IPTABLE1") -lt 1 ] && iptables -A $IPTABLE1
	[ $(iptables -S | grep -cF -- "-A $IPTABLE2") -lt 1 ] && iptables -A $IPTABLE2
	[ $(iptables -S | grep -cF -- "-A $IPTABLE3") -lt 1 ] && iptables -A $IPTABLE3
	[ $(iptables -S | grep -cF -- "-A $IPTABLE4") -lt 1 ] && iptables -A $IPTABLE4

	# Auto update if not disabled
	[ "$AUTOUPDATE" == "YES" ] && UPDATE --cron

	# Exit, because it run by cron
	exit 0
fi

# Call the menu
if [ "$1" == "-i" ] || [ "$1" == "-u" ] || [ "$1" == "-v" ] || [ "$1" == "--install" ] || [ "$1" == "--uninstall" ] || [ "$1" == "--verify" ] || [ "$1" == "-up" ] || [ "$1" == "--update" ]; then
	OPT="$1" && OPTL="$1" && ARG="YES"
else
	PS3='Please enter your choice: '
	[ -f "$SCRIPTLOCATION" ] && options=("Verify" "Edit Whitelist" "Update from GitHub" "Uninstall" "Quit")
	[ ! -f "$SCRIPTLOCATION" ] && options=("Install" "Verify" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"Install")
				OPT='-i' && OPTL='--install' && break
				;;
			"Uninstall")
				OPT='-u' && OPTL='--uninstall' && break
				;;
			"Edit Whitelist")
				WHITELIST ; break
				;;
			"Verify")
				OPT='-v' && OPTL='--verify' && break
				;;
			"Update from GitHub")
				UPDATE && break
				;;
			"Quit")
				break
				;;
			*) echo "Invalid option $REPLY";;
		esac
	done
fi

##
########### Menu: Install ###########
##

if [ "$OPT" == '-i' ] || [ "$OPTL" == '--install' ]; then

	#
	### Start Installation ###
	#

	# Start count the time of install process
	SECONDS=0

	IPSETCOMMANDCHECK

	IPTABLECOMMANDCHECK

	# Set crontab rule if it does not already exist
	SETCRONTAB

	# Copy the script to $SCRIPTLOCATION and add execute permission
	INSTALLERLOCATION=$(realpath $0)
	if [ "$INSTALLERLOCATION" != "$SCRIPTLOCATION" ]; then
		curl -s -o "$SCRIPTLOCATION" "$GITHUBRAW" && chmod +x "$SCRIPTLOCATION" && printf "$SCRIPTNAME has been copied in $SCRIPTLOCATION ${GR}OK.${NC}"
	else
		printf "$SCRIPTNAME already copied to destination. Nothing to do. ${GR}OK.${NC}"
	fi

	# First "cron like" run to activate the iptable rules
	"$SCRIPTLOCATION" --cron && printf "iptable rules have been activated. You are protected! ${GR}OK.${NC}\n"

	# Finish
	printf "\n${GR}Note:${NC} If you want to Edit Whitelist, or Verify the install, just run the below command:\nsudo $SCRIPTLOCATION\n"
	printf "${GR}Done.${NC} The install was $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec. That was so quick, wasn't?"
fi


##
########### Menu: Uninstall ###########
##

if [ "$OPT" == '-u' ] || [ "$OPTL" == '--uninstall' ]; then
	if [ "$ARG" != 'YES' ]; then
		loop=true;
		while $loop; do
			printf "${RED}UNINSTALL${NC} $SCRIPTNAME on $(hostname).\n"
			read -p "Are you sure? [Y/n]: " var1
			loop=false;
			if [ "$var1" == 'Y' ] || [ "$var1" == 'y' ]; then
				printf "Okay! You have 5 sec until starting the ${RED}UNINSTALL${NC} process on $(hostname). Press Ctrl + C to exit.\n"
				for i in {5..1}; do echo $i && sleep 1; done
			elif [ "$var1" == 'N' ] || [ "$var1" == 'n' ]; then
				echo "Okay, exit."
				exit 9
			else
				echo "Enter a valid response Y or n";
				loop=true;
			fi
		done
	fi

	#
	### Starting Uninstall ###
	#

	# Remove crontab file
	if [ -f "$CRONLOCATION" ]; then
		rm -r "$CRONLOCATION"
		printf "\nCrontab file has been removed. ${GR}OK.${NC}"
	else
		printf "\nCrontab file not found. ${GR}OK.${NC}"
	fi

	# Remove the script
	[ -f "$SCRIPTLOCATION" ] && rm -f "$SCRIPTLOCATION" && printf "$SCRIPTNAME has been removed. ${GR}OK.${NC}" || printf "Script not found. ${GR}OK.${NC}"

	# Remove iptable rules
	N=1
	for IPTABLERULE in "$IPTABLE1" "$IPTABLE2" "$IPTABLE3" "$IPTABLE4"; do
		if [ $(iptables -S | grep -cF -- "-A $IPTABLERULE") -gt 0 ]; then
			iptables -D $IPTABLERULE
			printf "#$N iptable rule has been removed. ${GR}OK.${NC}"
			(( N = N + 1 ))
		else
			printf "#$N iptable rule not found. ${GR}OK.${NC}"
			(( N = N + 1 ))
		fi
	done

	# Remove Whitelist rules
	if [ -f $WHITELISTLOCATION ]; then
		while read WHILELISTIP; do
			# Validate IP address
			if [[ "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
				iptables -D INPUT -s $WHILELISTIP -j ACCEPT
			fi
		done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
		printf "Whitelist removed from iptables if any. ${GR}OK.${NC}"
	fi

	# Remove Whitelist
	[ -f "$WHITELISTLOCATION" ] && rm -f "$WHITELISTLOCATION" && printf "Whitelist has been removed. ${GR}OK.${NC}" || printf "Whitelist not found. ${GR}OK.${NC}"

	# Remove ipset rules
	for IPSETRULE in scanned_ports port_scanners; do
		if [ $(ipset list | grep -c "$IPSETRULE") -gt 0 ]; then
			sleep 1
			ipset destroy $IPSETRULE
			printf "$IPSETRULE ipset rule has been removed. ${GR}OK.${NC}"
		else
			printf "$IPSETRULE ipset rule not found. ${GR}OK.${NC}"
		fi
	done

	printf "\nIf the $SCRIPTNAME removed accidently, run this below command to install it again:\n"
	printf "curl -s $GITHUBRAW | sudo bash /dev/stdin -i\n"
fi

##
########### Menu: Verify ###########
##

if [ "$OPT" == '-v' ] || [ "$OPTL" == '--verify' ]; then

	# Crontab verify
	[ ! -f "$CRONLOCATION" ] && printf "\nCrontab entry ${RED}not found.${NC}" || printf "\nCrontab entry found. ${GR}OK.${NC}"

	# Verify script location
	if [ -f "$SCRIPTLOCATION" ]; then
		printf "Script found. ${GR}OK.${NC}"

		# Verify execute permission
		[ -x "$SCRIPTLOCATION" ] && printf "The script is executable. ${GR}OK.${NC}" || printf "The execute permission is ${RED}missing.${NC} Fix it by run: chmod +x $SCRIPTLOCATION"

	else
		printf "Script ${RED}not found.${NC}"
	fi

	IPSETCOMMANDCHECK

	IPTABLECOMMANDCHECK

	[ $(iptables -S | grep -c port_scanners) -gt 0 ] && [ $(iptables -S | grep -c scanned_ports) -gt 0 ] && printf "iptables rules have been configured. You are protected! ${GR}OK.${NC}" || printf "iptables rules are ${RED}not configured!${NC}"

	if [ -f $WHITELISTLOCATION ]; then
		while read WHILELISTIP; do
			# Validate IP address
			if [[ ! "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
				printf "$WHILELISTIP is ${RED}not valid${NC} IPv4 address in the Whitelist and it will be ignored. May you have to fix it by choose Edit Whitelist from the menu."
			fi
		done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
	fi
fi


##
########### Menu: Update ###########
##

[ "$OPT" == '-up' ] || [ "$OPTL" == '--update' ] && UPDATE
