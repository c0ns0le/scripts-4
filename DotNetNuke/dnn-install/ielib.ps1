function Start-Web ($url)
{
	$ie = New-Object -ComObject internetexplorer.application
	$ie.Navigate($url)
	$ie.visible = $TRUE
}

function Invoke-DNNInstallWizard ([string]$VDir, [switch]$autoInstall)
{
	if ($autoInstall) {
		$Wizard = "/Install/install.aspx?mode=install"
	} else {
		$Wizard = "/Install/InstallWizard.aspx"
	}
	$URL = $VDir.Trim('/') + $Wizard
	
	if ($Url.StartsWith("http"))
	{
		"Launching: $Url"
		Start-Web  $Url
	}
	else
	{
		"Launching: http://localhost/$Url"
		Start-Web ("http://localhost/" + $Url)
	}
}