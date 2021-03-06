<#
.SYNOPSIS
  Pruebas Unitarias Para Funciones Para Administrar IIS
#>
Set-StrictMode -Version latest #ERROR REPORTING ALL
#-----------------------------------------------------------[Init]------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -le 2) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # powershell 2.0

$VerbosePreference = "SilentlyContinue" 	# messages do not appear
#$VerbosePreference = "Continue"			# all verbose messages will appear in the output

$TestingSourceName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$TestingSourceDir = (Resolve-Path "$PSScriptRoot\..\Powershell").Path
$TestingSourcePath = Join-Path $TestingSourceDir $TestingSourceName

#-----------------------------------------------------------[Include]------------------------------------------------------------

# WARNING: on this case, script is called below as it executes when called
#. $TestingSourcePath

# Loading Helper Libraries to Setup/Teardown
. "$PSScriptRoot\..\Powershell\Lib-General.ps1"
. "$PSScriptRoot\..\Powershell\Lib-IIS.ps1"


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function NewHomePage-SampleSite($RootFolder) {
#NewHomePage-SampleSite $SitePhysicalPath
	New-Folder $RootFolder
	New-File -Path "$RootFolder\Default.aspx" -Value @"
<%@ Page Language="C#" %>
<%
	private void Page_Load(object Sender, EventArgs e)
	{
	    HelloWorldLabel.Text = "Hello World!";
    }
%>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
    <title>Welcome Page</title>
</head>
<body>
    <form id="form1" runat="server">
    <div>
        <asp:Label runat="server" id="HelloWorldLabel"></asp:Label>
    </div>
	
	<ul>
	<% for (int i=1; i <7; i++) 
	{ %>
	  <li><font size="<%=i%>">C# inside aspx!</font> </li>
	<%}%>
	</ul>
    </form>
</body>
</html>
"@
}

Function Remove-AllItemsCreated {
	#Remove-Site $SiteName
	#Remove-AppPool $AppPoolName
	Remove-Folder $TestSitesRootPath
	Remove-User $TestUserName
}

Function Test-Setup {
	#cleanup
	Remove-AllItemsCreated
	
	# re-create
	New-User -UserName $TestUserName -Password $TestPassword
}

Function Test-Teardown {
	Remove-AllItemsCreated
}




#-----------------------------------------------------------[Data]------------------------------------------------------------
# Windows Account
$TestUserName, $TestPassword = "temphost", 'abc123$'

# Default Settings ********************************************************
# parent folder for all site subfolders
$TestSitesRootPath = "C:\Testing Temporary WebSite"
# AppPool
$AppPoolUserName = $TestUserName
$AppPoolPassword = $TestPassword

# IIS ********************************************************
$TestSettings = @{
	AppPools    = @{ 
		Test      = @{
			Found = @{ Name = "test-pool found"; UserName = $TestUserName; Password = $TestPassword; Enable32BitAppOnWin64 = 0 }
			NotFound = @{ Name = "test-pool not found"; UserName = $TestUserName; Password = $TestPassword; Enable32BitAppOnWin64 = 0 }
		}
		New       = @{
			NotExist = @{ Name = "test-pool not exist"; UserName = $TestUserName; Password = $TestPassword; Enable32BitAppOnWin64 = 0 }
			Existing = @{ Name = "test-pool existing"; UserName = $TestUserName; Password = $TestPassword; Enable32BitAppOnWin64 = 0 }
		}
	}
}

# Web Site
<#
$SiteName = $AppPoolName
$SitePhysicalPath = $TestSitesRootPath
$SitePoolName = $AppPoolName
$SiteIPAddress = ""
$SiteAlias = "$SiteName.dnndev.me"
$SitePort = 80
$SiteMaxUrlSegments = 120
# Web.Config
$MaxRequestMB = 100
$RuntimeExecutionTimeout = 1200
$RuntimeRequestLengthDiskThreshold = 90000
$RuntimeMaxUrlLength = 5000
$RuntimeRelaxedUrlToFileSystemMapping = "true"
$RuntimeMaxQueryStringLength = 50000
$ProviderName = "AspNetSqlMembershipProvider"
$ProviderEnablePasswordRetrieval = "true"
$ProviderMinRequiredPasswordLength = 6
$ProviderPasswordFormat = "Encrypted"
#>
# Debugging *******************************
#cls; Remove-AllItemsCreated; exit


#-----------------------------------------------------------[Tests]------------------------------------------------------------


#cls;Invoke-Pester -TestName "Test-AppPool"
Describe "Test-AppPool" {
	Test-Setup
    $poolSettings = $TestSettings.AppPools.Test
	# setup
	$myPool = $poolSettings.Found
	New-AppPool -Name $myPool.Name -UserName $myPool.UserName -Password $myPool.Password -Enable32BitAppOnWin64 $myPool.Enable32BitAppOnWin64 -BypassPermissions
	
	# run
	It "NotFound" {
		Test-AppPool $poolSettings.NotFound.Name
    }
	
	It "Found" {
		Test-AppPool $myPool.Name
    }

	# teardown
	Remove-AppPool $myPool.Name
	Test-Teardown
}

