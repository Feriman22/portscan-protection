# portscan-protection

## Description:
Hackers and kiddie scripts are always scanning servers for looking open ports. If they find one (for example your SSH port), they will try to break it. This script helps to avoid portscanning on Linux systems with built in firewall (iptables).

## How to use it

###### Installation

1. Download the script from GitHub:
>*wget https://github.com/Feriman22/portscan-protection/archive/master.zip*
2. Unzip the file:
>*unzip master.zip*
3. Add execute permission:
>*chmod +x ./portscan-protection-master/portscan-protection.sh*
4. Run the script:
>*sudo ./portscan-protection-master/portscan-protection.sh*

You have 3 options:
1. Install the script
2. Uninstall the script
3. Verify

The `install` process will copy the script in /root folder, then insert itself in the crontab. It will run on every startup, so your server will be protected at all time.

The `uninstall` process remove the script from /root folder and remove the crontab entry as well.
**WARNING!** You cannot run this script again after this step from /root folder!

The `verify` process check the crontab entry, script location, execute permission, iptables command and firewall rules.

###### Daily use

Nothing to do! Just install the script and enjoy the protection!

## Changelog

>13-04-2020
- Initial release


## Do not forget

If you found it useful, **please donate me via PayPal** and I can improve & fix bugs or develop another awesome scripts! (:
[paypal.me/BajzaFerenc](https://www.paypal.me/BajzaFerenc)
