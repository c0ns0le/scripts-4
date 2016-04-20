Push-Location 
cd $dnnhome

# Load our script defaults
.\load-config.ps1 dnn.installer.config

# Import all of our PowerShell scripts
. .\install-dnn.ps1
. .\ziplib.ps1
. .\acllib.ps1
. .\DBLib.ps1
. .\iislib.ps1
. .\dnnlib.ps1
. .\ielib.ps1

Pop-Location 
