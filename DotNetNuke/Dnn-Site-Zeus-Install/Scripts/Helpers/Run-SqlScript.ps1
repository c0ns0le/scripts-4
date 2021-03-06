#Function Run-SqlScript {
<#
.SYNOPSIS
  Ejecuta SQL de prueba para chequear conexion con el servidor

.PARAMETER Server
  nombre de servidor e instancia de sql server

.PARAMETER UserName
  nombre de usuario para conectarse al servidor. Omita este parámetro si desea usar autenticación de Windows.

.PARAMETER Password
  Contraseña del usuario. Omita este parámetro si desea usar autenticación de Windows.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param (
	[parameter(Mandatory=$true, ParameterSetName="File")]
	[string] $File,
	[parameter(Mandatory=$true, ParameterSetName="Text")]
	[string] $Query,
	[Parameter(Mandatory=$true)]
	[string] $ServerOrCnnString = ".\SQLExpress",	# nombre del servidor de base de datos o la cadena de conexion completa
	[string] $Database,
	[string] $UserName,
	[string] $Password,
	# Variables de macro-sustitucion en un archivo de script sql. 
	# Ejemplo: -Variables "IIS_DNN_ALIAS=%s;"
	[string] $Variables,
	[string] $VariableValueDelimiter = "=",
	[string] $VariableEndDelimiter = ";",
	[int] $ConnectionTimeout = 5,		# tiempo de espera para conectarse a la base de datos
	[switch] $ShowPrintOutput = $true,	# muestra el resultado de las sentencias PRINT de SQL Server
	[switch] $ReturnScalar = $false,	# retorna valor de la primera fila/columna
	[switch] $ReturnCsv = $false,			# retorna el resultset como una lista separada por comas (en cada fila)
	[switch] $ReturnTabDelimited = $false,	# retorna el resultset como una lista separada por TAB (en cada fila)
	# for Return*** (other than scalar)
	[switch] $ShowHeaders = $false,    	# mostrar fila de cabecera con nombres de columnas
	[switch] $ShowRowNumber = $false,  	# mostrar columna extra (al inicio) con n° de fila
	[switch] $ShowCommand = $false,		# true: Escribir el texto del script en la salida
	[switch] $ShowDebugInfo = $false	# true: Muestra información adicional usando para depurar
)
Trap { 
	Write-Host "ERROR:"
	Write-Host $_;
	if ($ShowDebugInfo) { "[Trap] `$?: '$?', `$LASTEXITCODE: '$LASTEXITCODE', Exitting with 1." }
	[Environment]::Exit(2);
	# WARNING: this statement was not working on powershell 2.0 default installation on Windows Server 2008
	Exit 2;
}
	if ($ServerOrCnnString -match ';') {
		$cnnString = $ServerOrCnnString;
	}
	else {
		if (-not $Database) { throw "Database parameter is required"; }
	
		$cnnString = "Server=$ServerOrCnnString;Database=$Database;";
		if ($UserName) { 
			$cnnString += "User ID=$UserName;Password=$Password"; 
		}
		else {
			$cnnString += "Integrated Security=True";
		}
	}
	
	if ($ConnectionTimeout -and -not ($cnnString -match 'Connection Timeout')) {
		$cnnString += ";Connection Timeout=$ConnectionTimeout";
	}
	
	# verify if delimited columns were requested as output
	$returnDelimiter = ""
	if ($ReturnCsv) { $returnDelimiter = "," }
	if ($ReturnTabDelimited) { $returnDelimiter = "`t" }

	# get script text
	if ($File) {
		$scriptContents = [IO.File]::ReadAllText($File);
	} 
	else {
		$scriptContents = $Query;
	}

	# perform variable macro-substitution
	if ($Variables) {
		$varArray = $Variables -split $VariableEndDelimiter;
		# NOTE: this line did not work with value such as 'Server=.\SQLExpress'
		# ERROR: parsing ".\SQLEXPRESS" - Unrecognized escape sequence \S.
		#$h = ConvertFrom-StringData -StringData ($Variables -replace $VariableDelimiter,"`n");
		foreach ($varitem in $varArray) {
			if (-not $varitem) { continue; }
			$parts = $varitem -split $VariableValueDelimiter;
			
			# get variable name
			$varName = $parts[0];
			if (-not $varName) { continue; }
			
			# get variable value
			$varValue = $parts[1];
			if ($varValue -eq $null) { $varValue = ""; }
			
			# replace variable that appears in SQL as in sqlcmd. Example: $(VarName)
			# NOTE: case-insensitive replace
			$scriptContents = $scriptContents -replace [Regex]::Escape("`$($varName)"), $varValue.Replace('$', '$$');
		}
	}
	
	# open database connection
	$cnn = New-Object Data.SqlClient.SqlConnection $cnnString;
	$cnn.Open();
	if ($ShowDebugInfo) { "[Open] `$?: $?, `$LASTEXITCODE: $LASTEXITCODE" }

#	Try {
		$cmd = $cnn.CreateCommand();
		# infinite timeout
		$cmd.CommandTimeout = 0;
		
		if ($ShowPrintOutput) {
			# get raised when any informational message (e.g. PRINT) or warning is returned by the SQL Server Database. 
			# To be precise, it is raised for errors with severity levels less than 10 and those 
			# with severity levels 11 or above causes an exception to be thrown
			$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { param($sender, $event) Write-Host $event.Message };
			$cnn.add_InfoMessage($handler);
		}

		if ($ReturnScalar) {
			$cmd.CommandText = $scriptContents;
			
			# write script back to output
			if ($ShowCommand) { Write-Host $scriptContents; }
			# display returned value
			Write-Host $cmd.ExecuteScalar();
			if ($ShowDebugInfo) { "[ExecuteScalar] `$?: $?, `$LASTEXITCODE: $LASTEXITCODE" }
		}
		elseif ($returnDelimiter) {
			$cmd.CommandText = $scriptContents;

			# write script back to output
			if ($ShowCommand) { Write-Host $scriptContents; }
			# execute
			$dr = $cmd.ExecuteReader();
			if ($ShowDebugInfo) { "[ExecuteReader] `$?: $?, `$LASTEXITCODE: $LASTEXITCODE" }
			
			do {
				# get column count
				$fieldCount = $dr.FieldCount

				# display headers
				if ($ShowHeaders) {
					$columns = @()
					for ($i=0; $i -lt $fieldCount; $i++) { $columns += $dr.GetName($i); }
					if ($ShowRowNumber) { Write-Host "#$returnDelimiter" -NoNewline }
					Write-Host ($columns -join $returnDelimiter)
				}
				
				# get all values
				$values = @()
				1..$fieldCount | % { $values += ""; }
				$i = 0
				foreach ($row in $dr) {
					$i++;
					$row.GetValues($values) | Out-Null
					if ($ShowRowNumber) { Write-Host "$i$returnDelimiter" -NoNewline }
					Write-Host ($values -join $returnDelimiter)
				}
				Write-Host ""
			} while ($dr.NextResult())
		}
		else {
			# parse each script part up to a "GO" into a separate script (SqlClient cannot run "GO" commands)
			$scripts = $scriptContents  -split "^\s*GO\s*", 0, "Multiline"	 

			$i = 0
			foreach ($script in $scripts) {
				# ignore empty screen
				if (!$script) { continue; }
				
				$i++;
				
				# write script back to output
				if ($ShowCommand) { 
					Write-Host ("--SCRIPT {0:00}: COMMAND {1}" -f $i,("-"*50))
					Write-Host $script; 
					Write-Host ("--SCRIPT {0:00}: OUTPUT{1}" -f $i,(" -"*(25+1)))
				}
				
				# run script
				$cmd.CommandText = $script;
				$rowsAffected = $cmd.ExecuteNonQuery();
				if ($ShowDebugInfo) { "[ExecuteNonQuery] `$?: $?, `$LASTEXITCODE: $LASTEXITCODE" }
				if ($rowsAffected -ge 0) {
					Write-Host "($rowsAffected) rows affected"
				}

				if ($ShowCommand) { 
					Write-Host ""
				}
			}
		}
#	}
#	finally {
#		if ($cnn -ne $null) { 
#			$cnn.Close();
#			if ($cnn -is [System.IDisposable]) { $cnn.Dispose(); }
#		}
#		if ($ShowDebugInfo) { "[finally] `$?: $?, `$LASTEXITCODE: $LASTEXITCODE" }
#	}
<#
//get the script
string scriptText = GetScript();
 
//split the script on "GO" commands
string[] splitter = new string[] { "\r\nGO\r\n" };
string[] commandTexts = scriptText.Split(splitter,
  StringSplitOptions.RemoveEmptyEntries);
foreach (string commandText in commandTexts)
{
  //execute commandText
}

var fileContent = File.ReadAllText("query.sql");
var sqlqueries = fileContent.Split(new[] {" GO "}, StringSplitOptions.RemoveEmptyEntries);
 
var con = new SqlConnection("connstring");
var cmd = new SqlCommand("query", con);
con.Open();
foreach (var query in sqlqueries)
{
    cmd.CommandText = query;
    cmd.ExecuteNonQuery();
}
con.Close();
#>

	
#}
