#requires -Version 4.0
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Funciones de manipulacion de XML
#>
#if ($Script:XmlFunctionsLoaded) { "XML Functions Already Loaded"; return } else { $Script:XmlFunctionsLoaded = $true }


Function RemoveAllChildren-Xml([Xml.XmlElement[]]$parentNode, [string[]]$ExceptionList) {
	foreach ($item in $parentNode) {
		$item.SelectNodes('*') | % { 
			if ($ExceptionList -notcontains $_.Name) { $item.RemoveChild($_) | Out-Null }
		}
	}
}

Function AddChild-Xml($root, $parentNode, $name, $value) {
	$node = $root.CreateElement($name)
	$node.PsBase.InnerText = $value
	$parentNode.AppendChild($node) | Out-Null
}


#-----------------------------------------------------------[Setup]------------------------------------------------------------

