# Portscan Protection (Linux)

## Description
Hackers and unskilled script-users often scan servers for open ports. If they find one, such as your SSH port, they will attempt to crack it. This script helps protect Linux systems with built-in firewall protection (iptables or nftables) from portscan attacks by automatically blocking the IP address of any attacker who attempts to access ports too quickly.

*The menu before install*  
![Screenshot](https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection-downloaded-screenshot.png)

*The menu after install*  
![Screenshot](https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection-installed-screenshot.png)

## Features

- **Automatic portscan detection and blocking** - Blocks IPs that scan too many ports too quickly
- **Dual firewall support** - Works with both iptables/ipset and nftables (auto-detected)
- **Systemd & Cron support** - Uses systemd if available, falls back to cron
- **Custom SSH port support** - Protects your custom SSH port from being blocked
- **Whitelist support** - Never block specific IP addresses
- **Auto-update** - Automatically updates itself (can be easily toggled on/off)
- **Easy reinstall** - Reinstall with a single command

## Installation

1. **Install required packages:**
- Ubuntu/Debian (iptables):
    - >*sudo apt update && sudo apt install curl iptables ipset -y*
- Ubuntu/Debian (nftables):
    - >*sudo apt update && sudo apt install curl nftables -y*
- RedHat/CentOS (iptables):
   - >*sudo yum install curl iptables ipset -y*
- RedHat/CentOS (nftables):
   - >*sudo yum install curl nftables -y*

2. **Install Portscan Protection directly from GitHub:**
>*curl -s https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection.sh | sudo bash /dev/stdin -i*

If you run it without argument, you have several options:

**Before installation:**
1. Install
2. Verify
3. Quit

**After installation:**
1. Verify
2. Edit Whitelist
3. Set SSH Port
4. Toggle Auto-Update
5. Update from GitHub
6. Reinstall
7. Uninstall
8. Quit

### Menu Options Explained

The `Install` process copies the script to the */usr/local/sbin* folder and then creates either a systemd service (if systemd is available) or a cron rule in the file called *portscan-protection* in the */etc/cron.d* folder. It is executed once by itself to enable the firewall rules, and every startup, so your server is protected at all times.

The `Uninstall` process removes the script from the */usr/local/sbin* folder, removes the systemd service or crontab entry, removes the configuration file, and deletes all firewall rules.
**WARNING!** After this step, you can no longer run the script from the */usr/local/sbin* folder!

The `Reinstall` process performs a complete uninstall followed by a fresh install. Useful for fixing issues or resetting configuration.

The `Edit Whitelist` option allows adding IPv4 addresses to the whitelist. Add one IP per line to this file. These IP addresses will never be blocked. Note: Only IPv4 addresses are supported.

The `Set SSH Port` option allows you to specify a custom SSH port. This ensures your SSH port won't be blocked even if you're using a non-standard port.

The `Toggle Auto-Update` option enables or disables the automatic update feature. Settings are saved to a configuration file.

The `Verify` process checks:
- The persistence method (systemd or cron)
- Whether the cron service is running (if using cron)
- The location and permissions of the script
- The configuration file settings
- Required commands (ipset/iptables or nft)
- Active firewall rules
- Whitelist validity

The `Update from GitHub` process updates the installed script. You cannot update it before the installation!

## Daily use

Nothing to do! Just install the script and enjoy the protection! If you want to run the script again, just type `portscan-protection.sh` as root user.

### Arguments

If you want to use this script somewhere else (e.g. in an OS installer script), there are some arguments:

| Argument | Description |
| --- | --- |
| -i, --install | Install the script |
| -u, --uninstall | Uninstall the script without confirmation |
| -r, --reinstall | Reinstall the script (uninstall + install) |
| -v, --verify | Verify the installation |
| -up, --update | Update the script from GitHub |
| --toggle-autoupdate | Enable or disable auto-update feature |
| --set-sshport | Set custom SSH port |
| --cron | Run the script like the crontab/systemd does. It will only set firewall rules and auto-update the script if not disabled. No output. |

### Configuration File

After installation, a configuration file is created at `/usr/local/sbin/portscan-protection.conf` containing:

```bash
# Auto-update setting (YES or NO)
AUTOUPDATE="YES"

# Custom SSH port (default: 22)
SSHPORT="22"

# Firewall backend (iptables or nftables, leave empty for auto-detect)
FIREWALL_BACKEND=""
```

You can edit this file directly or use the menu options.

### Exit codes

| Exit code | What does it mean? |
| --- | --- |
| 0 | Everything was fine (no error) |
| 5 | Not enough permission. Run as root or with sudo |
| 6 | ipset command not found |
| 7 | iptables command not found |
| 8 | GitHub is not available |
| 9 | Answered *No* at Uninstall |
| 10 | Required commands not found (curl, iptables/ipset or nft) |
| 11 | nft command not found |
| 130 | Script canceled by *ctrl + c* |

## Firewall Backends

### iptables (Legacy)
The original backend using iptables and ipset. Still fully supported and will be used if nftables is not available.

**Required packages:** curl, iptables, ipset

### nftables (Modern)
The modern replacement for iptables. If both are available, the script auto-detects which one to use based on:
1. Existing rules (prefers the one already in use)
2. nftables if no existing rules found

**Required packages:** curl, nftables

You can force a specific backend by setting `FIREWALL_BACKEND` in the configuration file.

## Systemd vs Cron

The script automatically detects if systemd is available:

### Systemd (Preferred)
- Creates a service at `/etc/systemd/system/portscan-protection.service`
- Creates a timer at `/etc/systemd/system/portscan-protection.timer` for auto-updates
- Runs automatically at boot
- Old cron entries are automatically migrated

### Cron (Fallback)
- Creates an entry at `/etc/cron.d/portscan-protection`
- Runs 30 seconds after boot
- The `Verify` option checks if the cron service is running

## How to update

The script will automatically update itself after reboot (if auto-update is enabled).

**To disable auto-update:**
- Run the script and choose "Toggle Auto-Update" from the menu, or
- Run `/usr/local/sbin/portscan-protection.sh --toggle-autoupdate`, or
- Edit `/usr/local/sbin/portscan-protection.conf` and set `AUTOUPDATE="NO"`

**To manually update:**
Run the script and choose "Update from GitHub" or run:
`/usr/local/sbin/portscan-protection.sh --update`

## Backward Compatibility

This version is fully backward compatible with previous installations:
- Existing iptables rules are preserved
- Cron-based installations continue to work
- Systemd is only used for new installations or after reinstall
- Configuration file is created automatically on first run

## Changelog

>01-01-2026
- **NEW:** Systemd support (auto-detected, with fallback to cron)
- **NEW:** nftables support (auto-detected)
- **NEW:** Custom SSH port support
- **NEW:** Reinstall function
- **NEW:** Easy toggle for auto-update (menu option and --toggle-autoupdate argument)
- **NEW:** Configuration file for persistent settings
- **NEW:** Verify checks if cron service is running
- Migration from cron to systemd on reinstall
- Improved firewall backend detection
- Added exit code 11 for missing nft command

>26-06-2023
- Use *command -v* instead of *which*
- Code simplification
- Small bugfixes

>14-03-2023
- Fix bug [#9](https://github.com/Feriman22/portscan-protection/issues/9)

>16-08-2022
- Bugfix: iptables flush has been removed
- Using _printf_ instead of _echo -e_
- Small text modifications

>05-04-2021
- Whitelist editor improved
- Installer not copied twice on the server thanks to direct install from GitHub
- cURL, iptables and ipset command verification (Exit code 10)
- Small text modifications

>04-04-2021
- Whitelist function
- Use cURL instead of wget
- Smarter way to update
- Different menus before and after install
- Shorter code (combine similar *if* structures in one *for* cycle)
- Replace original installer with symlink to avoid confusing
- Small bugfixes

>01-02-2021
- Bugfix: ipset and iptable commands are not found on CentOS systems
- Bugfix: Crontab syntax was wrong
- Bugfix: Run update process only if new version available

>28-04-2020
- Error codes have been added

>26-04-2020
- More efficient update process

>15-04-2020
- Update option added
- Auto-update function added
- Check for an update at the startup of the script
- Remove ipset and iptable rules at uninstalling
- Arguments added (-i, --install, -u, --uninstall, -v, --verify, -up, --update, --cron)
- Activate/remove ipset and iptable rules with variables
- The test condition for install has been improved
- Small typos fixed

>14-04-2020
- Copy the script in /usr/local/sbin directory instead of /root
- Use variables for menu selection instead of touch temp files
- Insert cron entry in /etc/cron.d folder instead of the main cron file
- Code review & cleanup
- Small bugs fixed

>13-04-2020
- Initial release

## Do not forget

If you found my work helpful, I would greatly appreciate it if you could make a **[donation through PayPal](https://paypal.me/BajzaFerenc)** to support my efforts in improving and fixing bugs or creating more awesome scripts. Thank you!

<a href='https://paypal.me/BajzaFerenc'><img height='36' style='border:0px;height:36px;' src='https://raw.githubusercontent.com/Feriman22/portscan-protection/master/paypal-donate.png' border='0' alt='Donate with Paypal' />
