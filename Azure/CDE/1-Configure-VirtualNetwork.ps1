#requires -Version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Enter description here
.EXAMPLE
CD C:\Users\PEscobar\Documents\GitHub\scripts\Azure\CDE
.\1-Configure-VirtualNetwork.ps1
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init {
	Import-Module AzureRM
	#Import-Module Azure
}

#region Credentials
Function Export-Credential($cred, $path) {
#=====================================================================
# Export-Credential
# Usage: Export-Credential $CredentialObject $FileToSaveTo
#=====================================================================
      $cred = $cred | Select-Object *
      $cred.password = $cred.Password | ConvertFrom-SecureString
      $cred | Export-Clixml $path
}


Function Get-MyCredential {
#=====================================================================
# Get-MyCredential
#=====================================================================
    $CredPath = "$PSScriptRoot\cred_${env:ComputerName}.bin"
	if (!(Test-Path -Path $CredPath -PathType Leaf)) {
        Export-Credential (Get-Credential) $CredPath
    }
    $cred = Import-Clixml $CredPath
    $cred.Password = $cred.Password | ConvertTo-SecureString
    $Credential = New-Object System.Management.Automation.PsCredential($cred.UserName, $cred.Password)
    Return $Credential
}
#endregion Credentials

#region Authenticate
Function Apply-PublishSettings {
	"Apply-PublishSettings"
	$settingsFile = Get-ChildItem "${env:UserProfile}\Downloads\test-Backups-prod**-credentials.publishsettings" | Select -ExpandProperty FullName -Last 1
	if (-not $settingsFile -and -not (Test-Path $settingsFile)) {
		Get-AzurePublishSettingsFile
		$settingsFile = Get-ChildItem "${env:UserProfile}\Downloads\test-Backups-prod**-credentials.publishsettings" | Select -ExpandProperty FullName -Last 1
	}
	Import-AzurePublishSettingsFile $settingsFile | Out-Null
}


Function Apply-Subscription {
	$subscriptionName = $Script:Settings.Subscription.Name
	"Apply-Subscription '$subscriptionName'"
	# To select a default subscription for your current session
	Get-AzureRmSubscription –SubscriptionName $subscriptionName | Select-AzureRmSubscription | Out-Null
}

Function Create-ResourceGroup {
	$resourceName = $Script:Settings.ResourceGroup.Name
	If ((Get-AzureRmResourceGroup $resourceName -ErrorAction SilentlyContinue).Count) {
		"FOUND: ResourceGroup '$resourceName'"
	}
	else {
		New-AzureRmResourceGroup -Name $resourceName -Location $Script:Settings.ResourceGroup.Region
		"CREATED: ResourceGroup '$resourceName'"
	}
}
#endregion Authenticate


#region VirtualNetwork
Function CreateMain-VirtualNetwork {
	$virtualNetName = $Script:Settings.VirtualNet.Main.Name
	"CreateMain-VirtualNetwork '$virtualNetName'"
	
	$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $Script:Settings.ResourceGroup.Name -Name $virtualNetName -ErrorAction SilentlyContinue
	$isDirty = $false
	if (-not $vnet) {
		$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $Script:Settings.ResourceGroup.Name `
					-Name $virtualNetName `
					-AddressPrefix $Script:Settings.VirtualNet.Main.AddressPrefix `
					-Location $Script:Settings.ResourceGroup.Region
		$isDirty = $true
	}
	$Script:Output.VirtualNet = $vnet
	
	$Script:Settings.VirtualNet.Subnets.GetEnumerator() | % {
		$wasAdded = CreateSubnet-VirtualNetwork $_.Value
		if ($wasAdded) { $isDirty = $true }
	}

	# save to azure
	if ($isDirty)  {
		Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
	}	
}

Function CreateSubnet-VirtualNetwork($subnet) {
	$subnetName = $subnet.Name
	$subnetAddress = $subnet.AddressPrefix
	Write-Host "    CreateSubnet-VirtualNetwork '$subnetName' $subnetAddress"

	$subnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $Script:Output.VirtualNet -ErrorAction SilentlyContinue
	if (-not $subnet) {
		$subnet = Add-AzureRmVirtualNetworkSubnetConfig -Name $subnetName `
    					-AddressPrefix $subnetAddress -VirtualNetwork $Script:Output.VirtualNet
    					#-AddressPrefix '10.8.1.0/24' -VirtualNetwork $Script:Output.VirtualNet
		return $true
	}
	return $false
}

Function Delete-VirtualNetwork {
	$virtualNetName = $Script:Settings.VirtualNet.Main.Name
	"Delete-VirtualNetwork '$virtualNetName'"
	Remove-AzureRmVirtualNetwork -Name $virtualNetName -ResourceGroupName $Script:Settings.ResourceGroup.Name -Force -ErrorAction SilentlyContinue
}
#endregion VirtualNetwork


#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
Init

$suffix = "Test"

$Settings = @{
	Subscription = @{ Name = "test" }
	ResourceGroup = @{ Name = "CDEResourceGroup$suffix"; Region = "EastUS" }
	VirtualNet = @{
		Main = @{ Name = "CdeMain$suffix"; AddressPrefix = '10.8.0.0/16' }
		Subnets = @{
			FrontEnd = @{ Name = "CdeFrontEnd$suffix"; AddressPrefix = '10.8.1.0/24' }
			BackEnd = @{ Name = "CdeBackEnd$suffix"; AddressPrefix = '10.8.2.0/24' }
		}
	}
}

$Output = @{
	VirtualNet = $null
	FrontEnd = $null
	BackEnd = $null
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#$cred = Get-MyCredential
Apply-PublishSettings
Login-AzureRmAccount
Apply-Subscription
#Login-AzureRmAccount -Credential $cred -SubscriptionName "test"

Create-ResourceGroup

Delete-VirtualNetwork

#CreateMain-VirtualNetwork
