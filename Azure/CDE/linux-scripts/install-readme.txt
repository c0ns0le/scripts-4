Installation Script
	Recommended
		A StackScript for installing the most recent stable ClearOS 7 release
		https://www.linode.com/stackscripts/view/13940-clearos-ClearOS+7
	Best
		https://www.clearos.com/clearfoundation/social/community/howto-install-clearos-community-and-professional-on-cloudatcost-com
Copy Scripts
Run Script	
	cd ~/install_scripts
	chmod +x install_clearos_*.sh
	sudo ./install_clearos_72.sh
Azure Extra
	Virtual Machine
		DNS	
			Public IP Address
				Configuration
					DNS name Label
						tempclearos.eastus.cloudapp.azure.com
			Associate to public IP
		Network Security Group
			(-netsec) add Port 81
			Inbound Security Rules
				Add
					Name: tempclearos-allow-81
					Source
					Protocol
					Source Port Range
					Destination port range: 81
					Action: Allow
HTTPS
	Install HTTPS certificate
		By default, shows warning
	How to Request/Install a certificate
		http://www.webmin.com/faq.html
Webconfig - web-based administration tool
	Make a Webmin user always use the same password as Unix?		
		http://www.webmin.com/faq.html
	Change Webconfig user password
		Assuming you have installed Webmin in /usr/libexec/webmin
			/usr/libexec/webmin/changepass.pl /etc/webmin host abcde12345$$
	Url
		https://tempclearos.eastus.cloudapp.azure.com:81
		https://40.121.145.184:81
	Login
		root
		<system-pwd>
