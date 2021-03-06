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
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init-Azure {
	Clear-Host
	Import-Module Azure
	Disable-AzureDataCollection | Out-Null
}

#region Credentials
Function Export-Credential($cred, $path) {
#Export-Credential $CredentialObject $FileToSaveTo
      $cred = $cred | Select-Object *
      $cred.password = $cred.Password | ConvertFrom-SecureString
      $cred | Export-Clixml $path
}

Function Get-MyCredential {
    $CredPath = "$PSScriptRoot\cred_${env:ComputerName}.bin"
	if (!(Test-Path -Path $CredPath -PathType Leaf)) {
        Export-Credential (Get-Credential) $CredPath
    }
    $cred = Import-Clixml $CredPath
    $cred.Password = $cred.Password | ConvertTo-SecureString
    $Credential = New-Object System.Management.Automation.PsCredential($cred.UserName, $cred.Password)
    Return $Credential
}

Function Test-AzureLogin {
	try {
		Get-AzureRmContext | Out-Null
		return $true
	}
	catch { return $false }
}

Function Enter-AzureLogin {
	"Enter-AzureLogin"
	if (Test-AzureLogin) { "OK (Already Logged in)"; return }

	$cred = Get-MyCredential
	# use azure AD integrated account or it will raise error: To sign into this application the account must be added to the xxxx.com directory
	#Add-AzureRmAccount -Credential $cred | Out-Null
	Login-AzureRmAccount -Credential $cred | Out-Null
	
	# set default subscription
	Get-AzureRmSubscription –SubscriptionName $Script:Settings.Default.SubscriptionName | Select-AzureRmSubscription | Out-Null
	"OK"
}

Function Exit-AzureLogin {
	#azure logout -u (Get-MyCredential).UserName
}
#endregion Credentials

#region Azure MarketPlace VmImages
Function Find-VmImage {
# Find-VmImage -PublisherName "OpenLogic"
# -Skus 7.2 -Offer CentOS -PublisherName OpenLogic
Param(
[string[]]$PublisherName,
[string]$Offer = 'CentOS',
[string]$Skus
)
	$pubs = $PublisherName
	$offerLike = $Offer
	$skuLike = $Skus
	$pubName = $null
	if (-not $pubs) {
		$pubs = Get-AzureRmVMImagePublisher -Location $Settings.Default.Region | Select -ExpandProperty PublisherName
	}
		
	foreach ($pub in $pubs) {
		$pubName = $pub
		$offers = Get-AzureRmVMImageOffer -Location $Settings.Default.Region -PublisherName $pubName | ? { -not $offerLike -or $_.Offer -like $offerLike } | Select -ExpandProperty Offer
		if ($offers) { break }
	}

	if ($offers) {
		foreach ($offerName in $offers) {
			Get-AzureRmVMImageSku -Location $Settings.Default.Region -Publisher $pubName -Offer $offerName | ? { -not $skuLike -or $_.Skus -like $skuLike }
		}
	}
}
#endregion Azure MarketPlace VmImages

#region Resource Groups
Function Test-ResourceGroup($Name) {
	return (Get-AzureRmResourceGroup -Name $Name -ErrorAction SilentlyContinue) -ne $null
}

Function New-ResourceGroup($Name, $Region) {
	"New-ResourceGroup '$Name'"
	if (Test-ResourceGroup $Name) { "OK (Found)"; return }
	New-AzureRmResourceGroup -Name $Name -Location $Region | Out-Null
	"OK"
}

Function Remove-ResourceGroup($Name) {
	"Remove-ResourceGroup '$Name'"
	if (-not (Test-ResourceGroup $Name)) { "OK (Not Found)"; return }
	Remove-AzureRmResourceGroup -Name $Name -Force
	"OK"
}
#endregion Resource Groups

#region Storage Account
Function Test-Storage {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
	return (Get-AzureRmStorageAccount -Name $Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) -ne $null
}

Function Get-Storage {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
	Get-AzureRmStorageAccount -Name $Name -ResourceGroupName $ResourceGroupName
}

Function New-Storage {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[ValidateSet("Standard_LRS", "Standard_ZRS", "Standard_GRS", "Standard_RAGRS")]
[string]$Type = "Standard_LRS",
[Parameter(Mandatory=$true)][string]$ResourceGroupName,
[Parameter(Mandatory=$true)][string]$Region,
[string]$SetAsDefaultStorageForSubscription
)
	"New-Storage '$Name'"
	if (Test-Storage $Name $ResourceGroupName) { "OK (Already exists)"; return }

	New-AzureRmStorageAccount -Name $Name -ResourceGroupName $ResourceGroupName `
						-Type $Type -Location $Region | Out-Null
	"OK"
}

Function Remove-Storage {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
	"Remove-Storage '$Name'"
	if (-not (Test-Storage $Name $ResourceGroupName)) { "OK (Not Found)"; return }
	Remove-AzureRmStorageAccount -Name $Name -ResourceGroupName $ResourceGroupName
	"OK"
}
#endregion Storage Account

#region Virtual Network
#region SubNetwork
Function Get-SubNetwork {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$Network
)
	Get-AzureRmVirtualNetworkSubnetConfig -Name $Name -VirtualNetwork $Network -ErrorAction SilentlyContinue
}

Function Test-SubNetwork {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$Network
)
	return (Get-SubNetwork -Name $Name -Network $Network) -ne $null
}

Function New-SubNetwork {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$AddressPrefix,
[Parameter(Mandatory=$true)][Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$Network
)
	"New-SubNetwork '$Name' $AddressPrefix"
	Add-AzureRmVirtualNetworkSubnetConfig -Name $Name -AddressPrefix $AddressPrefix -VirtualNetwork $Network | Out-Null
	"OK"
}
#enregion SubNetwork

#region Main Network
Function Get-Network {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
	Get-AzureRmVirtualNetwork -Name $Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}


Function Test-Network {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
	return (Get-Network -Name $Name -ResourceGroupName $ResourceGroupName) -ne $null
}

Function New-Network {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName,
[Parameter(Mandatory=$true)][string]$AddressPrefix,
[Parameter(Mandatory=$true)][string]$Region,
[Parameter(Mandatory=$true)]$Subnets
)
	"New-Network '$Name' $AddressPrefix"
	$vnet = Get-Network -Name $Name -ResourceGroupName $ResourceGroupName
	$isDirty = $false
	if (-not $vnet) {
		$vnet = New-AzureRmVirtualNetwork -Name $Name -ResourceGroupName $ResourceGroupName `
						-AddressPrefix $AddressPrefix -Location $Region
		$isDirty = $true
	}

	$Subnets.GetEnumerator() | % {
		$item = $_.Value
		if (-not (Test-SubNetwork -Name $item.Name -Network $vnet)) {
			New-SubNetwork -Name $item.Name -AddressPrefix $item.AddressPrefix -Network $vnet
			$isDirty = $true
		}
	}

	# save to azure
	if ($isDirty)  {
		Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
		"OK"
	}
	else {
		"OK (Already found and no changes were made)"
	}
}

Function Remove-Network {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$ResourceGroupName
)
	"Remove-Network '$Name'"
	if (Test-Network $Name $ResourceGroupName) {
		Remove-AzureRmVirtualNetwork -Name $Name -ResourceGroupName $ResourceGroupName -Force
		"OK"
	}
	else {
		"OK (Not Found)"
	}
}
#endregion Main Network

#endregion Virtual Network

#region Virtual Machine
Function Get-AzureVmImage($Pattern) {
	azure vm list $Script:Settings.Default.Region
}
#endregion Virtual Network

