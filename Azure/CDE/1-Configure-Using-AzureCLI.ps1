#requires -Version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Enter description here
.EXAMPLE
CD $env:USERPROFILE\Documents\GitHub\scripts\Azure\CDE
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init {
	Clear-Host
	# Setting the Resource Manager mode
	azure config mode arm
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

Function Test-AzureLogin {
	azure tag list | Out-Null
	return $LASTEXITCODE -eq 0
}

Function Enter-AzureLogin {
	if (Test-AzureLogin) { "Already Logged in!"; return }

	$cred = Get-MyCredential
	# NOTE: auto login not working with an account not added to AD
	#azure login -u $cred.UserName
	# use azure AD integrated account or it will raise error: To sign into this application the account must be added to the xxxx.com directory
	azure login -q -u $cred.UserName -p $cred.GetNetworkCredential().password
	
	# set default subscription
	azure account set $Script:Settings.Default.SubscriptionName
}

Function Exit-AzureLogin {
	azure logout -u (Get-MyCredential).UserName
}
#endregion Credentials

#region Virtual Machine
Function Get-AzureVmImage($FilterText) {
	azure vm list $Script:Settings.Default.Region
}
#endregion

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
Init

$suffix = "Test"

$Settings = @{
	Default = @{ SubscriptionName = "Visual Studio Enterprise"; Region = "EastUS" }
	ResourceGroup = @{ Name = "CDEResourceGroup$suffix" }
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

Enter-AzureLogin
