#requires -Version 4.0
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Funciones avanzadas para interaccion con el TFS (Check in, Check out, etc)
#>
#if ($Script:TfsFunctionsLoaded) { "TFS Functions Already Loaded"; return } else { $Script:TfsFunctionsLoaded = $true }


#region Acciones TFS
Function Add-TFS {
<#
.SYNOPSYS
  Marca para agregar archivos o carpetas al TFS
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	DoAction-TFS "add" $Paths
}

Function Get-TFS {
<#
.SYNOPSYS
  Obtiene ultima version del TFS
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	DoAction-TFS "get" $Paths
}

Function Undo-TFS {
<#
.SYNOPSYS
  Deshace cambios del TFS
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	DoAction-TFS "undo" $Paths
}

Function Checkout-TFS {
<#
.SYNOPSYS
  Desprotege para editar archivos del TFS
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	DoAction-TFS "checkout" $Paths
}

Function Delete-TFS {
<#
.SYNOPSYS
  Marca para borrar archivos del TFS
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	DoAction-TFS "delete" $Paths
}

Function Move-TFS {
<#
.SYNOPSYS
  Sinonimo de Move-TFS
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$OldPath,
	[Parameter(Mandatory=$true)]
	[string]$NewPath
)
	Rename-TFS $OldPath $NewPath
}

Function Rename-TFS {
<#
.SYNOPSYS
  Cambia el nombre o la ruta de acceso de un archivo o carpeta. Puede usar el 
comando rename o el alias move para mover un archivo o carpeta a una nueva ubicación.

tf rename [/lock:(none|checkout|checkin)] [/login:nombreUsuario,[contrase±a]]
          elementoAntiguo elementoNuevo
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$OldPath,
	[Parameter(Mandatory=$true)]
	[string]$NewPath,
	[Parameter(Mandatory=$false)]
	[ref][string]$OutNewPath
)
	# si el path nuevo es relativo, usar el mismo folder padre del archivo original
	if ($NewPath -notmatch '^(\$|[A-Z]:|\\)') { # ruta de servidor. Ej: $/Zeus/Front/...
		# ruta de servidor tfs. Ej: $/Zeus/Front/...
		if ($OldPath -match '^\$') { $NewPath = (Join-Path (Split-Path $OldPath -Parent) $NewPath) -replace '\\','/' }
		# ruta de cliente tfs. Ej: C:\TFS\Zeus\Front\... o \\Servidor\RutaCompatirda\folder\...
		elseif ($OldPath -match '^([A-Z]:|\\)') { $NewPath = Join-Path (Split-Path $OldPath -Parent) $NewPath }
		else { throw "Debe especificar una ruta absoluta: '$OldPath'" }
	}

	DoAction-TFS "rename" $OldPath -NewPath $NewPath
	If ($OutNewPath) {
		$OutNewPath.Value = $NewPath
	}
}

Function CheckIn-TFS {
<#
.SYNOPSYS
  Permite proteger cambios pendientes al servidor

.DESCRIPTION
  Confirma los cambios pendientes en el Área de trabajo actual o en un conjunto
  de cambios aplazados existente en el control de versiones de Team Foundation.

  tf checkin [/author:nombre del autor] [/comment:("comentario"|@commentfile)]
           [/noprompt] [/notes:("Nombre de la nota"="texto de la nota"|@notefile)]
           [/override:(motivo|@reasonfile)] [/recursive] [/saved] [/validate]
           [elemento] [/bypass] [/force] [/noautoresolve]  
           [/login:nombreUsuario,[contrase±a]] [/new]
         
  tf checkin /shelveset:nombreConjuntoCambiosAplazados
           [;propietarioConjuntoCambiosAplazados][/bypass]][/noprompt[/login:nombreUsuario,[contrase±a]]
           [/collection:urlColecci¾nProyectosEquipo][/author:nombre del autor] [/force]
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$Comment,
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	DoAction-TFS "checkin" $Paths -ExtraParams "`"/comment:$Comment`""
}

Function Merge-TFS {
<#
.SYNOPSYS
  Permite combinar cambios de archivos entre branches
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$SourceBranch,
	[Parameter(Mandatory=$true)]
	[string]$TargetBranch,
	[Parameter(Mandatory=$true)]
	[string[]]$Paths,
	[Parameter(Mandatory=$false)]
	[string]$PushLocation,
	# For a selective merge, this option specifies the range that should be merged into the destination. 
	# For a catch-up merge, this parameter specifies the version before which all un-merged changes should be merged.
	# For a selective merge, the version range denotes the beginning and end points of the set of changes to be merged. 
	# For example, if you attempt to merge version 4~6, the changesets 4, 5, and 6 are merged.
	[Parameter(Mandatory=$false)]
	[string]$Version,
	# Matches the source item specification in the current directory and any subfolders.
	[Switch]$Recursive = $false,
	# Ignores the merge history and merges the specified changes from the source into the destination, even if some or all these changes have been merged before.
	[Switch]$Force = $false,
	# Prints a list of all changesets in the source that have not yet been merged into the destination. The list should include the changeset ID that has not been merged and other basic information about that changeset.
	[Switch]$Candidate = $false,
	# Does not perform the merge operation, but updates the merge history to track that the merge occurred. This discards a changeset from being used for a particular merge.
	[Switch]$Discard = $false,
	# Shows a preview of the merge.
	[Switch]$Preview = $false,
	# Performs a merge without a base version. That is, allows the user to merge files and folders that do not have a merge relationship. After a baseless merge, a merge relationship exists, and future merges do not have to be baseless.
	[Switch]$Baseless = $false,
	# Suppresses any prompts for input from you.
	[Switch]$NoPrompt = $false
)
	# esto es usado generalmente cuando se pasan rutas de server (ej: $/Zeus/...) y no rutas de cliente (Ej: C:\TFS\Zeus\...)
	if ($PushLocation) { Set-Location $PushLocation }
	
	$ExtraParams = @()
	if ($Version) { $ExtraParams += "/version:$Version" }
	if ($Recursive) { $ExtraParams += "/recursive" }
	if ($Force) { $ExtraParams += "/force" }
	if ($Candidate) { $ExtraParams += "/candidate" }
	if ($Discard) { $ExtraParams += "/discard" }
	if ($Preview) { $ExtraParams += "/preview" }
	if ($Baseless) { $ExtraParams += "/baseless" }
	if ($NoPrompt) { $ExtraParams += "/noprompt" }
	
	DoAction-TFS "merge" $Paths $SourceBranch $TargetBranch $ExtraParams
	
	if ($PushLocation) { Pop-Location }
}
#endregion

#region Mixtos
Function AddAndCheckIn-TFS {
<#
.SYNOPSYS
  Agrega y proteger inmediatamente archivos especificados
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$Comment,
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	Add-TFS $Paths
	CheckIn-TFS $Comment $Paths
}

Function RenameAndCheckIn-TFS {
<#
.SYNOPSYS
  Renombra y proteger inmediatamente archivos especificados
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$Comment,
	[Parameter(Mandatory=$true)]
	[string]$OldPath,
	[Parameter(Mandatory=$true)]
	[string]$NewPath
)
	$OutNewPath = ""
	Rename-TFS $OldPath $NewPath ([ref]$OutNewPath)
	CheckIn-TFS $Comment $OutNewPath
}

Function DeleteAndCheckIn-TFS {
<#
.SYNOPSYS
  Borrar y proteger inmediatamente archivos especificados
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$Comment,
	[Parameter(Mandatory=$true)]
	[string[]]$Paths
)
	Delete-TFS $Paths
	CheckIn-TFS $Comment $Paths
}
#endregion

#region Core
Function Init-TFS {
	$VsCommons = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE",  # 2015
		 		 "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE",  # 2013
		 		 "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE",  # 2012
				 "C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE"   # 2010
	
	Foreach ($VsCommon in $VsCommons) {
		if (Test-Path "$VsCommon\TF.exe") { $tfPath = "$VsCommon\TF.exe"; break; }
	}
	if (!$tfPath) { throw "Cannot find VStudio TFS Command-Line Utility TF.exe"; }
	
	Set-Alias tf $tfPath -Scope "Script"
}

Function ResolveBranchName-TFS {
<#
.SYNOPSYS
  Resuelve el nombre del folder del branch
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$false)]
	[string]$BranchHint
)
	switch ($BranchHint)
    {
        "main" { "1_Main" }
        "test" { "2_Test" }
        "stage" { "3_Stage" }
		default { $BranchHint }
    }
}

Function DoAction-TFS {
<#
.SYNOPSYS
  Funcion interna utilizada en todas las otras
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string]$tfsAction,
	[Parameter(Mandatory=$true)]
	[string[]]$Paths,
	[Parameter(Mandatory=$false)]
	[string]$SourceBranch,
	[Parameter(Mandatory=$false)]
	[string]$TargetBranch,
	[Parameter(Mandatory=$false)]
	[string[]]$ExtraParams = @(),
	[Parameter(Mandatory=$false)]
	[string[]]$NewPath
)
	$bulkActions = "checkin", "delete", "undo"

	if ($tfsAction -eq "merge") {
		if (!$SourceBranch -or !$TargetBranch) {
			throw "El comando [merge] requiere valores para los parametros [SourceBranch] y [TargetBranch]"
		}
		$SourceBranch = ResolveBranchName-TFS $SourceBranch
		$TargetBranch = ResolveBranchName-TFS $TargetBranch
	}

	if ($ExtraParams -eq $null) { $ExtraParams = @() } 

	<#$Credential = Ask-TfsCredential
	if ($Credential) {
		$user = $Credential.UserName
		$password = $Credential.GetNetworkCredential().password
		#TODO: Revisar que esta variable sirva para el servidor remoto desde el equipo de Jaime
		$ExtraParams += "/login:$user,$password" 
	}#>

	$Paths = $Paths -replace '[\r\n\t]+', ' '
	$delimiters = 'C:', '\$/';
	$separator = $delimiters -join "|"
	
	# verifica que no se pase más de un archivo a la vez
	if ($tfsAction -eq "rename" -and $Paths.Length -gt 1) {
		throw "Solo se permite renombrar un archivo a la vez";
	}
	
	foreach ($fullPath in $Paths) {
		# los "()" en la expresion del split forzan a que los delimitadores se incluyan en el resultado como entradas independientes
		[string[]]$Items = $fullPath -split "($separator)"
		
		# verifica que no se pase más de un archivo a la vez (3 items: el primer item vacío, el item con el separador, el archivo)
		if ($tfsAction -eq "rename" -and $Items.Length -gt 3) {
			throw "Solo se permite renombrar un archivo a la vez";
		}
	
		# cada delimitador se crea como una entrada independiente
		# tambien la primera entrada puede estar vacia porque está antes del delimitador
		$totalFiles = ($Items.Length - 1) / 2
		$i = 0
		
		$bulkActionFiles = @()
		$priorDelimiter = ""
		foreach ($item in $Items) {
			# si la entrada es vacia o espacios, ignorar
			if (!$item -or [string]::IsNullOrWhiteSpace($item)) { continue }
			
			# utilizar el delimitador especifico de cada entrada
			if ($item -match $separator) {
				$priorDelimiter = $item
				continue
			}

			# ignore empty entries
			$path = "$priorDelimiter$($item.Trim())"
			if ($tfsAction -eq "rename") { $tfParamRecursive = "" }
			else {
				$tfParamRecursive = &{if (Test-Path $path -PathType Container) { "/recursive " } else { "" } }
			}
			
			if ($bulkActions -contains $tfsAction) {
				# add double quotes if file name contains blanks
				$bulkActionFiles += &{if ($path -match " ") { "`"$path`"" } else { $path } }
				continue
			}

			$i++
			if ($totalFiles -gt 1) { Write-Host "[$i/$totalFiles] " -NoNewline }
			
			if ($tfsAction -eq "merge") {
				if ($path -notmatch "\b$SourceBranch\b") {
					throw "Archivo no esta dentro del branch '$SourceBranch': '$targetPath'"
				}
				$targetPath = $path -replace "\b$SourceBranch\b","$TargetBranch"
			}
			elseif ($tfsAction -eq "rename") {
				$targetPath = $NewPath
			}
			else {
				$targetPath = ""
			}
			
			# TODO: Crear una funcion para encerrar en comillas si el archivo tiene espacios
			$path = &{if ($path -match " ") { "`"$path`"" } else { $path } }
			if ($targetPath) {
				$targetPath = &{if ($targetPath -match " ") { "`"$targetPath`"" } else { $targetPath } }
			}
			
			<# tf help
				merge 
				[/recursive] [/force] [/candidate] [/discard] 
				[/version:versionspec] [/lock:none|checkin|checkout] [/preview] 
				[/baseless] [/nosummary] [/noimplicitbaseless] [/conservative] [/format:(brief|detailed)] [/noprompt] [/login:username,[password]] source destination
			#>
			Try {
				# invoca
				tf $tfsAction $tfParamRecursive $ExtraParams $path $targetPath
				# DEBUG: uncomment to see actual parameters as received by the target tool
				#echoargs $tfsAction $tfParamRecursive $ExtraParams $path $targetPath
			}
			Catch {
				$exceptionMsg = $_;
				# undo saca error cuando no hay nada que deshacer
				if (-not ($tfsAction -eq "undo" -and $exceptionMsg -like "*No se han encontrado cambios pendientes*"))
				{ throw }
				if (-not ($tfAction -eq "merge" -and $exceptionMsg -like 'Conflict (merge, edit): *')) 
				{ throw }
				# mostrar mensaje en la consola
				Write-Host $exceptionMsg -ForegroundColor Magenta
			}
		}
		
		
		<# tf checkin help
		   https://goo.gl/T6A7Nx
		   tf checkin [/author:author name] [/comment:("comment"|@comment file)] 
			[/noprompt] [/notes:("Note Name"="note text"|@notefile)] 
			[/override:(reason|@reasonfile)] [/recursive] [/saved] [/validate] [itemspec] [/bypass] [/force] [/noautoresolve]  [/login:username,[password]] [/new]
		#>
		if ($bulkActions -contains $tfsAction) {
			if ($bulkActionFiles.Count -eq 0) { throw "No files to $tfsAction" }
			tf $tfsAction $tfParamRecursive $ExtraParams $bulkActionFiles
		}
		

	}
}
#endregion

#region Mixtos para Merge
Function MergeAndCheckInFilesToBothTestAndMain-TFS {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$files
	)
	Merge-TFS "Stage" "Test" $files
	$files = $files -replace "\b3_Stage\b", "2_Test"
	CheckIn-TFS "Merged from Stage" $files

	Merge-TFS "Test" "Main" $files
	$files = $files -replace "\b2_Test\b", "1_Main"
	CheckIn-TFS "Merged from Test" $files
}
#endregion

#region Aplicable a todos los Branches
Function DeleteFromAllBranches-TFS {
	Param([string]$file)
	"1_Main","2_Test","3_Stage" | % {
		$file = $file -f $_
		"$($_):" + [IO.Path]::GetFileName($file)
		if (Test-Path $file) {
			DeleteAndCheckIn-TFS "Removed" $file
		} else {
			"NOT FOUND"
		}
	}
}

Function RenameFromAllBranches-TFS {
	Param([string]$file, [string]$newfile)
	"1_Main","2_Test","3_Stage" | % {
		$file = $file -f $_
		"$($_):" + [IO.Path]::GetFileName($file)
		if (Test-Path $file) {
			RenameAndCheckIn-TFS "Renamed" $file $newfile
		}
		else { "NOT FOUND" }
	}
}
#endregion

#-----------------------------------------------------------[Setup]------------------------------------------------------------
Init-TFS


