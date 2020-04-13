#!/bin/bash
SCRIPTNAME="Portscan Protection"
SCRIPTLOCATION="/root/portscan-protection-test.sh"
CRONLOCATION="/etc/cron.d/portscan-protection"

if [ "$1" != "cron" ]; then
	# Coloring
	RED='\033[0;31m' # Red Color
	GR='\033[0;32m' # Green Color
	YL='\033[0;33m' # Yellow Color
	NC='\033[0m' # No Color

	echo -e "$SCRIPTNAME\n"
	echo -e "Author: Feriman"
	echo -e "URL: https://github.com/Feriman22/portscan-protection"
	echo -e "Version: 13-04-2020"
	echo -e "${GR}If you found it useful, please donate via PayPal: https://paypal.me/BajzaFerenc${NC}\n"
fi

# Check the root permission
[ ! $(id -u) = 0 ] && echo -e "${RED}Run as root!${NC} Exiting...\n" && exit

# Enter in this section only if run by cron - It will do the magic
if [ "$1" == "cron" ]; then
	if [ $(ipset list | grep -c port_scanners) -lt 1 ]; then
		ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
	fi

	if [ $(ipset list | grep -c scanned_ports) -lt 1 ]; then
		ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
	fi

	if [ $(iptables -S | grep -c "\-A INPUT \-m state \-\-state INVALID \-j DROP") -lt 1 ]; then
		iptables -A INPUT -m state --state INVALID -j DROP
	fi

	if [ $(iptables -S | grep -c "\-A INPUT \-m state \-\-state NEW \-m set ! \-\-match\-set scanned_ports src,dst \-m hashlimit \-\-hashlimit\-above 1/hour \-\-hashlimit\-burst 5 \-\-hashlimit\-mode srcip \-\-hashlimit\-name portscan \-\-hashlimit\-htable\-expire 10000 \-j SET \-\-add\-set port_scanners src \-\-exist") -lt 1 ]; then
		iptables -A INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist
	fi

	if [ $(iptables -S | grep -c "\-A INPUT \-m state \-\-state NEW \-m set \-\-match\-set port_scanners src \-j DROP") -lt 1 ]; then
		iptables -A INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP
	fi

	if [ $(iptables -S | grep -c "\-A INPUT \-m state \-\-state NEW \-j SET \-\-add\-set scanned_ports src,dst") -lt 1 ]; then
		iptables -A INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst
	fi

	# Exit, because it run by cron
	exit
fi

# Call the menu
PS3='Please enter your choice: '
options=("Install" "Uninstall" "Verify" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install")
			OPT=1 && break
            ;;
        "Uninstall")
			OPT=2 && break
            ;;
        "Verify")
			OPT=3 && break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done


##
########### Choosed the Install ###########
##

if [ "$OPT" == "1" ]; then

	#
	### Start Installation ###
	#

	# Start count the time of install process
	SECONDS=0

	# Check the ipset command
	! which ipset > /dev/null && echo -e "\nipset command ${RED}not found${NC}. Exiting..." && exit || echo -e "\nipset command found. ${GR}OK.${NC}"

	# Check the iptables command
	! which iptables > /dev/null && echo -e "iptables command ${RED}not found${NC}. Exiting...\n" && exit || echo -e "iptables command found. ${GR}OK.${NC}"

	# Set crontab rule if doesn't exists yet
	[ ! -f "$CRONLOCATION" ] && echo -e "# $SCRIPTNAME - Set at $(date)\n@reboot sleep 30 && $SCRIPTLOCATION" > "$CRONLOCATION" && echo -e "Crontab entry has been set. ${GR}OK.${NC}" || echo -e "Crontab entry ${YL}already set.${NC}"

	# Copy the script to $SCRIPTLOCATION and then remove from original place
	if [ "$(pwd)/$(basename "$0")" != "$SCRIPTLOCATION" ]; then
		/bin/cp -rf "$0" /root && chmod 700 "$SCRIPTLOCATION" && echo -e "This script has been copied to $SCRIPTLOCATION ${GR}OK.${NC}" && rm "$0" && echo -e "The script removed itself from $0. ${GR}OK.${NC}\n"
	else
		echo -e "The script already copied to destination or has been updated. Nothing to do. ${GR}OK.${NC}\n"
	fi

	# First "cron like" run to activate the iptable rules
	$SCRIPTLOCATION cron

	# Happy ending.
	echo -e "${GR}Done.${NC} Full install time was $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

fi


##
########### Choosed the Uninstall ###########
##

if [ "$OPT" == "2" ]; then
	loop=true;
	while $loop; do
		printf "${RED}UNINSTALL${NC} $SCRIPTNAME on $(hostname).\n"
		read -p "Are you sure? [Y/n]: " var1
		loop=false;
		if [ "$var1" == 'Y' ] || [ "$var1" == 'y' ]; then
			printf "Okay! You have 5 sec until start the ${RED}UNINSTALL${NC} process on $(hostname). Press Ctrl + C to exit.\n"
			for i in {5..1}; do echo $i && sleep 1; done
		elif [ "$var1" == 'n' ]; then
			echo "Okay, exit."
			exit
		else
			echo "Enter a valid response Y or n";
			loop=true;
		fi
	done

	#
	### Starting Uninstall ###
	#

	# Remove crontab entry
	if [ -f "$CRONLOCATION" ]; then
		rm -r "$CRONLOCATION"
		echo -e "\nCrontab entry removed. ${GR}OK.${NC}"
	else
		echo -e "\nCrontab entry is not found. ${GR}OK.${NC}"
	fi

	# Remove the script
	[ -f "$SCRIPTLOCATION" ] && rm -f "$SCRIPTLOCATION" && echo -e "The script removed. ${GR}OK.${NC}\n" || echo -e "The script is not found. ${GR}OK.${NC}\n"

fi


##
########### Choosed the Verify ###########
##

if [ "$OPT" == "3" ]; then

	# Crontab verify
	[ ! -f "$CRONLOCATION" ] && echo -e "\nCrontab entry is ${RED}not found.${NC}" || echo -e "\nCrontab entry found. ${GR}OK.${NC}"

	# Verify script location
	if [ -f "$SCRIPTLOCATION" ]; then
		echo -e "Script found. ${GR}OK.${NC}"

		# Verify execute permission
		[ -x "$SCRIPTLOCATION" ] && echo -e "Script is executable. ${GR}OK.${NC}" || echo -e "Execute permission is ${RED}missing.${NC} Fix it by run: chmod +x $SCRIPTLOCATION"

	else
		echo -e "Script ${RED}not found.${NC}"
	fi

	# Check the ipset command
	! which ipset > /dev/null && echo -e "ipset command ${RED}not found.${NC}" || echo -e "ipset command found. ${GR}OK.${NC}"

	# Check the iptables command
	! which iptables > /dev/null && echo -e "iptables command ${RED}not found${NC}" || echo -e "iptables command found. ${GR}OK.${NC}"

	[ $(ipset list | grep -c port_scanners) -gt 0 ] && [ $(ipset list | grep -c scanned_ports) -gt 0 ] && echo -e "iptables rules have been configured. ${GR}OK.${NC}\n" || echo -e "iptables rules are ${RED}not configured${NC}\n"

fi
