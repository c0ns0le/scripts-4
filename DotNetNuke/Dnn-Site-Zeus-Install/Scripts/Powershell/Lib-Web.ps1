<#
.SYNOPSIS
  Funciones Para Administrar IIS
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop" # Set Error Action to Stop

#-----------------------------------------------------------[Functions]------------------------------------------------------------

##region Web Functions

#region Html Parsing
Function Html-ToText([string]$html) {
	# remove line breaks, replace with spaces
	$html = $html -replace "(`r|`n|`t)", " "
	# write-verbose "removed line breaks: `n`n$html`n"
	
	# remove invisible content
	@('head', 'style', 'script', 'object', 'embed', 'applet', 'noframes', 'noscript', 'noembed') | % {
		$html = $html -replace "<$_[^>]*?>.*?</$_>", ""
	}
	# write-verbose "removed invisible blocks: `n`n$html`n"
	
	# Condense extra whitespace
	$html = $html -replace "( )+", " "
	# write-verbose "condensed whitespace: `n`n$html`n"
	
	# Add line breaks
	@('div','p','blockquote','h[1-9]') | % { $html = $html -replace "</?$_[^>]*?>.*?</$_>", ("`n" + '$0' )} 
	# Add line breaks for self-closing tags
	@('div','p','blockquote','h[1-9]','br') | % { $html = $html -replace "<$_[^>]*?/>", ('$0' + "`n")} 
	# write-verbose "added line breaks: `n`n$html`n"
	
	#strip tags 
	$html = $html -replace "<[^>]*?>", ""
	# write-verbose "removed tags: `n`n$html`n"
	 
	# replace common entities
	@( 
		@("&amp;bull;", " * "),
		@("&amp;lsaquo;", "<"),
		@("&amp;rsaquo;", ">"),
		@("&amp;(rsquo|lsquo);", "'"),
		@("&amp;(quot|ldquo|rdquo);", '"'),
		@("&amp;trade;", "(tm)"),
		@("&amp;frasl;", "/"),
		@("&amp;(quot|#34|#034|#x22);", '"'),
		@('&amp;(amp|#38|#038|#x26);', "&amp;"),
		@("&amp;(lt|#60|#060|#x3c);", "<"),
		@("&amp;(gt|#62|#062|#x3e);", ">"),
		@('&amp;(copy|#169);', "(c)"),
		@("&amp;(reg|#174);", "(r)"),
		@("&amp;nbsp;", " "),
		@("&amp;(.{2,6});", "")
	) | % { $html = $html -replace $_[0], $_[1] }
	# write-verbose "replaced entities: `n`n$html`n"
	
	return $html
}
#endregion Html to Test


#region Calling Web Pages/Methods
Function Invoke-WebPage {
Param(
[Parameter(Mandatory=$true)][string]$Url
)
	Write-Header "Esperando que el Sitio Cargue..."

	# -UseBasicParsing: if you don't need the html returned to be parsed into different objects (it is a bit quicker).
	# WARNING: timeout infinito
	$r = Invoke-WebRequest -Uri $Url -UseBasicParsing -UserAgent $UserAgent -TimeoutSec 0
	Write-Indented "$($r.StatusCode): $($r.StatusDescription)"
	if ($r.StatusCode -ne 200) { throw "Sitio no responde: $Url" }

	Write-Footer "OK"
}

Function Invoke-HttpRest([Parameter(Mandatory=$true)]$Url, $body, $sessionId, $method = "Post", $TimeoutSec = 0, $FailCondition = $null, $FailMessage = $null) {
	Write-Host (Get-Indented ([Uri] $Url).AbsolutePath)
	$response = $null
	try	{
		$jsonBody = &{ if ($body) { ConvertTo-Json ($body) }}
		$response = Invoke-RestMethod -Method $method -Uri $Url -Body $jsonBody -ContentType 'application/json; charset=UTF-8' -WebSession $sessionId -TimeoutSec $TimeoutSec
	}
	catch {
		if ($_.ErrorDetails) {
			$e = ConvertFrom-Json $_.ErrorDetails
			Write-Warning (Get-Indented $e.Message -ForegroundColor Red)
			Write-Warning (Get-Indented $e.StackTrace -ForegroundColor Red)
		}
		throw
	}

	if ($FailCondition) {
		$failed = & $FailCondition $response
		if ($FailMessage.GetType().Name -eq "ScriptBlock") { $message = & $FailMessage $response }
		else { $message = $FailMessage }
		if ($failed) { 
			throw $message 
		}
	}
	$response
}

#endregion Calling Web Pages/Methods

##endregion Web Functions

