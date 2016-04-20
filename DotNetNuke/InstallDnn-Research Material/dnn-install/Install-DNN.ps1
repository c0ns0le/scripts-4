if ($appSettings -eq $null) {.\load-config.ps1 dnn.installer.config}

function Global:Install-DNN( 
	$dnnVersion, 
	$dnnType = $appSettings["dnnType"],
	$shortName = "",
	$sourcebase = $(?: {$productname -eq "professional"} {$appSettings["proPath"]} {$appSettings["communityPath"]}),
	$targetbase = $appSettings["webHome"],
	$webservicename = $appSettings["iisIdentity"],
	$productname = $appSettings["productName"],
	[switch]$createDbUser,
	[switch]$useSqlExpress,
	[switch]$autoInstall,
	[switch]$showTimings)
{
	trap {break}
	
	if ($showTimings){
		[System.Diagnostics.Stopwatch] $sw;
		$sw = New-Object System.Diagnostics.StopWatch
		$sw.Start()
	}

	if ($Pscx:IsAdmin)
	{
		
		# This creates a string in the form DNNXXX  (DotNetNuke 04.08.05 would shorten to DNN485)
		if ($shortname -eq "") {
			$dnnVersion.Split(".") | % { $shortName = "DNN" }{ 
				if ($_.Length -eq 1) 
					{ $shortName = $shortName + $_ } 
				else 
					{$shortName = $shortName + $_.TrimStart("0")} 
			}

		}
		
		# We use a certain naming convention for where we extract DotNetNuke 
		# and how we name the directory - This is only used if we don't override it
		$target =  "$targetbase\$shortName"
		
		Write-Host "Step 1: Unzipping to the target directory..."
			
		# This function is from the ZipLib script
		# WARNING: This will remove the old directory if it exists
		Extract-DNN -dnnVersion  $dnnVersion `
					-dnnType     $dnnType     `
					-sourcebase  $sourcebase  `
					-targetbase  $targetbase  `
					-targetname  $shortname   `
					-productname $productname `
					-clean 
		
		if (([string]$dnnType).ToLower().StartsWith("source"))
		{
			$target = "$target\website"
		}
		
		Write-Host
		Write-Host "Step 2: Creating the necessary file permissions..."
			
		# This function is from the AclLib script
		Set-Permission -file $target -user $appSettings["iisIdentity"] -rights FullControl 
		
		if ($useSqlExpress) {
			Write-Host
			Write-Host "Step 3: Using SqlExpress database, skipping to step 5..."
		}
		else
		{
			Write-Host
			Write-Host "Step 3: Creating the database..."
			
			# These functions are from DBLib script
			
			# This assumes that our current Windows User has necessary db permissions
			$conn = new-dbconnection -integratedsecurity 
			$database = new-database $conn $shortName 
	
			if ($createDbUser) {
				Write-Host
				Write-Host "Step 4: Creating the database user account..."
				
				$login = get-dblogin $conn $webservicename
				if ($login -eq $null) {
					$login = new-dblogin $conn $webservicename -integratedsecurity 
				}
				
				if ($login -eq $null) {
					Write-Host "Unable to create the login for " + $webservicename
				}
				else
				{
					$user = new-dbuser $conn $login $shortName
					$user.AddToRole("db_owner")
				}
			}
		}
		
		Write-Host
		Write-Host "Step 5: Creating the web application..."
		
		# This function is from the IISLib script
		new-webapplication -AppPath "/$shortName" -Directory $target 
		
		Write-Host
		Write-Host "Step 6: Update Web.config..."
		
		$conn = new-dbconnection -database $shortname -integratedsecurity 
		
		# This function is from the DnnLib script
		Write-ConnectionString $target $conn
		
		Write-FormString $target $shortname
		
		Write-Host
		Write-Host "Step 7: Launching the Install Wizard in Internet Explorer..."
		
		# This function is from the IELib script
		Invoke-DNNInstallWizard $shortName -autoInstall:$autoInstall
	}
	else
	{
		Throw "This script requires elevated permissions"
	}
	
	if ($showTimings) {
		$sw.stop()
		$sw.Elapsed.TotalSeconds
	}
}

function Remove-DNN(
	$shortName,
	$fileDir = 'c:\websites',
	$iisDir = $iis,
	$sqlDir = $sql)
{
	Get-Process | ? {$_.ProcessName -eq 'w3wp'} | Stop-Process 
	cd $iisDir
	del $shortName -force -recurse
	cd $sqlDir
	del $shortName -force -recurse
	cd 'c:\websites'
	del $shortName -force -recurse
}