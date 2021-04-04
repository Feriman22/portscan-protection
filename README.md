# Portscan Protection (Linux)

## Description
Hackers and kiddie scripts always scan servers and look for open ports. If they find one (for example your SSH port), they will try to crack it. This script helps you to avoid becoming a victim of portscan attack on Linux systems with built-in firewall protection (iptables). If they try to knock on ports too quickly, the script will automagically block the attacker's IP address in the iptable.

*The menu before install*  
![Screenshot](https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection-not-installed-screenshot.png)  

*The menu after install*  
![Screenshot](https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection-installed-screenshot.png)

## Installation

0. **Install cURL and ipset:**
- Ubuntu/Debian:
>*apt update && apt install curl ipset*
- RedHat/CentOS:
>*yum install curl ipset*
1. **Download the script from GitHub:**
>*curl -s https://raw.githubusercontent.com/Feriman22/portscan-protection/master/portscan-protection.sh -O portscan-protection.sh*
2. **Add execute permission:**
>*chmod +x ./portscan-protection.sh*
3. **Install the script:**
>*sudo ./portscan-protection.sh --install*

If you run it without any argument, you have few options:
1. Install *# Available only if not installed yet*
2. Uninstall *# Available only if already installed*
3. Edit Whitelist *# Available only if already installed*
4. Verify
5. Update the script *# Available only if already installed*
6. Quit

The `Install` process copies the script to the */usr/local/sbin* folder and then creates a new cron rule in the file called *portscan-protection* in the */etc/cron.d* folder. It is executed once by itself to enable the ipset/iptable rules, and every startup, so your server is protected at all times.

The `Uninstall` process removes the script from the */usr/local/sbin* folder, removes the crontab entry and deletes ipset/iptable rules.
**WARNING!** After this step, you can no longer run the script from the */usr/local/sbin* folder!

The `Edit Whitelist` option allow to add IPv4 addresses to the whitelist. Add one IP per line to this file. These IP addresses will be never blocked. Note: Only IPv4 addresses are supported.

The `Verify` process checks the crontab entry, the location of the script, the execution permission, the ipset/iptables commands and the active firewall rules.

The `Update the script` process updates the installed script. You cannot update it before installation!

## Daily use

Nothing to do! Just install the script and enjoy the protection! If you want to run the script again, just type `portscan-protection.sh` as root user.

If you want to use this script somewhere else (e.g. in an OS installer script), there are some arguments:

-i, --install\
  Install the script

-u, --uninstall\
  Uninstall the script without confirmation
  
-v, --verify\
  Verify the installation
  
-up, --update\
  Update the script
  
--cron\
  Run the script like the crontab do. It will only set ipset/iptable rules and auto-update the script if not disabled. No output.


I added some exit codes in 28-04-2020 release. These codes documented here:

| Exit code  | What does it mean? |
| ------------- | ------------- |
| 0  | Everything was fine (no error) |
| 5  | Not enough permission. Run as root or with sudo |
| 6  | ipset command not found |
| 7  | iptables command not found |
| 8  | GitHub is not available  |
| 9  | Choosed *No* at Uninstall |
| 130  | Script canceled by *ctrl + c* |

## How to update

Run the script and choose "Update" or run with --update argument.\
The script will automatically update itself after reboot. If you want to disable it, modify the 7th line in the script.

## The future

- Add easier way to disable auto-update function
- Shorter code (combine similar *if* structures in one *for* cycle)
- Reinstall function
- Remove original installer to avoid confusing

## Changelog

>04-04-2021
- Whitelist function
- Use cURL instead of wget
- Smarter way to update
- Different menus before and after install
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

If you found it useful, **please donate me via PayPal** and I can improve & fix bugs or develop another awesome scripts! (:
[paypal.me/BajzaFerenc](https://www.paypal.me/BajzaFerenc)
