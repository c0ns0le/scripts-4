if ($appSettings -eq $null) {.\load-config.ps1 dnn.installer.config}

[void][reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo")
[void][reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")
[void][reflection.assembly]::LoadWithPartialName("microsoft.sqlserver.sqlenum")

. $scripthome\sqlserver\addSqlProvider.ps1

function global:get-sqlcred(
	$username="", 
	$password="", 
	[switch]$forcesecure) {

	# We are createing an object to which we'll add custom properties
	$user = New-Object object | select-object UserName, Password
	
	if ($username.length -eq 0) {
		# No username was specified, so we should use Get-Credential to prompt for a user
		# We also define a default username in order to suppress console output
		# The results are added as synthetic properties to the PSObject we created above
		$cred = Get-Credential "SqlUser"
		$user.UserName = $cred.GetNetworkCredential().Username
		if ($forcesecure) 
		{
			$user.Password = $Cred.Password
		}
		else
		{
			$user.Password = $cred.GetNetworkCredential().Password
		}
	} else {
		$newpassword = $password
		
		# If we are using secure passwords, then we need to convert our string to a securestring
		if ($forcesecure) 
		{
			$newpassword = New-Object System.Security.SecureString
			[char[]]$password | for-each {$newpassword.AppendChar($_)}
		}
		
		# In this case we can just create synthetic properties using the values passed to the function
		$user.UserName = $username
		$user.Password = $newpassword
	}

	# Return our synthetic object
	$user
}

function global:new-dbconnection (
	$serverName = ".", 
	$username = "", 
	$password="",
	$database,
	[switch]$integratedsecurity) {
	
	$sqlinfo = New-Object Microsoft.SqlServer.Management.Common.SqlConnectionInfo
	$sqlinfo.ServerName = $servername
	$sqlinfo.DatabaseName = $database
	$sqlinfo.UseIntegratedSecurity = $integratedsecurity
	
	if (!$integratedsecurity ) 
	{
		$cred = get-sqlcred $username $password 
		$sqlinfo.UserName = $cred.username
		$sqlinfo.Password = $cred.password
	}
		
	$conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection ($sqlinfo)
	
	$conn 
}

if ((Get-Alias ndbc -erroraction silentlycontinue) -eq $null) {
	New-Alias ndbc new-dbconnection -ErrorAction "SilentlyContinue" -scope "global" -Force 
}

function global:get-database ($conn, 
	$dbname) {

	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $conn
	$server.Databases | where {
		($dbname -eq $NULL) -or ($_.name -eq $dbname)
	}
}
if ((Get-Alias gdb -erroraction silentlycontinue) -eq $null) {
	New-Alias gdb get-database -ErrorAction "SilentlyContinue" -scope "global"
}

function global:new-database ($conn, 
	$dbname, 
	$overwritedb = $TRUE) {
	
	$server = new-object Microsoft.SqlServer.Management.Smo.Server $conn
    $db = $server.Databases[$dbname]

    if ($db -ne $Null)
    {
        Write-Verbose ("We need to drop the database " + $db.Name)
        
        $server.KillDatabase($dbname)
        
        if ($? -eq $FALSE)
        {
            Throw "We were not able to drop the database."
            
        }
    } 
	else
    {
        Write-Verbose ("The database " + $dbname + " doesn't exist.")
    }
	
	$db = new-object "Microsoft.SqlServer.Management.Smo.Database" ($server, $dbname)
	$db.Create()
	
	$db = $server.Databases[$dbname]
    
#     if ($db -ne $Null)
#     {
#         Write-Verbose ("The database, " + $db.Name + ", was successfully created")
#     } 
# 	else
#     {
#         Throw "There was an error creating the database " + $dbname
#     }
	
	return $db

}

if ((Get-Alias ndb -erroraction silentlycontinue) -eq $null) {
	New-Alias global:ndb new-database -ErrorAction "SilentlyContinue" -scope "global" -Force 
}

function new-DnnDatabase(
	$conn = {new-dbconnection -integratedsecurity},
	$dbname,
	$webservicename=$appSettings["iisIdentity"])
{
	$database = new-database $conn $dbname
	$login = get-dblogin $conn $webservicename
	$user = new-dbuser $conn $login $dbname
	$user.AddToRole("db_owner")
}

function get-dblogin ($conn, 
	$username) {

	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $conn
	$server.Logins | where { 
		($username -eq $NULL) -or ($_.name -eq $username) 
	}
}

if ((Get-Alias gdbl -erroraction silentlycontinue) -eq $null) {
New-Alias gdbl get-dblogin -ErrorAction "SilentlyContinue" -scope "global"
}

function global:new-dblogin($conn, 
	$username="", 
	$password="", 
	$defaultdb="Master",
	[switch]$integratedsecurity) {

	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $conn
	
	$login = New-Object Microsoft.SqlServer.Management.Smo.Login ($server, $username)
	$login.DefaultDatabase = $defaultdb
	if ($integratedsecurity) {
		$login.LoginType = "WindowsUser"
		$login.Create() 
	}
	else {
		$login.LoginType = "SqlLogin"
		$login.Create("dnnINC445*")
	}
	$login
}

if ((Get-Alias ndbl -erroraction silentlycontinue) -eq $null) {
	New-Alias ndbl new-dblogin -ErrorAction "SilentlyContinue" -scope "global"
}

function global:get-dbuser ($conn, 
	$dbname,
	$username) {

	$database = get-database $conn  $dbname
	
	#add error handling here
	
	$database.users | where {
		($username -eq $NULL) -or ($_.name -eq $username) 
	}
}

if ((Get-Alias gdbu -erroraction silentlycontinue) -eq $null) {
	New-Alias gdbu get-dbuser -ErrorAction "SilentlyContinue" -scope "global"
}

function global:new-dbuser ($conn, 
	$login, 
	$dbname) {

	$database = get-database $conn  $dbname
	
	#add error handling here
	
	$user = New-Object Microsoft.SqlServer.Management.Smo.User ($database, $login.Name)
	$user.Login = $login.Name
	$user.Create()
	$user
}

if ((Get-Alias ndbu -erroraction silentlycontinue) -eq $null) {
	New-Alias ndbu new-dbuser -ErrorAction "SilentlyContinue" -scope "global"
}

# This function uses SubSonic to generate the Data Access Layer.
function global:new-dal(
	$server = "localhost",
	$db,
	$username = "",
	$password = "",
	$namespace = "Test" ,
	$lang = "vb",
	$BuildPath = "D:\Batch\DAL",
	$SonicPath = "D:\Program Files\SubSonic\SubSonic 2.0.3\SubCommander\",
	$configfile = "",
	[switch]$excludetables,
	[switch]$excludeods,
	[switch]$excludeviews,
	[String]$passthruargs) { 

	$sonic = "sonic.exe"
	
	if ($configfile.length -gt 0)
	{
		if (Test-Path $configfile)
		{
			$generateconfig = "generate /config '$configfile'"

			# Due to some difficulties with Invoke-Expression we'll change directories
			# to excecute the command and then reset the directory when we are through.
			$savepath = $pwd
			Set-Location $SonicPath

			if ($excludetables -eq $FALSE) {Invoke-Expression(".\$sonic $generateconfig")}

			Set-Location $savepath
		}
		else 
		{
			"Please provide a valid configuration file name when using the configfile parameter."
			exit
		}
	}
	else
	{
		# Use a database helper function that allows us to get a password in a secure manner.
		# If the username is not an empty string then the function just returns the original username/password
		$cred = get-sqlcred $username $password
	
		# Create some standard argument strings for SubCommander
		$generatetables= "generatetables /override /out '$BuildPath' /lang $Lang"
		$generateods= "generateODS /override /out '$BuildPath' /lang $Lang"
		$generateviews = "generateviews /override /out '$BuildPath' /lang $Lang /viewStartsWith vw"
	
		
		"Removing and recreating the target directory: $BuildPath ..."
		del $BuildPath -recurse -force
		new-item $BuildPath -itemtype Directory -force | Out-Null 
	
		$username = $cred.username
		$password = $cred.password 
	
		# Building our provider string.  Everything is parameterized.
		$Provider = "/server $server /db $db /userid $userName /password $password /generatedNamespace $namespace"
	
	
		"Generate using connection string: "
		"`tserver             = $server"
		"`tdb                 = $db"
		"`tuserid             = $userName"
		"`tpassword           = $password"
		"`tgeneratedNamespace = $namespace"
		"`n"
		
		# Due to some difficulties with Invoke-Expression we'll change directories
		# to excecute the command and then reset the directory when we are through.
		$savepath = $pwd
		Set-Location $SonicPath
	
		if ($excludetables -eq $FALSE) {Invoke-Expression(".\$sonic $generatetables $provider $passthruargs")}
		if ($excludeods -eq $FALSE) {Invoke-Expression( ".\$sonic $generateods $provider $passthruargs" )}
		if ($excludeviews -eq $FALSE) {Invoke-Expression( ".\$sonic $generateviews $provider $passthruargs" )}
		
		Set-Location $savepath
	}
}
