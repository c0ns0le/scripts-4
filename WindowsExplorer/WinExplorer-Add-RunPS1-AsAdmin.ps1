<#
.SYNOPSIS
	Add context menu entry to windows explorer: Run PS1 As Admin
#>
New-PSDrive HKCR Registry HKEY_CLASSES_ROOT
New-Item 'HKCR:\Microsoft.PowerShellScript.1\Shell\Run with PowerShell (Admin)'
New-Item 'HKCR:\Microsoft.PowerShellScript.1\Shell\Run with PowerShell (Admin)\Command'
Set-ItemProperty 'HKCR:\Microsoft.PowerShellScript.1\Shell\Run with PowerShell (Admin)\Command' '(Default)' '"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-Command" ""& {Start-Process PowerShell.exe -ArgumentList ''-ExecutionPolicy RemoteSigned -File \"%1\"'' -Verb RunAs}"'

