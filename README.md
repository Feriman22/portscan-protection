# portscan-protection

## Description:
Hackers and kiddie scripts are always scanning servers for looking open ports. If they find one (for example your SSH port), they will try to break it. This script helps to avoid portscanning on Linux systems by built in firewall (iptables).

## How to use it

###### Installation

Run the script like this way:
./portscan-protection.sh

You have 3 options:
1. Install the script
2. Uninstall the script
3. Verify the installation

The *install* process will copy the script in /root folder, then insert itself in the crontab. It will run on every startup, so your server will be protected at all time.

The *uninstall* process remove the script from /root folder and remove the crontab entry as well.
**WARNING!** You cannot run this script again after this step from /root folder!

###### Daily use

Stay tuned! Upload in progress...

## Changelog

If you enjoy it, **please donate me via PayPal** and I can improve & fix bugs or develop another useful scripts!
[paypal.me/BajzaFerenc](https://www.paypal.me/BajzaFerenc)
