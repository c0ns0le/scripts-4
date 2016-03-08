Import-Module WebAdministration -ErrorAction SilentlyContinue 

if ((Get-Alias nwa -erroraction silentlycontinue) -eq $null) {
  New-Alias nwa new-webapplication -ErrorAction "SilentlyContinue" -scope "global"
}

function new-webapplication (
	$AppPath, 
	$Directory, 
	$AppPool = "DotNetNuke",
	$SiteName = "Default Web Site",
    $Computer = ".",
	[switch]$passthru,
	[switch]$verbose,
	[switch]$debug,
	[switch]$force ){
	
	trap [Exception] 
	{
		write-error $("TRAPPED: " + $_.Exception.Message);
		continue;
	}
	
	if ($Pscx:IsAdmin)
	{

		$path = "iis:\sites\" + $SiteName + "\" + $AppPath
		Write-Debug "Path is $path"
			
		$appinstance = New-Item $path -physicalPath $Directory -type Application -Force:$force
		Set-ItemProperty $path -name applicationPool -value $appPool
		
		if ($passthru) { $appinstance }
	}
	else
	{
		Throw "This script requires elevated permissions"
	}

}
