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
				-ResourceGroupName $Settings.Default.ResourceGroupName `
				-Region $Settings.Default.Region `
				-SetAsDefaultStorageForSubscription $Settings.Default.SubscriptionName
	# store in global var
	$Script:Output.Storage = Get-Storage -Name $Settings.Storage.Name `
				-ResourceGroupName $Settings.Default.ResourceGroupName
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

Function Remove-CustomNetwork {
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
	New-CustomPublicNetwork
	
	#TODO: create vm
	# https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-ps-create/

<#
Run the command to set the administrator account name and password for the virtual machine.

Copy
$cred = Get-Credential -Message "Type the name and password of the local administrator account."
The password must be at 12-123 characters long and have at least one lower case character, one upper case character, one number, and one special character.

Replace the value of $vmName with a name for the virtual machine. Create the variable and the virtual machine configuration.

Copy
$vmName = "myvm1"
$vm = New-AzureRmVMConfig -VMName $vmName -VMSize "Standard_A1"
See Sizes for virtual machines in Azure for a list of available sizes for a virtual machine.

Replace the value of $compName with a computer name for the virtual machine. Create the variable and add the operating system information to the configuration.

Copy
$compName = "myvm1"
$vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $compName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
Define the image to use to provision the virtual machine.

Copy
$vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
See Navigate and select Windows virtual machine images in Azure with PowerShell or the CLI for more information about selecting images to use.

Add the network interface that you created to the configuration.

Copy
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
Replace the value of $blobPath with a path and filename in storage that the virtual hard disk will use. The virtual hard disk file is usually stored in a container, for example vhds/WindowsVMosDisk.vhd. Create the variables.

Copy
$blobPath = "vhds/WindowsVMosDisk.vhd"
$osDiskUri = $storageAcc.PrimaryEndpoints.Blob.ToString() + $blobPath
Replace The value of $diskName with a name for the operating system disk. Create the variable and add the disk information to the configuration.

Copy
$diskName = "windowsvmosdisk"
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage
Finally, create the virtual machine.

Copy
New-AzureRmVM -ResourceGroupName $rgName -Location $locName -VM $vm
You should see the resource group and all its resources in the Azure portal and a success status in the PowerShell window:

Copy
RequestId  IsSuccessStatusCode  StatusCode  ReasonPhrase
---------  -------------------  ----------  ------------
                          True          OK  OK
#>
}




Function Cleanup-All {
	Remove-CustomStorage
	Remove-CustomNetwork
	# should be last one
	Remove-CustomResourceGroup
}


#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Init-Azure

$prefix = "CDE_Test-"

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
		PublicIpAddressName = "$($prefix)IPAddress"  # a name for the public IP address
		NetworkInterfaceName = "$($prefix)NIC"		  # a name for the network interface (NIC)
		# The password must be at 12-123 characters long 
		# and have at least one lower case character, one upper case character, 
		# one number, and one special character.
		Name = "$($prefix)clearos"
		UserName = "host"
		Password = 'abcde12345$$'
		<#
		--tempclearos
		23.96.44.226
		host
		abcde12345$$
		#>
	}
}

$Output = @{
	Storage = $null
	VirtualNet = $null
	FrontEnd = $null
	BackEnd = $null
}

#-----------------------------------------------------------[Testing]------------------------------------------------------------
#Cleanup-All;exit

#Get-AzureVmImage

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Enter-AzureLogin

New-CustomResourceGroup
New-CustomStorage
New-CustomNetwork
#New-CustomVirtualMachine
