function global:Set-Permission (
	$file,
	$user="ASPNET", 
	[System.Security.AccessControl.FileSystemRights]$Rights, 
	[System.Security.AccessControl.AccessControlType]$access = "Allow") { 
 
	if ($Pscx:IsAdmin)
	{
		trap{"Error setting permissions"; break} 
		
		# This will allow permissions to be inherited
		$Inherit=[System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
		$Prop=[System.Security.AccessControl.PropagationFlags]::InheritOnly
		
		$ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user,$Rights,$Inherit, $Prop, $access) 
		
		# check if given user is Valid, this will break function if not so. 
		
		$Sid = $ar.IdentityReference.Translate([System.Security.Principal.securityidentifier])  
		
		$acl = get-acl $file 
		
		$acl.SetAccessRule($ar)
		
		set-acl -Path $file -AclObject $acl 
	}
	else
	{
		Throw "This script requires elevated permissions"
	}

}

