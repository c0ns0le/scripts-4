REM install
REM https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install/
cinst npm -y
npm install azure-cli -g


REM Setting the Resource Manager mode
REM enable Azure CLI Resource Manager commands.
azure config mode arm

REM you are asking Azure to create a resource group
REM azure group create <groupname> <location> 
 
REM you are instructing Azure to create a deployment of any number of items and place them in a group.
REM azure group deployment create <resourcegroup> <deploymentname> 
 
 
REM Connect to an Azure subscription
 
REM Log in to Azure using a work or school account or a Microsoft account identity
REM -q: bypass this prompt for automation scenarios
azure login -u host@facturecol.onmicrosoft.com
azure login -u host@facturecol.onmicrosoft.com -p <pwd> -q
Premium123$

REM If you have multiple Azure subscriptions
azure account list
azure account set <default-sub-name>

