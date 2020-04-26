#!/bin/bash
SCRIPTNAME="Portscan Protection"
VERSION="26-04-2020"
SCRIPTLOCATION="/usr/local/sbin/portscan-protection.sh"
CRONLOCATION="/etc/cron.d/portscan-protection"
AUTOUPDATE="YES" # Edit this variable to "NO" if you don't want to auto update this script (NOT RECOMMENDED)

#
# Define some functions
#

IPSETCOMMANDCHECK()
{
	# Check the ipset command
	! which ipset > /dev/null && echo -e "\nipset command ${RED}not found${NC}. Exiting...\n" && exit || echo -e "ipset command found. ${GR}OK.${NC}"
}

IPTABLECOMMANDCHECK()
{
	# Check the iptables command
	! which iptables > /dev/null && echo -e "iptables command ${RED}not found${NC}. Exiting...\n" && exit || echo -e "iptables command found. ${GR}OK.${NC}"
}

UPDATE()
{
	# Getting info about the latest GitHub version
	NEW=$(curl -L --silent "https://github.com/Feriman22/portscan-protection/releases/latest" | grep css-truncate-target | grep span | cut -d ">" -f2 | cut -d "<" -f1 | tail -1)
	
	# Compare the installed and the GitHub stored version - Only internal, not available by any argument
	if [[ "$1" == "ONLYCHECK" ]] && [[ "$NEW" != "$VERSION" ]]; then
		[ "$1" != '--cron' ] && echo -e "New version ${GR}available!${NC}"
	else
		[[ "$1" == "ONLYCHECK" ]] && [ "$1" != '--cron' ] && echo -e "The script is ${GR}up to date.${NC}"
	fi

	# Check the current installation
	if [[ "$1" != "ONLYCHECK" ]] && [ -f "$CRONLOCATION" ] && [ -x "$SCRIPTLOCATION" ]; then

		# Check the GitHub - Is it available? - Exit if not
		[ "$1" != '--cron' ] && [[ ! "$NEW" ]] && echo -e "GitHub is ${RED}not available now.${NC} Try again later." && exit
		[ "$1" == '--cron' ] && [[ ! "$NEW" ]] && exit

		# Compare the installed and the GitHub stored version
		if [[ "$NEW" != "$(awk '/VERSION=/' "$SCRIPTLOCATION" | grep -o -P '(?<=").*(?=")')" ]]; then
			wget -q https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection.sh -O $SCRIPTLOCATION
			[ "$1" != '--cron' ] && echo -e "Script has been ${GR}updated.${NC}"
		else
			[ "$1" != '--cron' ] && echo -e "The script is ${GR}up to date.${NC}"
		fi
	else
		[[ "$1" != "ONLYCHECK" ]] && [ "$1" != '--cron' ] && echo -e "Script ${RED}not installed.${NC} Install first then you can update it."
	fi
}

if [ "$1" != '--cron' ]; then
	# Coloring
	RED='\033[0;31m' # Red Color
	GR='\033[0;32m' # Green Color
	YL='\033[0;33m' # Yellow Color
	NC='\033[0m' # No Color

	echo -e "\n$SCRIPTNAME\n"
	echo "Author: Feriman"
	echo "URL: https://github.com/Feriman22/portscan-protection"
	echo "Open GitHub page to read the manual and check new releases"
	echo "Version: $VERSION"
	UPDATE ONLYCHECK # Check new version
	echo -e "${GR}If you found it useful, please donate via PayPal: https://paypal.me/BajzaFerenc${NC}\n"
fi

# Check the root permission
[ ! $(id -u) = 0 ] && echo -e "${RED}Run as root!${NC} Exiting...\n" && exit

# Define ipset and iptable rules - Used at magic and uninstall part
IPSET1='port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600'
IPSET2='scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60'
IPTABLE1='INPUT -m state --state INVALID -j DROP'
IPTABLE2='INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist'
IPTABLE3='INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP'
IPTABLE4='INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst'

# Enter in this section only if run by cron - It will do the magic
if [ "$1" == '--cron' ]; then
	[ $(ipset list | grep -c port_scanners) -lt 1 ] && ipset create $IPSET1
	[ $(ipset list | grep -c scanned_ports) -lt 1 ] && ipset create $IPSET2
	[ $(iptables -S | grep -cF -- "-A $IPTABLE1") -lt 1 ] && iptables -A $IPTABLE1
	[ $(iptables -S | grep -cF -- "-A $IPTABLE2") -lt 1 ] && iptables -A $IPTABLE2
	[ $(iptables -S | grep -cF -- "-A $IPTABLE3") -lt 1 ] && iptables -A $IPTABLE3
	[ $(iptables -S | grep -cF -- "-A $IPTABLE4") -lt 1 ] && iptables -A $IPTABLE4

	# Auto update if not disabled
	[ "$AUTOUPDATE" == "YES" ] && UPDATE --cron

	# Exit, because it run by cron
	exit
fi

# Call the menu
if [ "$1" == "-i" ] || [ "$1" == "-u" ] || [ "$1" == "-v" ] || [ "$1" == "--install" ] || [ "$1" == "--uninstall" ] || [ "$1" == "--verify" ] || [ "$1" == "-up" ] || [ "$1" == "--update" ]; then
	OPT="$1" && OPTL="$1" && ARG="YES"
else
	PS3='Please enter your choice: '
	options=("Install" "Uninstall" "Verify" "Update" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"Install")
				OPT='-i' && OPTL='--install' && break
				;;
			"Uninstall")
				OPT='-u' && OPTL='--uninstall' && break
				;;
			"Verify")
				OPT='-v' && OPTL='--verify' && break
				;;
			"Update")
				OPT='-up' && OPTL='--update' && break
				;;
			"Quit")
				break
				;;
			*) echo "Invalid option $REPLY";;
		esac
	done
fi

##
########### Choosed the Install ###########
##

if [ "$OPT" == '-i' ] || [ "$OPTL" == '--install' ]; then

	#
	### Start Installation ###
	#

	# Start count the time of install process
	SECONDS=0

	IPSETCOMMANDCHECK
	
	IPTABLECOMMANDCHECK

	# Set crontab rule if doesn't exists yet
	[ ! -f "$CRONLOCATION" ] && echo -e "# $SCRIPTNAME installed at $(date)\n@reboot sleep 30 && $SCRIPTLOCATION --cron" > "$CRONLOCATION" && echo -e "Crontab entry has been set. ${GR}OK.${NC}" || echo -e "Crontab entry ${GR}already set.${NC}"

	# Copy the script to $SCRIPTLOCATION and add execute permission
	if [ "$(dirname "$0")/$(basename "$0")" != "$SCRIPTLOCATION" ]; then
		/bin/cp -rf "$0" /usr/local/sbin && chmod +x "$SCRIPTLOCATION" && echo -e "This script has been copied in $SCRIPTLOCATION ${GR}OK.${NC}"
	else
		echo -e "The script already copied to destination or has been updated. Nothing to do. ${GR}OK.${NC}"
	fi

	# First "cron like" run to activate the iptable rules
	$SCRIPTLOCATION --cron && echo -e "iptable rules have been activated. You are protected! ${GR}OK.${NC}\n"

	# Happy ending.
	echo -e "${GR}Done.${NC} Full install time was $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
fi


##
########### Choosed the Uninstall ###########
##

if [ "$OPT" == '-u' ] || [ "$OPTL" == '--uninstall' ]; then
	if [ "$ARG" != 'YES' ]; then
		loop=true;
		while $loop; do
			echo -e "${RED}UNINSTALL${NC} $SCRIPTNAME on $(hostname).\n"
			read -p "Are you sure? [Y/n]: " var1
			loop=false;
			if [ "$var1" == 'Y' ] || [ "$var1" == 'y' ]; then
				echo -e "Okay! You have 5 sec until start the ${RED}UNINSTALL${NC} process on $(hostname). Press Ctrl + C to exit.\n"
				for i in {5..1}; do echo $i && sleep 1; done
			elif [ "$var1" == 'n' ]; then
				echo "Okay, exit."
				exit
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
		echo -e "\nCrontab file removed. ${GR}OK.${NC}"
	else
		echo -e "\nCrontab file not found. ${GR}OK.${NC}"
	fi

	# Remove the script
	[ -f "$SCRIPTLOCATION" ] && rm -f "$SCRIPTLOCATION" && echo -e "The script removed. ${GR}OK.${NC}" || echo -e "Script not found. ${GR}OK.${NC}"
	
	
	# Remove ipset and iptable rules
	if [ $(iptables -S | grep -cF -- "-A $IPTABLE1") -gt 0 ]; then
		iptables -D $IPTABLE1
		echo -e "1st iptable rule has been removed. ${GR}OK.${NC}"
	else
		echo -e "1st iptable rule not found. ${GR}OK.${NC}"
	fi

	if [ $(iptables -S | grep -cF -- "-A $IPTABLE2") -gt 0 ]; then
		iptables -D $IPTABLE2
		echo -e "2nd iptable rule has been removed. ${GR}OK.${NC}"
	else
		echo -e "2nd iptable rule not found. ${GR}OK.${NC}"
	fi

	if [ $(iptables -S | grep -cF -- "-A $IPTABLE3") -gt 0 ]; then
		iptables -D $IPTABLE3
		echo -e "3rd iptable rule has been removed. ${GR}OK.${NC}"
	else
		echo -e "3rd iptable rule not found. ${GR}OK.${NC}"
	fi

	if [ $(iptables -S | grep -cF -- "-A $IPTABLE4") -gt 0 ]; then
		iptables -D $IPTABLE4
		echo -e "4th iptable rule has been removed. ${GR}OK.${NC}"
	else
		echo -e "4th iptable rule not found. ${GR}OK.${NC}"
	fi

	if [ $(ipset list | grep -c port_scanners) -gt 0 ]; then
		ipset destroy port_scanners
		echo -e "1st ipset rule has been removed. ${GR}OK.${NC}"
	else
		echo -e "1st ipset rule not found. ${GR}OK.${NC}"
	fi

	if [ $(ipset list | grep -c scanned_ports) -gt 0 ]; then
		ipset destroy scanned_ports
		echo -e "2nd ipset rule has been removed. ${GR}OK.${NC}\n"
	else
		echo -e "2nd ipset rule not found. ${GR}OK.${NC}\n"
	fi

fi


##
########### Choosed the Verify ###########
##

if [ "$OPT" == '-v' ] || [ "$OPTL" == '--verify' ]; then

	# Crontab verify
	[ ! -f "$CRONLOCATION" ] && echo -e "\nCrontab entry ${RED}not found.${NC}" || echo -e "\nCrontab entry found. ${GR}OK.${NC}"

	# Verify script location
	if [ -f "$SCRIPTLOCATION" ]; then
		echo -e "Script found. ${GR}OK.${NC}"

		# Verify execute permission
		[ -x "$SCRIPTLOCATION" ] && echo -e "Script is executable. ${GR}OK.${NC}" || echo -e "Execute permission is ${RED}missing.${NC} Fix it by run: chmod +x $SCRIPTLOCATION"

	else
		echo -e "Script ${RED}not found.${NC}"
	fi

	IPSETCOMMANDCHECK
	
	IPTABLECOMMANDCHECK

	[ $(ipset list | grep -c port_scanners) -gt 0 ] && [ $(ipset list | grep -c scanned_ports) -gt 0 ] && echo -e "iptables rules have been configured. You are protected! ${GR}OK.${NC}\n" || echo -e "iptables rules are ${RED}not configured!${NC}\n"
fi


##
########### Choosed the Update ###########
##

[ "$OPT" == '-up' ] || [ "$OPTL" == '--update' ] && UPDATE