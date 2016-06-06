<#
.SYNOPSIS
  Pruebas Unitarias Para Funciones de Administración de Bases de datos SQL Server
#>
Set-StrictMode -Version latest #ERROR REPORTING ALL
#-----------------------------------------------------------[Init]------------------------------------------------------------

if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ScriptToTest = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$ScriptToTest = (Resolve-Path "$PSScriptRoot\..\Helpers\$ScriptToTest").Path

#-----------------------------------------------------------[Include]------------------------------------------------------------

. $ScriptToTest

#-----------------------------------------------------------[Data]------------------------------------------------------------
$dbName = "sampleDummyDatabaseForUnitTesting"
$dbServer = "$env:COMPUTERNAME\SQLEXPRESS"
# Integrated Security 
$dbUser, $dbPassword = $null, $null

#-----------------------------------------------------------[Tests]------------------------------------------------------------


Describe "GetDefaultPaths-SqlServer" {
    It "Using Integrated Security" {
		$expectedPath = "C:\SqlData\MSSQL12.SQLEXPRESS\MSSQL\DATA\"
		$defaultDataPath, $defaultLogPath = GetDefaultPaths-SqlServer -Name $dbName -Server $dbServer -User $dbUser -Password $dbPassword
        $defaultDataPath | Should Be $expectedPath
        $defaultLogPath | Should Be $expectedPath
    }
}

Describe "SQL Server Databases" {
    It "Test-SqlServerDb" {
		$dbName = "MadeUpNameForDatabaseNonExisting"
		Test-SqlServerDb -Name $dbName -Server $dbServer -User $dbUser -Password $dbPassword |
			 Should Be $false
		Test-SqlServerDb -Name "master" -Server $dbServer -User $dbUser -Password $dbPassword |
			 Should Be $true
    }

    It "New/Test/Remove-SqlServerDb" {
		$dbName = $dbName
		# create database (force)
		New-SqlServerDb -Name $dbName -Server $dbServer -User $dbUser -Password $dbPassword -Force $true | Out-Null
		
		# check functionality
		Test-SqlServerDb -Name $dbName -Server $dbServer -User $dbUser -Password $dbPassword |
			 Should Be $true
		
		# cleanup (remove db)
		Remove-SqlServerDb -Name $dbName -Server $dbServer -User $dbUser -Password $dbPassword | Out-Null
	}
}
