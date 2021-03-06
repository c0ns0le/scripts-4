<#
.SYNOPSIS
  Funciones Para Administrar IIS
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop" # Set Error Action to Stop

#-----------------------------------------------------------[Functions]------------------------------------------------------------

##region IIS Functions
Function SetAlias-AppCmdIIS {
	if (-not (Get-Alias "appcmd" -ErrorAction SilentlyContinue)) {
		Register-Alias "appcmd" "$env:SystemRoot\system32\inetsrv\appcmd.exe"
	}
}

Function Run-CommandIIS($Text, $ArgList, [switch]$HideCommandLine = $false, [switch]$IgnoreError = $false, [int[]]$SuccessExitCodes = 0) {
	SetAlias-AppCmdIIS
	if ($Text) { Write-Header $Text }
	if (-not $HideCommandLine) { Write-Verbose "appcmd $ArgList" }
	appcmd $ArgList
	if (-not $HideCommandLine) { "" }
	if (-not $IgnoreError) { 
		if (-not ($SuccessExitCodes -contains $LASTEXITCODE)) { throw "LASTEXITCODE: $LASTEXITCODE" }
	}
	if ($Text) { Write-Footer "OK" }
}


#region Config
Function Set-ConfigIIS($Text, $SiteName, $Settings) {
	$argList = @("set", "config", "`"$SiteName`"") + $Settings
	Run-CommandIIS -Text $Text -ArgList $argList
}
#endregion Config


#region Application Pool
Function Test-AppPool($Name) {
	Run-CommandIIS -ArgList "list", "apppool", $Name -HideCommandLine -IgnoreError
	return $LASTEXITCODE -eq 0
}

Function New-AppPool {
#New-AppPool -Name $Name -UserName $UserName -Password $Password -Enable32BitAppOnWin64 1
Param(
[Parameter(Mandatory=$true)][string]$Name, 
[string]$UserName, 
[string]$Password,
[bool]$Enable32BitAppOnWin64,
[Switch]$BypassPermissions = $false
)
	Write-Header "New-AppPool '$Name'"

	if (Test-AppPool $Name) { Write-Footer "OK ('$Name' ya existe)"; return }

	<#
set appcmd=%SystemRoot%\system32\inetsrv\appcmd.exe
%appcmd% add apppool /name:"zeusdnn" /managedRuntimeVersion:v4.0 /enable32BitAppOnWin64:true /processModel.identityType:SpecificUser /processModel.userName:"temphost" /processModel.password:"abc123$"
%appcmd% delete apppool /apppool.name:"zeusdnn"
	#>
	$argList = "add", "apppool", "/name:`"$Name`"", "/managedRuntimeVersion:v4.0"
	if ($enable32BitAppOnWin64) { $argList += "/enable32BitAppOnWin64:true" }
	if ($UserName) {
		$argList += @("/processModel.identityType:SpecificUser", 
					"/processModel.userName:`"$UserName`"", 
					"/processModel.password:`"$password`"")
	}
	Run-CommandIIS -ArgList $argList
	
	# small delay so that it creates built-in user or it will raise error
	Start-Sleep -Milliseconds 500
	
	if ($BypassPermissions) { return }
	
	# special folders such as "C:\inetpub\temp\appPools" as given access through this group
	Add-GroupMember -Name "IIS_IUSRS" -Member $UserName
	
	# set permissions
	@("$env:SystemRoot\Temp", 
	"$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
	"$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files") | % {
		GrantFull-WindowsACL $_ "IIS_IUSRS"
		GrantFull-WindowsACL $_ "IIS AppPool\$Name"
	}
	
	Write-Footer "OK"
}


Function Remove-AppPool($Name) {
	# %appcmd% delete apppool /apppool.name:"zeusdnn"
	if (-not (Test-AppPool $Name)) { return }
	Run-CommandIIS -Text "Remove-AppPool '$Name'" -ArgList "delete", "apppool", "/apppool.name:`"$Name`""
	# wait for changes to take effect
	Start-Sleep -Milliseconds 500
}
#endregion Application Pool


#region Web Site
Function Test-Site($Name) {
	Run-CommandIIS -ArgList "list", "site", $Name -HideCommandLine -IgnoreError
	return $LASTEXITCODE -eq 0
}

Function New-Site {
#New-Site -Name $SiteName -PhysicalPath $SitePhysicalPath -AppPoolName $AppPoolName -IPAddress $SiteIPAddress -Alias $SiteAlias -Port $SitePort # -MaxUrlSegments $SiteMaxUrlSegments
Param(
[Parameter(Mandatory=$true)][string]$Name, 
[string]$PhysicalPath, 
[string]$AppPoolName,
[string]$IPAddress,
[string]$Alias,
[int]$Port = 80,
[int]$MaxUrlSegments = 120
)
	SetAlias-AppCmdIIS
	if (!$AppPoolName) { $AppPoolName = $Name }
	if (!$IPAddress) { $IPAddress = "*" }
	# NOTE: alias can be empty
	#if (!$Alias) { $Alias = $Name }
	
	Write-Header "New-Site '$Name'"
	if (Test-Site $Name) { Write-Footer "OK ('$Name' ya existe)"; return }
	
	#bindings:protocol/ipaddress:port:alias
	$argList = @("add", "site", "/name:`"$Name`"", 
				("/bindings:http/{0}:{1}:{2}" -f $IPAddress,$Port,$Alias), 
				"/physicalPath:$physicalPath",
				"/applicationDefaults.applicationPool:$AppPoolName"
				)
				#"/physicalPath:`"$physicalPath`"", "/applicationDefaults.applicationPool:`"$AppPoolName`""
	Write-Verbose "appcmd $argList"
	appcmd $argList
	""
	if ($LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE" }

	# add required permissions
	GrantFull-WindowsACL $physicalPath "IIS AppPool\$AppPoolName"
	GrantReadOnly-WindowsACL $physicalPath "Users" -FindLocalizedName
	
	# extra feature for win2012 or above
	if (IsWin2012OrAbove-OSVersion -and $maxUrlSegments) {
		Write-Header "Updating maxUrlSegments:$maxUrlSegments..."
		$argList = "set", "site", $Name, "/limits.maxUrlSegments:$maxUrlSegments"
		Write-Verbose "appcmd $argList"
		appcmd $argList
		""
	}
	
	# authentication
	Set-ConfigIIS -Text "Anonymous Authentication:Enabled" -SiteName $SiteName -Settings "/section:anonymousAuthentication", "/enabled:true", "/commit:apphost"
	Set-ConfigIIS -Text "Windows Authentication:Disabled" -SiteName $SiteName -Settings "/section:windowsAuthentication", "/enabled:false", "/commit:apphost"

	Write-Footer "OK"
}

Function Remove-Site($Name) {
	# %appcmd% delete site "abc"
	if (-not (Test-Site $Name)) { return }
	Run-CommandIIS -Text "Remove-Site '$Name'" -ArgList "delete", "site", $Name
	# wait for changes to take effect
	Start-Sleep -Milliseconds 100
}
#endregion Web Site


#region Web Application

Function New-WebApp($siteName, $virtualPath, $physicalPath) {
	Run-CommandIIS -Text "New-WebApp '$siteName$virtualPath'" `
		-ArgList "add", "app", "/site.name:`"$siteName`"" "/path:`"$virtualPath`"", "/physicalPath:`"$physicalPath`""
}

#endregion Web Application


#region Virtual Directories

Function New-VirtualDir($siteName, $virtualPath, $physicalPath) {
	<#
	appcmd list vdir zeusdnn_1_Main/*
	appcmd add vdir /app.name:zeusdnn_1_Main/ /path:"/DesktopModules/ZeusConectorHardware" /physicalPath:"C:\TFS\Zeus\Comun\Portales\Dev\ConectoresHardware\ConectoresHardware"
	appcmd delete vdir /vdir.name:"zeusdnn_1_Main/DesktopModules/ZeusConectorHardware"
	#>
	Delete-VirtualDir $siteName $virtualPath

	Run-CommandIIS -Text "New-VirtualDir '$siteName$virtualPath'" `
				-ArgList "add", "vdir", "/app.name:`"$siteName/`"", "/path:`"$virtualPath`"", "/physicalPath:`"$physicalPath`""
}


Function Delete-VirtualDir($siteName, $virtualPath) {
	Run-CommandIIS -Text "Delete-VirtualDir '$siteName$virtualPath'" `
				-ArgList "delete", "vdir", "/vdir.name:`"$siteName$virtualPath`"" -SuccessExitCodes 0,50
	# wait for changes to take effect
	Start-Sleep -Milliseconds 100
}
#endregion Virtual Directories

##endregion IIS Functions

