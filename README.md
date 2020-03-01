# oath knock

This repo contains sample scripts for securing machine by obstacle with allowing only IP of user which knows right knock sequence that generated via oath.

It is based on [knockd](https://linux.die.net/man/1/knockd) and its [alternative](https://www.digitalocean.com/community/tutorials/how-to-configure-port-knocking-using-only-iptables-on-an-ubuntu-vps) , etc.

#### Notes
- initial idea was to have knocking using [only iptables](https://www.digitalocean.com/community/tutorials/how-to-configure-port-knocking-using-only-iptables-on-an-ubuntu-vps?comment=24274) and then to try write sample script for CentOS service
- oathKnock.sh can be executed to guess port knowing oath key files using parameter _--now=<:time>_ which can be useful if service fails to start and old rules are still used
- use _./iptables.simple_ and do not use _./iptables.simpleWithBkp_ that contains backdoor for testing on remote machine and store it as _/etc/sysconfig/iptables_

#### TODO
- implement it to knockd's One_Time_Sequences
