#requires -version 4.0
<# 1. Agregar "enter" al final de cada archivo si le falta.
# 2. Verificar si los archivos tienen al menos 3 GOs en cada SP
# 3. Verificar que las "ñ"s se generen bien
# 4. Verificar que no haya archivos que no tenga el numero (0-9) como sufijo.
# 5. Join todos los archivos


# Modified by F.RICHARD August 2010
# add comment + more BOM
# http://unicode.org/faq/utf_bom.html
# http://en.wikipedia.org/wiki/Byte_order_mark
#
#>
Function Get-FileEncoding {
[CmdletBinding()] 
Param (
	[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] 
	[string]$Path
)

	[byte[]]$byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -LiteralPath $Path
	#Write-Host Bytes: $byte[0] $byte[1] $byte[2] $byte[3]

	$encoding = ""

	if (-not $byte.Length) { return "ANSI" }

	 # EF BB BF (UTF8)
	 if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
	 { $encoding = 'UTF8' }
	 
	 # FE FF  (UTF-16 Big Endian)
	 elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
	 { #$encoding = 'Unicode UTF-16 Big Endian' 
		$encoding = 'UCS-2 Big Endian' 
	  }
	 
	 # FF FE  (UTF-16 Little Endian)
	 elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
	 { 
	 #$encoding = 'Unicode UTF-16 Little Endian' 
	 $encoding = 'UCS-2 Little Endian' 
	 }
	 
	 # 00 00 FE FF (UTF32 Big Endian)
	 elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
	 { $encoding = 'UTF32 Big Endian' }
	 
	 # FE FF 00 00 (UTF32 Little Endian)
	 elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0)
	 { $encoding = 'UTF32 Little Endian' }
	 
	 # 2B 2F 76 (38 | 38 | 2B | 2F)
	 elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) )
	 { $encoding = 'UTF7'}
	 
	 # F7 64 4C (UTF-1)
	 elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c )
	 { $encoding = 'UTF-1' }
	 
	 # DD 73 66 73 (UTF-EBCDIC)
	 elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73)
	 { $encoding = 'UTF-EBCDIC' }
	 
	 # 0E FE FF (SCSU)
	 elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff )
	 { $encoding = 'SCSU' }
	 
	 # FB EE 28  (BOCU-1)
	 elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 )
	 { $encoding = 'BOCU-1' }
	 
	 # 84 31 95 33 (GB-18030)
	 elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33)
	 { $encoding = 'GB-18030' }
	 
	 else
	 { $encoding = 'ANSI' }
 
	return $encoding
}

Function Set-FileEncoding([Parameter(Mandatory=$true)][string]$sql, [string]$target = $null, [string]$Encoding = "ANSI") {
	$fileEncoding = &{if ($Encoding -eq "ANSI") { "Default" } else { $Encoding } }

	$thisfile = $sql
	$tempfile = $thisfile + '.tmp'
	# convierte el "encoding" del archivo a ASCII y lo escribe en un archivo temporal
	Get-Content -LiteralPath $thisfile | Out-File -LiteralPath $tempfile -Encoding $fileEncoding
	
	# borrar el archivo antiguo y lo sobrescribe con el archivo con el "encoding" correcto
	if ($target) { $thisfile = $target }
	
	if (Test-Path -LiteralPath $thisfile) { Remove-Item -LiteralPath $thisfile -Force }
	Rename-Item -LiteralPath $tempfile $thisfile
	return $Encoding
}

Function Check-FileEncoding([Parameter(Mandatory=$true)][string]$Path, [string]$OtherThanEncoding = "ANSI", $FileExtension = ".sql") {
	Get-ChildItem $Path -Recurse | 
		Where {$_.extension -eq $FileExtension} | 
		Select @{n='FullName';e={$_.FullName<#.replace($path+"\", '')#>}}, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | 
		Where {$_.Encoding -ne $OtherThanEncoding}
}

Function Fix-FileEncoding([Parameter(Mandatory=$true)][string]$Path, [ValidateNotNull()][scriptblock]$BeforeScript, $NewEncoding = "ANSI") {
	$files = Check-FileEncoding $Path -OtherThanEncoding $NewEncoding
	
	foreach ($file in $files) {
		try {
			& $BeforeScript $file.FullName
		}
		catch {
			New-Object PSObject -Property @{
				RelativeName=$file.FullName.Replace($Path, '')
				Encoding_Before=$file.Encoding
				Encoding_After="ERROR"
				}
			Write-Host $_.Exception.Message -ForegroundColor Red
			continue
		}

		#Select  @{n='FullName'; e={$file.FullName<#.Replace($Path+'\', '')#>}}, 
		#		@{n='Encoding_Before'; e={$file.Encoding}}, 
		#		@{n='Encoding_After'; e={Set-FileEncoding $file.FullName}}
		New-Object PSObject -Property @{
			RelativeName=$file.FullName.Replace($Path, '')
			Encoding_Before=$file.Encoding
			Encoding_After=(Set-FileEncoding $file.FullName)
			}
	}
}
