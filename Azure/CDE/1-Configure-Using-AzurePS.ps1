#requires -Version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Enter description here
.EXAMPLE
CD $env:USERPROFILE\Documents\GitHub\scripts\Azure\CDE
#>
Set-StrictMode -Version Latest 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$WarningActionPreference = "SilentlyContinue"
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Include]------------------------------------------------------------

.  "$PSScriptRoot\Lib-Azure.ps1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function New-CustomResourceGroup {
	New-ResourceGroup $Settings.Default.ResourceGroupName $Settings.Default.Region
}
Function Remove-CustomResourceGroup {
	Remove-ResourceGroup $Settings.Default.ResourceGroupName
}

Function New-CustomStorage {
	New-Storage -Name $Settings.Storage.Name -Type $Settings.Storage.Type `
				-ResourceGroupName $Settings.Default.ResourceGroupName -Region $Settings.Default.Region `
				-SetAsDefaultStorageForSubscription $Settings.Default.SubscriptionName
	# store in global var
	$Script:Output.Storage = Get-Storage -Name $Settings.Storage.Name `
				-ResourceGroupName $Settings.Default.ResourceGroupName -Region $Settings.Default.Region `
}

Function Remove-CustomStorage {
	Remove-Storage -Name $Settings.Storage.Name -ResourceGroupName $Settings.Default.ResourceGroupName
}

Function New-CustomNetwork {
	New-Network -Name $Settings.VirtualNet.Main.Name `
		-ResourceGroupName $Settings.Default.ResourceGroupName `
		-AddressPrefix $Settings.VirtualNet.Main.AddressPrefix `
		-Region $Settings.Default.Region `
		-Subnets $Settings.VirtualNet.Subnets
	
	$vnet = Get-Network -Name $Settings.VirtualNet.Main.Name `
						-ResourceGroupName $Settings.Default.ResourceGroupName
	# store in global vars
	$Script:Output.VirtualNet = $vnet
	$Script:Output.FrontEnd = $vnet.Subnets[0]
	$Script:Output.BackEnd = $vnet.Subnets[1]
}

Function Delete-CustomNetwork {
	Remove-Network -Name $Settings.VirtualNet.Main.Name -ResourceGroupName $Settings.Default.ResourceGroupName
}


# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-ps-create/
# To enable communication with the virtual machine in the virtual network, you need a public IP address and a network interface.

#Step 5: Create a public IP address and network interface
Function New-CustomPublicNetwork {
	$pip = Get-AzureRmPublicIpAddress -Name $Settings.VirtualMachine.PublicIpAddressName -ResourceGroupName $Settings.Default.ResourceGroupName -ErrorAction SilentlyContinue
	if (-not $pip) {
		$pip = New-AzureRmPublicIpAddress -Name $Settings.VirtualMachine.PublicIpAddressName `
				-ResourceGroupName $Settings.Default.ResourceGroupName `
				-Location $Settings.Default.Region `
				-AllocationMethod Dynamic
	}
	
	$nic = Get-AzureRmNetworkInterface -Name $Settings.VirtualMachine.NetworkInterfaceName -ResourceGroupName $Settings.Default.ResourceGroupName -ErrorAction SilentlyContinue
	if (-not $nic) {
		$nic = New-AzureRmNetworkInterface -Name $Settings.VirtualMachine.NetworkInterfaceName `
				-ResourceGroupName $Settings.Default.ResourceGroupName `
				-Location $Settings.Default.Region `
				-SubnetId $Script:Output.FrontEnd.Id `
				-PublicIpAddressId $pip.Id
	}
}

# Step 6: Create a virtual machine
Function New-CustomVirtualMachine {
	#New-CustomPublicNetwork
	
	#TODO: create vm
	# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-ps-create/
}




Function Cleanup-All {
	Remove-CustomStorage
	Delete-CustomNetwork
	# should be last one
	Remove-CustomResourceGroup
}
#init;Cleanup-All; exit

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Init-Azure

$prefix = "CDE_Test"

$Settings = @{
	Default = @{ 
		SubscriptionName = "Visual Studio Enterprise"
		Region = "EastUS" 
		ResourceGroupName = "$($prefix)ResourceGroup"
	}
	Storage = @{
		# Valid: lowercase letters and numbers only
		Name = "$($prefix)Storage".ToLower() -replace "[^a-z0-9]",""
		<#
		• Standard_LRS (Locally-redundant storage)
		• Standard_ZRS (Zone-redundant storage)
		• Standard_GRS (Geo-redundant storage)
		• Standard_RAGRS (Read access geo-redundant storage)
		#>
		Type = "Standard_LRS"
	}
	VirtualNet = @{
		Main = @{ Name = "$($prefix)Network"; AddressPrefix = '10.8.0.0/16' }
		Subnets = @{
			FrontEnd = @{ Name = "$($prefix)FrontEndSubnet"; AddressPrefix = '10.8.1.0/24' }
			BackEnd = @{ Name = "$($prefix)BackEndSubnet"; AddressPrefix = '10.8.2.0/24' }
		}
	}
	VirtualMachine = @{
		PublicIpAddressName = "myIPaddress1"  # a name for the public IP address
		NetworkInterfaceName = "mynic1"		  # a name for the network interface (NIC)
		# The password must be at 12-123 characters long 
		# and have at least one lower case character, one upper case character, 
		# one number, and one special character.
	}
}

$Output = @{
	Storage = $null
	VirtualNet = $null
	FrontEnd = $null
	BackEnd = $null
}

#-----------------------------------------------------------[Testing]------------------------------------------------------------

#Get-AzureVmImage

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Enter-AzureLogin
New-CustomResourceGroup
New-CustomStorage
New-CustomNetwork

#New-CustomVirtualMachine
