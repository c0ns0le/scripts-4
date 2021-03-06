<#
.SYNOPSIS
  Funciones Comunes
#>
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
Set-StrictMode -Version latest  # Error Reporting: ALL

#-----------------------------------------------------------[Functions]------------------------------------------------------------
##region Functions

#region PowerShell 2.0
Function FixBug_PowerShellv2 {
<#
.SYNOPSIS
  Corrige problemas de Powershell 2.0
.NOTES
	Powershell 2.0 BUG
	ERROR: The OS handle’s position is not what FileStream expected. 
		Do not use a handle simultaneously in one FileStream and in Win32 code or another FileStream. 
		This may cause data loss.
	NOTE: This bug was fixed in December 2012 along with the release of Windows Management Framework 3.0
	http://goo.gl/Zbcsj0
	This is bug in PowerShell V1 and V2, and happens when:
		a PowerShell command generates both regular and error output
		you have used cmd.exe to redirect the output to a file
		you have used cmd.exe to merge the output and error streams
#>
	if ($PSVersionTable.PSVersion.Major -eq 2) {
		$bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
		$objectRef = $host.GetType().GetField("externalHostRef", $bindingFlags).GetValue($host)
		
		$bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetProperty"
		$consoleHost = $objectRef.GetType().GetProperty("Value", $bindingFlags).GetValue($objectRef, @())
		$stdOutMethod = $consoleHost.GetType().GetProperty("IsStandardOutputRedirected", $bindingFlags)
		if ($stdOutMethod) { [void] $stdOutMethod.GetValue($consoleHost, @()) }
		
		$bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
		$field = $consoleHost.GetType().GetField("standardOutputWriter", $bindingFlags)
		if ($field) { $field.SetValue($consoleHost, [Console]::Out) }
		$field2 = $consoleHost.GetType().GetField("standardErrorWriter", $bindingFlags)
		if ($field2) { $field2.SetValue($consoleHost, [Console]::Out) }
	}
}

Function FillGaps_Powershellv2 {
	# powershell 2.0
	if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent }
}
#endregion PowerShell 2.0


#region Logging
$Script:LogIndentedLevel = 0
Function Get-Indented($Text) { "{0}{1}" -f (" " * ($Script:LogIndentedLevel*2)), $Text }
Function Add-Indented($Text, [Switch]$Decrease = $false) { 
	if ($Decrease) { $Script:LogIndentedLevel-- }
	Get-Indented $Text
	if (-not $Decrease)  { $Script:LogIndentedLevel++ }
}
Function Write-Custom {
Param(
[Parameter(Mandatory=$true)][string]$Text,
[ConsoleColor]$ForegroundColor
)
	Write-Host
}
Function Write-Indented($Text) { Write-Host (Get-Indented $Text) }
Function Write-Header($Text) { Write-Host (Add-Indented $Text) -ForegroundColor DarkGreen }
Function Write-Footer($Text, [Switch]$AddExtraTrailingNewLine = $false) { Write-Host (Add-Indented $Text -Decrease) -ForegroundColor DarkGreen; if ($AddExtraTrailingNewLine) { Write-Host "" } }
#Function Write-Indented($Text) { Write-Host (Get-Indented $Text) }
#Function Write-Header($Text) { Write-Host (Add-Indented $Text) -ForegroundColor DarkGreen }
#Function Write-Footer($Text, [Switch]$AddExtraTrailingNewLine = $false) { Write-Host (Add-Indented $Text -Decrease) -ForegroundColor DarkGreen; if ($AddExtraTrailingNewLine) { Write-Host "" } }
#endregion


#region Timing
Function Start-Stopwatch() {
	$Script:_Timer = New-Object Diagnostics.Stopwatch
	$Script:_Timer.Start()
}

Function Stop-Stopwatch() {
	$Script:_Timer.Stop()
	Write-Header ("Elapsed: " + $Script:_Timer.Elapsed.TotalSeconds + " sec")
	Write-Footer "Done!"
}
#endregion


#region General
Function Register-Alias($aliasName, $paths) {
	$found = $false
	foreach ($path in $paths) {
		if (Test-Path $path) {
			Set-Alias -Name $aliasName -Value $path -Scope "Script"
			$found = $true
			# TODO: if chosen "Team Explorer Everywhere 2015", you must accept EULA (only once)
			# if ($path -match "TEE-CLC") { tf eula /accept }
			break
		}
	}

	if (-not $found) { throw "Cannot find any valid path to register alias '$aliasName'" }
}

$Script:OSVersion = $null
Function Get-OSVersion {
<#
.SYNOPSIS
  Obtiene el tipo y versión del sistema operativo instalado en la máquina solicitado.
  See Updated List of OS Version Queries for WMI Filters at http://goo.gl/KX604c

.PARAMETER ComputerName
  Opcional. El nombre del equipo el cual se desea verificar la versión del sistema operativo. 
  Por defecto, verifica en el equipo local.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param(
	[string]$ComputerName = $env:COMPUTERNAME
)
	# como esta funcion es usada en varios lugares, se guarda en cache la respuesta obtenida la primera vez
	$osVersion = $Script:OSVersion;
	if ($osVersion) { return $osVersion; }

	#Try {
		#Log-RegionStart "Get-OSVersion";
		#Log-WriteLine "`$ComputerName: '$ComputerName'";
		#Log-WriteLine;

		#Log-WriteLine "Get-WmiObject Win32_OperatingSystem";
		$os = Get-WmiObject Win32_OperatingSystem -ComputerName $ComputerName

		# whether 32-bit or 64-bit
		$platform = ($os | select OSArchitecture).OSArchitecture;
		$productType = $os.ProductType
		#Log-WriteLine "`$platform: '$platform'";
		#Log-WriteLine "`$productType: '$productType'";
		#Log-WriteLine "Caption: '$($os.Caption)'";
		#Log-WriteLine "Version: '$($os.Version)'";
		
		#Log-WriteLine "Resolving Windows Version";
		$osVersion = . {
			if ($productType -eq 1) { # ANY WINDOWS DESKTOP OS
			  switch -wildcard ($os.Version)
			  {
				"5.1*" { "XP" }
				"5.2*" { "XP" }
				"6.0*" { "Vista" }
				"6.1*" { "Win7" }
				"6.2*" { "Win8" }
				"6.3*" { "Win81" }
				"10.*" { "Win10" }
				default { "UNKNOWN_$($os.Version)" }
			  }
			}
			else { # ANY WINDOWS SERVER OS
			  switch -wildcard ($os.Version)
			  {
				"5.2.3*" { "2003R2" }
				"5.2*" { "2003" }
				"6.0*" { "2008" }
				"6.1*" { "2008R2" }
				"6.2*" { "2012" }
				"6.3*" { "2012R2" }
				default { "UNKNOWN_$($os.Version)" }
			  }
			}
		};
	
		# add whether it is a server or client product
		$osVersion += if ($productType -eq 1) { "_DESKTOP" } else { "_SERVER" }

		# also, it is a domain controller
		if ($productType -eq 2) {
			$osVersion += "_DC"
		}
		$osVersion += "_$platform"
  
		#Log-WriteLine "`$osVersion: '$osVersion'";
		$global:OSVersion = $osVersion;
		return $osVersion;
	#}
	#Finally { Log-RegionEnd; }
}

Function IsWin2012OrAbove-OSVersion {
<#
.SYNOPSIS
	Retorna $true para: 1) windows Server 2012 o superior. 2) Windows 8.x o superior
#>
	$osVersion = Get-OSVersion
	# Windows Server 2012 and above / Windows 8 and above
	$win2012OrAbove = ($osVersion -like '*DESKTOP*' -and $osVersion -gt "Win8*") -or
					  ($osVersion -like '*SERVER*' -and $osVersion -gt "2012*")
	return $win2012OrAbove
}

Function Get-OSLanguage {
	$osLangCode = Get-WmiObject Win32_OperatingSystem -ErrorAction continue | select -First 1 -ExpandProperty OSLanguage
	$osLang = switch ($osLangCode) { 1033 {"EN"} 3082 {"ES"} }
	return $osLang
}

#endregion General


#region General - File System
Function Test-Folder([Parameter(Mandatory=$true)]$Path) {
	Test-Path $Path -PathType Container
}

Function New-Folder([Parameter(Mandatory=$true)]$Path) {
	if (-not (Test-Folder $Path)) {
		mkdir $Path | Out-Null
	}
}

Function Remove-Folder([Parameter(Mandatory=$true)]$Path) {
	Write-Header "Deleting existing folder '$Path' (recursively)..."
	if (-not (Test-Path $Path -PathType Container)) {
		Write-Footer "OK (Not found)"
		return
	}

	Remove-Item $Path -Recurse -Force
	Write-Footer "OK"
}

Function New-File {
Param(
[Parameter(Mandatory=$true)][string]$Path,
[string]$Value,
[Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]$Encoding = "UTF8",
[Switch]$Force = $false
)
	if ((Test-Path $Path) -and -not $Force) { throw "File already exists: '$Path'. Use '-Force' if you want to overwrite existing file" }
	New-Item $Path -Type File -Force
	Set-Content $Path -Value $Value -Encoding $Encoding
}
#endregion General - File System


#region General - .NET Version
Function Get-DotNetVersion {
	Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
		Get-ItemProperty -Name Version, Release -ErrorAction "SilentlyContinue" |
			Where { $_.PSChildName -match '^v|Full'} |
			% {
				if (Get-Member -InputObject $_ -Name Release -MemberType Properties) {
				#if ($_.Release) { 
			      switch($_.Release) {
			        378389 { "4.5" }
			        378675 { "4.5.1" } 	# .NET Framework 4.5.1 installed with Windows 8.1 or Windows Server 2012 R2
			        378758 { "4.5.1" } 	# .NET Framework 4.5.1 installed on Windows 8, Windows 7 SP1, or Windows Vista SP2
			        379893 { "4.5.2" }
			        393295 { "4.6" } 	# On Windows 10
			        393297 { "4.6" } 	# On all other OS other than Windows 10
			        394254 { "4.6.1" } 	# On Windows 10 November Update
			        394271 { "4.6.1" } 	# On all other OS versions
			        394747 { "4.6.2" } 	# On Windows 10 Insider Preview Build 14295
			        394748 { "4.6.2" } 	# On all other OS versions
					default { [string]$_.Version }
			      } # end switch
				}
				else { [string]$_.Version }
			} # end '%'
}
#cls; Get-DotNetVersion; exit

Function Enforce-DotNetVersion([Parameter(Mandatory=$true)][string]$version) {
	$matchVersion = if ($version -match '^4\.0') { '4' } else { $version }
	$versionsInstalled = Get-DotNetVersion
	Write-Verbose "[.NET Versions Installed]"
	$versionsInstalled | Write-Verbose 
	$items = $versionsInstalled | ? { $_ -ge $matchVersion }
	if (-not $items) { throw "Se requiere instalar .NET Framework '$version'" }
}
#cls; Enforce-DotNetVersion '4.0'; exit
#endregion General - .NET Version


#region General - Users and Groups
Function List-User($computerName = $env:ComputerName) {
	<#
	AccountType : 512
	Caption     : DEV04\Admin
	Domain      : DEV04
	SID         : S-1-5-21-1517187790-1355912472-2987691090-1001
	FullName    :
	Name        : Admin
	#>
	Get-WmiObject Win32_UserAccount -Filter "Domain='${env:ComputerName}'" | Select -ExpandProperty Name
}

Function Remove-User($UserName) {
	if (Test-User $UserName) {
		$argList = @("user",
					$UserName,
					"/DEL"
					)
		#"net $argList"
		net $argList
	}
}

Function Test-User($UserName) {
	try {
		net user $UserName > $null 2>&1
		return $LASTEXITCODE -eq 0
	}
	catch { return $false }
}

Function New-User($UserName, $Password) {
	if (Test-User $UserName) { return }
	
	# creates the user account
	$argList = @("user",
			$UserName, 
			$Password, 
			"/ADD"
			"/FULLNAME:`"$UserName`""
			"/PASSWORDCHG:Yes"		# allow user to change password
			#"/EXPIRES:Never"		# set the USER to Never expire (WARNING: the user, not the password)
			)
	#"net $argList"
	net $argList
	if ($LASTEXITCODE -ne 0) { throw "LASTEXITCODE: $LASTEXITCODE" }

	# set the Password to Never expire
	WMIC USERACCOUNT WHERE "Name='$UserName'" SET PasswordExpires=FALSE | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "LASTEXITCODE: $LASTEXITCODE" }
}

Function Add-GroupMember($Name, $Member) {
	# adds the user to the Local Administrators Group
	$argList = @("localgroup",
			$Name, 				# group name
			$Member, 			# user name
			"/ADD"
			)
	$cmdOutput = $null
	Write-Indented "net $argList"
	try {
		net $argList > $cmdOutput 2>&1
	}
	catch {
		if (-not ($_.Exception.Message -match '1378')) { throw }
	}
}
#endregion General - Users and Groups


#region General - Windows ACL
Function Grant-WindowsACL($physicalPath, $userOrGroupName, $simplePermission, [switch]$FindLocalizedName = $false) {
	Write-Header "GRANT '$simplePermission' to '$userOrGroupName' on '$physicalPath'..."

	if ($FindLocalizedName) {
		$osLang = Get-OSLanguage
		
		if ($osLang -eq "ES") {
			switch ($userOrGroupName) {
				"Users" { $userOrGroupName = "Usuarios" }
				"Administrators" { $userOrGroupName = "Administradores" }
				"Administrator" { $userOrGroupName = "Administrador" }
				default { throw "No localized string for '$userOrGroupName' has been defined" }
			}
		}
	}
	
	<# icacls.exe "$physicalPath" /grant "$userOrGroupName":(OI)(CI)(F) /T /Q /C
		(OI) - herencia de objeto
	    (CI) - herencia de contenedor
	una secuencia de derechos simples:
	    N - sin acceso
	    F - acceso total
	    M - acceso de modificación
	    RX - acceso de lectura y ejecución
	    R - acceso de solo lectura
	    W - acceso de solo escritura
	    D - acceso de eliminación
	#>
	$ArgList = @("`"$physicalPath`"", 
				"/grant", 
				"`"$userOrGroupName`":(OI)(CI)($simplePermission)", 
				"/T", 	# /T se realiza en todos los archivos o directorios bajo los directorios especificados en el nombre.
				"/Q",   # /Q suprimir los mensajes de que las operaciones se realizaron correctamente.
				"/C"	# /C indica que esta operación continuará en todos los errores de archivo. Se seguirán mostrando los mensajes de error.
				)
	Write-Indented "icacls.exe $ArgList"
	$cmdOutput = icacls.exe $ArgList
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	Write-Footer "OK"
}

Function GrantReadOnly-WindowsACL($physicalPath, $userOrGroupName, [switch]$FindLocalizedName = $false) {
	Grant-WindowsACL $physicalPath $userOrGroupName 'RX' -FindLocalizedName:$FindLocalizedName
}

Function GrantFull-WindowsACL($physicalPath, $userOrGroupName, [switch]$FindLocalizedName = $false) {
	Grant-WindowsACL $physicalPath $userOrGroupName 'F' -FindLocalizedName:$FindLocalizedName
}
#endregion General - Windows ACL


#region General - IE ESC (Internet Explorer - Enhanced Security Configuration)
Function UpdateFlag-OnRegistryKey {
<#
.SYNOPSIS
  Verifica is un key en registry de windows está presenta y la actualiza

.PARAMETER Enable
  $true: si se quiere habilitar. $false: si que quiere deshabilitar

.PARAMETER ParentKeyToSearch
  Indica la clave en el registry de windows donde buscar

.PARAMETER NameToUpdate
  Esta es el nombre de la clave dentro de ParentKeyToSearch que se quiere actualizar
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(Mandatory=$true)]
	[string]$ParentKeyToSearch,
	[Parameter(Mandatory=$true)]
	[string]$NameToUpdate,
	[switch]$Enable
	)
	$item = Get-ItemProperty -Path $ParentKeyToSearch -Name $NameToUpdate -ErrorAction SilentlyContinue;
	if (-not $item) {
		Write-Warning "No se encontró en el Registry el parent key: '$ParentKeyToSearch', name: '$NameToUpdate'"
		return $false # no updates made
	}

	$isEnabled = $item | Select -ExpandProperty $NameToUpdate

	$newValue = -1;
	if ($isEnabled -and -not $Enable) {
		$newValue = 0
	}
	elseif (-not $isEnabled -and $Enable) {
		$newValue = 1
	}

	if ($newValue -ne -1) {
		Set-ItemProperty -Path $ParentKeyToSearch -Name $NameToUpdate -Value $newValue
		return $true # an update was made
	}
	return $false # no updates made
}

Function Set-InternetExplorerESC {
<#
.SYNOPSIS
  habilita o deshabilita Internet Explorer ESC (Enhanced Security Configuration). 
  Esto es necesario hasta para ejecutar scripts de powershell desde una unidad de red, como en el caso de las pruebas en maquinas virtuales.

.PARAMETER Enable
  $true: si se quiere habilitar. $false: si que quiere deshabilitar

.PARAMETER Administrators
  Indica que el cambio debe aplicarse para Administradores

.PARAMETER Users
  Indica que el cambio debe aplicarse para usuarios no Administradores
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param(
	[Parameter(Mandatory=$true)]
	[switch]$Enable,
	[Parameter(ParameterSetName='AtLeastAdmin', Mandatory=$true)]
    [Parameter(ParameterSetName='AtLeastUser', Mandatory=$false)]
	[switch]$Administrators = $false,
	[Parameter(ParameterSetName='AtLeastAdmin', Mandatory=$false)]
    [Parameter(ParameterSetName='AtLeastUser', Mandatory=$true)]
	[switch]$Users = $false
)
	$nuevoEstado = if ($Enable) { 'Habilitado' }  else { 'Deshabilitado' }
	$textoAccion = if ($Enable) { 'Habilitando' }  else { 'Deshabilitando' }
	Write-Header "$textoAccion Seguridad Extendida de Internet Explorer"

	$osVersion = Get-OSVersion
	# Desactivar ESC para IE en Administradores
	# es necesario hasta para ejecutar scripts desde un folder de red
	if (-not ($osVersion -like '*SERVER*')) {
		Write-Footer "OK (No aplica para esta versión de Windows)"
		return
	}

	if (-not ($Administrators -or $Users)) {
		throw "Debe especificar por los menos un grupo de usuarios sobre el cual aplicar la acción"
	}

	$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
	$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
	
	$adminUpdated = $false;
	$userUpdated = $false;
	
	if ($Administrators) {
		Write-Indented "$textoAccion para Administradores"
		$adminUpdated = UpdateFlag-OnRegistryKey $AdminKey "IsInstalled" -Enable:$Enable
	}
	if ($Users) {
		Write-Indented "$textoAccion para Usuarios (NO administradores)"
		$userUpdated = UpdateFlag-OnRegistryKey $UserKey "IsInstalled" -Enable:$Enable
	}
	# reinicia el shell (windows explorer). 
	# NOTA: En este caso se mata el proceso pero el sistema lo reinicia automáticamente
	if ($adminUpdated -or $userUpdated) {
		Write-Indented "Reiniciando Proceso: Windows Explorer"
		Stop-Process -Name Explorer -Force
		Start-Sleep -Seconds 2
		if (-not (Get-Process -Name Explorer -ErrorAction SilentlyContinue)) {
			Write-Indented "WARNING: Levantando manualmente Proceso: Windows Explorer (Se esperaba que el sistema operativo lo reiniciara automáticamente)"
			Start-Process Explorer.exe
		}
		Write-Footer "OK"
	}
	else {
		Write-Footer "OK (Ya está $nuevoEstado)"
	}
}

Function Enable-InternetExplorerESC {
<#
.SYNOPSIS
  Habilita Internet Explorer ESC (Enhanced Security Configuration). 
#>
	Set-InternetExplorerESC -Enable -Administrators -Users
}

Function Disable-InternetExplorerESC {
<#
.SYNOPSIS
  Deshabilita Internet Explorer ESC (Enhanced Security Configuration) para Administradores
#>
	Set-InternetExplorerESC -Enable:$false -Administrators
}
#endregion General - IE ESC (Internet Explorer - Enhanced Security Configuration)


#region General - Installing Windows Components

Function Install_IIS-WinComponents {
[CmdletBinding(SupportsShouldProcess=$true)]
Param()
<#
.SYNOPSIS
  Instala IIS con todos los componentes necesarios para ejecutar una aplicacion ASP.NET
#>
	# ADVERTENCIA: si requiere reiniciar, retornara codigo 3010
	$RequiresRebootExitCode = 3010;
	
	# make sure .NET 4.0 is installed before proceeding
	Enforce-DotNetVersion "4.0"

	<# IIS 7.x Features / Windows Vista, Windows Server 2008 Editions
.SYNTAX
	"START /WAIT" must be used to wait until the installation finishes
	START /WAIT PkgMgr /quiet /iu:package1;package2

.EXAMPLE
	START /WAIT PkgMgr /quiet /iu:IIS-WebServerRole;IIS-WebServer;WAS-WindowsActivationService;WAS-ProcessModel;WAS-ConfigurationAPI;IIS-CommonHttpFeatures;IIS-StaticContent;IIS-DefaultDocument;IIS-DirectoryBrowsing;IIS-HttpErrors;IIS-ApplicationDevelopment;IIS-ASPNET;IIS-NetFxExtensibility;IIS-ISAPIExtensions;IIS-ISAPIFilter;WAS-NetFxEnvironment;IIS-Security;IIS-RequestFiltering;IIS-HealthAndDiagnostics;IIS-HttpLogging;IIS-RequestMonitor;IIS-BasicAuthentication;IIS-RequestFiltering;IIS-Performance;IIS-HttpCompressionStatic;IIS-HttpCompressionDynamic;IIS-WebServerManagementTools;IIS-ManagementConsole
	ECHO ERRORLEVEL: %ERRORLEVEL%

	Legend
		X: needed for dnn
		-: not needed

X [IIS-WebServerRole] Servidor web (IIS)
	X [IIS-WebServer] Servidor web
		*** REQUIRES:
			X [WAS-WindowsActivationService] Servicio WAS (Windows Process Activation Services)
				X [WAS-ProcessModel] Modelo de proceso
				X [WAS-ConfigurationAPI] API de configuración
		X [IIS-CommonHttpFeatures] Características HTTP comunes
			X [IIS-StaticContent] Contenido estático
			X [IIS-DefaultDocument] Documento predeterminado
			X [IIS-DirectoryBrowsing] Examen de directorios
			X [IIS-HttpErrors] Errores Http
			- [IIS-HttpRedirect] Redirección HTTP
		X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
			X [IIS-ASPNET] ASP.NET
				*** REQUIRES:
					X [IIS-NetFxExtensibility] Extensibilidad de .NET
					X [IIS-ISAPIExtensions] Extensiones ISAPI
					X [IIS-ISAPIFilter] Filtros ISAPI
					X {DUPLICATE_HEADER_LINE} [WAS-WindowsActivationService] Servicio WAS (Windows Process Activation Services)
						X [WAS-NetFxEnvironment] Entorno de .NET
					X {DUPLICATE_HEADER_LINE} [IIS-Security]
						X [IIS-RequestFiltering] Filtro de Solicitudes
			- [IIS-ASP] ASP
			- [IIS-CGI] CGI
			- [IIS-ServerSideIncludes] Inclusiones al lado del servidor
		X [IIS-HealthAndDiagnostics] Estado y diagnóstico
			X [IIS-HttpLogging] Registro HTTP
			- [IIS-LoggingLibraries] Herramienta de registro
			- [IIS-RequestMonitor] Monitores de solicitudes
			- [IIS-HttpTracing] Seguimiento
			- [IIS-CustomLogging] Registro personalizado
			- [IIS-ODBCLogging] Registro ODBC
		X [IIS-Security] Seguridad
			X [IIS-BasicAuthentication] Autenticación básica
			- [IIS-WindowsAuthentication] Autenticación de Windows
			- [IIS-DigestAuthentication] Autenticación implicita
			- [IIS-ClientCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente
			- [IIS-IISCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente de IIS
			- [IIS-URLAuthorization] Autorización para URL
			- [IIS-IPSecurity] Restricciones de IP y dominio
		X [IIS-Performance] Rendimiento
			X [IIS-HttpCompressionStatic] Compresión de contenido estático
			X [IIS-HttpCompressionDynamic] Compresión de contenido dinámico
		X [IIS-WebServerManagementTools] Herramientas de administración
			X [IIS-ManagementConsole] Consola de administración de IIS
			- [IIS-ManagementScriptingTools] Scripts y herramientas de administración de IIS
			- [IIS-ManagementService] Servicio de administración
			- [IIS-IIS6ManagementCompatibility] Compatibilidad con la administración de IIS 6
				- [IIS-Metabase] Compatibilidad con la metabase de IIS 6
				- [IIS-WMICompatibility] Compatibilidad con WMI de IIS 6
				- [IIS-LegacyScripts] Herramientas de scripting de IIS 6
				- [IIS-LegacySnapIn] Consola de administración de IIS 6
		- [IIS-FTPPublishingService] Servicio de publicación FTP
			- [IIS-FTPServer] Servidor FTP
			- [IIS-FTPManagement] Consola de administración de FTP
#>

	<# IIS 7.5 features / Windows 2008 R2, Windows 7
.EXAMPLE
	check syntax

dism /Online /Enable-Feature /?

.EXAMPLE
	List all features available for IIS

$pattern = "Nombre de característica : (?<feature>(IIS|WAS)-.+)"
$output = dism /Online /Get-Features
$output | ? { $_ -match $pattern } | % { $Matches["feature"] }

	Legend
		X: needed for dnn
		-: not needed

X [IIS-WebServerRole] Servidor web (IIS)
	X [IIS-WebServer] Servidor web
		X [IIS-CommonHttpFeatures] Características HTTP comunes
			X [IIS-StaticContent] Contenido estático
			X [IIS-DefaultDocument] Documento predeterminado
			X [IIS-DirectoryBrowsing] Examen de directorios
			X [IIS-HttpErrors] Errores HTTP
			- [IIS-WebDAV] Publicación en WebDAV
			- [IIS-HttpRedirect] Redirección HTTP
		X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
			X [IIS-ASPNET] ASP.NET
				*** REQUIRES:
					X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
						X [IIS-NetFxExtensibility] Extensibilidad de .NET
						X [IIS-ISAPIExtensions] Extensiones ISAPI
						X [IIS-ISAPIFilter] Filtros ISAPI
					X [IIS-Security]
						X [IIS-RequestFiltering] Filtro de Solicitudes
			- [IIS-ASP] ASP
			- [IIS-CGI] CGI
			- [IIS-ServerSideIncludes] Inclusiones al lado del servidor
		X [IIS-HealthAndDiagnostics] Estado y diagnóstico
			X [IIS-HttpLogging] Registro HTTP
			- [IIS-LoggingLibraries] Herramienta de registro
			- [IIS-RequestMonitor] Monitores de solicitudes
			- [IIS-HttpTracing] Seguimiento
			- [IIS-CustomLogging] Registro personalizado
			- [IIS-ODBCLogging] Registro ODBC
		X [IIS-Security] Seguridad
			X [IIS-BasicAuthentication] Autenticación básica
			- [IIS-WindowsAuthentication] Autenticación de Windows
			- [IIS-DigestAuthentication] Autenticación implicita
			- [IIS-ClientCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente
			- [IIS-IISCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente de IIS
			- [IIS-URLAuthorization] Autorización para URL
			- [IIS-IPSecurity] Restricciones de IP y dominio
		X [IIS-Performance] Rendimiento
			X [IIS-HttpCompressionStatic] Compresión de contenido estático
			X [IIS-HttpCompressionDynamic] Compresión de contenido dinámico
		X [IIS-WebServerManagementTools] Herramientas de administración
			X [IIS-ManagementConsole] Consola de administración de IIS
			- [IIS-ManagementScriptingTools] Scripts y herramientas de administración de IIS
			- [IIS-ManagementService] Servicio de administración
			- [IIS-IIS6ManagementCompatibility] Compatibilidad con la administración de IIS 6
				- [IIS-Metabase] Compatibilidad con la metabase de IIS 6
				- [IIS-WMICompatibility] Compatibilidad con WMI de IIS 6
				- [IIS-LegacyScripts] Herramientas de scripting de IIS 6
				- [IIS-LegacySnapIn] Consola de administración de IIS 6
		- [IIS-FTPServer] Servidor FTP
			- [IIS-FTPSvc] Servicio FTP
			- [IIS-FTPExtensibility] Extensibilidad de FTP
		- [IIS-HostableWebCore] Núcleo de web hospeadable IIS


.EXAMPLE
	Extra features on IIS 7.5:

	Legend:
		{NEW}			agregado a IIS 7.5 y no estaba en IIS 7.0
		{REMOVED}		removido de IIS 7.5 y estaba en IIS 7.0
		{REPLACES: old}	reemplaza a una característica antigua con nombre 'old'
	
	ADDITIONAL features:
	
		[IIS-CommonHttpFeatures] Características HTTP comunes
	 		{NEW} [IIS-WebDAV] Publicación en WebDAV
		[IIS-FTPServer] Servidor FTP {REPLACES: [IIS-FTPPublishingService]}
			[IIS-FTPSvc] Servicio FTP {REPLACES: [IIS-FTPServer]}
			{NEW} [IIS-FTPExtensibility] Extensibilidad de FTP
			{REMOVED} [IIS-FTPManagement] Consola de administración de FTP
		{NEW} [IIS-HostableWebCore] Núcleo de web hospeadable IIS

	***WARNING: [IIS-WebDAV] entra en conflicto con los servicios REST y web API. Hay que desinstalarlo

.EXAMPLE
	Instalar IIS y carateristicas necesitadas por dnn

dism /Online /Enable-Feature /FeatureName:IIS-WebServerRole /FeatureName:IIS-WebServer /FeatureName:WAS-WindowsActivationService /FeatureName:WAS-ProcessModel /FeatureName:WAS-ConfigurationAPI /FeatureName:IIS-CommonHttpFeatures /FeatureName:IIS-StaticContent /FeatureName:IIS-DefaultDocument /FeatureName:IIS-DirectoryBrowsing /FeatureName:IIS-HttpErrors /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ASPNET /FeatureName:IIS-NetFxExtensibility /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-ISAPIFilter /FeatureName:WAS-NetFxEnvironment /FeatureName:IIS-Security /FeatureName:IIS-RequestFiltering /FeatureName:IIS-HealthAndDiagnostics /FeatureName:IIS-HttpLogging /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-Performance /FeatureName:IIS-HttpCompressionStatic /FeatureName:IIS-HttpCompressionDynamic /FeatureName:IIS-WebServerManagementTools /FeatureName:IIS-ManagementConsole
"LASTEXITCODE: $LASTEXITCODE"

	WARNING: dism options not working on Windows 2008 R2
		/All
		/LimitAccess

.EXAMPLE
	Desinstalar WebDAV (sino está instalado, no saca error)

	***WARNING: [IIS-WebDAV] entra en conflicto con los servicios REST y web API. Hay que desinstalarlo

dism /Online /Disable-Feature /FeatureName:IIS-WebDAV
"LASTEXITCODE: $LASTEXITCODE"

.EXAMPLE
	Verificar si está instalado (opcional) y desinstalar WebDAV

	#dism /Online /Enable-Feature /FeatureName:IIS-WebDAV
	"LASTEXITCODE: $LASTEXITCODE"

	$output = dism /online /Get-FeatureInfo /FeatureName:IIS-WebDAV
	$status = $output | ? { $_ -match "^(Estado|State) : (?<state>.+)" } | % { $Matches["state"] }
	$status -match "Disabled|Deshabilitado"
	$status -match "Enabled|Habilitado"
#>

	<# IIS 8.0 features / Windows 2012, Windows 8.x
.EXAMPLE
	List all features available for IIS

$pattern = "Nombre de característica : (?<feature>.*(IIS|WAS|NetFx4).*)"
$output = dism /Online /Get-Features
$output | ? { $_ -match $pattern } | % { $Matches["feature"] }

.EXAMPLE
	Obtiene la descripcion de un feature

dism /Online /Get-FeatureInfo /FeatureName:WAS-WindowsActivationService | Select-string 'DisplayName|Parent'

.EXAMPLE
	List all features on IIS 8.0:

X [IIS-WebServerRole] Servidor web (IIS)
	*** REQUIRES:
		X [IIS-WebServerManagementTools] Herramientas de administración
			X [IIS-ManagementConsole] Consola de administración de IIS
	X [IIS-WebServer] Servidor web
		X [IIS-CommonHttpFeatures] Características HTTP comunes
			X [IIS-StaticContent] Contenido estático
			X [IIS-DefaultDocument] Documento predeterminado
			X [IIS-HttpErrors] Errores Http
			X [IIS-DirectoryBrowsing] Examen de directorios
			- [IIS-WebDAV] Publicación WebDAV
			- [IIS-HttpRedirect] Redirección HTTP
		X [IIS-HealthAndDiagnostics] Estado y diagnóstico
			X [IIS-HttpLogging] Registro HTTP
			- [IIS-LoggingLibraries] Herramienta de registro
			- [IIS-RequestMonitor] Monitores de solicitudes
			- [IIS-HttpTracing] Seguimiento
			- [IIS-CustomLogging] Registro personalizado
			- [IIS-ODBCLogging] Registro ODBC
		X [IIS-Performance] Rendimiento
			X [IIS-HttpCompressionStatic] Compresión de contenido estático
			X [IIS-HttpCompressionDynamic] Compresión de contenido dinámico
		X [IIS-Security] Seguridad
			X [IIS-RequestFiltering] Filtro de Solicitudes
			X [IIS-BasicAuthentication] Autenticación básica
			- [IIS-ClientCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente
			- [IIS-IISCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente de IIS
			- [IIS-WindowsAuthentication] Autenticación de Windows
			- [IIS-DigestAuthentication] Autenticación implicita
			- [IIS-URLAuthorization] Autorización para URL
			- [IIS-CertProvider] Compatibilidad con certificados centralizados SSL
			- [IIS-IPSecurity] Restricciones de IP y dominio
		X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
			- [IIS-ASP] ASP
			- [IIS-ASPNET] ASP 3.5
			X [IIS-ASPNET45] ASP.NET 4.5
				*** REQUIRES:
					* [NetFx4ServerFeatures] Características de .NET Framework 4.5
						* [NetFx4] .NET Framework 4.5
						X [NetFx4Extended-ASPNET45] ASP.NET 4.5
					X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
						X [IIS-ISAPIExtensions] Extensiones ISAPI
						X [IIS-ISAPIFilter] Filtros ISAPI
						X [IIS-NetFxExtensibility45] Extensibilidad de .NET 4.5
			- [IIS-CGI] CGI
			- [IIS-NetFxExtensibility] Extensibilidad de .NET 3.5
			- [IIS-ServerSideIncludes] Inclusiones al lado del servidor
			X [IIS-ApplicationInit] Inicialización de aplicaciones
			X [IIS-WebSockets] Protocolo WebSocket
		X [IIS-WebServerManagementTools] Herramientas de administración
			- [IIS-IIS6ManagementCompatibility] Compatibilidad con la administración de IIS 6
				- [IIS-Metabase] Compatibilidad con la metabase de IIS 6
				- [IIS-WMICompatibility] Compatibilidad con WMI de IIS 6
				- [IIS-LegacySnapIn] Consola de administración de IIS 6
				- [IIS-LegacyScripts] Herramientas de scripting de IIS 6
			- [IIS-ManagementScriptingTools] Scripts y herramientas de administración de IIS
			- [IIS-ManagementService] Servicio de administración
		- [IIS-HostableWebCore] Núcleo de web hospeadable IIS
		- [IIS-FTPServer] Servidor FTP
			- [IIS-FTPSvc] Servicio FTP
			- [IIS-FTPExtensibility] Extensibilidad de FTP

	***WARNING: [IIS-WebDAV] entra en conflicto con los servicios REST y web API. Hay que desinstalarlo

.EXAMPLE
	Instalar IIS y carateristicas necesitadas por dnn

dism /Online /Enable-Feature /FeatureName:IIS-WebServerRole /FeatureName:IIS-WebServer /FeatureName:WAS-WindowsActivationService /FeatureName:WAS-ProcessModel /FeatureName:WAS-ConfigurationAPI /FeatureName:IIS-CommonHttpFeatures /FeatureName:IIS-StaticContent /FeatureName:IIS-DefaultDocument /FeatureName:IIS-DirectoryBrowsing /FeatureName:IIS-HttpErrors /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ASPNET /FeatureName:IIS-NetFxExtensibility /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-ISAPIFilter /FeatureName:WAS-NetFxEnvironment /FeatureName:IIS-Security /FeatureName:IIS-RequestFiltering /FeatureName:IIS-HealthAndDiagnostics /FeatureName:IIS-HttpLogging /FeatureName:IIS-RequestMonitor /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-Performance /FeatureName:IIS-HttpCompressionStatic /FeatureName:IIS-HttpCompressionDynamic /FeatureName:IIS-WebServerManagementTools /FeatureName:IIS-ManagementConsole
"LASTEXITCODE: $LASTEXITCODE"

	WARNING: dism options not working on Windows 2008 R2
		/All
		/LimitAccess

.EXAMPLE
	Desinstalar WebDAV (sino está instalado, no saca error)

	***WARNING: [IIS-WebDAV] entra en conflicto con los servicios REST y web API. Hay que desinstalarlo

dism /Online /Disable-Feature /FeatureName:IIS-WebDAV
"LASTEXITCODE: $LASTEXITCODE"

.EXAMPLE
	Verificar si está instalado (opcional) y desinstalar WebDAV

	#dism /Online /Enable-Feature /FeatureName:IIS-WebDAV
	"LASTEXITCODE: $LASTEXITCODE"

	$output = dism /online /Get-FeatureInfo /FeatureName:IIS-WebDAV
	$status = $output | ? { $_ -match "^(Estado|State) : (?<state>.+)" } | % { $Matches["state"] }
	$status -match "Disabled|Deshabilitado"
	$status -match "Enabled|Habilitado"
#>

	<# IIS 8.5 features / Windows 2012 R2, Windows 10

Same features as in IIS 8.0
#>

	# Legend
	#	X: needed for dnn
	#	-: not needed
	$featureListWin2008R2 = @"
X [IIS-WebServerRole] Servidor web (IIS)
	X [IIS-WebServer] Servidor web
		X [IIS-CommonHttpFeatures] Características HTTP comunes
			X [IIS-StaticContent] Contenido estático
			X [IIS-DefaultDocument] Documento predeterminado
			X [IIS-DirectoryBrowsing] Examen de directorios
			X [IIS-HttpErrors] Errores HTTP
			- [IIS-WebDAV] Publicación en WebDAV
			- [IIS-HttpRedirect] Redirección HTTP
		X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
			X [IIS-ASPNET] ASP.NET
				*** REQUIRES:
					X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
						X [IIS-NetFxExtensibility] Extensibilidad de .NET
						X [IIS-ISAPIExtensions] Extensiones ISAPI
						X [IIS-ISAPIFilter] Filtros ISAPI
					X [IIS-Security]
						X [IIS-RequestFiltering] Filtro de Solicitudes
			- [IIS-ASP] ASP
			- [IIS-CGI] CGI
			- [IIS-ServerSideIncludes] Inclusiones al lado del servidor
		X [IIS-HealthAndDiagnostics] Estado y diagnóstico
			X [IIS-HttpLogging] Registro HTTP
			- [IIS-LoggingLibraries] Herramienta de registro
			- [IIS-RequestMonitor] Monitores de solicitudes
			- [IIS-HttpTracing] Seguimiento
			- [IIS-CustomLogging] Registro personalizado
			- [IIS-ODBCLogging] Registro ODBC
		X [IIS-Security] Seguridad
			X [IIS-BasicAuthentication] Autenticación básica
			- [IIS-WindowsAuthentication] Autenticación de Windows
			- [IIS-DigestAuthentication] Autenticación implicita
			- [IIS-ClientCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente
			- [IIS-IISCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente de IIS
			- [IIS-URLAuthorization] Autorización para URL
			- [IIS-IPSecurity] Restricciones de IP y dominio
		X [IIS-Performance] Rendimiento
			X [IIS-HttpCompressionStatic] Compresión de contenido estático
			X [IIS-HttpCompressionDynamic] Compresión de contenido dinámico
		X [IIS-WebServerManagementTools] Herramientas de administración
			X [IIS-ManagementConsole] Consola de administración de IIS
			- [IIS-ManagementScriptingTools] Scripts y herramientas de administración de IIS
			- [IIS-ManagementService] Servicio de administración
			- [IIS-IIS6ManagementCompatibility] Compatibilidad con la administración de IIS 6
				- [IIS-Metabase] Compatibilidad con la metabase de IIS 6
				- [IIS-WMICompatibility] Compatibilidad con WMI de IIS 6
				- [IIS-LegacyScripts] Herramientas de scripting de IIS 6
				- [IIS-LegacySnapIn] Consola de administración de IIS 6
		- [IIS-FTPServer] Servidor FTP
			- [IIS-FTPSvc] Servicio FTP
			- [IIS-FTPExtensibility] Extensibilidad de FTP
		- [IIS-HostableWebCore] Núcleo de web hospeadable IIS
"@

	$featureListWin2012 = @"
X [IIS-WebServerRole] Servidor web (IIS)
	*** REQUIRES:
		X [IIS-WebServerManagementTools] Herramientas de administración
			X [IIS-ManagementConsole] Consola de administración de IIS
	X [IIS-WebServer] Servidor web
		X [IIS-CommonHttpFeatures] Características HTTP comunes
			X [IIS-StaticContent] Contenido estático
			X [IIS-DefaultDocument] Documento predeterminado
			X [IIS-HttpErrors] Errores Http
			X [IIS-DirectoryBrowsing] Examen de directorios
			- [IIS-WebDAV] Publicación WebDAV
			- [IIS-HttpRedirect] Redirección HTTP
		X [IIS-HealthAndDiagnostics] Estado y diagnóstico
			X [IIS-HttpLogging] Registro HTTP
			- [IIS-LoggingLibraries] Herramienta de registro
			- [IIS-RequestMonitor] Monitores de solicitudes
			- [IIS-HttpTracing] Seguimiento
			- [IIS-CustomLogging] Registro personalizado
			- [IIS-ODBCLogging] Registro ODBC
		X [IIS-Performance] Rendimiento
			X [IIS-HttpCompressionStatic] Compresión de contenido estático
			X [IIS-HttpCompressionDynamic] Compresión de contenido dinámico
		X [IIS-Security] Seguridad
			X [IIS-RequestFiltering] Filtro de Solicitudes
			X [IIS-BasicAuthentication] Autenticación básica
			- [IIS-ClientCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente
			- [IIS-IISCertificateMappingAuthentication] Autenticación de asignaciones de certificado de cliente de IIS
			- [IIS-WindowsAuthentication] Autenticación de Windows
			- [IIS-DigestAuthentication] Autenticación implicita
			- [IIS-URLAuthorization] Autorización para URL
			- [IIS-CertProvider] Compatibilidad con certificados centralizados SSL
			- [IIS-IPSecurity] Restricciones de IP y dominio
		X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
			- [IIS-ASP] ASP
			- [IIS-ASPNET] ASP 3.5
			X [IIS-ASPNET45] ASP.NET 4.5
				*** REQUIRES:
					* [NetFx4ServerFeatures] Características de .NET Framework 4.5
						* [NetFx4] .NET Framework 4.5
						X [NetFx4Extended-ASPNET45] ASP.NET 4.5
					X [IIS-ApplicationDevelopment] Desarrollo de aplicaciones
						X [IIS-ISAPIExtensions] Extensiones ISAPI
						X [IIS-ISAPIFilter] Filtros ISAPI
						X [IIS-NetFxExtensibility45] Extensibilidad de .NET 4.5
			- [IIS-CGI] CGI
			- [IIS-NetFxExtensibility] Extensibilidad de .NET 3.5
			- [IIS-ServerSideIncludes] Inclusiones al lado del servidor
			X [IIS-ApplicationInit] Inicialización de aplicaciones
			X [IIS-WebSockets] Protocolo WebSocket
		X [IIS-WebServerManagementTools] Herramientas de administración
			- [IIS-IIS6ManagementCompatibility] Compatibilidad con la administración de IIS 6
				- [IIS-Metabase] Compatibilidad con la metabase de IIS 6
				- [IIS-WMICompatibility] Compatibilidad con WMI de IIS 6
				- [IIS-LegacySnapIn] Consola de administración de IIS 6
				- [IIS-LegacyScripts] Herramientas de scripting de IIS 6
			- [IIS-ManagementScriptingTools] Scripts y herramientas de administración de IIS
			- [IIS-ManagementService] Servicio de administración
		- [IIS-HostableWebCore] Núcleo de web hospeadable IIS
		- [IIS-FTPServer] Servidor FTP
			- [IIS-FTPSvc] Servicio FTP
			- [IIS-FTPExtensibility] Extensibilidad de FTP
"@

	$osVersion = Get-OSVersion

	# **************************************************************************
	# ***WARNING: [IIS-WebDAV] entra en conflicto con los servicios REST y web API. Hay que desinstalarlo si estuviere instalado
	# **************************************************************************
	Write-Header "Removiendo conflictos con WebDAV..."
	$argList = "/Online",					# Se destina al sistema operativo en ejecución.
				"/Disable-Feature",  		# Habilita una característica específica en la imagen
				"/FeatureName:IIS-WebDAV"   # Publicación en WebDAV
	Write-Indented "dism $argList"
	if ($PSCmdLet.ShouldProcess("WebDAV")) {
		$cmdOutput = dism $argList
		if (-not (0 -contains $LASTEXITCODE)) { throw "LASTEXITCODE: $LASTEXITCODE. $cmdOutput" }
	}
	Write-Footer "OK"


	# **************************************************************************
	$argList = "/Online",			# Se destina al sistema operativo en ejecución.
				"/Enable-Feature"   # Habilita una característica específica en la imagen
	
	# Windows Server 2012 and above / Windows 8 and above
	$win2012OrAbove = IsWin2012OrAbove-OSVersion
	$featureList = if ($win2012OrAbove) { $featureListWin2012 } else { $featureListWin2008R2 }
	$neededFeatures = $featureList -split "`r`n" | ? { $_ -match 'X \[(?<feature>[^\]]+)\]' } | % { $Matches["feature"] } | Select -Unique

	$argList += $neededFeatures | % { "/FeatureName:$_" }

	if ($win2012OrAbove) {
		$argList += "/LimitAccess", # evitar que DISM se comunique con WU/WSUS (Windows Update)
					"/All" 			# habilitar todas las características primarias de la característica especificada.
	}

	# **************************************************************************
	# ADVERTENCIA: si requiere reiniciar, retornara codigo 3010
	# **************************************************************************
	Write-Header "Instalando IIS y componentes requeridos..."
	Write-Indented "dism $argList"
	if ($PSCmdLet.ShouldProcess("Install-IIS")) {
		$cmdOutput = dism $argList
		if ($LASTEXITCODE -eq $RequiresRebootExitCode) { Write-Warning (Get-Indented "WARNING: REQUIRES_REBOOT") }
		if (-not (0,$RequiresRebootExitCode -contains $LASTEXITCODE)) 
		{ throw "LASTEXITCODE: $LASTEXITCODE. $cmdOutput" }
	}
	Write-Footer "OK"
	

	# **************************************************************************
	Write-Header "Registrando ASP.NET en el IIS..."
	# **************************************************************************
	if ($win2012OrAbove) {
		<#
		Microsoft (R) ASP.NET RegIIS versión 4.0.30319.34209
		Utilidad de administración que instala y desinstala ASP.NET en el equipo local.
		Copyright (C) Microsoft Corporation. Todos los derechos reservados.
		Inicie la instalación de ASP.NET (4.0.30319.34209).

		Esta opción no es compatible con esta versión del sistema operativo. Los administradores deben instalar o desinstalar ASP.NET 4.5 con I
		IS8 a través del cuadro de diálogo "Activar o desactivar las características de Windows", la herramienta Administrador del servidor o l
		a herramienta de línea de comandos dism.exe. Para obtener más detalles, vea http://go.microsoft.com/fwlink/?LinkID=216771.
		Finalizó la instalación de ASP.NET (4.0.30319.34209).
		#>
		Write-Footer "OK (Proceso automático en esta versión de Windows)"
	} 
	else {
		$frameworkSubfolder = if ($OSVersion -like '*64 bits') { "Framework64" } else { "Framework" }
		Register-Alias "aspnet_regiis" "$env:SystemRoot\Microsoft.NET\$frameworkSubfolder\v4.0.30319\aspnet_regiis.exe"
		
		Write-Indented "regiis -i"
		if ($PSCmdLet.ShouldProcess("aspnet_regiis")) {
			$cmdOutput = aspnet_regiis -i
			if (-not (0 -contains $LASTEXITCODE)) { throw "LASTEXITCODE: $LASTEXITCODE. $cmdOutput" }
		}
		Write-Footer "OK"
	}
}
#endregion General - Installing Windows Components


#region General - Win Explorer Handling Zip Files
# Recursive Function to calculate the total number of files and directories in the Zip file.
Function GetItemCountInternal-ZipFile($shellItems) {
    [int]$totalItems = $shellItems.Count
    foreach ($shellItem in $shellItems)
    {
        if ($shellItem.IsFolder)
        { $totalItems += GetItemCountInternal-ZipFile -shellItems $shellItem.GetFolder.Items() }
    }
    $totalItems
}
 
# Recursive Function to move a directory into a Zip file, since we can move files out of a Zip file, but not directories, and copying a directory into a Zip file when it already exists is not allowed.
Function AddFolderInternal-ZipFile($parentInZipFileShell, $pathOfItemToCopy) {
    # Get the name of the file/directory to copy, and the item itself.
    $nameOfItemToCopy = Split-Path -Path $pathOfItemToCopy -Leaf
    if ($parentInZipFileShell.IsFolder)
    { $parentInZipFileShell = $parentInZipFileShell.GetFolder }
    $itemToCopyShell = $parentInZipFileShell.ParseName($nameOfItemToCopy)
     
    # If this item does not exist in the Zip file yet, or it is a file, move it over.
    if ($itemToCopyShell -eq $null -or !$itemToCopyShell.IsFolder)
    {
        $parentInZipFileShell.MoveHere($pathOfItemToCopy)
         
        # Wait for the file to be moved before continuing, to avoid erros about the zip file being locked or a file not being found.
        while (Test-Path -Path $pathOfItemToCopy)
        { Start-Sleep -Milliseconds 10 }
    }
    # Else this is a directory that already exists in the Zip file, so we need to traverse it and copy each file/directory within it.
    else
    {
        # Copy each file/directory in the directory to the Zip file.
        foreach ($item in (Get-ChildItem -Path $pathOfItemToCopy -Force))
        {
            AddFolderInternal-ZipFile -parentInZipFileShell $itemToCopyShell -pathOfItemToCopy $item.FullName
        }
    }
}
 
# Recursive Function to move all of the files that start with the File Name Prefix to the Directory To Move Files To.
Function ExtractInternal-ZipFile($shellItems, $directoryToMoveFilesToShell, $fileNamePrefix) {
    # Loop through every item in the file/directory.
    foreach ($shellItem in $shellItems)
    {
        # If this is a directory, recursively call this Function to iterate over all files/directories within it.
        if ($shellItem.IsFolder)
        { 
            $totalItems += ExtractInternal-ZipFile -shellItems $shellItem.GetFolder.Items() -directoryToMoveFilesTo $directoryToMoveFilesToShell -fileNameToMatch $fileNameToMatch
        }
        # Else this is a file.
        else
        {
            # If this file name starts with the File Name Prefix, move it to the specified directory.
            if ($shellItem.Name.StartsWith($fileNamePrefix))
            {
                $directoryToMoveFilesToShell.MoveHere($shellItem)
            }
        }           
    }
}
  
Function Compress-ZipFile {
[CmdletBinding()]
Param(
    [Parameter(Position=1,Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $_ })]
	[string]$Source, 
    [Parameter(Position=2,Mandatory=$false)][string]$ZipFile
)
    Begin { }
    End { }
    Process {
		$OverwriteWithoutPrompting = $true

		# zip file extension is required by the shell.application
        if (-not ($ZipFile -match '\.zip$')) { $ZipFile += '.zip' }
         
        # If the Zip file to add the file to does not exist yet, create it.
        if (!(Test-Path -Path $ZipFile -PathType Leaf))
        {
			Set-Content $ZipFile ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
			(dir $ZipFile).IsReadOnly = $false
		}
 
        # Get the Name of the file or directory to add to the Zip file.
        # Get the number of files and directories to add to the Zip file.
        # Get if we are adding a file or directory to the Zip file.
        $fileOrDirectoryNameToAddToZipFile = Split-Path -Path $Source -Leaf
        $numberOfFilesAndDirectoriesToAddToZipFile = (Get-ChildItem -Path $Source -Recurse -Force).Count
        $itemToAddToZipIsAFile = Test-Path -Path $Source -PathType Leaf
 
        # Get Shell object and the Zip File.
        $shell = New-Object -ComObject Shell.Application
        $zipShell = $shell.NameSpace($ZipFile)
 
        # We will want to check if we can do a simple copy operation into the Zip file or not. Assume that we can't to start with.
        # We can if the file/directory does not exist in the Zip file already, or it is a file and the user wants to be prompted on conflicts.
        $canPerformSimpleCopyIntoZipFile = $false
 
        # If the file/directory does not already exist in the Zip file, or it does exist, but it is a file and the user wants to be prompted on conflicts, then we can perform a simple copy into the Zip file.
        $fileOrDirectoryInZipFileShell = $zipShell.ParseName($fileOrDirectoryNameToAddToZipFile)
        $itemToAddToZipIsAFileAndUserWantsToBePromptedOnConflicts = ($itemToAddToZipIsAFile -and !$OverwriteWithoutPrompting)
        if ($fileOrDirectoryInZipFileShell -eq $null -or $itemToAddToZipIsAFileAndUserWantsToBePromptedOnConflicts)
        {
            $canPerformSimpleCopyIntoZipFile = $true
        }
         
        # If we can perform a simple copy operation to get the file/directory into the Zip file.
        if ($canPerformSimpleCopyIntoZipFile) {
            # Start copying the file/directory into the Zip file since there won't be any conflicts. This is an asynchronous operation.
            $zipShell.CopyHere($Source)  # Copy Flags are ignored when copying files into a zip file, so can't use them like we did with the Expand-ZipFile function.
             
            # The Copy operation is asynchronous, so wait until it is complete before continuing.
            # Wait until we can see that the file/directory has been created.
            while ($zipShell.ParseName($fileOrDirectoryNameToAddToZipFile) -eq $null)
            { Start-Sleep -Milliseconds 100 }
             
            # If we are copying a directory into the Zip file, we want to wait until all of the files/directories have been copied.
            if (!$itemToAddToZipIsAFile) {
                # Get the number of files and directories that should be copied into the Zip file.
                $numberOfItemsToCopyIntoZipFile = (Get-ChildItem -Path $Source -Recurse -Force).Count
             
                # Get a handle to the new directory we created in the Zip file.
                $newDirectoryInZipFileShell = $zipShell.ParseName($fileOrDirectoryNameToAddToZipFile)
                 
                # Wait until the new directory in the Zip file has the expected number of files and directories in it.
                while ((GetItemCountInternal-ZipFile -shellItems $newDirectoryInZipFileShell.GetFolder.Items()) -lt $numberOfItemsToCopyIntoZipFile)
                { Start-Sleep -Milliseconds 100 }
            }
        }
        # Else we cannot do a simple copy operation. We instead need to move the files out of the Zip file so that we can merge the directory, or overwrite the file without the user being prompted.
        # We cannot move a directory into the Zip file if a directory with the same name already exists, as a MessageBox warning is thrown, not a conflict resolution prompt like with files.
        # We cannot silently overwrite an existing file in the Zip file, as the flags passed to the CopyHere/MoveHere functions seem to be ignored when copying into a Zip file.
        else
        {
            # Create a temp directory to hold our file/directory.
            $tempDirectoryPath = $null
            $tempDirectoryPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
            New-Item -Path $tempDirectoryPath -ItemType Container | Out-Null
         
            # If we will be moving a directory into the temp directory.
            $zipItemCountsDirectory = 0
            if ($fileOrDirectoryInZipFileShell.IsFolder)
            {
                # Get the number of files and directories in the Zip file's directory.
                $zipItemCountsDirectory = GetItemCountInternal-ZipFile -shellItems $fileOrDirectoryInZipFileShell.GetFolder.Items()
            }
         
            # Start moving the file/directory out of the Zip file and into a temp directory. This is an asynchronous operation.
            $tempDirectoryShell = $shell.NameSpace($tempDirectoryPath)
            $tempDirectoryShell.MoveHere($fileOrDirectoryInZipFileShell)
             
            # If we are moving a directory, we need to wait until all of the files and directories in that Zip file's directory have been moved.
            $fileOrDirectoryPathInTempDirectory = Join-Path -Path $tempDirectoryPath -ChildPath $fileOrDirectoryNameToAddToZipFile
            if ($fileOrDirectoryInZipFileShell.IsFolder)
            {
                # The Move operation is asynchronous, so wait until it is complete before continuing. That is, sleep until the Destination Directory has the same number of files as the directory in the Zip file.
                while ((Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Recurse -Force).Count -lt $zipItemCountsDirectory)
                { Start-Sleep -Milliseconds 100 }
            }
            # Else we are just moving a file, so we just need to check for when that one file has been moved.
            else
            {
                # The Move operation is asynchronous, so wait until it is complete before continuing.
                while (!(Test-Path -Path $fileOrDirectoryPathInTempDirectory))
                { Start-Sleep -Milliseconds 100 }
            }
             
            # We want to copy the file/directory to add to the Zip file to the same location in the temp directory, so that files/directories are merged.
            # If we should automatically overwrite files, do it.
            if ($OverwriteWithoutPrompting)
            { Copy-Item -Path $Source -Destination $tempDirectoryPath -Recurse -Force }
            # Else the user should be prompted on each conflict.
            else
            { Copy-Item -Path $Source -Destination $tempDirectoryPath -Recurse -Confirm -ErrorAction SilentlyContinue }  # SilentlyContinue errors to avoid an error for every directory copied.
 
            # For whatever reason the zip.MoveHere() Function is not able to move empty directories into the Zip file, so we have to put dummy files into these directories 
            # and then remove the dummy files from the Zip file after.
            # If we are copying a directory into the Zip file.
            $dummyFileNamePrefix = 'Dummy.File'
            [int]$numberOfDummyFilesCreated = 0
            if ($fileOrDirectoryInZipFileShell.IsFolder)
            {
                # Place a dummy file in each of the empty directories so that it gets copied into the Zip file without an error.
                $emptyDirectories = Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Recurse -Force -Directory | Where-Object { (Get-ChildItem -Path $_ -Force) -eq $null }
                foreach ($emptyDirectory in $emptyDirectories)
                {
                    $numberOfDummyFilesCreated++
                    New-Item -Path (Join-Path -Path $emptyDirectory.FullName -ChildPath "$dummyFileNamePrefix$numberOfDummyFilesCreated") -ItemType File -Force | Out-Null
                }
            }       
 
            # If we need to copy a directory back into the Zip file.
            if ($fileOrDirectoryInZipFileShell.IsFolder)
            {
                AddFolderInternal-ZipFile -parentInZipFileShell $zipShell -pathOfItemToCopy $fileOrDirectoryPathInTempDirectory
            }
            # Else we need to copy a file back into the Zip file.
            else
            {
                # Start moving the merged file back into the Zip file. This is an asynchronous operation.
                $zipShell.MoveHere($fileOrDirectoryPathInTempDirectory)
            }
             
            # The Move operation is asynchronous, so wait until it is complete before continuing.
            # Sleep until all of the files have been moved into the zip file. The MoveHere() Function leaves empty directories behind, so we only need to watch for files.
            do
            {
                Start-Sleep -Milliseconds 100
                $files = Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Force -Recurse | Where-Object { !$_.PSIsContainer }
            } while ($files -ne $null)
             
            # If there are dummy files that need to be moved out of the Zip file.
            if ($numberOfDummyFilesCreated -gt 0)
            {
                # Move all of the dummy files out of the supposed-to-be empty directories in the Zip file.
                ExtractInternal-ZipFile -shellItems $zipShell.items() -directoryToMoveFilesToShell $tempDirectoryShell -fileNamePrefix $dummyFileNamePrefix
                 
                # The Move operation is asynchronous, so wait until it is complete before continuing.
                # Sleep until all of the dummy files have been moved out of the zip file.
                do
                {
                    Start-Sleep -Milliseconds 100
                    [Object[]]$files = Get-ChildItem -Path $tempDirectoryPath -Force -Recurse | Where-Object { !$_.PSIsContainer -and $_.Name.StartsWith($dummyFileNamePrefix) }
                } while ($files -eq $null -or $files.Count -lt $numberOfDummyFilesCreated)
            }
             
            # Delete the temp directory that we created.
            Remove-Item -Path $tempDirectoryPath -Force -Recurse | Out-Null
        }
    }
}
#cls; Compress-ZipFile "C:\inetpub\zeusdnn\dev"

Function Extract-ZipFile {
#Extract-ZipFile -ZipFile $ZipFile -Destination $Destination
[CmdLetBinding(SupportsShouldProcess=$true)]
Param(
    [Parameter(Position=1,Mandatory=$true)]
    [ValidateScript({(Test-Path -Path $_ -PathType Leaf) -and $_.EndsWith('.zip', [StringComparison]::OrdinalIgnoreCase)})]
    [string]$ZipFile, 
    [Parameter(Mandatory=$true)]
    [string]$Destination,
    [string[]]$Exclude
)
    Begin { }
    End { }
    Process {   
		Write-Header "Extracting zip file: '$ZipFile'"
		$shell = New-Object -ComObject Shell.Application

		# Folder.CopyHere method (Windows)
		# https://msdn.microsoft.com/en-us/library/windows/desktop/bb787866%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
		# Note: In some cases, such as compressed (.zip) files, some option flags may be ignored by design.
		$copyFlags =   4 +  # Do not display a progress dialog box.
					  16 +  # Respond with "Yes to All" for any dialog box that is displayed.
					1024    # Do not display a user interface if an error occurs.
		$zipShell = $shell.Namespace($ZipFile)
		
        # Get the number of files and directories in the Zip file.
        $zipItemCount = GetItemCountInternal-ZipFile -shellItems $zipShell.Items()
		Write-Indented "Zip file items: '$zipItemCount'"

		if (-not (Test-Path $Destination -PathType Container)) { mkdir $Destination | Out-Null }
		
		# if $Destination does not exist, it will be created
		$shell.Namespace($Destination).CopyHere($zipShell.Items(), $copyFlags);
        
		# NOTE: On windows 10, the process went "sync"
        # The Copy (i.e. unzip) operation is asynchronous, so wait until it is complete before continuing. 
		# That is, sleep until the Destination Directory has the same number of files as the Zip file.
		$unzipItemCount = (Get-ChildItem -Path $Destination -Recurse -Force).Count
		while ($unzipItemCount -lt $zipItemCount) {
			Write-Indented "$unzipItemCount of $zipItemCount items..."
			Start-Sleep -Milliseconds 3000
			$unzipItemCount = (Get-ChildItem -Path $Destination -Recurse -Force).Count
		}
		
		if ($Exclude) {
			gci $Destination -Recurse | 
				Write-Header "Removing Excluded Files..."
				? { 
					foreach($excludeItem in $Exclude) { 
						if ($_.FullName -like "*$excludeItem") { return $true } 
					}
					return $false 
				} |
				% {
					if (Test-Path $_) { # in case it were a file and the parent folder had been deleted by a prior iteration
						Write-Indented $_.FullName
						Remove-Item $_ -Force -Recurse
					}
				}
				Write-Footer "OK"
		}
		Write-Footer "OK"
    }
}
#cls; Extract-ZipFile "C:\Temp\dm\DesktopModules.zip" "C:\Temp\dm"; exit

#endregion General - Win Explorer Handling Zip Files


#region Xml Files
Function Update-ConfigFile {
#Update-ConfigFile -Path $Path -NodeXPath $NodeXPath -Attribute $Attribute -Value $Value
Param(
[Parameter(Mandatory=$true)]$Path,
[Parameter(Mandatory=$true)]$NodeXPath,
[Parameter(Mandatory=$true)]$Attribute,
[Parameter(Mandatory=$true)]$Value
)
	$doc = (Get-Content $Path -Encoding UTF8) -as [Xml]
	$root = $doc.DocumentElement

	$node = $root.SelectSingleNode($NodeXPath)
	if (-not $node) {
		$names = $NodeXPath -split '/'
		$node = $root
		foreach ($name in $names) {
			#if ($node.$name) {
			if (Get-Member -InputObject $node -Name $name -MemberType Properties) {
				$node = $node.$name -As [Xml.XmlElement]
			}
			else {
				$isDirty = $true
				$item = $doc.CreateElement($name)
				$node = $node.AppendChild($item)
			}
		}
	}
	

	if ($Attribute) { 
		$Value = "$Value" # to-string
		
		#if ($currentValue -eq $null) { 
		if (-not (Get-Member -InputObject $node -Name $Attribute -MemberType Properties)) {
			$isDirty = $true
			$node.setAttribute($Attribute, $Value)
		}
		else {
			$currentValue = $node.$Attribute
			if ($currentValue -ne $Value) { 
				$isDirty = $true
				$node.$Attribute = $Value
			}
		}
	}

	if ($Attribute) {
		Write-Indented ( "{0}/@{1}: '{2}' [{3}]" -f $NodeXPath, $Attribute, $Value, (&{if ($isDirty) {"UPDATED"} else {"UNCHANGED"}}) )
	}
	else {
		Write-Indented ( "{0}: '{1}' [{2}]" -f $NodeXPath, $Value, (&{if ($isDirty) {"UPDATED"} else {"UNCHANGED"}}) )
	}
	if ($isDirty) { $doc.Save($Path) }
}
#endregion Xml Files

##endregion Functions

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------

FixBug_PowerShellv2
FillGaps_Powershellv2
