#requires -version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Configure IIS Sites
#>
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 

$ErrorActionPreference = "Stop"	# Set Error Action to Stop
$Script:ScriptVersion = "4.0"   # Script Version

#----------------------------------------------------------[Declarations]----------------------------------------------------------
 


#-----------------------------------------------------------[Functions]------------------------------------------------------------
#region Functions

#region Generic Helpers
Function Set-AliasAppCmd {
	Set-Alias appcmd -Value "$env:SystemRoot\system32\inetsrv\appcmd.exe" -Scope "Script"
}

Function Write-Header($Text) {
	Write-Host "[$Text]" -ForegroundColor DarkGreen
}

Function Set-FullAccess($physicalPath, $userName) {
	#xcacls $physicalPath /E /G "IIS AppPool\$poolName":F /Q
	$ArgumentList = "`"$physicalPath`"", "/grant", "`"$userName`":(OI)(CI)(F)", "/T", "/Q", "/C"
	Write-Header "icacls.exe $ArgumentList"
	icacls.exe $ArgumentList
	""
}
#endregion

#region IIS Functions
Function CreatePool($poolName, $user, $pwd) {
	Write-Header "Create App Pool $poolName"
	appcmd add apppool /name:"$poolName" /managedRuntimeVersion:v4.0 /enable32BitAppOnWin64:true /processModel.identityType:SpecificUser /processModel.userName:"$user" /processModel.password:"$pwd"
	
	# small delay so that it creates built-in user
	Start-Sleep -Milliseconds 3000
	# set permissions
	Set-FullAccess "$env:SystemRoot\Temp" "IIS AppPool\$poolName"
	Set-FullAccess "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files" "IIS AppPool\$poolName"
	Set-FullAccess "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files" "IIS AppPool\$poolName"
}

Function Delete-SiteIIS($siteName) {
	appcmd delete site $siteName
	if ($LASTEXITCODE) { throw "LASTEXITCODE: $LASTEXITCODE" }
}

Function Create-SiteIIS($siteName, $physicalPath, $poolName, $siteAlias, $sitePort = 80) {
	if ($poolName -eq $null) { $poolName = $siteName }
	if ($siteAlias -eq $null) { $siteAlias = $siteName }
	
	Write-Header "Create Site $siteName"
	appcmd add site /name:"$siteName" ("/bindings:http/*:{0}:{1}" -f $sitePort,$siteAlias) /physicalPath:"$physicalPath" /applicationDefaults.applicationPool:"$poolName"
	
	Write-Header "Enabling Anonymous Authentication, Disable Windows Authentication..."
	appcmd set config "$siteName" /section:anonymousAuthentication /enabled:true /commit:apphost
	appcmd set config "$siteName" /section:windowsAuthentication /enabled:false /commit:apphost

	Set-FullAccess $physicalPath "IIS AppPool\$poolName"
	
	Write-Header "maxUrlSegments:120"
	appcmd set site $siteName /limits.maxUrlSegments:120
}

Function Create-SiteIISApp($siteName, $virtualPath, $physicalPath) {
	appcmd add app /site.name:"$siteName" /path:"$virtualPath" /physicalPath:"$physicalPath"
}

Function Create-VirtualDir($siteName, $virtualPath, $physicalPath) {
	<#
	appcmd list vdir zeusdnn_1_Main/*
	appcmd add vdir /app.name:zeusdnn_1_Main/ /path:"/DesktopModules/ZeusConectorHardware" /physicalPath:"C:\TFS\Zeus\Comun\Portales\Dev\ConectoresHardware\ConectoresHardware"
	appcmd delete vdir /vdir.name:"zeusdnn_1_Main/DesktopModules/ZeusConectorHardware"
	#>
	"Adding virtual directory $virtualPath..."
	$cmdOutput = appcmd delete vdir /vdir.name:"$siteName$virtualPath"
	if (0,50 -notcontains $LASTEXITCODE) { throw $cmdOutput }

	$cmdOutput = appcmd add vdir /app.name:"$siteName/" /path:"$virtualPath" /physicalPath:"$physicalPath"
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
}
#endregion

#region IIS Global Changes
Function ConfigIIS {
	appcmd set config /section:staticContent /+"[fileExtension='.svg',mimeType='image/svg+xml']"

	("$env:SystemRoot\Temp", 
	"$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
	"$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files") | 
	% {
		Set-FullAccess $_ "IIS_IUSRS"
	}

	Write-Header "Reiniciando IIS.."
	iisreset
	Exit
}

Function Clubes-DeleteSites {
	appcmd delete site /site.name:"clubes-ligeras"
	appcmd delete site /site.name:"clubes-ligerascomun"
	appcmd delete apppool /apppool.name:"clubes-ligeras"

	appcmd delete site /site.name:"clubes-test"
	appcmd delete site /site.name:"clubes-testcomun"
	appcmd delete apppool /apppool.name:"clubes-test"
	Exit
}

Function Clubes-DeleteShareFolders {
	"test","testcomun","ligeras","ligerascomun" |
	% {
		try {
			$ArgumentList = ("share", "clubes-$_", "\\$env:ComputerName", "/DELETE")
			Write-Header "net $ArgumentList"
			net $ArgumentList
		} catch { $_.Exception.Message }
	}
}
#endregion

#region SQL Server Helpers
Function Create-DnnDatabase {
Param(
	[Parameter(Mandatory=$true)][string]$dbServer, 
	[Parameter(Mandatory=$true)][string]$dbName, 
	[string]$dnnOwner = "dbo",
	[string]$dbUser = $null, 
	[string]$dbPassword = $null,
	[string]$dataPath= "C:\SqlData\MSSQL10_50.SQLEXPRESS\MSSQL\DATA"
)
	$scriptFile = "$PSScriptRoot\dnn_create_database.sql"
	
	$ArgumentList = ("-S", $dbServer)
	if ($user) { $ArgumentList += "-U", $dbUser, "-P", $dbPassword }
	else { $ArgumentList += "-E" }
	$ArgumentList += "-v", "dbName", "=`"$dbName`"", "dataPath", "=`"$dataPath`"", "owner", "=`"$dnnOwner`"", "-i", $scriptFile
	
	Write-Header "Running $scriptFile"
	sqlcmd $ArgumentList
}

Function CleanupPostInstall-DnnDatabase {
Param(
	[Parameter(Mandatory=$true)][string]$dbServer, 
	[Parameter(Mandatory=$true)][string]$dbName, 
	[string]$dnnOwner = "dbo",
	[string]$dbUser = $null, 
	[string]$dbPassword = $null
)
	$scriptFile = "$PSScriptRoot\dnn_cleanup_postinstall.sql"
	
	$ArgumentList = ("-S", $dbServer)
	if ($user) { $ArgumentList += "-U", $dbUser, "-P", $dbPassword }
	else { $ArgumentList += "-E" }
	$ArgumentList += "-v", "dbName", "=`"$dbName`"", "dataPath", "=`"$dataPath`"", "owner", "=`"$dnnOwner`"", "-i", $scriptFile
	
	Write-Header "Running $scriptFile"
	sqlcmd $ArgumentList
}

Function CleanupPostInstall-DnnWebConfig($physicalPath) {
	Write-Header "Updating ConnectionString to use Integrated Security"
	
	$configFile = Join-Path $physicalPath "web.config"

	$stringToReplace = 'User ID=dnn;Password=abc123$'
	$replaceWith = 'Integrated Security=True'
	
	$lines = Get-Content $configFile -Encoding Default | % { 
		if ($_ -match '<add (key|name)="SiteSqlServer"') {
			$_.Replace($stringToReplace, $replaceWith) 
		}
		else { $_ }
	}
	Set-Content $configFile $lines -Encoding Default
}
#endregion

#endregion

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
Set-AliasAppCmd

# uncomment and run once per server
#ConfigIIS

# uncomment to clean all sites and start over
#Delete-Sites

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#region Clubes
Function Clubes-Create-SiteIISs {
	$user, $pwd = "ZEUSTECNOLOGIA\ZeusFrontWeb", 'abc123$'
	CreatePool "clubes-ligeras" $user $pwd
	Create-SiteIIS "clubes-ligeras" "E:\inetpub\clubes-ligeras"
	Create-SiteIIS "clubes-ligerascomun" "E:\inetpub\clubes-ligerascomun" "clubes-ligeras"
	Create-SiteIISApp "clubes-ligerascomun" "/ZeusImagenesSitio" "E:\inetpub\clubes-ligerascomun\ZeusImagenesSitio"
	Create-SiteIISApp "clubes-ligerascomun" "/ZeusImagenesWSInstalador" "E:\inetpub\clubes-ligerascomun\ZeusImagenesWSInstalador"

	CreatePool "clubes-test" $user $pwd
	Create-SiteIIS "clubes-test" "E:\inetpub\clubes-test"
	Create-SiteIIS "clubes-testcomun" "E:\inetpub\clubes-testcomun" "clubes-test"
	Create-SiteIISApp "clubes-testcomun" "/ZeusImagenesSitio" "E:\inetpub\clubes-testcomun\ZeusImagenesSitio"
	Create-SiteIISApp "clubes-testcomun" "/ZeusImagenesWSInstalador" "E:\inetpub\clubes-testcomun\ZeusImagenesWSInstalador"
}

Function Clubes-CreateShareFolders {
	$sharedUser = "ZEUSTECNOLOGIA\YMora"
	"test","testcomun","ligeras","ligerascomun" |
	% {
		try {
			$shareName = "clubes-$_"
			$physicalPath = "E:\inetpub\$shareName"
		
			#$ArgumentList = ("share", "$shareName=$physicalPath", "/GRANT:$sharedUser,FULL")
			$ArgumentList = ("share", "$shareName=$physicalPath")
			Write-Header "net $ArgumentList"
			net $ArgumentList

			Set-FullAccess $physicalPath $sharedUser
		} catch { $_.Exception.Message }
	}
}

#Clear-Host
#Clubes-Create-SiteIISs

#Clubes-CreateShareFolders
#Clubes-DeleteShareFolders

#endregion


#-----------------------------------------------------------[Bug]------------------------------------------------------------
cls
[string]$dnnRootPath = "C:\inetpub\acuacar.dnndev.me"
[string]$dnnRootUrl = "acuacar.dnndev.me"

#Delete-SiteIIS $dnnRootUrl
#Start-Sleep -Seconds 1

if (Test-Path $dnnRootPath -PathType Container) {
	"Remove-Item $dnnRootPath"
	Remove-Item $dnnRootPath -Recurse -Force
}

Set-Alias 7z "C:\Program Files\7-Zip\7z.exe" -Scope Script
7z x "C:\Compartido\Acuacar\WebSite\acuacar.dnndev.me.7z" -o"C:\inetpub" -r
Create-SiteIIS "acuacar.dnndev.me" "C:\inetpub\acuacar.dnndev.me" "dnndev" "acuacar.dnndev.me"
exit

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Create-SiteIIS "ddd-trunk.dnndev.me" "C:\inetpub\DotNetNukeTripleD" "dnndev" "ddd-trunk.dnndev.me"
exit
Create-SiteIIS "gateway.dnndev.me" "C:\inetpub\gateway.me" "dnndev" "gateway.dnndev.me"
exit
Create-SiteIIS "appolozfpc" "C:\inetpub\appolozfpc" "dnndev" "appolozfpc.dnndev.me"
exit
Create-SiteIIS "dnn800" "C:\inetpub\dnn800" "dnndev" "800.dnndev.me"
exit
Create-SiteIIS "testdnn" "C:\inetpub\testdnn" "dnndev" "test.dnndev.me"
exit
Create-SiteIIS "dnn742" "C:\inetpub\dnn742" "dnndev" "742.dnndev.me"
exit
Create-SiteIIS "zeusdnn_1_Main" "C:\TFS\Zeus\1_Main\Web\zeusdnn" "dnndev" "zeusdnn_1_Main"
exit


#Create-SiteIIS "dnn742" "C:\inetpub\dnn742" "dnndev" "742.dnndev.me"
Create-DnnDatabase ".\SQLEXPRESS" "dnn742" "dnn"
#CleanupPostInstall-DnnDatabase ".\SQLEXPRESS" "dnn742" "dnn"
#CleanupPostInstall-DnnWebConfig "C:\inetpub\dnn742"
exit

$user = "FACTURECOLOMBIA\PEscobar"
if (!$passwd) { throw "Defina su contraseña" }
CreatePool "dnndev" $user $passwd
Create-SiteIIS "dnn734" "C:\inetpub\dnn734" "dnndev" "734.dnndev.me"
exit

Create-SiteIIS "dnn721" "C:\inetpub\dnn721" "dnndev" "dnndev.me"
