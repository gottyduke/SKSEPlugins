#Requires -Version 5

# args
param(
	[switch]$Bootstrap,
	[switch]$Update,
	[switch]$WhatIf,
	[ValidateSet('AE', 'SE', 'VR', 'ALL', 'PRE-AE', 'FLATRIM')][string]$Runtime = 'ALL',
	[Alias('C', 'Custom')][switch]$CustomCLib,
	[Alias('N', 'NoBuild')][switch]$NoPrebuild,
	[Alias('DBG')][string[]]$EnableDebugger,
	[Alias('D')][string[]]$ExtraCMakeArgument
)

$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$env:DKScriptVersion = '23518'
$env:RebuildInvoke = $true
$env:ScriptCulture = (Get-Culture).Name -eq 'zh-CN'


function L {
	param (
		[Parameter(Mandatory)][string]$en,
		[string]$zh = ''
	)
	
	process {
		if ($env:ScriptCulture -and $zh) {
			return $zh
		}
		else {
			return $en
		}
	}
}


[IO.Directory]::SetCurrentDirectory($PSScriptRoot)
Set-Location $PSScriptRoot

# @@BOOTSTRAP
if ($Bootstrap) {	
	function Initialize-Repo {
		param (
			[string]$EnvName,
			[string]$RepoName,
			[string]$Token,
			[string]$Path,
			[string]$RemoteUrl
		)
		
		process {
			if (Test-Path "$PSScriptRoot/$Path/$Token" -PathType Leaf) {
				Write-Host "`n`t* Located local $RepoName   " -ForegroundColor Green
			}
			else {
				Remove-Item "$PSScriptRoot/$Path" -Recurse -Force -Confirm:$false -ErrorAction:SilentlyContinue
				Write-Host "`n`t- Bootstrapping $RepoName..." -ForegroundColor Yellow -NoNewline
				& git clone $RemoteUrl $Path -q
				Write-Host "`r`t- Installed $RepoName               " -ForegroundColor Green
			}
			
			$CurrentEnv = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$PSScriptRoot/$Path")
			Write-Host "`t`t- Mapping path, please wait..." -NoNewline
			Start-Job {
				if ($RepoName -notlike '*CommonLib*') {
					Push-Location $using:CurrentEnv
					& git checkout -f master -q
					Pop-Location
				}
				[System.Environment]::SetEnvironmentVariable($using:EnvName, $using:CurrentEnv, [System.EnvironmentVariableTarget]::Machine) 
			} | Out-Null
			Write-Host "`r`t`t- $EnvName has been set to [$CurrentEnv]               "
		}
	}

	
	function Find-Game {
		param (
			[string]$EnvName,
			[string]$GameName
		)
		
		process {
			Write-Host "`n`t! Missing $GameName" -ForegroundColor Red -NoNewline
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Add build support for $($GameName)?`n`nMake sure to select correct version of game if proceeding.", 'YesNo,MsgBoxSetForeground,Question', 'Game Build Support')		
			while ($Result -eq 6) {
				$SkyrimFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
					Title  = "Select $($GameName) Executable"
					Filter = 'Skyrim Game (SkyrimSE.exe) | SkyrimSE.exe'
				}
			
				$SkyrimFile.ShowDialog() | Out-Null
				if (Test-Path $SkyrimFile.Filename -PathType Leaf) {
					$CurrentEnv = Split-Path $SkyrimFile.Filename
					Write-Host "`r`t* Located $GameName               " -ForegroundColor Green
					Write-Host "`t`t- Mapping path, please wait..." -NoNewline
					Start-Job { [System.Environment]::SetEnvironmentVariable($using:EnvName, $using:CurrentEnv, [System.EnvironmentVariableTarget]::Machine) } | Out-Null
					Write-Host "`r`t`t- $EnvName has been set to [$CurrentEnv]               "
					break
				}
				else {
					$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Unable to locate $($GameName), try again?", 'YesNo,MsgBoxSetForeground,Exclamation', 'Game Build Support')		
				}
			}

			$MO2EnvName = 'MO2' + $EnvName
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Enable MO2 support for $($GameName)?`n`nMO2 Support: Allows plugin to be directly copied to MO2 directory for faster debugging.", 'YesNo,MsgBoxSetForeground,Question', 'MO2 Support')
			$MO2Dir = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
				Description         = "Select MO2 directory for $($GameName), containing /mods, /profiles, and /override folders."
				ShowNewFolderButton = $false
			}
			while ($Result -eq 6) {	
				$MO2Dir.ShowDialog() | Out-Null
				if (Test-Path "$($MO2Dir.SelectedPath)/mods" -PathType Container) {
					Write-Host "`tMapping path, please wait..." -NoNewline
					$MO2Dir = $MO2Dir.SelectedPath
					Start-Job { [System.Environment]::SetEnvironmentVariable($using:MO2EnvName, $using:MO2Dir, [System.EnvironmentVariableTarget]::Machine) } | Out-Null
					Write-Host "`r`t* Enabled MO2 support for $GameName               " -ForegroundColor Green
					break
				}
				else {
					$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Not a valid MO2 path, try again?`n`nMO2 directory contains /mods, /profiles, and /override folders", 'YesNo,MsgBoxSetForeground,Exclamation', 'MO2 Support')
				}
			}
		}
	}


	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	$admin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

	if (!$admin) {
		Write-Host "`tExecute with admin privilege to continue!" -ForegroundColor Red
		Exit
	}

	$Signature = Get-AuthenticodeSignature "$PSScriptRoot\!Rebuild.ps1"
	if ($Signature.Status -ne 'Valid') {
		Write-Host "`t! Self signing updating..." -ForegroundColor Yellow -NoNewline
		$scriptCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=DKScriptSelfCert' }
		if (!$scriptCert) {
			$authenticode = New-SelfSignedCertificate -Subject 'DKScriptSelfCert' -CertStoreLocation Cert:\LocalMachine\My -Type CodeSigningCert
			foreach ($store in @([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPublisher)) {
				$Cert = [System.Security.Cryptography.X509Certificates.X509Store]::new($store, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
				$Cert.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
				$Cert.Add($authenticode)
				$Cert.Close()
			}
		}
		$scriptCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=DKScriptSelfCert' }
		@('!MakeNew.ps1', '!Rebuild.ps1', '!Update.ps1') | ForEach-Object {
			Set-AuthenticodeSignature "$PSScriptRoot/$_" -Certificate $scriptCert -TimeStampServer 'http://timestamp.digicert.com' | Out-Null
		}

		$Signature = Get-AuthenticodeSignature "$PSScriptRoot/!Rebuild.ps1"
		if ($Signature.Status -ne 'Valid') {
			Write-Host "`r`t! Failed to complete self signing procecss!  " -ForegroundColor Red
			Exit
		}
		else {
			Write-Host "`r`t* Self signing complete               `n" -ForegroundColor Green
		}
		
		$OldPolicy = Get-ExecutionPolicy -Scope LocalMachine
		if ($OldPolicy -eq 'Restricted') {
			Write-Host "`t* Updated ExecutionPolicy to [RemoteSigned] on [LocalMachine]"
			Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
		}
	}
	
	if ($Update.IsPresent) {
		Exit
	}

	Add-Type -AssemblyName Microsoft.VisualBasic
	Add-Type -AssemblyName System.Windows.Forms

	Write-Host "`tBOOTSTRAP initiating, please wait..." -ForegroundColor Red -NoNewline
	foreach ($env in @('CommonLibSSEPath', 'CustomCommonLibSSEPath', 'DKUtilPath', 'SkyrimSEPath', 'SkyrimAEPath', 'SkyrimVRPath', 'MO2SkyrimSEPath', 'MO2SkyrimAEPath', 'MO2SkyrimVRPath', 'SKSETemplatePath', 'SKSEPluginAuthor')) {
		Start-Job { [Environment]::SetEnvironmentVariable($using:env, $null, [System.EnvironmentVariableTarget]::Machine) } | Out-Null
	}
	Get-Job | Wait-Job | Out-Null
	Write-Host "`r`tBOOTSTRAP initiated!               " -ForegroundColor Yellow

	Write-Host "`t>>> Checking out requirements... <<<" -ForegroundColor Yellow

	# VCPKG_ROOT
	if (Test-Path "$env:VCPKG_ROOT/vcpkg.exe" -PathType Leaf) {
		Write-Host "`n`t* Located local VCPKG" -ForegroundColor Green
	}
 else {
		Initialize-Repo 'VCPKG_ROOT' 'VCPKG' 'vcpkg.exe' 'vcpkg' 'https://github.com/microsoft/vcpkg'

		& $PSScriptRoot/vcpkg/bootstrap-vcpkg.bat | Out-Null
		& $PSScriptRoot/vcpkg/vcpkg.exe integrate install | Out-Null
	}

	# CommonLibSSEPath
	Initialize-Repo 'CommonLibSSEPath' 'CommonLibSSE-NG' 'CMakeLists.txt' 'Library/CommonLibSSE-NG' 'https://github.com/CharmedBaryon/CommonLibSSE-NG'
	$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Enable custom CLib support?`n`nThis is for people who maintain their own modification of CommonLibSSE-NG", 'YesNo,MsgBoxSetForeground,Question', 'Custom CLib support') 
	while ($Result -eq 6) {
		$CustomCLibDir = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
			Description = 'Select custom CommonLibSSE directory, containing CMakeLists.txt'
		}

		$CustomCLibDir.ShowDialog() | Out-Null
		if (Test-Path "$($CustomCLibDir.SelectedPath)/CMakeLists.txt" -PathType Leaf) {
			Write-Host "`n`t* Enabled custom CommonLibSSE" -ForegroundColor Green

			$CustomCLibDir = $CustomCLibDir.SelectedPath
			Start-Job { [System.Environment]::SetEnvironmentVariable('CustomCommonLibSSEPath', $using:CustomCLibDir, [System.EnvironmentVariableTarget]::Machine) } | Out-Null
			Write-Host "`t`t- CustomCommonLibSSEPath has been set to [$($CustomCLibDir)]"
			Write-Host "`t`t# To use custom CommonLibSSE-NG in build, append switch parameter '-C', '-Custom', or '-CustomCLib' to the !Rebuild command."
			break
		}
		else {
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Unable to locate valid CMakeLists.txt, try again?', 'YesNo,MsgBoxSetForeground,Exclamation', 'Custom CLib support')		
		}
	}

	# DKUtilPath
	Initialize-Repo 'DKUtilPath' 'DKUtil' 'CMakeLists.txt' 'Library/DKUtil' 'https://github.com/gottyduke/DKUtil'
	# SKSETemplatePath
	Initialize-Repo 'SKSETemplatePath' 'SKSETemplate' 'CMakeLists.txt' 'Plugins/Template' 'https://github.com/gottyduke/Template'

	# SkyrimSEPath
	Find-Game 'SkyrimSEPath' 'Skyrim Special Edition (1.5.97)'
	# SkyrimAEPath
	Find-Game 'SkyrimAEPath' 'Skyrim Anniversary Edition (1.6.xxx)'
	# SkyrimAEPath
	Find-Game 'SkyrimVRPath' 'Skyrim VR (1.3.64)'

	$Author = $null
	while (!$Author) {
		$Author = [Microsoft.VisualBasic.Interaction]::InputBox("Input the plugin author name:`n`nThis cannot be null", 'Author', 'ToddHoward')
	}
	Start-Job { [System.Environment]::SetEnvironmentVariable('SKSEPluginAuthor', $using:Author, [System.EnvironmentVariableTarget]::Machine) } | Out-Null
	Write-Host "`n`t* Plugin author: $Author" -ForegroundColor Magenta

	# TODO setup bethesda scripts
	# TODO setup versionlib support

	Write-Host "`n`t>>> Bootstrapping finishing up... <<<" -ForegroundColor Green
	Get-Job | Wait-Job | Out-Null
	Get-Job | Remove-Job | Out-Null

	Write-Host "`n`tRestart current command line interface to complete BOOTSTRAP."
	Exit
}


function Normalize ($text) {
	return $text -replace '\\', '/'
}


function Add-Subdirectory ($Name, $Path) {
	return Normalize "message(CHECK_START `"Rebuilding $Name`")`nadd_subdirectory($Path)`nmessage(CHECK_PASS `"Complete`")"
}


function Restore {
	Copy-Item "$env:CommonLibSSEPath/CMakeLists.txt.disabled" "$env:CommonLibSSEPath/CMakeLists.txt" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
	Remove-Item "$env:CommonLibSSEPath/CMakeLists.txt.disabled" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
	Exit
}


Write-Host "`tDKScriptVersion $env:DKScriptVersion`t$Runtime`n"
# @@CLib
$CMakeLists = [System.Collections.ArrayList]::new(256)
$CLibType = 'NG'
if ($CustomCLib -and !(Test-Path "$env:CustomCommonLibSSEPath/CMakeLists.txt" -PathType Leaf)) {
	$CustomCLib = $false
	Write-Host "`t! CustomCLib invoked but target path does not contain valid CMakeLists!`n`t`t# Path: $($env:CustomCommonLibSSEPath)`n`tFallback to default CLib..." -ForegroundColor Orange
}
if ($CustomCLib) {
	$env:CommonLibSSEPath = $env:CustomCommonLibSSEPath
	$CLibType = 'Custom'
}
elseif (!(Test-Path "$env:CommonLibSSEPath/CMakeLists.txt" -PathType Leaf)) {
	Write-Host "`tNone of the CLib paths is valid!`n`tOR`n`tIncorrect Bootstrap" -ForegroundColor Red
	Exit
}

$CMakeLists.Add("`nset(`ENV{CommonLibSSEPath} `"$(Normalize $env:CommonLibSSEPath)`")`n") | Out-Null
$CMakeLists.Add((Add-Subdirectory "CommonLib-$CLibType" '$ENV{CommonLibSSEPath} "CLib"')) | Out-Null
Write-Host "`t===> Rebasing for [$Runtime] Runtime <===`n" -ForegroundColor DarkYellow
Copy-Item "$env:CommonLibSSEPath/CMakeLists.txt" "$env:CommonLibSSEPath/CMakeLists.txt.disabled" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
Copy-Item "$PSScriptRoot/cmake/SKSE.CMakeLists.CLib.txt" "$env:CommonLibSSEPath/CMakeLists.txt" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null


# @@CMake Targets
$AcceptedSubfolder = @('Library', 'Plugins')
$ExcludedSubfolder = 'Template|CommonLib'
Write-Host "`tFinding CMake targets..."
$ProjectVCPKG = [IO.File]::ReadAllText("$PSScriptRoot/cmake/vcpkg.json.in") | ConvertFrom-Json
foreach ($subfolder in $AcceptedSubfolder) {
	$CMakeLists.Add("`nset(GROUP `"$subfolder`")`n") | Out-Null
	Get-ChildItem "$PSScriptRoot/$subfolder" -Directory | Where-Object {
		$_.Name -notmatch $ExcludedSubfolder
	} | Resolve-Path -Relative | ForEach-Object {
		if (Test-Path "$_/CMakeLists.txt" -PathType Leaf) {
			$TargetPath = $_.Substring(2)
			$TargetName = $_.Substring(10)
			Write-Host "`t`t[ $TargetName ]"
	
			$vcpkg = [IO.File]::ReadAllText("$_/vcpkg.json") | ConvertFrom-Json
			$ProjectVCPKG.dependencies += $vcpkg.'dependencies'
	
			if ($EnableDebugger -and $EnableDebugger.Contains($TargetName)) {
				$TargetName += 'Debugger'
			}
	
			$CMakeLists.Add((Add-Subdirectory $TargetPath $TargetPath)) | Out-Null
			$CMakeLists.Add((Normalize "fipch($TargetName $TargetPath)")) | Out-Null
			$CMakeLists.Add((Normalize "define_external($TargetName)")) | Out-Null
		}
	}
}
$Deps = @()
foreach ($dep in $ProjectVCPKG.dependencies) {
	$tmp = $dep
	if ($dep.name) {
		$tmp = $dep.name
	}
	if ($dep.features) {
		$tmp += " <$($dep.features)>"
	}
	$Deps += $tmp
}
$Deps = $Deps | Sort-Object -Unique
$Header = @((Get-Date -UFormat '# !Rebuild generated @ %R %B %d'), "# DKScriptVersion $env:DKScriptVersion")
$Boiler = [IO.File]::ReadAllLines("$PSScriptRoot/cmake/SKSE.CMakeLists.txt")
$CMakeLists = $Header + $Boiler + $CMakeLists
$CMakeLists = $CMakeLists -replace '\sskse64', "`tSKSE64_$($Runtime.ToUpper())"
[IO.File]::WriteAllLines("$PSScriptRoot/CMakeLists.txt", $CMakeLists)
$ProjectVCPKG = $ProjectVCPKG | ConvertTo-Json -Depth 9
[IO.File]::WriteAllText("$PSScriptRoot/vcpkg.json", $ProjectVCPKG)


# @@Debugger
if ($EnableDebugger.Count) {
	Write-Host "`tEnabled debugger:"
	foreach ($enabledDebugger in $EnableDebugger) {
		Write-Host "`t`t- $enabledDebugger"
	}
}


# @@WhatIf
if ($WhatIf) {
	Write-Host "`tPrebuild complete" -ForegroundColor Green
	Invoke-Item "$PSScriptRoot/CMakeLists.txt"
}


# @@CMake Generator
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction:Ignore | Out-Null
Write-Host "`tCleaned build folder"

$Arguments = @(
	'-Wno-dev'
)
foreach ($enabledDebugger in $EnableDebugger) {
	$Arguments += "-D$($enabledDebugger.ToUpper())_DEBUG_BUILD:BOOL=1"
}
foreach ($extraArg in $ExtraCMakeArgument) {
	$Arguments += "-D$extraArg"
}
$CurProject = $null
Write-Host "`tListing vcpkg dependencies: "
$Deps | ForEach-Object {
	"`t`t[ $_ ]"
}
Write-Host "`tBuilding dependencies & generating solution..."
$CMake = & cmake.exe -B $PSScriptRoot/Build -S $PSScriptRoot --preset=$($Runtime.ToUpper()) $Arguments | ForEach-Object {
	if ($_.StartsWith('-- Rebuilding ') -and !($_.EndsWith(' - Complete'))) {
		$CurProject = $_.Substring(14)
		Write-Host "`t`t! [Building] $CurProject" -ForegroundColor Yellow -NoNewline
	}
	elseif ($_.Contains('CMake Error')) {
		Write-Host "`r`t`t* [Failed] $CurProject               " -ForegroundColor Red
	}
	elseif ($_.StartsWith('-- Rebuilding ') -and $_.EndsWith(' - Complete')) {
		Write-Host "`r`t`t* [Complete] $CurProject               " -ForegroundColor Cyan
	}
	$_
}

if ($CMake[-2] -ne '-- Generating done') {
	Write-Host "`tFailed generating solution!" -ForegroundColor Red
}
else {
	Write-Host "`tFinished generating solution!`n`n`tYou may open the skse64.sln and starting coding." -ForegroundColor Green

	Invoke-Item "$PSScriptRoot/Build"

	# @@Compile
	if (!$NoPrebuild) {
		Write-Host "`n`tCompiling CommonLib in the background.`n`t# To disable this behavior, append switch `-N` or `-NoBuild` to the !Rebuild command."
		Write-Host "`n`tDo not close the compiler windows! Wait for background compilers to finish." -ForegroundColor Red
		Start-Process cmd.exe -ArgumentList "/k cmake.exe --build Build/CLib --config Debug && exit"
		Start-Process cmd.exe -ArgumentList "/k cmake.exe --build Build/CLib --config Release && exit"
	}
	
	# @@QuickBuild
	$Invocation = "@echo off`n" + 'powershell -ExecutionPolicy Bypass -Command "& %~dp0/!Rebuild.ps1 '
	$Invocation += " $($Runtime)"
	if ($CustomCLib) {
		$Invocation += " -custom"
	}
	if ($NoPrebuild) {
		$Invocation += " -nobuild"
	}
	if ($EnableDebugger) {
		$Invocation += " -dbg"
		foreach ($enabledDebugger in $EnableDebugger) {
			$Invocation += " $($enabledDebugger)"
		}
	}
	if ($ExtraCMakeArgument) {
		$Invocation += " -d"
		foreach ($extraArg in $ExtraCMakeArgument) {
			$Invocation += " $($extraArg)"
		}
	}

	$Invocation += '"'

	$Batch = Get-ChildItem "$PSSciptRoot" -File | Where-Object { ($_.Extension -eq '.cmd') -and ($_.BaseName.StartsWith('!_LAST_')) } | ForEach-Object {
		Remove-Item "$_" -Confirm:$false -Force -ErrorAction:SilentlyContinue | Out-Null
	}

	$Batch = "!_LAST_$($Runtime.ToUpper())$(if ($CustomCLib) {"_CUSTOM"}).cmd"

	[IO.File]::WriteAllText("$PSScriptRoot/$Batch", $Invocation)

	Write-Host "`tTo rebuild with same configuration, use the generated batch file.`n`t* $Batch *" -ForegroundColor Green
	Write-Host "`n`t!Rebuild will now exit." -ForegroundColor Green
}


