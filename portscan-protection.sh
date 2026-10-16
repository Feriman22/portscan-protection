#!/bin/bash
SCRIPTNAME="Portscan Protection"
VERSION="16-10-2026"
SCRIPTLOCATION="/usr/local/sbin/portscan-protection.sh"
WHITELISTLOCATION="/usr/local/sbin/portscan-protection-white.list"
BLACKLISTLOCATION="/usr/local/sbin/portscan-protection-black.list"
BLACKLISTAPPLIEDLOCATION="/usr/local/sbin/portscan-protection-black.applied"
CONFIGLOCATION="/usr/local/sbin/portscan-protection.conf"
CRONLOCATION="/etc/cron.d/portscan-protection"
SYSTEMDSERVICE="/etc/systemd/system/portscan-protection.service"
SYSTEMDTIMER="/etc/systemd/system/portscan-protection.timer"
GITHUBRAW="https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection.sh"
SPONSORURL="https://paypal.me/BajzaFerenc" # Single place to change the support link shown by the script
AUTOUPDATE="YES" # Set to "NO" to disable automatic updates (NOT RECOMMENDED)
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
	
	# Auto-detect the firewall backend
	if ! command -v nft > /dev/null 2>&1; then
		command -v iptables > /dev/null 2>&1 && FIREWALL_BACKEND="iptables"
	elif ! command -v iptables > /dev/null 2>&1; then
		FIREWALL_BACKEND="nftables"
	elif iptables -V 2>/dev/null | grep -q "nf_tables"; then
		FIREWALL_BACKEND="iptables"
	elif ! nft list tables 2>/dev/null | grep -q "filter\|inet" && iptables -S 2>/dev/null | grep -q "port_scanners\|scanned_ports"; then
		FIREWALL_BACKEND="iptables"
	else
		FIREWALL_BACKEND="nftables"
	fi
}

COMMANDCHECK()
{
	# Check the commands of the firewall backend
	[ "$FIREWALL_BACKEND" == "iptables" ] && CHECKS="ipset:6 iptables:7" || CHECKS="nft:11"
	for CHECK in $CHECKS; do
		! command -v ${CHECK%%:*} > /dev/null && printf "${CHECK%%:*} command ${RED}not found${NC}.\n" && exit ${CHECK#*:}
		printf "${CHECK%%:*} command found. ${GR}OK.${NC}\n"
	done
}

DETECTSYSTEMD()
{
	# Check if systemd is the init system
	command -v systemctl > /dev/null 2>&1 && systemctl --version > /dev/null 2>&1 && [ -d /run/systemd/system ] && return 0
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
	# Check if cron service is running
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
}

# IPv4 address
IPV4REGEX='^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$'

GET_WHITELIST_ENTRIES()
{
	# Get the IPs from the whitelist
	[ -f $WHITELISTLOCATION ] || return
	while read WHILELISTIP; do
		[[ "$WHILELISTIP" =~ $IPV4REGEX ]] && echo "$WHILELISTIP"
	done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
}

WHITELIST()
{
	[ ! -f "$WHITELISTLOCATION" ] && printf "# This file is part of $SCRIPTNAME\n# Add one IP per line to this file. These IP addresses will be never blocked. Note: Only IPv4 addresses are supported.\n# More info on GitHub: https://github.com/Feriman22/portscan-protection\n# If you found it useful, please support the project: $SPONSORURL\n\n# Thank you!\n\n127.0.0.1" > $WHITELISTLOCATION
	EDITLIST "$WHITELISTLOCATION" Whitelist
}

BLACKLIST()
{
	[ ! -f "$BLACKLISTLOCATION" ] && printf "# This file is part of $SCRIPTNAME\n# Add one entry per line to this file. These will always be blocked (e.g. known botnet/attacker IPs). Supports both single IPv4 addresses (e.g. 203.0.113.5) and IPv4 CIDR ranges (e.g. 203.0.113.0/24). Note: Only IPv4 is supported.\n# More info on GitHub: https://github.com/Feriman22/portscan-protection\n# If you found it useful, please support the project: $SPONSORURL\n\n# Thank you!\n\n" > $BLACKLISTLOCATION
	EDITLIST "$BLACKLISTLOCATION" Blacklist
}

EDITLIST()
{
	# Edit whitelist or blacklist
	for i in nano vi vim; do
		if command -v $i > /dev/null; then
			$i "$1"
			"$SCRIPTLOCATION" --cron
			printf "$2 has been activated if the file has been modified.\n" ; FOUND="1"
			break
		fi
	done
	[ "$FOUND" != "1" ] && echo "nano, vi or vim is not found. Edit manually the ${2,,}: $1"
}

BLACKLISTIPSETNAME="blacklisted_ips"
IPSET3="$BLACKLISTIPSETNAME hash:net family inet hashsize 4096 maxelem 131072"

GET_BLACKLIST_ENTRIES()
{
	# Prints the validated, de-duplicated list of blacklist entries (one per line, sorted).
	# Accepts plain IPv4 addresses AND IPv4 CIDR ranges (e.g. 203.0.113.0/24).
	# Silently skips comments, blank lines, surrounding whitespace, CRLF line endings, and invalid entries.
	# Safety: never returns 0.0.0.0, 127.0.0.1, any 127.x.x.x entry, or a /0 range (which would match
	# every IPv4 address and effectively block all traffic).
	# Uses a single-pass awk filter (instead of a bash loop) so this stays fast at tens of thousands
	# of entries - important since blacklists built from CIDR feeds can get large quickly.
	[ ! -f "$BLACKLISTLOCATION" ] && return
	[ ! -r "$BLACKLISTLOCATION" ] && return
	awk '
	{
		gsub(/\r/, "")
		sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "")
		if ($0 == "" || $0 ~ /^#/) next
		if ($0 !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/) next
		split($0, whole, "/")
		ip = whole[1]; prefix = whole[2]
		if (prefix != "" && (prefix == "0" || prefix+0 > 32)) next
		split(ip, oct, ".")
		valid = 1
		for (i = 1; i <= 4; i++) { if (oct[i]+0 > 255) valid = 0 }
		if (!valid) next
		if (ip == "0.0.0.0") next
		if (oct[1] == "127") next
		print $0
	}
	' "$BLACKLISTLOCATION" | sort -u
}

SYNC_BLACKLIST_IPTABLES()
{
	# Applies the blacklist via a single ipset (hash:net, supports both plain IPs and CIDR ranges)
	# matched by one static iptables rule, instead of one iptables rule per entry. The set is rebuilt
	# in a temp set and atomically swapped in - this keeps the sync fast and correct even at
	# tens of thousands of entries, and avoids ever leaving the live set half-updated.
	# Missing or unreadable blacklist file -> do nothing (never wipe existing protection due to a permissions glitch).
	[ ! -f "$BLACKLISTLOCATION" ] && return
	[ ! -r "$BLACKLISTLOCATION" ] && return

	NEWLIST=$(GET_BLACKLIST_ENTRIES)
	OLDLIST=""
	[ -f "$BLACKLISTAPPLIEDLOCATION" ] && OLDLIST=$(cat "$BLACKLISTAPPLIEDLOCATION")

	# Skip only if the entries are unchanged AND the live ipset + rule already exist.
	# File content alone isn't enough to decide this: after a reboot, ipset/iptables state
	# resets even though the blacklist file itself didn't change, so we must also check
	# what's actually live before trusting the "nothing to do" shortcut.
	if [ "$NEWLIST" == "$OLDLIST" ]; then
		if ipset list -n 2>/dev/null | grep -qx "$BLACKLISTIPSETNAME" && [ $(iptables -S INPUT 2>/dev/null | grep -c -- "-m set --match-set $BLACKLISTIPSETNAME src -j DROP") -ge 1 ]; then
			return
		fi
	fi

	# Make sure the base ipset + firewall rule exist (idempotent, only really does anything once)
	ipset list -n 2>/dev/null | grep -qx "$BLACKLISTIPSETNAME" || ipset create $IPSET3
	if [ $(iptables -S INPUT 2>/dev/null | grep -c -- "-m set --match-set $BLACKLISTIPSETNAME src -j DROP") -lt 1 ]; then
		iptables -I INPUT -m set --match-set "$BLACKLISTIPSETNAME" src -j DROP
	fi

	# Build a temp set with the current entries in one bulk restore, then atomically swap it in
	TMPSETNAME="${BLACKLISTIPSETNAME}_tmp"
	ipset destroy "$TMPSETNAME" 2>/dev/null
	ipset create "$TMPSETNAME" hash:net family inet hashsize 4096 maxelem 131072

	if [ -n "$NEWLIST" ]; then
		echo "$NEWLIST" | awk -v s="$TMPSETNAME" '{print "add " s " " $0}' | ipset restore -exist
	fi

	ipset swap "$BLACKLISTIPSETNAME" "$TMPSETNAME"
	ipset destroy "$TMPSETNAME"

	echo "$NEWLIST" > "$BLACKLISTAPPLIEDLOCATION"
}

SYNC_BLACKLIST_NFTABLES()
{
	# nftables equivalent of SYNC_BLACKLIST_IPTABLES - uses a dedicated interval set (so it can hold
	# both plain IPs and CIDR ranges) + a single drop rule, refreshed in one batched nft transaction
	# instead of one nft call per entry, to stay fast at tens of thousands of entries.
	[ ! -f "$BLACKLISTLOCATION" ] && return
	[ ! -r "$BLACKLISTLOCATION" ] && return

	NEWLIST=$(GET_BLACKLIST_ENTRIES)
	OLDLIST=""
	[ -f "$BLACKLISTAPPLIEDLOCATION" ] && OLDLIST=$(cat "$BLACKLISTAPPLIEDLOCATION")

	# Fix rule order if blacklist rule is above the whitelist rule
	CHAINLIST=$(nft -a list chain inet portscan_protection input 2>/dev/null)
	if echo "$CHAINLIST" | grep -m1 "@whitelist accept\|@blacklist drop" | grep -q "@blacklist drop" && echo "$CHAINLIST" | grep -q "@whitelist accept"; then
		for RULEHANDLE in $(echo "$CHAINLIST" | grep "@blacklist drop" | grep -oE 'handle [0-9]+' | awk '{print $2}'); do
			nft delete rule inet portscan_protection input handle "$RULEHANDLE"
		done
	fi

	MIGRATED="0"
	# One-time migration: earlier versions created the set without interval support (no CIDR ranges).
	# If we find that older set, remove the rule referencing it and the set itself, so they get
	# recreated below with CIDR support.
	if nft list set inet portscan_protection blacklist > /dev/null 2>&1 && ! nft list set inet portscan_protection blacklist 2>/dev/null | grep -q "flags interval"; then
		RULEHANDLE=$(nft -a list chain inet portscan_protection input 2>/dev/null | grep "@blacklist drop" | grep -oE 'handle [0-9]+' | awk '{print $2}')
		[ -n "$RULEHANDLE" ] && nft delete rule inet portscan_protection input handle "$RULEHANDLE" 2>/dev/null
		nft delete set inet portscan_protection blacklist 2>/dev/null
		MIGRATED="1"
	fi

	if [ "$NEWLIST" == "$OLDLIST" ] && [ "$MIGRATED" == "0" ]; then
		# Skip only if the live set + rule already exist. File content alone isn't enough:
		# after a reboot, nftables state resets even though the blacklist file itself
		# didn't change, so we must also check what's actually live before skipping.
		if nft list set inet portscan_protection blacklist > /dev/null 2>&1 && nft list chain inet portscan_protection input 2>/dev/null | grep -q "@blacklist drop"; then
			return
		fi
	fi

	# Create the blacklist set if it doesn't exist (interval + auto-merge so CIDR ranges work and
	# adjacent/overlapping entries get merged automatically)
	if ! nft list set inet portscan_protection blacklist > /dev/null 2>&1; then
		nft add set inet portscan_protection blacklist { type ipv4_addr\; flags interval\; auto-merge\; }
	fi

	# Add the drop rule once, at the very front of the chain (whitelist's own "insert at front"
	# call happens right after this one, so it ends up above this rule - whitelist always wins)
	if ! nft list chain inet portscan_protection input 2>/dev/null | grep -q "@blacklist drop"; then
		# Put the blacklist rule after the whitelist rule
		WHITELISTHANDLE=$(nft -a list chain inet portscan_protection input 2>/dev/null | grep "@whitelist accept" | grep -oE 'handle [0-9]+' | awk '{print $2; exit}')
		if [ -n "$WHITELISTHANDLE" ]; then
			nft add rule inet portscan_protection input position "$WHITELISTHANDLE" ip saddr @blacklist drop
		else
			nft insert rule inet portscan_protection input ip saddr @blacklist drop
		fi
	fi

	# Re-sync set contents in a single batched transaction (flush + bulk add), instead of one
	# nft process per entry - this is what keeps large/CIDR lists fast to apply
	NFTBATCHFILE=$(mktemp)
	{
		echo "flush set inet portscan_protection blacklist"
		[ -n "$NEWLIST" ] && echo "$NEWLIST" | awk '{printf "add element inet portscan_protection blacklist { %s }\n", $0}'
	} > "$NFTBATCHFILE"
	nft -f "$NFTBATCHFILE"
	rm -f "$NFTBATCHFILE"

	echo "$NEWLIST" > "$BLACKLISTAPPLIEDLOCATION"
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
	# Download the latest script from GitHub and extract the VERSION string
	# This compares the version line (e.g., VERSION="01-01-2026") with the current version
	NEW=$(curl -s "$GITHUBRAW" | awk -F'"' '/^VERSION/ {print $2}')

	# Compare the installed and the GitHub stored version - Only internal, not available by any argument
	if [[ "$1" == "ONLYCHECK" ]]; then
		[[ "$NEW" != "$VERSION" ]] && printf "New version ${YL}available!${NC}\n" || printf "The downloaded $SCRIPTNAME is ${GR}up to date.${NC}\n\n"
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
		
		for WHILELISTIP in $(GET_WHITELIST_ENTRIES); do
			nft add element inet portscan_protection whitelist { $WHILELISTIP } 2>/dev/null
		done
		
		# Add whitelist accept rule at the beginning if not exists
		if ! nft list chain inet portscan_protection input 2>/dev/null | grep -q "@whitelist accept"; then
			nft insert rule inet portscan_protection input ip saddr @whitelist accept 2>/dev/null
		fi
	fi
}

CHECK_NFTABLES_RULES()
{
	# Check nftables rules
	CHAINRULES=$(nft list chain inet portscan_protection input 2>/dev/null) || return 1
	for RULEPATTERN in "@port_scanners drop" "add @port_scanners" "add @scanned_ports"; do
		echo "$CHAINRULES" | grep -qF -- "$RULEPATTERN" || return 1
	done
}

SHOWSTATS()
{
	# Show statistics
	if [ "$FIREWALL_BACKEND" == "nftables" ]; then
		# Blocked IPs
		ACTIVE=$(nft list set inet portscan_protection port_scanners 2>/dev/null | sed -n '/elements/,$p' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | wc -l)
		DROPPED=0
	else
		ACTIVE=$(ipset list port_scanners 2>/dev/null | awk '/^Number of entries:/ {print $4}')
		DROPPED=$(iptables -L INPUT -v -n -x 2>/dev/null | awk '/match-set port_scanners src/ && /DROP/ {SUM += $1} END {print SUM + 0}')
	fi
	[[ "$ACTIVE" =~ ^[0-9]+$ ]] || ACTIVE=0
	[[ "$DROPPED" =~ ^[0-9]+$ ]] || DROPPED=0

	if [ "$ACTIVE" -gt 0 ] || [ "$DROPPED" -gt 0 ]; then
		printf "\nCurrently blocked port scanners: ${YL}$ACTIVE${NC} IP(s) (each block lasts 10 min)\n"
		[ "$DROPPED" -gt 0 ] && printf "Packets dropped from port scanners since the rules were (re)loaded: ${YL}$DROPPED${NC}\n"
		printf "If this keeps your server safe, please consider supporting the project: ${GR}$SPONSORURL${NC}\n"
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
	printf "${GR}If you found it useful${NC}, please support the project: $SPONSORURL\n\n"
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
		SYNC_BLACKLIST_NFTABLES
		ADD_WHITELIST_NFTABLES
	else
		# iptables setup (original behavior)
		# Sync Blacklist IPs first, so Whitelist (added right after) ends up taking priority in the chain
		SYNC_BLACKLIST_IPTABLES

		# Add Whitelist IPs if any
		for WHILELISTIP in $(GET_WHITELIST_ENTRIES); do
			[ $(iptables -S | grep -cF -- "-A INPUT -s $WHILELISTIP/32 -j ACCEPT") -lt 1 ] && iptables -I INPUT -s $WHILELISTIP -j ACCEPT
		done

		# Allow SSH port if custom
		if [ "$SSHPORT" != "22" ]; then
			# Add custom SSH rule
			iptables -C INPUT -p tcp --dport $SSHPORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $SSHPORT -j ACCEPT
			# Remove duplicates
			while [ $(iptables -S INPUT | grep -cxF -- "-A INPUT -p tcp -m tcp --dport $SSHPORT -j ACCEPT") -gt 1 ]; do
				iptables -D INPUT -p tcp --dport $SSHPORT -j ACCEPT || break
			done
		fi

		ipset list -n 2>/dev/null | grep -qx port_scanners || ipset create $IPSET1
		ipset list -n 2>/dev/null | grep -qx scanned_ports || ipset create $IPSET2
		for IPTABLERULE in "$IPTABLE1" "$IPTABLE2" "$IPTABLE3" "$IPTABLE4"; do
			iptables -S | grep -qF -- "-A $IPTABLERULE" || iptables -A $IPTABLERULE
		done
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
	[ -f "$SCRIPTLOCATION" ] && options=("Verify" "Edit Whitelist" "Edit Blacklist" "Set SSH Port" "Toggle Auto-Update" "Update from GitHub" "Reinstall" "Uninstall" "Quit")
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
			"Edit Blacklist")
				BLACKLIST ; break
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

	COMMANDCHECK

	# Set persistence (systemd or cron)
	SETPERSISTENCE

	# Copy the script to $SCRIPTLOCATION and add execute permission
	INSTALLERLOCATION=$(realpath $0)
	if [ "$INSTALLERLOCATION" != "$SCRIPTLOCATION" ]; then
		# Download latest version from GitHub and make it executable
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
	printf "${GR}Done.${NC} The install was $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec. That was so quick, wasn't it?\n"
	printf "\nThis project is free and maintained in my spare time. If it protects your server, please consider supporting it: ${GR}$SPONSORURL${NC}\n"
	printf "Tip: run ${YL}sudo $SCRIPTLOCATION --verify${NC} anytime to see how many port scanners are currently blocked.\n\n"
fi


##
########### Menu: Uninstall ###########
##

if [ "$OPT" == '-u' ] || [ "$OPTL" == '--uninstall' ]; then
	if [ "$ARG" != 'YES' ]; then
		while true; do
			printf "${RED}UNINSTALL${NC} $SCRIPTNAME on $(hostname).\n"
			read -p "Are you sure? [Y/n]: " var1
			if [ "$var1" == 'Y' ] || [ "$var1" == 'y' ]; then
				printf "Okay! You have 5 sec until starting the ${RED}UNINSTALL${NC} process on $(hostname). Press Ctrl + C to exit.\n"
				for i in {5..1}; do echo $i && sleep 1; done
				break
			elif [ "$var1" == 'N' ] || [ "$var1" == 'n' ]; then
				echo "Okay, exit."
				exit 9
			fi
			echo "Enter a valid response Y or n"
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
			for WHILELISTIP in $(GET_WHITELIST_ENTRIES); do
				iptables -D INPUT -s $WHILELISTIP -j ACCEPT 2>/dev/null
			done
			printf "Whitelist removed from iptables if any. ${GR}OK.${NC}\n"
		fi

		# Remove Blacklist rule (single ipset-match rule, regardless of how many entries it holds)
		iptables -D INPUT -m set --match-set "$BLACKLISTIPSETNAME" src -j DROP 2>/dev/null
		printf "Blacklist rule removed from iptables if any. ${GR}OK.${NC}\n"

		# Remove custom SSH port rule
		if [ "$SSHPORT" != "22" ]; then
			iptables -D INPUT -p tcp --dport $SSHPORT -j ACCEPT 2>/dev/null
		fi

		# Remove ipset rules
		for IPSETRULE in scanned_ports port_scanners "$BLACKLISTIPSETNAME" "${BLACKLISTIPSETNAME}_tmp"; do
			if ipset list -n 2>/dev/null | grep -qx "$IPSETRULE"; then
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

	# Remove Blacklist
	[ -f "$BLACKLISTLOCATION" ] && rm -f "$BLACKLISTLOCATION" && printf "Blacklist has been removed. ${GR}OK.${NC}\n" || printf "Blacklist not found. ${GR}OK.${NC}\n"
	[ -f "$BLACKLISTAPPLIEDLOCATION" ] && rm -f "$BLACKLISTAPPLIEDLOCATION"

	printf "\nIf the $SCRIPTNAME removed accidently, run this below command to install it again:\n"
	printf "curl -s $GITHUBRAW | sudo bash /dev/stdin -i\n"
fi

##
########### Menu: Reinstall ###########
##

if [ "$OPT" == '-r' ] || [ "$OPTL" == '--reinstall' ]; then
	printf "Starting ${YL}reinstall${NC} process...\n\n"

	# Back up whitelist/blacklist/config before uninstalling, so a reinstall no longer wipes them.
	# (The blacklist "applied state" tracking file is deliberately NOT backed up - it must start
	# fresh so the next sync run correctly rebuilds the actual firewall rules from the restored file,
	# instead of wrongly assuming the rules are already live.)
	REINSTALLBACKUPDIR=$(mktemp -d)

	# Download the script before uninstall
	REINSTALLER="$REINSTALLBACKUPDIR/portscan-protection.sh"
	if ! curl -s -o "$REINSTALLER" "$GITHUBRAW" || ! grep -q "^VERSION=" "$REINSTALLER"; then
		printf "GitHub is ${RED}not available now.${NC} Nothing has been changed. Try again later.\n"
		rm -rf "$REINSTALLBACKUPDIR"
		exit 8
	fi
	REINSTALLFILES=("Whitelist:$WHITELISTLOCATION" "Blacklist:$BLACKLISTLOCATION" "Configuration:$CONFIGLOCATION")
	for ENTRY in "${REINSTALLFILES[@]}"; do
		[ -f "${ENTRY#*:}" ] && cp "${ENTRY#*:}" "$REINSTALLBACKUPDIR/${ENTRY%%:*}" 2>/dev/null
	done

	# Run uninstall silently
	bash "$REINSTALLER" -u

	printf "\n--- Uninstall complete, starting install ---\n\n"

	# Install the downloaded script
	cp "$REINSTALLER" "$SCRIPTLOCATION" && chmod +x "$SCRIPTLOCATION"
	bash "$SCRIPTLOCATION" -i

	# Restore whitelist/blacklist/config if we had them
	for ENTRY in "${REINSTALLFILES[@]}"; do
		[ -f "$REINSTALLBACKUPDIR/${ENTRY%%:*}" ] && cp "$REINSTALLBACKUPDIR/${ENTRY%%:*}" "${ENTRY#*:}" && printf "${ENTRY%%:*} restored. ${GR}OK.${NC}\n"
	done
	rm -rf "$REINSTALLBACKUPDIR"

	# Re-apply firewall rules now that the restored whitelist/blacklist/config are back in place
	"$SCRIPTLOCATION" --cron
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

	COMMANDCHECK
	if [ "$FIREWALL_BACKEND" == "nftables" ]; then
		if CHECK_NFTABLES_RULES; then
			printf "nftables rules have been configured. You are protected! ${GR}OK.${NC}\n"
		else
			printf "nftables rules are ${RED}not configured!${NC}\n"
		fi
	else
		iptables -S | grep -q port_scanners && iptables -S | grep -q scanned_ports && printf "iptables rules have been configured. You are protected! ${GR}OK.${NC}\n" || printf "iptables rules are ${RED}not configured!${NC}\n"
	fi

	if [ -f $WHITELISTLOCATION ]; then
		while read WHILELISTIP; do
			# Validate IP address
			if [[ ! "$WHILELISTIP" =~ $IPV4REGEX ]]; then
				printf "$WHILELISTIP is ${RED}not valid${NC} IPv4 address in the Whitelist and it will be ignored. May you have to fix it by choose Edit Whitelist from the menu.\n"
			fi
		done < <(grep -v "^#\|^$" $WHITELISTLOCATION)
	fi

	if [ -f $BLACKLISTLOCATION ]; then
		while read BLACKLISTIP; do
			# Validate IP address or CIDR range (e.g. 203.0.113.0/24)
			if [[ ! "$BLACKLISTIP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))(/([1-9]|[12][0-9]|3[0-2]))?$ ]]; then
				printf "$BLACKLISTIP is ${RED}not valid${NC} IPv4 address/CIDR range in the Blacklist and it will be ignored. May you have to fix it by choose Edit Blacklist from the menu.\n"
			fi
		done < <(grep -v "^#\|^$" $BLACKLISTLOCATION | tr -d '\r')
		printf "Blacklist contains ${YL}$(GET_BLACKLIST_ENTRIES | wc -l)${NC} valid entry/entries currently applied.\n"
	fi

	# Show blocking statistics
	SHOWSTATS
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

exit 0
