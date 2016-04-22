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

	public static string GetSymbolicLinkTarget(string SymName)
	{
		SafeFileHandle directoryHandle = CreateFile(SymName, 0, 2, System.IntPtr.Zero, CREATION_DISPOSITION_OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, System.IntPtr.Zero);
		if(directoryHandle.IsInvalid)
		throw new Win32Exception(Marshal.GetLastWin32Error());

		StringBuilder path = new StringBuilder(512);
		int size = GetFinalPathNameByHandle(directoryHandle.DangerousGetHandle(), path, path.Capacity, 0);
		if (size<0)
		throw new Win32Exception(Marshal.GetLastWin32Error());
		// The remarks section of GetFinalPathNameByHandle mentions the return being prefixed with "\\?\"
		// More information about "\\?\" here -> http://msdn.microsoft.com/en-us/library/aa365247(v=VS.85).aspx
		if (path[0] == '\\' && path[1] == '\\' && path[2] == '?' && path[3] == '\\')
		 	return path.ToString().Substring(4);
		else
		 	return path.ToString();
	}
"@ `
		-Name SymbolicLink -NameSpace WinAPI -UsingNamespace System.Text, Microsoft.Win32.SafeHandles, System.ComponentModel
	}
}

Function Test-SymLink {
[CmdLetBinding(SupportsShouldProcess=$True)]
Param (
    [Parameter(Mandatory=$true)]
    [string]$SymName
)
	if (-not (Test-Path $SymName)) { return $false }
	
	$file = Get-Item $SymName -Force -ea 0
	return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

Function List-SymLink {
[CmdLetBinding(SupportsShouldProcess=$True)]
Param (
    [Parameter(Mandatory=$true)]
    [string[]]$SymName
)
	$cacheList = @()
	foreach ($item in $SymName) {
		Get-ChildItem $item -Recurse -Directory | 
		% {
			$fullPath = $_.FullName
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
[CmdLetBinding(SupportsShouldProcess=$True)]
Param([string]$SymName)
	Process {
		if ($Input) { $SymName = $Input }
		#
		if (-not (Test-Path $SymName)) { return }
		if (-not (Test-SymLink $SymName)) { throw "Path is not a Symbolic Link: '$symlinkPath'" }
		
		$Path = GetTarget-SymLink $SymName
		$isDirectory = (Get-Item $Path).PSIsContainer
		
		"Deleting Symbolic Link '$SymName'..."
		If ($PScmdlet.ShouldProcess($SymName, 'Delete Symbolic Link')) {
			if ($isDirectory) { cmd @("/c", "rmdir", $SymName) }
			else { Remove-Item $SymName }
		}
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
	[Parameter(Mandatory=$true)][string]$SymName,
	[Switch]$Force = $false,
	[Switch]$ReplaceExistingFileOrFolder = $false
)
	# resolves to a full path always
	$Path = [IO.Path]::GetFullPath($Path)
	$SymName = [IO.Path]::GetFullPath($SymName)
	
	if (-not (Test-Path $Path)) { throw "Path does not exist: '$Path'" }
	
	# if symbolic link already exist
	if (Test-Path $SymName) { 
		$isSymLink = Test-SymLink $SymName
		if (-not $isSymLink) { 
			# if it is a file/folder and confirm you want to remove it
			if (-not $ReplaceExistingFileOrFolder) { throw "Target already exists and won't be deleted as it's not a Symbolic Link (Specificy '-ReplaceExistingFileOrFolder' to force replace existing file): '$SymName'"  }
		}

		if (-not $Force) { throw "Target already exists (specify '-Force' to overwrite): '$SymName'" }
		
		# check if it is already mapped to the same target path
		$currentTarget = GetTarget-SymLink $SymName
		if ($Path -eq $currentTarget) {
			return "OK"
		}
		
		# remove link/file
		if ($isSymLink) { Delete-SymLink $SymName } else { Remove-Item $SymName -Force -Recurse }
	}
	
	# create parent folder if it does not exist and Force=True
	$parentFolder = Split-Path $SymName -Parent
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
        $success = [WinAPI.SymbolicLink]::CreateSymbolicLink($SymName, $Path, $Flags[$symType])
		If ($success) {
            return "Updated"
        }
		else { throw "Unable to create symbolic link '$SymName'" }
    }
}

Function GetTarget-SymLink($SymName) {
	if (-not (Test-SymLink $SymName)) { return }
	[WinAPI.SymbolicLink]::GetSymbolicLinkTarget((Get-Item $SymName))
}

Function UnitTest-SymLink($Path, $SymName) {
	Delete-SymLink -SymName $SymName
	Create-SymLink -Path $Path -SymName $SymName
	"Target of '$SymName': {0}" -f (GetTarget-SymLink $SymName)
	"Exists '$SymName': {0}" -f (Test-SymLink $SymName)
	Delete-SymLink -SymName $SymName
}
#endregion


#region Mappings
Function ExecMapping-SymLink($SourceRoot, $TargetRoot, $Mappings, [Switch]$Delete = $false) {
	foreach ($Mapping in $Mappings) {
		$Sources = @()
		if ($Mapping.Source -match '\*$') { 
			$sourcePattern = "$SourceRoot\$($Mapping.Source)"
			# when adding mapping, default mode changes to '-Recurse' when using '...\*'
			if ($Mapping.Exclude) {
				# when '*' is removed, the '-Recurse' goes back to $false
				$sourcePattern = $sourcePattern -replace '\*$', ""
			}
			
			$Sources = Get-ChildItem $sourcePattern -Exclude $Mapping.Exclude -Directory:($Mapping.Directory -eq $true) | 
						Select -ExpandProperty FullName 
		}
		else { $Sources = [IO.Path]::GetFullPath("$SourceRoot\$($Mapping.Source)") }
		
		foreach ($itemSource in $Sources) {
			$itemTarget = "$TargetRoot\$($Mapping.Target)"
			# replace {0} by Name
			if ($itemTarget -like "*{0}*") {
				$Name = [IO.Path]::GetFileName($itemSource)
				$itemTarget = $itemTarget -f $Name
			}
			# delete symbolic link
			if ($Delete) {
				if (Test-SymLink $itemTarget) { Delete-SymLink $itemTarget }
				elseif (Test-Path $itemTarget) { "Not a symbolic link: '$itemTarget'" }
				else { "Not found: $itemTarget" }
			}
			# create symbolic link
			else {
				Create-SymLink $itemSource $itemTarget -Force -ReplaceExistingFileOrFolder:$Mapping.ReplaceExistingFileOrFolder
			}
		}
	}
}

Function CreateMapping-SymLink($SourceRoot, $TargetRoot, $Mappings) {
	Write-Host "[CreateMapping-SymLink]" -ForegroundColor Blue
	ExecMapping-SymLink $SourceRoot $TargetRoot $Mappings
}

Function DeleteMapping-SymLink($SourceRoot, $TargetRoot, $Mappings) {
	Write-Host "[DeleteMapping-SymLink]" -ForegroundColor Blue
	ExecMapping-SymLink $SourceRoot $TargetRoot $Mappings -Delete
}
#endregion


#init
Init-SymLink

#UNIT-TESTING
#cls; UnitTest-SymLink -Path "C:\temp\realfolder" -SymName "C:\temp\symfolder"; exit
#cls; UnitTest-SymLink -Path "C:\temp\realfolder\AmazonSendEmails.sln" -SymName "C:\temp\MyOtherSolution.sln"; exit
