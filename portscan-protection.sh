#!/bin/bash
SCRIPTNAME="Portscan Protection"
SCRIPTLOCATION="/root/portscan-protection.sh"

if [ "$1" != "cron" ]; then
	# Coloring
	RED='\033[0;31m' # Red Color
	GR='\033[0;32m' # Green Color
	YL='\033[0;33m' # Yellow Color
	NC='\033[0m' # No Color

	echo -e "$SCRIPTNAME\n"
	echo -e "Author: Feriman\n"
	echo -e "URL: https://github.com/Feriman22/portscan-protection\n"
	echo -e "Version: 13-04-2020\n"
	echo -e "${GR}If you found it useful, please donate me via PayPal: https://www.paypal.me/BajzaFerenc${NC}\n"
fi

# Check the root permission
[ ! $(id -u) = 0 ] && echo -e "${RED}Run as root!${NC} Exiting...\n" && exit

for i in 1 2 3
do
	[ -f $i ] && rm -f $i
done

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

PS3='Please enter your choice: '
options=("Install" "Uninstall" "Verify" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install")
			touch 1 && break
            ;;
        "Uninstall")
			touch 2 && break
            ;;
        "Verify")
			touch 3 && break
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
if [ -f 1 ]; then

	#
	### Start Installation ###
	#

	# Start count the time of install process
	SECONDS=0
	
	# Check the ipset command
	! which ipset > /dev/null && echo -e "ipset command ${RED}not found${NC}. Exiting...\n" && exit || echo -e "ipset command found. ${GR}OK.${NC}\n"

	# Check the iptables command
	! which iptables > /dev/null && echo -e "iptables command ${RED}not found${NC}. Exiting...\n" && exit || echo -e "iptables command found. ${GR}OK.${NC}\n"
	
	# Set crontab rule if doesn't exists yet
	[ $(crontab -l | grep -c "$SCRIPTLOCATION") -lt "1" ] && (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $SCRIPTLOCATION") | crontab - && echo -e "Crontab entry has been set. ${GR}OK.${NC}\n" || echo -e "Crontab entry ${YL}already set.${NC}\n"
	
	# Copy the script to $SCRIPTLOCATION and then remove from original place
	if [ "$(dirname "$0")/$(basename "$0")" != "$SCRIPTLOCATION" ]; then
		/bin/cp -rf "$(dirname "$0")/$(basename "$0")" /root && chmod 700 "$SCRIPTLOCATION" && echo -e "This script has been copied to $SCRIPTLOCATION ${GR}OK.${NC}\n" && rm $(dirname "$0")/$(basename "$0") && echo -e "The script removed itself. ${GR}OK.${NC}\n"
	else
		echo -e "The script already copied to destination or has been updated.\n"
	fi
	
	# First "cron like" run to activate the iptable rules
	$SCRIPTLOCATION cron

	# Happy ending.
	ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
	echo -e "${GR}Done.${NC} Full install time was $ELAPSED"
fi


##
########### Choosed the Uninstall ###########
##
if [ -f 2 ]; then
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
			rm 2 && exit 1
		else
			echo "Enter a valid response Y or n";
			loop=true;
		fi
	done
	
	#
	### Starting Uninstall ###
	#

	# Remove crontab entry
	if [ $(crontab -l | grep -c "$SCRIPTLOCATION") -gt 0 ]; then
		sed -i '\/root\/portscan-protection.sh/d' /var/spool/cron/crontabs/root
		echo -e "Crontab entry removed. ${GR}OK.${NC}\n"
	else
		echo -e "Crontab entry is not found. ${GR}OK.${NC}\n"
	fi
	
	# Remove the script
	[ -f "$SCRIPTLOCATION" ] && rm -f "$SCRIPTLOCATION" && echo -e "The script removed. ${GR}OK.${NC}\n" || echo -e "The script is not found. ${GR}OK.${NC}\n"
fi


##
########### Choosed the Verify ###########
##
if [ -f 3 ]; then

	# Crontab verify
	[ $(crontab -l | grep -c "$SCRIPTLOCATION") -lt 1 ] && echo -e "Crontab entry is ${RED}not found${NC}\n" || echo -e "Crontab entry found. ${GR}OK.${NC}\n"
	
	# Verify script location
	if [ -f "$SCRIPTLOCATION" ]; then
		echo -e "Script found. ${GR}OK.${NC}\n"
		
		# Verify execute permission
		[ -x "$SCRIPTLOCATION" ] && echo -e "Script is executable. ${GR}OK.${NC}\n" || echo -e "Execute permission is ${RED}missing${NC}. Fix it by run: chmod +x $SCRIPTLOCATION\n"
		
	else
		echo -e "Script ${RED}not found${NC}.\n"
	fi

	# Check the ipset command
	! which ipset > /dev/null && echo -e "ipset command ${RED}not found${NC}\n" || echo -e "ipset command found. ${GR}OK.${NC}\n"
	
	# Check the iptables command
	! which iptables > /dev/null && echo -e "iptables command ${RED}not found${NC}\n" || echo -e "iptables command found. ${GR}OK.${NC}\n"
	
	[ $(ipset list | grep -c port_scanners) -gt 0 ] && [ $(ipset list | grep -c scanned_ports) -gt 0 ] && echo -e "iptables rules have been configured. ${GR}OK.${NC}\n" || echo -e "iptables rules are ${RED}not configured${NC}\n"
fi
