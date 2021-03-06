#requires -Version 4.0
#requires -RunAsAdministrator
#
#if ($Script:SymLinkFunctionsLoaded) { "SymLink Functions Already Loaded"; return } else { $Script:SymLinkFunctionsLoaded = $true }


#region Functions
Function Init-SymLink {
	Try {
		$null = [WinAPI.SymbolicLink]
	}
	Catch {
		Add-Type -MemberDefinition @"
	private const int FILE_SHARE_READ = 1;
	private const int FILE_SHARE_WRITE = 2;

	private const int CREATION_DISPOSITION_OPEN_EXISTING = 3;
	private const int FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;

	//TODO: not working
	[DllImport("kernel32.dll")]
	public static extern bool CreateSymbolicLink(string lpSymlinkFileName, string lpTargetFileName, int dwFlags);

	[DllImport("kernel32.dll", EntryPoint = "GetFinalPathNameByHandleW", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern int GetFinalPathNameByHandle(IntPtr handle, [In, Out] StringBuilder path, int bufLen, int flags);

	[DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern SafeFileHandle CreateFile(string lpFileName, int dwDesiredAccess, int dwShareMode,
	IntPtr SecurityAttributes, int dwCreationDisposition, int dwFlagsAndAttributes, IntPtr hTemplateFile);
"@ `
		-Name SymbolicLink -NameSpace WinAPI -UsingNamespace System.Text, Microsoft.Win32.SafeHandles, System.ComponentModel
	}
}

Function Test-SymLink {
[CmdLetBinding(SupportsShouldProcess=$True)]
Param (
    [Parameter(Mandatory=$true)]
    [string]$SymPath
)
	if (-not (Test-Path $SymPath)) { return $false }
	
	#$file = Get-Item $SymPath -Force -ea 0
	#return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
	$item = Get-Item $SymPath
	return $item.LinkType -eq "SymbolicLink"
}

Function List-SymLink {
[CmdLetBinding(SupportsShouldProcess=$True)]
Param (
    [Parameter(Mandatory=$true)][string[]]$SymPath,
	[Switch]$IncludeFileSymLink = $false
)
	$cacheList = @()
	foreach ($item in $SymPath) {
		Get-ChildItem $item -Recurse -Directory:(!$IncludeFileSymLink) -ErrorAction SilentlyContinue | 
		% {
			$fullPath = $_.FullName
		#Write-Host "[$fullPath]" -ForegroundColor Blue
			$withinAnotherSymLink = $false
			
			foreach ($cachedItem in $cacheList) { if ($fullPath.StartsWith($cachedItem)) { $withinAnotherSymLink = $true; break } }
			
			if (-not $withinAnotherSymLink) {
				if (Test-SymLink $fullPath) { 
					$cacheList += $fullPath # add to the cached list
					$fullPath # return
				}
			}
		}
	}
}

Function Delete-SymLink {
#[CmdLetBinding(SupportsShouldProcess=$True)]
Param([string]$SymPath)
	Process {
		if (-not $SymPath) { $SymPath = [string]$Input }
		#
		if (-not $SymPath) { throw "[Delete-SymLink] You must specify a valid path." }
		if (-not (Test-Path $SymPath)) { return }
		if (-not (Test-SymLink $SymPath)) { throw "Path is not a Symbolic Link: '$symlinkPath'" }
		
		# an alternative that behaves consistently
		[IO.Directory]::Delete($SymPath, $true) | Out-Null
	}
}

Function Create-SymLink {
<#
.SYNOPSIS
    Creates a Symbolic link to a file or directory

.DESCRIPTION
    Creates a Symbolic link to a file or directory as an alternative to mklink.exe

.PARAMETER Path
    Name of the path that you will reference with a symbolic link.

.PARAMETER SymName
    Name of the symbolic link to create. Can be a full path/unc or just the name.
    If only a name is given, the symbolic link will be created on the current directory that the
    function is being run on.

.EXAMPLE
	Create-SymLink -Path "C:\temp\realfolder" -SymName "C:\temp\symfolder"

    Description
    -----------
    Creates a symbolic link to 'realfolder' folder that resides on 'C:\temp\symfolder'.

.EXAMPLE
	Create-SymLink -Path "C:\temp\realfolder\AmazonSendEmails.sln" -SymName "C:\temp\MyOtherSolution.sln"

    Description
    -----------
    Creates a symbolic link to document.txt file under the current directory called SomeDocument.
#>
[CmdLetBinding(SupportsShouldProcess=$True)]
Param (
	[Parameter(Mandatory=$true)][string]$Path, 
	[Parameter(Mandatory=$true)][string]$SymPath,
	[Switch]$Force = $false,
	[Switch]$ReplaceExistingFileOrFolder = $false
)
	# resolves to a full path always
	$Path = [IO.Path]::GetFullPath($Path)
	$SymPath = [IO.Path]::GetFullPath($SymPath)
	
	if (-not (Test-Path $Path)) { throw "Path does not exist: '$Path'" }
	
	# if symbolic link already exist
	if (Test-Path $SymPath) { 
		$isSymLink = Test-SymLink $SymPath
		if (-not $isSymLink) { 
			# if it is a file/folder and confirm you want to remove it
			if (-not $ReplaceExistingFileOrFolder) { throw "Target already exists and won't be deleted as it's not a Symbolic Link (Specificy '-ReplaceExistingFileOrFolder' to force replace existing file): '$SymPath'"  }
		}

		if (-not $Force) { throw "Target already exists (specify '-Force' to overwrite): '$SymPath'" }
		
		# check if it is already mapped to the same target path
		$currentTarget = GetTarget-SymLink $SymPath
		if ($Path -eq $currentTarget) {
			return "OK"
		}
		
		# remove link/file
		if ($isSymLink) { Delete-SymLink $SymPath } else { Remove-Item $SymPath -Force -Recurse }
	}
	
	# create parent folder if it does not exist and Force=True
	$parentFolder = Split-Path $SymPath -Parent
	if (-not (Test-Path $parentFolder)) {
		if ($Force) {
			md $parentFolder | Out-Null 
		}
		else { throw "Target parent folder does not exist: '$parentFolder'" }
	}
	
    # check if symbolic link is a directory
    $Flags = @{ File = 0; Directory = 1 }
	$symType = &{ if ((Get-Item $Path).PSIsContainer) { "Directory" } else { "File" } }
	
    # create symbolic link
	If ($PScmdlet.ShouldProcess($Path, 'Create Symbolic Link')) {
        $success = [WinAPI.SymbolicLink]::CreateSymbolicLink($SymPath, $Path, $Flags[$symType])
		If ($success) {
            return "Updated"
        }
		else { throw "Unable to create symbolic link '$SymPath'" }
    }
}

Function GetTarget-SymLink($SymPath) {
	if (-not (Test-SymLink $SymPath)) { return }
	#[WinAPI.SymbolicLink]::GetSymbolicLinkTarget((Get-Item $SymPath))
	return (Get-Item $SymPath).Target
}

cls
Init-SymLink
$dir = "C:\inetpub\DotNetNukeTripleD\DesktopModules\noexiste"
#Create-SymLink -SymName "C:\inetpub\DotNetNukeTripleD\DesktopModules\noexiste" -Path "C:\TFS1\TripleD\Trunk\Common\noexiste"
#GetTarget-SymLink $dir
#$item = Get-Item $dir
#$item | gm
#Test-Path $dir
#Test-SymLink $dir
#$dir | Delete-SymLink
#Delete-SymLink $dir
exit

Function UnitTest-SymLink($Path, $SymPath) {
	Delete-SymLink -SymName $SymPath
	Create-SymLink -Path $Path -SymName $SymPath
	"Target of '$SymPath': {0}" -f (GetTarget-SymLink $SymPath)
	"Exists '$SymPath': {0}" -f (Test-SymLink $SymPath)
	Delete-SymLink -SymName $SymPath
}
#endregion

#init
Init-SymLink

#UNIT-TESTING
#cls; UnitTest-SymLink -Path "C:\temp\realfolder" -SymName "C:\temp\symfolder"; exit
#cls; UnitTest-SymLink -Path "C:\temp\realfolder\AmazonSendEmails.sln" -SymName "C:\temp\MyOtherSolution.sln"; exit
