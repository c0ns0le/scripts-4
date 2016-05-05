<#
.SYNOPSIS
	Asigna un nuevo password para un usuario en DotNetNuke o cualquier sistema que use las tablas de ASP.NET Membership
.EXAMPLE
.\SetPassword-AspNetMembership.ps1 "host" "abc123$" "Server=.\SQLExpress;Database=acuacar-dnndev;Integrated Security=True"
#>
Param(
	[Parameter(Mandatory=$true)]
	[string]$UserName,
	[Parameter(Mandatory=$true)]
	[string]$NewPassword,
	[Parameter(Mandatory=$true)]
	[string]$CnnString
)
Trap {
	Write-Host $_ -ForegroundColor Red
	Exit 1
} 

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#region SqlMembershipProvider Reflection
Function Load-SystemWeb {
	[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
}

Function SqlMembershipProvider_EncodePassword {
Param(
	[Parameter(Mandatory=$true)]
	[string]$password, 
	[Parameter(Mandatory=$true)]
	[int]$passwordFormat, 
	[Parameter(Mandatory=$true)]
	[string]$salt
)
	#Call constructor
	$Instance = New-Object "System.Web.Security.SqlMembershipProvider"
 
	# Find private nonstatic method. If you want to invoke static private method, replace Instance with Static
	$BindingFlags = [Reflection.BindingFlags] "NonPublic,Instance"
 
	$m = $Instance.GetType().GetMethod("EncodePassword", $BindingFlags);
 	$encryptedPassword = [string]$m.Invoke($Instance, @($password, $passwordFormat, $salt));

	if ($encryptedPassword.Length -gt 128) { throw "Invalid Password"; }
	return $encryptedPassword;
}

Function SqlMembershipProvider_GenerateSalt {
	#Call constructor
	$Instance = New-Object "System.Web.Security.SqlMembershipProvider"
 
	# Find private nonstatic method. If you want to invoke static private method, replace Instance with Static
	$BindingFlags = [Reflection.BindingFlags] "NonPublic,Instance"
 
	$m = $Instance.GetType().GetMethod("GenerateSalt", $BindingFlags);
 	return [string]$m.Invoke($Instance, $null);
}
#endregion

#region Run Sql Scripts
Function Run-SqlScript {
Param(
	[Parameter(Mandatory=$true)]
	[string]$ConnectionString,
	[Parameter(Mandatory=$true)]
	[string]$SqlScript,
	[switch]$ReturnScalar,
	[switch]$ReturnDataTable,
	[switch]$ReturnDataRow  # return first row only
)
	$cnn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
	try {
		$cnn.Open();
		$cmd = $cnn.CreateCommand();
		$cmd.CommandText = $SqlScript
		
		if ($ReturnScalar) { 
			return $cmd.ExecuteScalar(); 
		}
		elseif ($ReturnDataTable -or $ReturnDataRow) { 
			$dt = New-Object System.Data.DataTable
			$dt.Load($cmd.ExecuteReader())
			
			if ($ReturnDataTable) { return $dt; }
			elseif ($ReturnDataRow) {
				if ($dt.Rows.Count -gt 0) { return $dt.Rows[0]; }
			}
		}
		else {
			$cmd.ExecuteNonQuery();
		}
	}
	finally {
		if ($cnn) { $cnn.Close(); }
	}
}

Function SqlGet-AspNetPassword {
Param(
	[Parameter(Mandatory=$true)]
	[string]$CnnString,
	[Parameter(Mandatory=$true)]
	[string]$UserName
)
	$SqlGetPassword = `
"SELECT m.UserID, u.UserName, m.Password, m.PasswordSalt, m.PasswordFormat
	FROM aspnet_Users u
    	INNER JOIN aspnet_Membership m
        	ON (u.UserID = m.UserID)
	WHERE u.UserName = '{0}'";

	$sql = $SqlGetPassword -f $UserName
	Run-SqlScript $CnnString $sql -ReturnDataRow
}

Function SqlUpdate-AspNetPassword {
Param(
	[Parameter(Mandatory=$true)]
	[string]$CnnString,
	[Parameter(Mandatory=$true)]
	[string]$UserName,
	[Parameter(Mandatory=$true)]
	[string]$Password,
	[Parameter(Mandatory=$true)]
	[string]$PasswordFormat,
	[Parameter(Mandatory=$true)]
	[string]$PasswordSalt
)
	$SqlSetPassword = `
"UPDATE aspnet_Membership
	SET Password = '{1}',
		PasswordFormat = {2},
		PasswordSalt = '{3}'
	WHERE UserID = (Select UserID FROM aspnet_Users WHERE UserName = '{0}')";

	$sql = $SqlSetPassword -f $UserName, $Password, $PasswordFormat, $PasswordSalt
	Run-SqlScript $CnnString $sql
}
#endregion

Function Update-AspNetPassword {
Param(
	[Parameter(Mandatory=$true)]
	[string]$UserName,
	[Parameter(Mandatory=$true)]
	[string]$NewPassword,
	[Parameter(Mandatory=$true)]
	[string]$CnnString
)
	$row = SqlGet-AspNetPassword $CnnString $UserName
	if (!$row) { 
		throw "Cannot find user name '$UserName'";
	}

	if ($row.PasswordFormat -ne [System.Web.Security.MembershipPasswordFormat]::Hashed) {
		$row.PasswordFormat = [int] ([System.Web.Security.MembershipPasswordFormat]::Hashed)
		$row.PasswordSalt = SqlMembershipProvider_GenerateSalt;
	}

	$row.Password = SqlMembershipProvider_EncodePassword $NewPassword $row.PasswordFormat $row.PasswordSalt

	$rowsAffected = SqlUpdate-AspNetPassword $CnnString $UserName $row.Password $row.PasswordFormat $row.PasswordSalt

	if (-not $rowsAffected) {
		throw "Password was not updated. Membership row for '$UserName' was not found";
	}

	Write-Verbose ("NEW Password: '{0}'" -f $NewPassword)
	Write-Verbose ("NEW Password (Encrypted): '{0}'" -f $row.Password)
	Write-Verbose ("NEW Password Salt: '{0}'" -f $passwordSalt)
}


#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
Load-SystemWeb

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Update-AspNetPassword $UserName $NewPassword $CnnString

<#
TODO: Cual app.config leeria en este caso (llamado de Powershell)?
$Salt = "algo"
SqlMembershipProvider_EncodePassword $NewPassword [int]([System.Web.Security.MembershipPasswordFormat]::Encrypted) $Salt
#>

Write-Host "OK" -ForegroundColor Blue

