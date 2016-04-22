#requires -Version 4.0
#requires -RunAsAdministrator
#
#if ($Script:IisFunctionsLoaded) { "IIS Functions Already Loaded"; return } else { $Script:IisFunctionsLoaded = $true }


#region IIS Functions
Function Init-AppCmd {
	Set-Alias appcmd -Value "$env:SystemRoot\system32\inetsrv\appcmd.exe" -Scope "Script"
}

Function Exist-Site($siteName) {
	<#
	appcmd list site dev.dnndev.me
	#>
	$cmdOutput = appcmd list site "$siteName"
	return ($LASTEXITCODE -eq 0)
}
#UNIT-TEST
#Exist-Site "dev.dnndev.me";Exist-Site "xyz"; exit

#region Site App
Function Delete-SiteApp([string]$appName) {
	Process {
		if ($Input) { $appName = $Input }
		#appcmd delete app /app.name:"dev.dnndev.me"
		"Deleting Application '$appName'..."
		$cmdOutput = appcmd delete app /app.name:"$appName"
		if (0,50 -notcontains $LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE, Site Name '$siteName' does not exist. OUTPUT: '$cmdOutput'" }
	}
}
#UNIT-TEST
#Init; Delete-SiteApp "dev.dnndev.me/DesktopModules/Admin"; exit

Function List-SiteApp($siteName) {
	#appcmd list app /site.name:"dev.dnndev.me"
	$cmdOutput = appcmd list app /site.name:"$siteName"
	if (0,50 -notcontains $LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE, Site Name '$siteName' does not exist. OUTPUT: '$cmdOutput'" }
	$cmdOutput | Select-String "$siteName/([^`"]+)" | % { "{0}/{1}" -f $siteName,$_.Matches.Groups[1].Value }
}
#UNIT-TEST
#Init; $apps = List-SiteApp "dev.dnndev.me"; "[Count: $($apps.Count)]"; $apps; exit

Function GetPhysicalPath-SiteApp($siteName, $appName = "/") {
    Function Get-PipelineInput($appName)
    {
        End { 
            [xml]$appConfigXml = $Input
			$appConfigXml.application.virtualDirectory | ? { $_.path -eq $appName }  | Select -ExpandProperty physicalPath
        }
    }
	#appcmd list app "dev.dnndev.me/" /config
	appcmd list app "$siteName$appName" /config | Get-PipelineInput $appName
	if (0,50 -notcontains $LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE" }
}
#UNIT-TEST
#Init; GetPhysicalPath-SiteApp "dev.dnndev.me"; exit
#endregion Site App

#region VirtualDir
Function List-VirtualDir($siteName) {
	#appcmd list vdir /app.name:"dev.dnndev.me/"
	$cmdOutput = appcmd list vdir /app.name:"$siteName/"
	if (0,50 -notcontains $LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE, Site Name '$siteName' does not exist. OUTPUT: '$cmdOutput'" }
	$cmdOutput | Select-String "$siteName/([^`"]+)" | % { "{0}/{1}" -f $siteName,$_.Matches.Groups[1].Value }
}
#UNIT-TEST
#Init; $vdirs = List-VirtualDir "dev.dnndev.me"; "[Count: $($vdirs.Count)]"; $vdirs; exit

Function GetPhysicalPath-VirtualDir([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string]$vdirPath) {
	#appcmd list vdir /app.name:"dev.dnndev.me/" /path:"/DesktopModules/ZeusClubes"
	#VDIR "dev.dnndev.me/DesktopModules/ZeusClubes" (physicalPath:C:\TFS\Zeus\Clubes\Dev\Web\ClubesWeb)
	$cmdOutput = appcmd list vdir /app.name:"$siteName/" /path:"$vdirPath"
	# if not found, return (do not raise error)
	if (0,50 -notcontains $LASTEXITCODE) { return $null }
	$cmdOutput | Select-String '\(physicalPath:(.+)\)$' | % { $_.Matches.Groups[1].Value }
}
#UNIT-TEST
#Init; GetPhysicalPath-VirtualDir "dev.dnndev.me" "/DesktopModules/ZeusClubes"; exit

Function Delete-VirtualDir([string]$vdirPath) {
	Process {
		if ($Input) { $vdirPath = $Input }
		#appcmd delete vdir /vdir.name:"dev.dnndev.me/DesktopModules"
		$cmdOutput = appcmd delete vdir /vdir.name:"$vdirPath"
		if (0,50 -notcontains $LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE, OUTPUT: '$cmdOutput'" }
	}
}
#UNIT-TEST
#Init; Delete-VirtualDir "dev.dnndev.me/DesktopModules"; exit

Function Exist-VirtualDir([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string]$virtualPath) {
	#appcmd list vdir /vdir.name:"dev.dnndev.me/DesktopModules"
	$cmdOutput = appcmd list vdir /vdir.name:"$siteName$virtualPath"
	if ($LASTEXITCODE -ne 0) { return $false }
	return ($cmdOutput.Contains("VDIR `"$siteName$virtualPath`""))
}
#UNIT-TEST
#Init; Exist-VirtualDir "dev.dnndev.me" "/DesktopModules"; Exist-VirtualDir "dev.dnndev.me" "/DesktopModules2"; exit

Function Create-VirtualDir([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string]$virtualPath, [Parameter(Mandatory=$true)][string]$physicalPath) {
	# make sure virtual path starts with '/'
	if ($virtualPath -notmatch '^/') { $virtualPath = "/$virtualPath" }

	<#
	appcmd list vdir dev.dnndev.me/*
	appcmd add vdir /app.name:dev.dnndev.me/ /path:"/DesktopModules/ZeusConectorHardware" /physicalPath:"C:\TFS\Zeus\Comun\Portales\Dev\ConectoresHardware\ConectoresHardware"
	#>
	$currentPath = GetPhysicalPath-VirtualDir $siteName $virtualPath
	if ($currentPath -eq $physicalPath) { return "OK" }

	if (Exist-VirtualDir $siteName $virtualPath) { Delete-VirtualDir "$siteName/$virtualPath" }
	
	$cmdOutput = appcmd add vdir /app.name:"$siteName/" /path:"$virtualPath" /physicalPath:"$physicalPath"
	if (0 -notcontains $LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE. OUTPUT: '$cmdOutput'" }
	return "Updated"
}
#endregion VirtualDir
#endregion IIS Admin

#init
Init-AppCmd

#UNIT-TESTING
#cls; ...; exit
