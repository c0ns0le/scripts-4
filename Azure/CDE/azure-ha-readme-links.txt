Azure PCI
	PCI-DSS
	https://www.microsoft.com/en-us/trustcenter/compliance/pci
Azure PCI-DSS to Customers
	http://www.zdnet.com/article/microsofts-windows-azure-gets-payment-card-compliance-nod/
	This of course presents a problem for cloud data centres like Azure, where it's impossible to allow auditors every time a customer requires a certification. So, the way around this is for Microsoft to achieve compliance. Today's announcement means customers can now deploy applications and have them certified, so this opens up Azure for a new type of workload."

	PCI DSS is just one of a growing number of compliance certifications that Azure now meets. Azure completed its annual ISO audit, according to Azure General Manager Steven Martin.
Tags
	Uso de etiquetas para organizar los recursos de Azure | Microsoft Azure
	https://azure.microsoft.com/es-es/documentation/articles/resource-group-using-tags/
Templates
	Tutorial de la plantilla de Resource Manager | Microsoft Azure
	https://azure.microsoft.com/es-es/documentation/articles/resource-manager-template-walkthrough/

Service Fabric
	Service Fabric Mindmap
	https://azure.microsoft.com/en-us/documentation/learning-paths/service-fabric/

	Service Fabric IoT Sample (Event Hubs + Azure PowerBI)
	https://github.com/Azure-Samples/service-fabric-dotnet-iot

Analytics & Metrics
	Azure and Power BI | Microsoft Power BI
	https://powerbi.microsoft.com/en-us/documentation/powerbi-azure-and-power-bi/
	
	Power BI web app sample
	https://msdn.microsoft.com/en-us/library/mt186158.aspx

	Get started with Stream Analytics: Real-time fraud detection | Microsoft Azure
	https://azure.microsoft.com/en-us/documentation/articles/stream-analytics-get-started/
	
	
	Pricing - Stream Analytics | Microsoft Azure
	https://azure.microsoft.com/en-us/pricing/details/stream-analytics/
Configure HA
	Terms
		A fault domain
			ensures that the members of the availablity set have separate power and network resouces. 
		An update domain
			ensures that members of the availabilty set are not brought down for maintenance at the same time
	Manual
		Configure Always On availability group in Azure VM manually - Resource Manager
		https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-portal-sql-alwayson-availability-groups-manual/
	Templated
		Configuración de Azure Resource Manager para grupos de disponibilidad AlwaysOn | Microsoft Azure
		https://azure.microsoft.com/es-es/documentation/articles/virtual-machines-windows-portal-sql-alwayson-availability-groups/
	Example
	autoHAVNET
		10.0.0.0/16
		Subnet-dc
			10.0.0.0/24
		Subnet-sql
			10.0.1.0/24
	Availabiltiy Set
		adAvailabilitySet: Domain Controller
			ad-primary-dc
				Network Security Group
					Same name as the VM
				Diagnostics	Enabled
					Diagnostics storage account	Automatically created
				Availability set
					adAvailabilitySet
			ad-secondary-dc
		SQL Server
Load Balancer			
	Manage the availability of Windows VMs | Microsoft Azure
	https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-manage-availability/

	Create Listener for AlwaysOn availabilty group for SQL Server in Azure Virtual Machines
	https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-portal-sql-alwayson-int-listener/
Web Site to VNET
	Integrate an app with an Azure Virtual Network
	https://azure.microsoft.com/en-us/documentation/articles/web-sites-integrate-with-vnet/

	
	Configuración de una conexión de puerta de enlace de VPN punto a sitio a una Red virtual de Azure | Microsoft Azure
	https://azure.microsoft.com/es-es/documentation/articles/vpn-gateway-howto-point-to-site-rm-ps/
App Service Environment (App Service on a Secured Network)
	Introduction to App Service Environment
	https://azure.microsoft.com/en-us/documentation/articles/app-service-app-service-environment-intro/
	
	Architecture
	https://azure.microsoft.com/en-us/documentation/articles/app-service-app-service-environment-layered-security/
	
		You can use network security groups to restrict inbound network communications to the subnet 
		where an App Service Environment resides. 
		This allows you to run apps behind upstream devices and services such as WEB APPLICATION FIREWALLS, 
		and network SaaS providers.
	
	enable high scale and secure network access
	https://azure.microsoft.com/documentation/videos/azurecon-2015-deploying-highly-scalable-and-secure-web-and-mobile-apps/
	
	Integrate an Azure App Service to V2 VNet
	https://blog.gearoidcrowley.com/integrate-an-azure-app-service-to-v2-vnet/
	"...We have setup a connection from an Azure App Service to a VM located in a V2 network"
	
	horizontally scaling using multiple App Service Environments
	https://azure.microsoft.com/documentation/articles/app-service-app-service-environment-geo-distributed-scale/
	
	Choice 1 (http://goo.gl/qonDT4)
		PROBLEM
		You could create a v2 VNet and have a site to site VPN between them. This would give a reasonably flat / Open IP structure. The problem with this will be that you are limited to approx 10mb bandwidth and the only way to up that would be to use Express Route.
		
	Choice 2 (http://goo.gl/qonDT4)
		SOLUTION
		I found another way.(I also found some discussion online that V2 VNET integration should be ready in a matter of days or weeks.): 
		Expand your resource group and then under Microsoft.Web, find your web app.
		Click on that, and scroll down in the details pane to find the following outboundIpAddresses
		For each of these, go to your Resource Manager VM Network Security resource, and add the required Inbound Security Rule. Watch out, the inbound security rule changes do not take effect immediately. I observed delays of about 2 mins before they worked.
private IP address ranges are:
	10.0.0.0/8 - this is the same as 10.0.0.0 - 10.255.255.255
	172.16.0.0/12 - this is the same as 172.16.0.0 - 172.31.255.255
	192.168.0.0/16 - this is the same as 192.168.0.0 - 192.168.255.255

Porque la nube?
	¿Por qué usar Hadoop en la nube?
	https://azure.microsoft.com/es-es/solutions/hadoop/

Azure Resource Explorer
	Give you the powershell equivalent command
	https://resources.azure.com
Disable FTP (force FTPS) on Web Apps
	https://goo.gl/PG9l9f
	There is a way to effectively disable FTP and FTP/S - however the app mus be running on App Service Environments as opposed to the public multi-tenant service (which I'm guessing is what you are currently using).
	On App Service Environments customers can control inbound network traffic, including, disabling inbound calls to the FTP endpoints.
Azure Tools
	Microsoft Azure Web Site Cheat Sheet
	http://microsoftazurewebsitescheatsheet.info/
VNET
	Create a VNet-to-VNet VPN Gateway connection using Azure Resource Manager and PowerShell for VNets | Microsoft Azure
	https://azure.microsoft.com/en-us/documentation/articles/vpn-gateway-vnet-vnet-rm-ps/
	
	DMZ en Azure - Introducción a Red virtual de Azure (VNet)
	https://azure.microsoft.com/es-es/documentation/articles/virtual-networks-overview/
	
Traffic Manager
	Implementing a Layered Security Architecture with App Service Environments
	https://azure.microsoft.com/en-us/documentation/articles/app-service-app-service-environment-layered-security/
	
	Precios - Servicio de aplicaciones | Microsoft Azure
	https://azure.microsoft.com/es-es/pricing/details/app-service/