function Write-ConnectionString ($target, $conn)
{
	Write-Config $target '(?<=name="SiteSqlServer"\sconnectionString=")[a-zA-Z0-9\.=\s\\\(\);|-["]]*' $conn.ConnectionString
}

function Write-FormString ($target, $formname)
{
	Write-Config $target '(?<=<forms name=")\.DOTNETNUKE(?=")' $formname
}

function Write-Config ($target, $pattern, $value)
{
	$content = Get-Content "$target\web.config"	
	$content -replace $pattern, $value	| out-file "$target\web.config"	
}
