if ($appSettings -eq $null) {.\load-config.ps1 dnn.installer.config}

[void] [System.Reflection.Assembly]::LoadFrom("$dnnhome\Libraries\ICSharpCode.SharpZipLib.dll")

function Get-Zip ([string]$zipfilename)
{
	if(test-path($zipfilename))
	{
		$unzip = New-Object ICSharpCode.SharpZipLib.Zip.ZipFile($zipFileName)
		foreach ($zipEntry in $unzip)
		{
			$zipEntry.name
		}
		$unzip.close()
	}
}

function Extract-Zip (
    [string] $zipfilename, 
    [string] $destination) {

	if(test-path($zipfilename))
	{	
		if ( (Test-Path $destination) -eq $FALSE ) {
			Write-Verbose "Creating Target Directory $destination..."
			new-item $destination -ItemType Directory
		}
		
    	Write-Verbose "Unzipping $zipfilename ..."
		$fastzip = new-object ICSharpCode.SharpZipLib.Zip.FastZip
		$fastzip.ExtractZip($zipfilename, $destination, $null)
		
		Write-Verbose "Completed unzipping file..."
	}
	else 
	{
		Throw "'" + $zipfilename + "'  does not exist"
	}

}

function Extract-DNN (
	$dnnVersion,
	$dnnType=$appSettings["dnnType"],
	$sourcebase=$(?: {$productname -eq "professional"} {$appSettings["proPath"]} {$appSettings["communityPath"]}),
	$targetbase=$appSettings["webHome"],
	$targetname="",
	$productname=$appSettings["productName"],
	[switch]$clean,
	[switch]$nodialog) {
	
	$dnnVersion.Split(".") | % { $Ver = "" }{ if ($_.Length -eq 1) { $ver = $ver + "0" + $_ + "." } else {$ver = $ver + $_ + "."} }{$ver = $ver.TrimEnd(".") }
	
	if ($productname -ne ""){
		$productname = "_" + $productname
	}

	$sourcezip = [string]::format( "{0}\{1}\DotNetNuke{2}_{3}_{4}.zip", ($sourcebase, $dnnVersion, $productname, $ver, $dnnType) )
	if ($targetname -eq "") {
		$target =  "$targetbase\DotNetNuke_$dnnversion"
	} else {
		$target =  "$targetbase\$targetname"
	}

	if ($clean) {
		if ( (Test-Path $target) -eq $TRUE) {
			Write-Verbose "Removing and recreating the target directory: $target ..."
			del $target -recurse -force
		}
		
		$dir = new-item $target -itemtype Directory -force
	}
	
	Extract-Zip $sourcezip $target
}