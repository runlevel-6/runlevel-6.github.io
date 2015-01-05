*****************************************************************************
*************** gatekeeper general setup instructions ***********************
*****************************************************************************
Author: Kenneth W. Zahorec
Date: 2012-12-25

This is a continuation from "cent6.3-cd-installed-additions.txt".
Assuming you have all of the necessary software packages installed
in the instructions within the file referenced above.

*****************************************************************************
**** Configuring Network Adapters and Hostname ******************************

Once the system has all the necessary software installed, reboot it, then
bring it up and login as zadmin.  Your Internet-side network card should have
already be setup during installation.

In the "Connections" tab, you should see two Wired connections. They should
both be enabled with a check mark in their corresponding checkbox.

You can manage which network adapter gets assigned to which name in the
following file:
	/etc/udev/rules.d/70-persistent-net.rules

    (primary adapter on ISP side)
	Card interface is setup to use DHCP for networks that provide this.
	For example, the Road Runner network with cable modem provides DHCP
	server on TCP/IP. You will see "Wired connection (eth0)" for this
	interface.

	This interface can continue to be managed with Network Manager
	
    (secondary adapter on LAN or subnet side)

	Initially it can be setup static using the network manager 
	icon in the panel, "Edit Connections". Once completed we can use
	the configuration script below. It can be renamed to simply ifcfg-eth1

	You will normally see "Wired Connection (eth1)" for this interface.
	This interface is set up with a static IP address and subnet mask.
	Network Manager should not manage this interface. It is set up
	manually as shown below in the "ifcfg-eth1" network script.

	/etc/sysconfig/network-scripts/ifcfg-eth1

	...contains the following settings data:

		DEVICE=eth1
		ONBOOT=yes
		TYPE=Ethernet
		BOOTPROTO=static
		DEFROUTE=yes
		IPV4_FAILURE_FATAL=yes
		IPV6INIT=no
		UUID=(whatever the system has assigned)
		ONBOOT=yes
		HWADDR=(whatever the system has assigned)
		IPADDR=192.168.2.1
		PREFIX=24
		LAST_CONNECT=(whatever the system has assigned)
		NM_CONTROLLED=no
		USERCTL=no

To permanently change the hostname, edit the network file at
/etc/sysconfig/network.

	HOSTNAME=gatekeeper

note:
DNS resolution for the at gatekeeper itself will reside in the Internet
Service Providers (ISP) domain. This will prevent gatekeeper from being able
to resolve hostnames on the local subnet.  If name resolution for gatekeeper
to the internal subnet is needed, then you can add internal- -subnet domain
hostnames in the "Hosts" tab (see above).  If you attempt to modify the
resolver configuration (/etc/resolv.conf) you will find that gatekeeper's dhcp
client will overwrite it the next time you connect to the ISP using DHCP.
Although this can be prevented, it would also prevent any DHCP lease changes
from the ISP from being deployed.  So to summarize, if you need to resolve
host names from gatekeeper to LAN workstations, then you will have to use the
hosts definitions file to do this.


*****************************************************************************
**** Enabling and Disabling Network Connections ***************

Note: Security
  If you are concerned about unprotected exposure to the internet while setting
  up gatekeeper, you can delay bringing up eth0 until after the firewall script
  is in place. This would mean that you would not allow eth0 to activiate when
  the computer starts. Change the eth0 setting accordingly and don't try to
  start it up until you at least have the rc.iptables firewall executed.

  Alternatively, you could setup gatekeeper behind a firewall to prevent any
  unprotected exposure to the internet while setting gatekeeper up. This, of
  course, will require additional resources which may not be available.
  
  An easy way to take down a network interface is to use the ifdown command.
  For the primary ethernet adapter you can use the command:
	ifdown eth0

  To bring the primary ethernet adapter up you can use:
	ifup eth0

  To check the general network configuration and network adapter statistics
  you can use the following:
  	ifconfig


*****************************************************************************
**** Network Sanity Checks ***********************************

*** determining which interface is eth0? ***

If eth0 (ISP side) does not initialize then switch ISP cable modem to other
network adapter.  Try to bring up the network again for the eth0 interface (as
root... "/sbin/ifup eth0").  It should come up.  Recheck interface status
(/sbin/ifconfig). 

*** Internet service provider (ISP) connection checkpoint ***

Test check gatekeeper's ISP connection and Internet name resolution: You
should be able to ping outside DNS names at this time.  Try pinging yahoo.com
or google.com (ping google.com).  If the ping times out, you need to review
your steps and resolve the problem.  Do not continue with additional
configuration until you can successfully connect to your ISP and resolve host
names on external domains with the ping test.

*****************************************************************************
**************** Connecting Gatekeeper to the LAN ***************************

Connect the secondary eth1 interface adapter to the network hub or switch that
will serve the internal subnet.

*****************************************************************************
*************** Configuring the Services ************************************

*** limiting dhcpd service to internal LAN ***

If more than one network interface is attached to the system, but the DHCP
server should offer services to only one of the interfaces, configure the DHCP
server to offer services only on that interface. This is required for
gatekeeper to avoid offering DHCP service to the external network (your ISP).

In /etc/sysconfig/dhcpd, add the name of the interface to the list of
DHCPDARGS. This will force dhcpd to provided service only to the internal
subnet to which eth1 is connected.

		DHCPDARGS=eth1

*** Testing the dhcpd service with an attached workstation client ***

Testing the dhcpd service can be done by running it as root in a terminal
session at gatekeeper:

	dhcpd -d -f

...this will provide output to std error in the terminal session. You can
basically watch it run while servicing client requests.

*** dhcpd client testing with the new service ***

Connect a workstation client to the network switch and bring it up. If it is
set to automatically set up the network, then gatekeeper should provide the
settings through the dhcpd service.

If you are running network manager on the client and need to see the current
client host network settings you need to look at the network manager settings
in the GUI. Alternatively for a much quicker and more detailed approach use
the network manager command line interface like so:

	nmcli dev list iface eth0

...this will provide a complete list of current network settings
for the specified interface (eth0). As an example it will Look something
like this on a CENT host client:

[zadmin@gate1 ~]$ nmcli dev list iface eth0
GENERAL.DEVICE:                 eth0
GENERAL.TYPE:                   802-3-ethernet
GENERAL.DRIVER:                 forcedeth
GENERAL.HWADDR:                 00:21:97:EE:13:5A
GENERAL.STATE:                  connected
CAPABILITIES.CARRIER-DETECT:    yes
CAPABILITIES.SPEED:             100 Mb/s
WIRED-PROPERTIES.CARRIER:       on
IP4-SETTINGS.ADDRESS:           192.168.1.91
IP4-SETTINGS.PREFIX:            24 (255.255.255.0)
IP4-SETTINGS.GATEWAY:           192.168.1.255
IP4-DNS1.DNS:                   192.168.1.1

Another way to see network manager network details is by
using nm-tool like so:

	nm-tool

...will provide to standard out a text display of the current settings
for each network interface managed. For example:

[zadmin@gate1 ~]$ nm-tool

NetworkManager Tool

State: connected

- Device: eth1 -----------------------------------------------------------------
  Type:              Wired
  Driver:            3c59x
  State:             unmanaged
  Default:           no
  HW Address:        00:01:03:E7:39:5B

  Capabilities:
    Carrier Detect:  yes
    Speed:           100 Mb/s

  Wired Properties
    Carrier:         on


- Device: eth0  [Auto eth0] ----------------------------------------------------
  Type:              Wired
  Driver:            forcedeth
  State:             connected
  Default:           yes
  HW Address:        00:21:97:EE:13:5A

  Capabilities:
    Carrier Detect:  yes
    Speed:           100 Mb/s

  Wired Properties
    Carrier:         on

  IPv4 Settings:
    Address:         192.168.1.91
    Prefix:          24 (255.255.255.0)
    Gateway:         192.168.1.1

    DNS:             192.168.1.1



*** Arno Firewall install and basic setup ***

As root, unpack the arno-iptables-firewall_2.0.1b.tar.gz archive and run the
install.sh script. It should lead you through a simple install and setup of
the firewall. External interface is eth0 and internal LAN interface is eth1.

*** named (Bind9) configuration ***

Make certain that the fixed zone directory for Bind allows read access for the
group "bind". This is the group that the bind executable "named" is run under.
It must have access to this directory. If you copy the config files from
another filesystem, you may not get this set up correctly--so you must adjust
it manually. If "bind" group access to this directory is not set up correctly,
then local name resolution will not work while name resolution to outside
(Internet) addresses will probably work. The following command should provide
the necessary attributes:

	chgrp -R named /var/named/.

The listing line for the fixed zone directory (ls -l /var/named/static)
should look like this:

	drwxr-xr--  2 root named 4096 2005-10-20 00:12 internal.zone.db

*** Using rndc to control named (Bind9) ***

Bind9 requires special auth configuration if you want to be able to manage it
from the localhost (gatekeeper). This was added in Bind9 to better protect the
name space from hacking attempts on internet name servers.  The "rndc" utility
is used to manage bind9. To allow the utility access to the bind daemon, a key
must be inserted into both the rndc and the bind configuration.  Normally there
is a default security key located in at /etc/bind/rndc.key. For security, this
file should also be set to prevent others from viewing it (i.e. chmod 640).

The auth key needs to be included in named.conf. See example named.conf for
details.

*** Samba configuration ***

Create the samba logon share as indicated in the samba confuration file
(/etc/samba/smb.conf).
As root create /tmp/smblogon and provide access rights of 744
	chmod 744 /tmp/smblogon

Use a public-admin user for public sharing of data.
Create a new user and associated group called "pub-admin".

Make sure that the /home/pub-admin folder is executable to allow
samba to traverse into it by all users for the public share:
	chmod 755 /home/pub-admin

Any user accounts in the gatekeeper "pub-admin" group will be able to connect
to the gatekeeper SMB "public" share from a remote workstation with
**read/write** access using their specific samba credentials. This means that
anyone that will need to write to, or manage, the public share via samba will
have to use their specific account credentials when connecting to the
gatekeeper public share *and* also need to be members of the "pub-admin"
group. See setting for "write list" in the samba share definition below.

The pub-admin user will be able to connect to the gatekeeper pub-admin share
using their specific pub-admin account credentials (their home share). They
can read/write to the "public" directory located in their home
"/home/pub-admin" directory. The "pub-admin" user will be able to manage the
public share area by default because it is provide via their account.

Any user on the local network will be able to remotely mount the gatekeeper
"public" share from a workstation as read-only without providing any
credentials via the "guest" account. This provides a quick and simple way to
access files in the public share on gatekeeper with ***read-only*** access.

[public]
	comment = pub - gatekeeper.zgroup.net write protected public share
	path = /home/pub-admin/public
	browseable = yes
	public = yes
	read only = yes
	guest ok = yes
	write list = @pub-admin
	force user = pub-admin
	force group = pub-admin

The following is to allow samba access to home directories which will allow
the home directory sharing to work in the samba configuration.  Set the
selinux boolean to allow samba access to home directories for sharing:
 	setsebool -P samba_enable_home_dirs on

Creat a samba "nobody" samba user with blank password for access to the the
open "public" guest share:
	smbpasswd -an nobody

Adjust SELinux to allow samba to access the public folder:
	chcon -t samba_share_t /home/public

Make sure smb and nmb are enabled to start at boot time:
	chkconfig smb on
	chkconfig nmb on

*** Arno Firewall configuration ***

Set up the firewall to start at boot for the default run levels 2,3,4:
	chkconfig arno-iptables-firewall on

List the current runlevel config for arno-iptables-firewall:
	chkconfig --list

..or more specifically:
	chkconfig --list | grep arno

Verify you see this as output:
arno-iptables-firewall 0:off 1:off 2:on 3:on 4:on 5:on 6:off

Start the firewall script:
	/etc/rc.d/init.d/arno-iptables-firewall start

You can pass the firewall script a "start" or "stop" on the command line to
enable or disable it

You can check to see if the firewall is active...
the iptables configuration as root with "/sbin/iptables -L". The output should
dump information on the kernel packet management policy setup by the
rc.iptables script. If it just indicates "accept" for Input, Forward, and
Output, then the script has not been run or it has been disabled.

Make sure the script has been run.

At this point you should have the filtering in place that is established by the
arno-iptables-firewall script. You should have protected access to the internet
using gatekeeper.  Your external interface "eth0" should be activated
automatically when the system is brought up.


*** Automated nightly backup script ***

The backup script will be executed via zadmin user account as perscribed in
the zadmin crontab.

Follow the instructions in the backup script (/root/bin/backup) for creating a
zadmin crontab entry for nightly backups and also follow the instructions in
the same script for setting up logrotation of the backup.log file.

	crontab -e

To make sure the script can backup from the various directories listed in the
backup script. For example: "/var/named/fixed/", "/etc/dhcp/", and each users
"/home" directory we need to make sure zadmin is a member of the following
groups
	named
	root
	(each users specific group)

By default when a user is created, an identically named group for that user is
created. For the zadmin to be able to read contents of the users home
directory and below zadmin must be adjusted to be a member of the respective
users group.

To add an existing user (user-name) to an existing group (group-name) while
preserving all other groups the user is currently a member of:

	usermod -a -G group-name user-name


*************************************************************************
************* user account permissions for usb scanning *****************

These steps will allow a user to physically log into gatekeeper and use an
attached USB scanner. In my case it is a HP PSC 1610 All-in-One which I use
for high-def color scanning. The hplip software package package has already
been installed.

The user must be a member of group "lp" before the scanner device can be
accessed and used. Details follow.

Identify the USB scanner by running the "sane-find-scanner" utility
as a user:
	sane-find-scanner

...should output something like:
found USB scanner (vendor=0x03f0 [HP], product=0x4811 [PSC 1600 series])
at libusb:002:002

...The "libusb:002:002" suggests a udev node entry at /dev/bus/usb/002/002

Now we will check the corresponding dev entry to find out who can read and
write this device. As sudo or root:
	ls -la /dev/bus/usb/002

...should output something like
crw-rw-r--+ 1 root lp   189, 129 Dec 25 22:46 002
    ||             | 

So we see from the attributes above that group "lp" has read and write access
to the scanner device.

Therefore any local user that requires scanner access will need to be a
member of the group "lp".

The scanimage utility also identifies the backend device and should list
the scanner device present once access has been granted. As a user:
	scanimage -L

...should output scanner device details.



*****************************************************************************
********************* Support for workstations *****************************

The next few steps add support for the workstations that will be connected to
gatekeeper on the internal subnet.

Create accounts on gatekeeper:
  Create accounts on gatekeeper for any users that will need to have shares
  available on gatekeeper. Users that do not require personal shares on
  gatekeeper will not need to have accounts on this server. Users that do not
  have accounts will still have access to public file shares, print resources
  (via pcguest) and gateway services to the internet.  The account names (and
  password) should match the account name and password used for login to their
  windows workstation. This will prevent the server from challenging them when
  they try to access their shares on gatekeeper.

Create Samba accounts:
  Any new smb accounts created must already be user accounts on the gatekeeper
  system.  Login as root or su to root and run the smbpasswd program to add
  these users into the samba database. Again, this is only for users that
  require access to personal shares on gatekeeper. Include their windows
  password or the password that they would like to use to attach to their
  private gatekeeper home share.

Connect a workstation to the hub or switch.
  Bring up the workstation.  If it's a windows workstation, then set up the
  networking to use DHCP. Set the workstation up for user login and join the
  workgroup ZGROUP.NET. You should be able to browse the network and see
  gatekeeper along with gatkeeper's printer share. Set up a printer queue for
  this printer on the workstation. Test access to the internet, printer and
  various other services that might be used (AIM, HTTP, FTP, etc.). Everything
  should be working.

The following configuration items are optional. They allow you to specify an IP
address for each workstation. The IP address will be based on the MAC address
of the workstation LAN adapter MAC (hardware address).  Additionally you can
establish a DNS name for each workstation. For example you would be able to
ping a named host, such as "ping fred1". Without local DNS host name resolution
you might have to resort to something like "ping 192.168.1.55" instead

Setting up Local DNS service to fixed IP based on MAC address

  You may want to provide DNS name resolution for the internal network. You can
  assign specific names to each workstation attached to the network. To do this
  you can fix the IP address DHCP provides to the workstation based on the MAC
  address associated to the network adapter on the workstation.

  Check the system log file (var/log/system). Inspect it to  pull the MAC
  address for the workstation when the DHCP server assigns them.
  Alternatively, you could get the MAC address of the workstation by running a
  local utility on the workstation like "ifconfig" (linux), "ipconfig /all"
  (windows), or "winipcfg" (windows).  Use the MAC address in the DHCP server
  file (dhcpd.conf) to assign a specific ip to the host.  Use the specific ip
  in the private_zone named configuration files to associate the host name to
  the ip adresses.  Make sure to set up both the forward and reverse lookup
  private_zone files with the new host information.

  Use DHCP server to assign workstation hostname

  Additionally you can have the DHCP server assign the hostname to Linux
  workstations when they are provided their network configuration. The
  advantage of this is that workstation hostnames are defined centrally at the
  server. To do this you must address two items:
  
	1. You will need to set the workstation up to accept a host name. This
	can be done in the network settings for Linux workstations.

	2. You will need to use the "host-name" option in the configuration
	file for the DHCP server (dhcpd.conf). Refer to the dhcpd.conf file in
	the gatekeeper configuration files provided.

  Important Note:
  Do not do this with workstations that use the newer Network Manager. This
  can cause X11 to crash severely. Hosts generally do not like to have their
  names changed midstream when a user logs into the system.  Systems with
  Network Manager typically ignore the hostname attribute that is provided
  with DHCP. This means that it is typically OK to send, but the workstation
  host will not automatically change it's host name to match the host-name
  attribute provided.

Setting up the samba server on gatekeeper:
  Use "System Settings - Administration - Printing" to setup a local printer on
  gatekeeper.  The local printer will be shared using samba.  There should be
  an entry in the samba config file (etc/samba/smb.conf) for the printer share.
  The samba configuration file provided will make the alias provided in the
  printcap file available to workstations on the samba guest account. This
  network printer can be installed and accessed from the Windows or Linux
  workstations.

  Take a look at the samba configuration file (/etc/samba/smb.conf) and adjust
  the shares to include the printer and any other public or private shares you
  might want to make available to the workgroup or specific members of the
  workgroup or general guest. You can get help for the samba config file using
  the manual page "man smb.conf" or other sources on the internet or in books.

  Adjust the samba configuration as required and restart the samba server after
  any changes are made (/etc/rc.d/init.d/smb restart).  Check the shares by
  browsing the network neighborhood on the workstation. Make sure to re-boot
  the windows workstation and try again. Windows does some strange things with
  networking so a reboot test for the workstation is highly recommended. :)

IMPORTANT NOTE: email, web surfing, instant messaging, ftp, etc...
  If you plan to use the gatekeeper for general or non-administrative purposes,
  make sure avoid using the root account. For security and safety, any use that
  is not related to system administration should take place from within a
  normal user account.

Add more workstations as needed.
  If you want to resolve the name of the workstation through DNS then do the
  following: Get the MAC address of the new workstation. You can get the MAC
  address by inspecting \var\log\messages for the auto assigned IP address by
  the DHCP daemon. The entry will list the MAC address of the interface that
  was granted the IP address. Set the workstation IP address in the dhcpd
  configuration file. Insert the new workstation host ip and name into the
  fixed zone configuration for named (both the forward and reverse lookup
  tables).

Once you have everything working, make sure to copy all of the customized
scripts, config files, and documentation (like this document) to media to
capture your work and make it available for future reference or for disaster
recovery.

Spend some time testing the system to make sure that everything is
working as desired.  Afterwards you can sit back and enjoy your new server.

-end-
