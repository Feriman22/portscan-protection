#!/bin/bash
SCRIPTNAME="Portscan Protection"
VERSION="01-01-2026"
SCRIPTLOCATION="/usr/local/sbin/portscan-protection.sh"
WHITELISTLOCATION="/usr/local/sbin/portscan-protection-white.list"
CONFIGLOCATION="/usr/local/sbin/portscan-protection.conf"
CRONLOCATION="/etc/cron.d/portscan-protection"
SYSTEMDSERVICE="/etc/systemd/system/portscan-protection.service"
SYSTEMDTIMER="/etc/systemd/system/portscan-protection.timer"
GITHUBRAW="https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection.sh"
AUTOUPDATE="YES" # Edit this variable to "NO" if you don't want to auto update this script (NOT RECOMMENDED)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Default configuration values
SSHPORT="22"
FIREWALL_BACKEND="" # Will be auto-detected: iptables or nftables

#
# Define some functions
#

LOADCONFIG()
{
	# Load configuration file if exists
	if [ -f "$CONFIGLOCATION" ]; then
		source "$CONFIGLOCATION"
	fi
}

SAVECONFIG()
{
	# Save configuration to file
	cat > "$CONFIGLOCATION" << EOF
# Portscan Protection Configuration File
# Generated at $(date)

# Auto-update setting (YES or NO)
AUTOUPDATE="$AUTOUPDATE"

# Custom SSH port (default: 22)
SSHPORT="$SSHPORT"

# Firewall backend (iptables or nftables, leave empty for auto-detect)
FIREWALL_BACKEND="$FIREWALL_BACKEND"
EOF
}

DETECTFIREWALL()
{
	# Detect which firewall backend to use
	if [ -n "$FIREWALL_BACKEND" ]; then
		# Use configured backend
		return
	fi
	
	# Auto-detect: prefer nftables if available and iptables-nft is not in use
	if command -v nft > /dev/null 2>&1; then
		# Check if iptables is actually nftables backend
		if command -v iptables > /dev/null 2>&1; then
			if iptables -V 2>/dev/null | grep -q "nf_tables"; then
				FIREWALL_BACKEND="iptables"
			else
				# Both available, check if nftables is actively used
				if nft list tables 2>/dev/null | grep -q "filter\|inet"; then
					FIREWALL_BACKEND="nftables"
				elif iptables -S 2>/dev/null | grep -q "port_scanners\|scanned_ports"; then
					# Existing iptables rules found
					FIREWALL_BACKEND="iptables"
				else
					FIREWALL_BACKEND="nftables"
				fi
			fi
		else
			FIREWALL_BACKEND="nftables"
		fi
	elif command -v iptables > /dev/null 2>&1; then
		FIREWALL_BACKEND="iptables"
	else
		FIREWALL_BACKEND=""
	fi
}

IPSETCOMMANDCHECK()
{
	# Check the ipset command (only for iptables backend)
	if [ "$FIREWALL_BACKEND" == "iptables" ]; then
		! command -v ipset > /dev/null && printf "\nipset command ${RED}not found${NC}.\n" && exit 6 || printf "ipset command found. ${GR}OK.${NC}\n"
	fi
}


IPTABLECOMMANDCHECK()
{
	# Check the iptables command
	if [ "$FIREWALL_BACKEND" == "iptables" ]; then
		! command -v iptables > /dev/null && printf "iptables command ${RED}not found${NC}.\n" && exit 7 || printf "iptables command found. ${GR}OK.${NC}\n"
	fi
}

NFTCOMMANDCHECK()
{
	# Check the nft command
	if [ "$FIREWALL_BACKEND" == "nftables" ]; then
		! command -v nft > /dev/null && printf "nft command ${RED}not found${NC}.\n" && exit 11 || printf "nft command found. ${GR}OK.${NC}\n"
	fi
}

DETECTSYSTEMD()
{
	# Check if systemd is available and running
	if command -v systemctl > /dev/null 2>&1 && systemctl --version > /dev/null 2>&1; then
		# Check if systemd is actually the init system
		if [ -d /run/systemd/system ]; then
			return 0
		fi
	fi
	return 1
}

SETCRONTAB()
{
	[ ! -f "$CRONLOCATION" ] || ! grep -q "reboot root sleep" "$CRONLOCATION" && printf "# $SCRIPTNAME installed at $(date)\n@reboot root sleep 30 && $SCRIPTLOCATION --cron\n\n" > "$CRONLOCATION" && printf "Crontab entry has been set. ${GR}OK.${NC}\n" || printf "Crontab entry ${GR}already set.${NC}\n"
}

SETSYSTEMD()
{
	# Create systemd service file
	cat > "$SYSTEMDSERVICE" << EOF
[Unit]
Description=Portscan Protection Service
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPTLOCATION --cron
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

	# Create systemd timer for auto-update checks
	cat > "$SYSTEMDTIMER" << EOF
[Unit]
Description=Portscan Protection Auto-Update Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=24h

[Install]
WantedBy=timers.target
EOF

	# Reload systemd and enable service
	systemctl daemon-reload
	systemctl enable portscan-protection.service > /dev/null 2>&1
	systemctl enable portscan-protection.timer > /dev/null 2>&1
	printf "Systemd service has been set. ${GR}OK.${NC}\n"
}

REMOVESYSTEMD()
{
	if [ -f "$SYSTEMDSERVICE" ]; then
		systemctl stop portscan-protection.service > /dev/null 2>&1
		systemctl stop portscan-protection.timer > /dev/null 2>&1
		systemctl disable portscan-protection.service > /dev/null 2>&1
		systemctl disable portscan-protection.timer > /dev/null 2>&1
		rm -f "$SYSTEMDSERVICE" "$SYSTEMDTIMER"
		systemctl daemon-reload
		printf "Systemd service has been removed. ${GR}OK.${NC}\n"
	else
		printf "Systemd service not found. ${GR}OK.${NC}\n"
	fi
}

SETPERSISTENCE()
{
	# Use systemd if available, otherwise fallback to cron
	if DETECTSYSTEMD; then
		SETSYSTEMD
		# Remove old cron entry if exists (migration from old version)
		[ -f "$CRONLOCATION" ] && rm -f "$CRONLOCATION" && printf "Old crontab entry removed (migrated to systemd). ${GR}OK.${NC}\n"
	else
		SETCRONTAB
	fi
}

REMOVEPERSISTENCE()
{
	# Remove both systemd and cron (for clean uninstall)
	if DETECTSYSTEMD; then
		REMOVESYSTEMD
	fi
	if [ -f "$CRONLOCATION" ]; then
		rm -f "$CRONLOCATION"
		printf "Crontab file has been removed. ${GR}OK.${NC}\n"
	else
		printf "Crontab file not found. ${GR}OK.${NC}\n"
	fi
}

CHECKCRONSERVICE()
{
	# Check if cron service is enabled and running
	if ! DETECTSYSTEMD || [ -f "$CRONLOCATION" ]; then
		# Using cron, check if it's running
		if command -v systemctl > /dev/null 2>&1; then
			if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
				printf "Cron service is ${GR}running.${NC}\n"
			else
				printf "Cron service is ${RED}not running!${NC} Enable it with: systemctl enable --now cron\n"
			fi
		elif command -v service > /dev/null 2>&1; then
			if service cron status > /dev/null 2>&1 || service crond status > /dev/null 2>&1; then
				printf "Cron service is ${GR}running.${NC}\n"
			else
				printf "Cron service is ${RED}not running!${NC}\n"
			fi
		fi
	fi
}

WHITELIST()
{
	[ ! -f "$WHITELISTLOCATION" ] && printf "# This file is part of $SCRIPTNAME\n# Add one IP per line to this file. These IP addresses will be never blocked. Note: Only IPv4 addresses are supported.\n# More info on GitHub: https://github.com/Feriman22/portscan-protection\n# If you found it useful, please donate via PayPal: https://paypal.me/BajzaFerenc\n\n# Thank you!\n\n127.0.0.1" > $WHITELISTLOCATION
	for i in nano vi vim; do
		if command -v $i > /dev/null; then
			$i "$WHITELISTLOCATION"
			"$SCRIPTLOCATION" --cron
			printf "Whitelist has been activated if the file has been modified.\n" ; FOUND="1"
			break
		fi
	done
	[ "$FOUND" != "1" ] && echo "nano, vi or vim is not found. Edit manually the whitelist: $WHITELISTLOCATION"
}

SETSSHPORT()
{
	printf "Current SSH port: ${YL}$SSHPORT${NC}\n"
	read -p "Enter new SSH port (1-65535) or press Enter to keep current: " NEWSSHPORT
	if [ -n "$NEWSSHPORT" ]; then
		if [[ "$NEWSSHPORT" =~ ^[0-9]+$ ]] && [ "$NEWSSHPORT" -ge 1 ] && [ "$NEWSSHPORT" -le 65535 ]; then
			SSHPORT="$NEWSSHPORT"
			SAVECONFIG
			printf "SSH port set to ${GR}$SSHPORT${NC}. Reapplying rules...\n"
			"$SCRIPTLOCATION" --cron
		else
			printf "${RED}Invalid port number.${NC}\n"
		fi
	fi
}

UPDATE()
{
	# Getting info about the latest GitHub version
	NEW=$(curl -s "$GITHUBRAW" | awk -F'"' '/^VERSION/ {print $2}')

	# Compare the installed and the GitHub stored version - Only internal, not available by any argument
	if [[ "$1" == "ONLYCHECK" ]] && [[ "$NEW" != "$VERSION" ]]; then
		[ "$1" != '--cron' ] && printf "New version ${YL}available!${NC}\n"
	else
		[[ "$1" == "ONLYCHECK" ]] && [ "$1" != '--cron' ] && printf "The downloaded $SCRIPTNAME is ${GR}up to date.${NC}\n\n"
	fi

	# Check the current installation
	if [[ "$1" != "ONLYCHECK" ]] && [ -x "$SCRIPTLOCATION" ]; then

		# Check the GitHub - Is it available? - Exit if not
  		if [[ ! "$NEW" ]]; then
			[ "$1" != '--cron' ] && printf "GitHub is ${RED}not available now.${NC} Try again later.\n"
   			exit 8
   		fi

		# Compare the installed and the GitHub stored version
		if [[ "$NEW" != "$VERSION" ]]; then
			curl -s -o "$SCRIPTLOCATION" "$GITHUBRAW"
			# Re-apply persistence settings
			SETPERSISTENCE
			[ "$1" != '--cron' ] && printf "Script has been ${GR}updated.${NC}\n"
		else
			[ "$1" != '--cron' ] && printf "The installed $SCRIPTNAME is ${GR}up to date.${NC}\n\n"
		fi
	else
		[[ "$1" != "ONLYCHECK" ]] && [ "$1" != '--cron' ] && printf "Script ${RED}not installed.${NC} Install first then you can update it.\n"
	fi
}

TOGGLEAUTOUPDATE()
{
	LOADCONFIG
	if [ "$AUTOUPDATE" == "YES" ]; then
		AUTOUPDATE="NO"
		SAVECONFIG
		printf "Auto-update has been ${YL}disabled.${NC}\n"
	else
		AUTOUPDATE="YES"
		SAVECONFIG
		printf "Auto-update has been ${GR}enabled.${NC}\n"
	fi
}

# nftables functions
SETUP_NFTABLES()
{
	# Create nftables rules for portscan protection
	# Check if our table exists
	if ! nft list table inet portscan_protection > /dev/null 2>&1; then
		nft add table inet portscan_protection
	fi
	
	# Create sets if they don't exist
	if ! nft list set inet portscan_protection port_scanners > /dev/null 2>&1; then
		nft add set inet portscan_protection port_scanners { type ipv4_addr\; flags timeout\; timeout 10m\; }
	fi
	
	if ! nft list set inet portscan_protection scanned_ports > /dev/null 2>&1; then
		nft add set inet portscan_protection scanned_ports { type ipv4_addr . inet_service\; flags timeout\; timeout 1m\; }
	fi
	
	# Create chain if it doesn't exist
	if ! nft list chain inet portscan_protection input > /dev/null 2>&1; then
		nft add chain inet portscan_protection input { type filter hook input priority -1\; policy accept\; }
	fi
	
	# Add rules (check if they exist first)
	RULES_COUNT=$(nft list chain inet portscan_protection input 2>/dev/null | grep -c "add @port_scanners\|@port_scanners drop\|add @scanned_ports")
	
	if [ "$RULES_COUNT" -lt 3 ]; then
		# Flush and recreate rules
		nft flush chain inet portscan_protection input
		
		# Drop invalid packets
		nft add rule inet portscan_protection input ct state invalid drop
		
		# Allow established connections
		nft add rule inet portscan_protection input ct state established,related accept
		
		# Allow SSH port
		nft add rule inet portscan_protection input tcp dport $SSHPORT accept
		
		# Drop known port scanners
		nft add rule inet portscan_protection input ip saddr @port_scanners drop
		
		# Rate limit new connections - add to port_scanners if too fast
		nft add rule inet portscan_protection input ct state new meter portscan_meter { ip saddr limit rate over 5/minute burst 5 packets } add @port_scanners { ip saddr }
		
		# Track scanned ports
		nft add rule inet portscan_protection input ct state new add @scanned_ports { ip saddr . tcp dport }
	fi
}

REMOVE_NFTABLES()
{
	# Remove nftables rules
	if nft list table inet portscan_protection > /dev/null 2>&1; then
		nft delete table inet portscan_protection
		printf "nftables rules have been removed. ${GR}OK.${NC}\n"
	else
		printf "nftables rules not found. ${GR}OK.${NC}\n"
	fi
}

ADD_WHITELIST_NFTABLES()
{
	# Add whitelist IPs to nftables
	if [ -f $WHITELISTLOCATION ]; then
		# Create whitelist set if it doesn't exist
		if ! nft list set inet portscan_protection whitelist > /dev/null 2>&1; then
			nft add set inet portscan_protection whitelist { type ipv4_addr\; }
		fi
		
		while read WHILELISTIP; do
			if [[ "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
				nft add element inet portscan_protection whitelist { $WHILELISTIP } 2>/dev/null
			fi
		done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
		
		# Add whitelist accept rule at the beginning if not exists
		if ! nft list chain inet portscan_protection input 2>/dev/null | grep -q "@whitelist accept"; then
			nft insert rule inet portscan_protection input ip saddr @whitelist accept 2>/dev/null
		fi
	fi
}

# Load configuration
LOADCONFIG

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
	printf "${GR}If you found it useful${NC}, please donate via PayPal: https://paypal.me/BajzaFerenc\n\n"
fi

# Check the root permission
[ ! "$(id -u)" = 0 ] && printf "${RED}Run as root!${NC}\n" && exit 5

# Detect firewall backend
DETECTFIREWALL

# Check required commands based on firewall backend
if [ "$FIREWALL_BACKEND" == "iptables" ]; then
	for i in curl ipset iptables; do ! command -v $i > /dev/null && echo "$i command ${RED}not found${NC}" && NOT_FOUND="1"; done
elif [ "$FIREWALL_BACKEND" == "nftables" ]; then
	for i in curl nft; do ! command -v $i > /dev/null && echo "$i command ${RED}not found${NC}" && NOT_FOUND="1"; done
else
	printf "${RED}No supported firewall found!${NC} Install iptables+ipset or nftables.\n"
	exit 10
fi
[ "$NOT_FOUND" == "1" ] && exit 10

# Define ipset and iptable rules - Used at magic and uninstall part (for iptables backend)
IPSET1='port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600'
IPSET2='scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60'
IPTABLE1='INPUT -m state --state INVALID -j DROP'
IPTABLE2='INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist'
IPTABLE3='INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP'
IPTABLE4='INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst'

# Enter in this section only if run by cron - It will do the magic
if [ "$1" == '--cron' ]; then
	# Load config
	LOADCONFIG

	if [ "$FIREWALL_BACKEND" == "nftables" ]; then
		# nftables setup
		SETUP_NFTABLES
		ADD_WHITELIST_NFTABLES
	else
		# iptables setup (original behavior)
		# Add Whitelist IPs if any
		if [ -f $WHITELISTLOCATION ]; then
			while read WHILELISTIP; do
				# Validate IP address
				if [[ "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]] && [ $(iptables -S | grep -cF -- "-A INPUT -s $WHILELISTIP/32 -j ACCEPT") -lt 1 ]; then
					iptables -I INPUT -s $WHILELISTIP -j ACCEPT
				fi
			done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
		fi

		# Allow SSH port if custom
		if [ "$SSHPORT" != "22" ]; then
			if [ $(iptables -S | grep -cF -- "-A INPUT -p tcp --dport $SSHPORT -j ACCEPT") -lt 1 ]; then
				iptables -I INPUT -p tcp --dport $SSHPORT -j ACCEPT
			fi
		fi

		ipset list | grep -q port_scanners || ipset create $IPSET1
		ipset list | grep -q scanned_ports || ipset create $IPSET2
		iptables -S | grep -qF -- "-A $IPTABLE1" || iptables -A $IPTABLE1
		iptables -S | grep -qF -- "-A $IPTABLE2" || iptables -A $IPTABLE2
		iptables -S | grep -qF -- "-A $IPTABLE3" || iptables -A $IPTABLE3
		iptables -S | grep -qF -- "-A $IPTABLE4" || iptables -A $IPTABLE4
	fi

	# Auto update if not disabled
	[ "$AUTOUPDATE" == "YES" ] && UPDATE --cron

	# Exit, because it run by cron
	exit 0
fi

# Call the menu
if [ "$1" == "-i" ] || [ "$1" == "-u" ] || [ "$1" == "-v" ] || [ "$1" == "--install" ] || [ "$1" == "--uninstall" ] || [ "$1" == "--verify" ] || [ "$1" == "-up" ] || [ "$1" == "--update" ] || [ "$1" == "-r" ] || [ "$1" == "--reinstall" ] || [ "$1" == "--toggle-autoupdate" ] || [ "$1" == "--set-sshport" ]; then
	OPT="$1" && OPTL="$1" && ARG="YES"
else
	PS3='Please enter your choice: '
	[ -f "$SCRIPTLOCATION" ] && options=("Verify" "Edit Whitelist" "Set SSH Port" "Toggle Auto-Update" "Update from GitHub" "Reinstall" "Uninstall" "Quit")
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
			"Reinstall")
				OPT='-r' && OPTL='--reinstall' && break
				;;
			"Edit Whitelist")
				WHITELIST ; break
				;;
			"Set SSH Port")
				SETSSHPORT ; break
				;;
			"Toggle Auto-Update")
				TOGGLEAUTOUPDATE ; break
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

	printf "Detected firewall backend: ${YL}$FIREWALL_BACKEND${NC}\n"

	if [ "$FIREWALL_BACKEND" == "iptables" ]; then
		IPSETCOMMANDCHECK
		IPTABLECOMMANDCHECK
	else
		NFTCOMMANDCHECK
	fi

	# Set persistence (systemd or cron)
	SETPERSISTENCE

	# Copy the script to $SCRIPTLOCATION and add execute permission
	INSTALLERLOCATION=$(realpath $0)
	if [ "$INSTALLERLOCATION" != "$SCRIPTLOCATION" ]; then
		curl -s -o "$SCRIPTLOCATION" "$GITHUBRAW" && chmod +x "$SCRIPTLOCATION" && printf "$SCRIPTNAME has been copied in $SCRIPTLOCATION ${GR}OK.${NC}\n"
	else
		printf "$SCRIPTNAME already copied to destination. Nothing to do. ${GR}OK.${NC}\n"
	fi

	# Create default config if not exists
	[ ! -f "$CONFIGLOCATION" ] && SAVECONFIG && printf "Configuration file created. ${GR}OK.${NC}\n"

	# First "cron like" run to activate the firewall rules
	"$SCRIPTLOCATION" --cron && printf "Firewall rules have been activated. You are protected! ${GR}OK.${NC}\n"

	# Finish
	printf "\n${GR}Note:${NC} If you want to Edit Whitelist, Set SSH Port, or Verify the install, just run the below command:\nsudo $SCRIPTLOCATION\n\n"
	printf "${GR}Done.${NC} The install was $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec. That was so quick, wasn't?\n"
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

	# Remove persistence (cron and/or systemd)
	printf "\n"
	REMOVEPERSISTENCE

	# Remove the script
	[ -f "$SCRIPTLOCATION" ] && rm -f "$SCRIPTLOCATION" && printf "$SCRIPTNAME has been removed. ${GR}OK.${NC}\n" || printf "Script not found. ${GR}OK.${NC}\n"

	# Remove config file
	[ -f "$CONFIGLOCATION" ] && rm -f "$CONFIGLOCATION" && printf "Configuration file has been removed. ${GR}OK.${NC}\n" || printf "Configuration file not found. ${GR}OK.${NC}\n"

	if [ "$FIREWALL_BACKEND" == "nftables" ]; then
		REMOVE_NFTABLES
	else
		# Remove iptable rules
		N=1
		for IPTABLERULE in "$IPTABLE1" "$IPTABLE2" "$IPTABLE3" "$IPTABLE4"; do
			if iptables -S | grep -qF -- "-A $IPTABLERULE"; then
				iptables -D $IPTABLERULE
				printf "#$N iptable rule has been removed. ${GR}OK.${NC}\n"
			else
				printf "#$N iptable rule not found. ${GR}OK.${NC}\n"
			fi
	  		((N++))
		done

		# Remove Whitelist rules
		if [ -f $WHITELISTLOCATION ]; then
			while read WHILELISTIP; do
				# Validate IP address
				if [[ "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
					iptables -D INPUT -s $WHILELISTIP -j ACCEPT 2>/dev/null
				fi
			done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
			printf "Whitelist removed from iptables if any. ${GR}OK.${NC}\n"
		fi

		# Remove custom SSH port rule
		if [ "$SSHPORT" != "22" ]; then
			iptables -D INPUT -p tcp --dport $SSHPORT -j ACCEPT 2>/dev/null
		fi

		# Remove ipset rules
		for IPSETRULE in scanned_ports port_scanners; do
			if ipset list | grep -q "$IPSETRULE"; then
				sleep 1
				ipset destroy $IPSETRULE
				printf "$IPSETRULE ipset rule has been removed. ${GR}OK.${NC}\n"
			else
				printf "$IPSETRULE ipset rule not found. ${GR}OK.${NC}\n"
			fi
		done
	fi

	# Remove Whitelist
	[ -f "$WHITELISTLOCATION" ] && rm -f "$WHITELISTLOCATION" && printf "Whitelist has been removed. ${GR}OK.${NC}\n" || printf "Whitelist not found. ${GR}OK.${NC}\n"

	printf "\nIf the $SCRIPTNAME removed accidently, run this below command to install it again:\n"
	printf "curl -s $GITHUBRAW | sudo bash /dev/stdin -i\n"
fi

##
########### Menu: Reinstall ###########
##

if [ "$OPT" == '-r' ] || [ "$OPTL" == '--reinstall' ]; then
	printf "Starting ${YL}reinstall${NC} process...\n\n"
	
	# Run uninstall silently
	"$0" -u
	
	printf "\n--- Uninstall complete, starting install ---\n\n"
	
	# Run install
	"$0" -i
fi

##
########### Menu: Verify ###########
##

if [ "$OPT" == '-v' ] || [ "$OPTL" == '--verify' ]; then

	printf "\nFirewall backend: ${YL}$FIREWALL_BACKEND${NC}\n"

	# Check persistence method
	if DETECTSYSTEMD && [ -f "$SYSTEMDSERVICE" ]; then
		if systemctl is-enabled --quiet portscan-protection.service 2>/dev/null; then
			printf "Systemd service is ${GR}enabled.${NC}\n"
		else
			printf "Systemd service is ${RED}not enabled.${NC}\n"
		fi
		if systemctl is-active --quiet portscan-protection.service 2>/dev/null; then
			printf "Systemd service is ${GR}active.${NC}\n"
		else
			printf "Systemd service is ${YL}not active${NC} (will start on boot).\n"
		fi
	elif [ -f "$CRONLOCATION" ]; then
		printf "Crontab entry found. ${GR}OK.${NC}\n"
		CHECKCRONSERVICE
	else
		printf "No persistence method found. ${RED}Not protected after reboot!${NC}\n"
	fi

	# Verify script location
	if [ -f "$SCRIPTLOCATION" ]; then
		printf "Script found. ${GR}OK.${NC}\n"

		# Verify execute permission
		[ -x "$SCRIPTLOCATION" ] && printf "The script is executable. ${GR}OK.${NC}\n" || printf "The execute permission is ${RED}missing.${NC} Fix it by run: chmod +x $SCRIPTLOCATION\n"

	else
		printf "Script ${RED}not found.${NC}\n"
	fi

	# Check config
	if [ -f "$CONFIGLOCATION" ]; then
		printf "Configuration file found. ${GR}OK.${NC}\n"
		printf "  - Auto-update: ${YL}$AUTOUPDATE${NC}\n"
		printf "  - SSH Port: ${YL}$SSHPORT${NC}\n"
	fi

	if [ "$FIREWALL_BACKEND" == "nftables" ]; then
		NFTCOMMANDCHECK
		if nft list table inet portscan_protection > /dev/null 2>&1; then
			printf "nftables rules have been configured. You are protected! ${GR}OK.${NC}\n"
		else
			printf "nftables rules are ${RED}not configured!${NC}\n"
		fi
	else
		IPSETCOMMANDCHECK
		IPTABLECOMMANDCHECK
		iptables -S | grep -q port_scanners && iptables -S | grep -q scanned_ports && printf "iptables rules have been configured. You are protected! ${GR}OK.${NC}\n" || printf "iptables rules are ${RED}not configured!${NC}\n"
	fi

	if [ -f $WHITELISTLOCATION ]; then
		while read WHILELISTIP; do
			# Validate IP address
			if [[ ! "$WHILELISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
				printf "$WHILELISTIP is ${RED}not valid${NC} IPv4 address in the Whitelist and it will be ignored. May you have to fix it by choose Edit Whitelist from the menu.\n"
			fi
		done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
	fi
fi


##
########### Menu: Update ###########
##

[ "$OPT" == '-up' ] || [ "$OPTL" == '--update' ] && UPDATE

##
########### Menu: Toggle Auto-Update ###########
##

[ "$OPTL" == '--toggle-autoupdate' ] && TOGGLEAUTOUPDATE

##
########### Menu: Set SSH Port ###########
##

[ "$OPTL" == '--set-sshport' ] && SETSSHPORT
