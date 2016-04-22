#Requires -Version 4.0
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Corrige plantillas de CodeOnTime para generar los paquetes correctamente.

.DESCRIPTION
  Los cambios a realizar al generar paquetes de DNN desde COT (CodeOnTime) son los siguientes:
  
  * Excluir DLLs de componentes de Zeus (que empiecen con 'Zeus.**' dentro del paquete a instalar en COT
  * Excluirlas igualmente del archivo de manifiesto del modulo (*.dnn)
  * Que los paquetes sean generados con la nueva extensión ZIP que es el nuevo estándar para paquetes (en vez de ".resources")

  La plantilla de COT a modificar es la siguiente:
  
	  [Code OnTime\Library\DotNetNuke Factory\CodeOnTime.Project.xml]
  
  Esto lo hace en todos los branches donde se haya configurado COT (CodeOnTime). 
  Si se crea un nuevo branch, será necesario correr este script nuevamente. 
  Por defecto, intenta recorre todos los branches y detecta donde no se ha aplicado la correcion y la hace.
  Crea un archivo de backup ".00#.bak" cada vez que realice un cambio. 
  Si ya se aplicaron los cambios, sale sin crear archivos de backups innecesarios o sobreescribir archivos existentes.

.NOTES
  Version:        1.0
  Author:         Zeus Tecnología
  Creation Date:  2015-04-03
  Purpose/Change: Corregir generación de Paquetes para DNN desde CodeOnTime
#>
Trap { 
	$ErrorActionPreference = "Continue"; 
	Write-Host $_.Exception.Message -ForegroundColor Red
	if ($_.Exception.Message -ne "ScriptHalted") {
		Write-Host $_.ScriptStackTrace -ForegroundColor Red
	}
	Exit 1; 
}


#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# permite la ejecución de scripts en powershell
if ((Get-ExecutionPolicy) -ne "Bypass") {
	Set-ExecutionPolicy Bypass -Force
}

# Set the output level to verbose
$global:VerbosePreference = "Continue"
#Set Error Action to Stop on Error
$global:ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
$global:MainScriptRoot = &{ if ($PSScriptRoot) { $PSScriptRoot } else { (Resolve-Path .).Path } };
$global:MainScriptName = &{ if ($MyInvocation.MyCommand.Name) { $MyInvocation.MyCommand.Name } else { "Remove_ExtraDLLs_From_DnnPackages.ps1" } };
$global:MainScriptName = [IO.Path]::GetFileNameWithoutExtension($global:MainScriptName)

#Script Version
$global:ScriptVersion = "1.0"


$global:DnnAlias = "zeusdnn";
$global:TfsBranch = $tfsBranch;


#-----------------------------------------------------------[Functions]------------------------------------------------------------

# Dot Source required Function Libraries

Function Install-Prerrequisites {
<#
.SYNOPSYS
  instala Administrador de Paquetes de Windows y Actualiza Powershell a v 4.0
#>
	if (-not (Get-Command choco -CommandType Application -ErrorAction SilentlyContinue)) {
		Write-Host "Instalando Administrador de Paquetes de Windows..."
		iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
		$env:Path += ";%ALLUSERSPROFILE%\chocolatey\bin";
		Set-Alias choco %ALLUSERSPROFILE%\chocolatey\bin\choco.exe
	}

	if ($PSVersionTable.PSVersion.Major -lt 4) {
		Write-Host "Instalando Update para Powershell..."
		cinst powershell -y
		Write-Warning "REINICIE EL COMPUTADOR ANTES DE CONTINUAR";
		Exit 2;
	}
}

Function using-ps {
<#
.SYNOPSIS
	Simulando la sentencia "using" de C# en Powershell.
	http://blogs.msdn.com/b/powershell/archive/2009/03/12/reserving-keywords.aspx
#>
    param($obj, [scriptblock]$sb)             
            
    try {             
        & $sb             
    } finally {             
        if ($obj -is [IDisposable]) {             
            $obj.Dispose()             
        }             
    }             
}   


Function Fix-CodeOnTime_DnnPackageSettings {
<#
.SYNOPSIS
  Forza CodeOnTime (COT) a excluir assemblies de dlls de Zeus (como por ejemplo: Zeus.Arquitectura) de los paquetes de DNN
#>
Param(
	[Parameter(Mandatory=$true)]
	[string]$parentFolderForCodeOnTime
)
	#---------------------------------------------------------------------------
	# resolves path under current branch for CodeOnTime template to update
	#---------------------------------------------------------------------------
	$ProjectPathXml = Join-Path $parentFolderForCodeOnTime "Code OnTime\Library\DotNetNuke Factory\CodeOnTime.Project.xml"
		
	#validate template exists
	if (-not (Test-Path $ProjectPathXml)) {
		Write-Host $ProjectPathXml
		Write-Host "`tADVERTENCIA: La plantilla no existe en este carpeta." -ForegroundColor Magenta
		Continue
	}
	else {
		Write-Host $ProjectPathXml
	}
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --


	#---------------------------------------------------------------------------
	# Load xml
	#---------------------------------------------------------------------------
	# get a backup file with a non-existing name
	$i = 0; Do { $i++; $backup = $ProjectPathXml.Replace(".xml", ("_bak_{0:000}.xml" -f $i)) } While (Test-Path $backup)
	$isDirty = $false
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

	
	#---------------------------------------------------------------------------
	# Load xml and initilization
	#---------------------------------------------------------------------------
	# to preserve new lines on attribute values
	#$xml = New-Object xml
	#$xml.psbase.PreserveWhitespace = $true

	# Load while preserve setting
	$xml = New-Object System.Xml.XmlDocument
	$xml.PreserveWhitespace = $true
	$xml.Load($ProjectPathXml)
	# ALTERNATIVE:
	#[xml]$xml = Get-Content $ProjectPathXml

	# add needed xml namespaces
	$ns = New-Object Xml.XmlNamespaceManager $xml.NameTable
	$ns.AddNamespace("ns", "http://www.codeontime.com/2008/code-generator")
	
	# root xpath for all searches
	$xpathPublish = "/ns:project/ns:actions/ns:action[@name='Publish']/ns:load[@path='DataAquarium.Project.xml']"
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --


	
	#---------------------------------------------------------------------------
	# Exclude Zeus.** assemblies
	#---------------------------------------------------------------------------
	$xpath = "$xpathPublish/ns:load[@path='`$ProjectPath\Modules\bin']/ns:forEach"
	<# 		<load path="$ProjectPath\Modules\bin">
		        <forEach select="//file[@extension = '.dll' and not(
		                  starts-with(@loweredName,'dotnetnuke.') 
  Line to be added ==> or starts-with(@name,'Zeus.')
		               or starts-with(@name,'ClientDependency.')
		               or starts-with(@name,'CountryListBox.')
		               or starts-with(@name,'SharpZipLib.')
		               or starts-with(@name,'Telerik')
		               )]">
		          <copy input="$ProjectPath\Modules\Bin\{@path}" output="$Root\Publish\DotNetNuke Factory\$ProjectName\Package\bin\{@path}" />
		        </forEach>
	 #>
	$node = $xml.SelectSingleNode($xpath, $ns)
	if (-not ($node)) { throw "El XML no contiene un nodo para el XPATH: '$xpath'" }
	
	$CRLF = "`r`n"
	$lines = $node.select -split $CRLF
	
	# apply the change only once
	if ($($lines -like '*Zeus.*').Count -eq 0) {
		$isDirty = $true # a change was made
		# insert exception to exclude certain DLLs
		$list = [Collections.Generic.List[String]]$lines
		$list.Insert(2, "                   or starts-with(@name,'Zeus.')")
		#$list
		# <node select="..."
		$node.select = $list.ToArray() -join $CRLF
	}
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
	
	
	#---------------------------------------------------------------------------
	# BEGIN: Rename package name from ".resources" to ".zip"
	#---------------------------------------------------------------------------
	# Example:
	# <copy input="$Root\Publish\DotNetNuke Factory\$ProjectName\Package" output="$Root\Publish\DotNetNuke Factory\$ProjectName\{'$Namespace'}_{'$Version'}_Install.resources" mode="zip"/>
	$xpath = "$xpathPublish/ns:copy[@mode='zip']"
	$node = $xml.SelectSingleNode($xpath, $ns)
	if (-not ($node)) { throw "El XML no contiene un nodo para el XPATH: '$xpath'" }

	# apply change only once
	if ($node.output.EndsWith(".resources")) {
		$isDirty = $true # a change was made
		$node.output = $node.output.Replace(".resources", ".zip")
	}


	# Example:
    # <copy input="$Root\Publish\DotNetNuke Factory\$ProjectName\{'$Namespace'}_{'$Version'}_Install.resources" output="$HostPath\Install\Module"/>
	$xpath = "$xpathPublish/ns:copy[@output='`$HostPath\Install\Module']"
	$node = $xml.SelectSingleNode($xpath, $ns)
	if (-not ($node)) { throw "El XML no contiene un nodo para el XPATH: '$xpath'" }

	# apply change only once
	if ($node.input.EndsWith(".resources")) {
		$isDirty = $true # a change was made
		$node.input = $node.input.Replace(".resources", ".zip")
	}
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
	

	#---------------------------------------------------------------------------
	# Save changes back to file
	#---------------------------------------------------------------------------
	# if no changes made, return
	if (-not $isDirty) { 
		Write-Host "`tNOTA: YA ESTA CORREGIDO. NO SE HICIERON CAMBIOS."
		return 
	}
		
	# before changing file, create a backup file with a non-existing file name
	Copy-Item $ProjectPathXml $backup -Force

	$xwSettings = New-Object System.Xml.XmlWriterSettings
  	$xwSettings.Indent = $true
	$xwSettings.CheckCharacters = $false
	#$xwSettings.NewLineHandling = [Xml.NewLineHandling]::None

	# ALTERNATIVE 1: SAVE
	# Create an XmlWriter and save the modified XML document
  	using-ps ($xmlWriter = [Xml.XmlWriter]::Create($ProjectPathXml, $xwSettings)) {
	 	$xml.Save($xmlWriter)
	}
	$xml.Close

	# ALTERNATIVE 2: SAVE
	#$xml.Save($ProjectPathXml)
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
	

	#---------------------------------------------------------------------------
	# get back human-readable new lines on changed attribute with assembly names
	# NOTE: when saving, it inserts unicode values for CRLF on attribute value
	#---------------------------------------------------------------------------
	$contents = Get-Content $ProjectPathXml | % { 
		if ($_.Contains("forEach select=`"//file[@extension = '.dll'")) {
			$_.Replace("&#xD;&#xA;", "`r`n")
		}
		else {
			$_
		}
	}
	Set-Content -Path $ProjectPathXml -Value $contents -Encoding UTF8
	Write-Host "`tNOTA: CAMBIADO EXITOSAMENTE!"
	#-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
}

Function Install-Prerrequisites {
<#
.SYNOPSYS
  instala Administrador de Paquetes de Windows y Actualiza Powershell a v 4.0
#>
	if (-not (Get-Command choco -CommandType Application -ErrorAction SilentlyContinue)) {
		Write-Host "Instalando Administrador de Paquetes de Windows..."
		iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
		$env:Path += ";%ALLUSERSPROFILE%\chocolatey\bin";
		Set-Alias choco %ALLUSERSPROFILE%\chocolatey\bin\choco.exe
	}

	if ($PSVersionTable.PSVersion.Major -lt 4) {
		Write-Host "Actualizando a Powershell 4.0..."
		cinst powershell -y
		Write-Warning "REINICIE EL COMPUTADOR ANTES DE CONTINUAR";
		Exit;
	}
}

Function Initialize {
<#
.SYNOPSIS
  Configuracion de arranque
#>
	Install-Prerrequisites
}


#-----------------------------------------------------------[Loading]------------------------------------------------------------
Clear-Host
Initialize

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Fix-CodeOnTime_DnnPackageSettings  $PSScriptRoot

