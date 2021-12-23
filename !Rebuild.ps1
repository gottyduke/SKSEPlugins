#Requires -Version 5

# args
param(
	[Parameter(Mandatory)][ValidateSet('MT', 'MD', 'BOOTSTRAP')][string]$Mode0,
	[ValidateSet('AE', 'SE')][string]$Mode1,
	[Alias('C', 'Custom')][switch]$CustomCLib,
	[switch]$WhatIf,
	[string[]]$EnableDebugger
)

$ErrorActionPreference = 'Stop'

$env:DKScriptVersion = '11222'
$env:RebuildInvoke = $true

Write-Host "`tDKScriptVersion $env:DKScriptVersion`t$Mode0`t$Mode1`n"
[IO.Directory]::SetCurrentDirectory($PSScriptRoot)


# @@BOOTSTRAP
if ($Mode0 -eq 'BOOTSTRAP') {	
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
			foreach($store in @([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPublisher)) {
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
		} else {
			Write-Host "`r`t* Self signing complete               `n" -ForegroundColor Green
		}
		
		$OldPolicy = Get-ExecutionPolicy -Scope LocalMachine
		if ($OldPolicy -eq 'Restricted') {
			Write-Host "`t* Updated ExecutionPolicy to [RemoteSigned] on [LocalMachine]"
			Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
		}
	}

	Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
	Add-Type -AssemblyName System.Windows.Forms | Out-Null

	Write-Host "`tBOOTSTRAP starting, please wait..." -ForegroundColor Red -NoNewline
	foreach ($env in @('CommonLibSSEPath', 'CustomCommonLibSSEPath', 'DKUtilPath', 'SkyrimSEPath', 'SkyrimAEPath', 'MO2SkyrimSEPath', 'MO2SkyrimAEPath', 'SKSETemplatePath', 'SKSEPluginAuthor')) {
		Start-Job {[Environment]::SetEnvironmentVariable($using:env, $null, [System.EnvironmentVariableTarget]::Machine)} | Out-Null
	}
	Get-Job | Wait-Job | Out-Null
	Write-Host "`r`tBOOTSTRAP initiated!               " -ForegroundColor Yellow

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
			} else {
				Remove-Item "$PSScriptRoot/$Path" -Recurse -Force -Confirm:$false -ErrorAction:SilentlyContinue
				Write-Host "`n`t- Bootstrapping $RepoName..." -ForegroundColor Yellow -NoNewline
				& git clone $RemoteUrl $Path -q
				Write-Host "`r`t- Installed $RepoName               " -ForegroundColor Green
			}
			
			$CurrentEnv = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$PSScriptRoot/$Path")
			Write-Host "`t`t- Mapping path, please wait..." -NoNewline
			Start-Job {
				Push-Location $using:CurrentEnv
				& git checkout -f master -q
				Pop-Location
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
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Add build support for $($GameName)?`n`nMake sure to select correct version of game if proceeding.", 36, 'Game Build Support')		
			while ($Result -eq 6) {
				$SkyrimFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
					Title = "Select $($GameName) Executable"
					Filter = 'Skyrim Game (SkyrimSE.exe) | SkyrimSE.exe'
				}
			
				$SkyrimFile.ShowDialog() | Out-Null
				if (Test-Path $SkyrimFile.Filename -PathType Leaf) {
					$CurrentEnv = Split-Path $SkyrimFile.Filename
					Write-Host "`r`t* Located $GameName               " -ForegroundColor Green
					Write-Host "`t`t- Mapping path, please wait..." -NoNewline
					Start-Job {[System.Environment]::SetEnvironmentVariable($using:EnvName, $using:CurrentEnv, [System.EnvironmentVariableTarget]::Machine)} | Out-Null
					Write-Host "`r`t`t- $EnvName has been set to [$CurrentEnv]               "
					break
				} else {
					$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Unable to locate $($GameName), try again?", 52, 'Game Build Support')		
				}
			}

			$MO2EnvName = 'MO2' + $EnvName
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Enable MO2 support for $($GameName)?`n`nMO2 Support: Allows plugin to be directly copied to MO2 directory for faster debugging.", 36, 'MO2 Support')
			while ($Result -eq 6) {
				$MO2Dir = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
					Description = "Select MO2 directory for $($GameName), containing /mods, /profiles, and /override folders."
					ShowNewFolderButton = $false
				}

				$MO2Dir.ShowDialog() | Out-Null
				if (Test-Path "$($MO2Dir.SelectedPath)/mods" -PathType Container) {
					Write-Host "`tMapping path, please wait..." -NoNewline
					$MO2Dir = $MO2Dir.SelectedPath
					Start-Job {[System.Environment]::SetEnvironmentVariable($using:MO2EnvName, $using:MO2Dir, [System.EnvironmentVariableTarget]::Machine)} | Out-Null
					Write-Host "`r`t* Enabled MO2 support for $GameName               " -ForegroundColor Green
					break
				} else {
					$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Not a valid MO2 path, try again?`n`nMO2 directory contains /mods, /profiles, and /override folders", 52, 'MO2 Support')
				}
			}
		}
	}

	Write-Host "`t>>> Checking out requirements... <<<" -ForegroundColor Yellow

	# VCPKG_ROOT
	if (Test-Path "$env:VCPKG_ROOT/vcpkg.exe" -PathType Leaf) {
		Write-Host "`n`t* Located local VCPKG" -ForegroundColor Green
	} else {
		Initialize-Repo 'VCPKG_ROOT' 'VCPKG' 'vcpkg.exe' 'vcpkg' 'https://github.com/microsoft/vcpkg'
	}

	# CommonLibSSEPath
	Initialize-Repo 'CommonLibSSEPath' 'CommonLib' 'CMakeLists.txt' 'Library/CommonLibSSE' 'https://github.com/Ryan-rsm-McKenzie/CommonLibSSE'
	$Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Enable custom CLib support?', 36, 'Custom CLib support') 
	while ($Result -eq 6) {
		$CustomCLibDir = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
			Description = 'Select custom CommonLib directory, containing CMakeLists.txt'
		}
	
		$CustomCLibDir.ShowDialog() | Out-Null
		if (Test-Path "$($CustomCLibDir.SelectedPath)/CMakeLists.txt" -PathType Leaf) {
			Write-Host "`n`t* Enabled custom CommonLib" -ForegroundColor Green
			$CustomCLibDir = $CustomCLibDir.SelectedPath
			Start-Job {[System.Environment]::SetEnvironmentVariable('CustomCommonLibSSEPath', $using:CustomCLibDir, [System.EnvironmentVariableTarget]::Machine)} | Out-Null
			Write-Host "`t`t- CustomCommonLibSSEPath has been set to [$($CustomCLibDir)]"
			Write-Host "`t`t# To use custom CommonLib in build, append switch parameter '-C', '-Custom', or '-CustomCLib' to the !Rebuild command."
			break
		} else {
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Unable to locate valid CMakeLists.txt, try again?', 52, 'Custom CLib support')		
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

	$Author = $null
	while (!$Author) {
		$Author = [Microsoft.VisualBasic.Interaction]::InputBox("Input the plugin author name:`n`nThis cannot be null", 'Author', 'ToddHoward')
	}
	Start-Job {[System.Environment]::SetEnvironmentVariable('SKSEPluginAuthor', $using:Author, [System.EnvironmentVariableTarget]::Machine)} | Out-Null
	Write-Host "`n`t* Plugin author: $Author" -ForegroundColor Magenta

	Write-Host "`n`t>>> Bootstrapping finishing up... <<<" -ForegroundColor Green
	Get-Job | Wait-Job | Out-Null
	Get-Job | Remove-Job | Out-Null

	$env:VCPKG_ROOT = [System.Environment]::GetEnvironmentVariable('VCPKG_ROOT', [System.EnvironmentVariableTarget]::Machine)
	& $env:VCPKG_ROOT\bootstrap-vcpkg.bat | Out-Null
	& $env:VCPKG_ROOT\vcpkg.exe integrate install | Out-Null

	Write-Host "`n`tRestart current command line interface to complete BOOTSTRAP."
	Exit
}


# @@Build Linkage
$Triplet = $null
$MTD = ($Mode0 -ne 'MT')
if ($MTD) {
	$Triplet = "x64-windows-static-md"
	Write-Host "`t***** Runtime MultiThreadedDLL *****" -ForegroundColor DarkMagenta
} else {
	$Triplet = "x64-windows-static"
	Write-Host "`t***** Static MultiThreaded *****" -ForegroundColor DarkGreen
}


# @@Build Target
$ANNIVERSARY_EDITION = ($Mode1 -eq 'AE')
if ($ANNIVERSARY_EDITION -and $env:SkyrimAEPath) {
	Write-Host "`tTarget: Anniversary Edition" -ForegroundColor Yellow
} elseif (!$ANNIVERSARY_EDITION -and $env:SkyrimSEPath) {
	Write-Host "`tTarget: Special Edition" -ForegroundColor Yellow
} else {
	# unbootstrapped game version
	Write-Host "`tUnknown game version specified!`n`tOR:`n`tIncorrect BOOTSTRAP" -ForegroundColor Red
	Exit
}


function Normalize ($text) {
	return $text -replace '\\', '/'
}


function Add-Subdirectory ($Name, $Path) {
	return Normalize "message(CHECK_START `"Rebuilding $Name`")`nadd_subdirectory($Path)`nmessage(CHECK_PASS `"Complete`")"
}


$Concerns = @()
function Show-Concerns {
	if (!$Concerns.Count) {
		return
	}

	Write-Host "`n`tFollowing concerns regarding the vcpkg dependencies: "
	foreach ($concern in $Concerns) {
		Write-Host "`n`t $concern"
	}

	Write-Host "`tThese concerns have been *resolved* by !Rebuild`n`tHowever, it is suggested to modify the target CMakeLists.txt to address these concerns" -ForegroundColor Yellow
}


# @@CLib
$CMakeLists = [System.Collections.ArrayList]::new(128)
$CLibType = $null
$CLibPath = $null
if ($CustomCLib -and !(Test-Path "$env:CustomCommonLibSSEPath/CMakeLists.txt" -PathType Leaf)) {
	$CustomCLib = $false
	Write-Host "`t! CustomCLib invoked but target path does not contain valid CMakeLists!`n`t`t# Path: $($env:CustomCommonLibSSEPath)`n`tFallback to default CLib..." -ForegroundColor Red
}
if ($CustomCLib) {
	$CLibType = 'Custom'
	$CLibPath = $env:CustomCommonLibSSEPath
} elseif (Test-Path "$env:CommonLibSSEPath/CMakeLists.txt" -PathType Leaf) {
	Push-Location $env:CommonLibSSEPath
	if ($ANNIVERSARY_EDITION) {
		& git checkout -f master -q
		$CLibType = 'Latest'
	} else {
		& git checkout -f 575f84a -q
		$CLibType = 'Legacy'
	}
	Pop-Location
	$CLibPath = $env:CommonLibSSEPath
} else {
	Write-Host "`tNone of the CLib paths is valid!`n`tOR`n`tIncorrect BOOTSTRAP" -ForegroundColor Red
	Exit
}
$CMakeLists.Add("`nset(`ENV{CommonLibSSEPath} `"$(Normalize $CLibPath)`")`n") | Out-Null
$CMakeLists.Add((Add-Subdirectory "$($CLibType)CommonLib" '$ENV{CommonLibSSEPath} "CLib"')) | Out-Null
Write-Host "`t===> Rebasing [$CLibType] CLib <===" -ForegroundColor DarkYellow
Copy-Item "$PSScriptRoot/cmake/CLibCustomCMakeLists.txt.in" "$CLibPath/CMakeLists.txt" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null


# @@CMake Targets & Dependencies
# Enforce external find_package & target_link_library
# Concern if not present in the target CMakeLists
$AcceptedSubfolder = @('Library', 'Plugins')
$ExcludedSubfolder = @('Template')
$Installed = @()
Write-Host "`tBuilding CMake targets & dependencies...`n`t`t= [$Triplet]"
if (!(Test-Path "$env:VCPKG_ROOT/vcpkg.exe" -PathType Leaf)) {
	Write-Host "`tInvalid VCPKG_ROOT path!`n`tOR`n`tIncorrect BOOTSTRAP" -ForegroundColor Red
	Exit
}
foreach ($subfolder in $AcceptedSubfolder) {
	$CMakeLists.Add("`nset(GROUP `"$subfolder`")`n") | Out-Null
	Get-ChildItem "$subfolder" -Directory | Where-Object {
		$_.Name -notin $ExcludedSubfolder
	} | Resolve-Path -Relative | ForEach-Object {
		if (Test-Path "$_/CMakeLists.txt" -PathType Leaf) {
			$TargetCMake = [IO.File]::ReadAllText("$_/CMakeLists.txt")
			$TargetLibraries = [regex]::match($TargetCMake, '(?s)(?:(?<=target_link_libraries\()(.*?)(?=\)))').Groups[1].Value.Trim() -split '\s+'
			$TargetLibraries = $TargetLibraries[2 .. ($TargetLibraries.Count)]
			$TargetPath = $_.Substring(2)
			$TargetName = $_.Substring(10)
	
			$vcpkg = [IO.File]::ReadAllText("$_/vcpkg.json") | ConvertFrom-Json
			$Dependencies = $vcpkg.'dependencies'
			if ($EnableDebugger -and $EnableDebugger.Contains($TargetName)) {
				$TargetName += 'Debugger'
			}
	
			$CMakeLists.Add((Add-Subdirectory $TargetPath $TargetPath)) | Out-Null
			if ($TargetName -ne 'CommonLibSSE') {
				$CMakeLists.Add((Normalize "fipch($TargetName $TargetPath)")) | Out-Null
			}
	
			foreach ($dependency in $Dependencies) {
				if (!$Installed.Contains($dependency)) {
					Write-Host "`t`t! [Building] $dependency" -ForegroundColor Yellow -NoNewline
				}
				$BuildResult = & $env:VCPKG_ROOT/vcpkg install ${dependency}:$Triplet
				$PackageInfo = $BuildResult[($BuildResult.Count - 5) .. ($BuildResult.Count - 2)].Trim()
	
				if ($PackageInfo[0].Contains('CMake targets')) {
					# process each library package
					$Package = $PackageInfo[2] -split '\s+'
					$PackageName = $Package[0].Substring(13)
					if (!$TargetCMake.Contains($Package[0])) {
						# assume package is present at this point
						$CMakeLists.Insert(($CMakeLists.Count - 2), "$($Package[0]) $($Package[1]))") | Out-Null
						$Concerns += "# $TargetPath : Missing $($Package[0]) $($Package[1])) or similar calls"
					}
	
					$Libraries = $PackageInfo[3].Substring(35).Substring(0, ($PackageInfo[3].Length - 36)) -split '\s+'
					# full-module-wild
					$Linked = $Libraries | Where-Object {$TargetLibraries -contains $_}
					$Linked += $TargetLibraries -like ($PackageName + '::*')
					$Linked += $TargetLibraries -contains $PackageName
	
					if (!$Linked.Count) {
						$CMakeLists.Add((Normalize "link_external($TargetName $($Libraries[0]))")) | Out-Null
						$Concerns += "# $TargetPath : Missing one of [$($Libraries -join ' ')] in target_link_libraries call"
						Write-Host "`r`t`t* [LinkedExt] $dependency               " -ForegroundColor Green
					}
	
					if (!$Installed.Contains($dependency)) {
						Write-Host "`r`t`t* [Installed] $dependency               " -ForegroundColor Green
					}
				} elseif ($PackageInfo[0].Contains('header only')) {
					# skip scanning cmakelists for header only package
					# enforce include anyway
					$Header = ($PackageInfo[2] -split '\s+')[0].Substring(10)
					if (!$Installed.Contains($dependency)) {
						$CMakeLists.Insert(($CMakeLists.Count - 2), "$($PackageInfo[2])") | Out-Null
						$CMakeLists.Add((Normalize "include_external($TargetName $Header)")) | Out-Null
						Write-Host "`r`t`t* [HeaderLib] $dependency               " -ForegroundColor Green
					}
				} else {
					if (!$Installed.Contains($dependency)) {
						Write-Host "`r`t`t!![Failed] $dependency               " -ForegroundColor Red
					}
					Write-Host $BuildResult
					Exit
				}
				$Installed += $dependency
			}
			$CMakeLists.Add((Normalize "include_external($TargetName `"$PSScriptRoot/Build/$TargetPath`")`n")) | Out-Null
		}
	}
}
$Header = @((Get-Date -UFormat '# !Rebuild generated @ %R %B %d'), "# DKScriptVersion $env:DKScriptVersion")
$Boiler = [IO.File]::ReadAllLines("$PSScriptRoot/cmake/CMakeLists.txt.in")
$CMakeLists = $Header + $Boiler + $CMakeLists
[IO.File]::WriteAllLines("$PSScriptRoot/CMakeLists.txt", $CMakeLists)


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
	Show-Concerns
	Invoke-Item "$PSScriptRoot/CMakeLists.txt"
	Exit
}


# @@CMake Generator
Write-Host "`tCleaning build folder..."
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction:Ignore

Write-Host "`tBuilding solution..."
$Arguments = @(
	"-DANNIVERSARY_EDITION:BOOL=$([Int32][bool ]$ANNIVERSARY_EDITION)",
	"-DMTD:BOOL=$([Int32]$MTD)"
)
foreach ($enabledDebugger in $EnableDebugger) {
	$Arguments += "-D$($enabledDebugger.ToUpper())_DEBUG_BUILD:BOOL=1"
}
$CurProject = $null
$Failed = $false
$CMake = & cmake.exe -B $PSScriptRoot/Build -S $PSScriptRoot $Arguments | Where-Object {!$Failed} | ForEach-Object {
	if ($_.StartsWith('-- Rebuilding ') -and !($_.EndsWith(' - Complete'))) {
		$CurProject = $_.Substring(14)
		Write-Host "`t`t! [Building] $CurProject" -ForegroundColor Yellow -NoNewline
	} elseif ($_.Contains('CMake Error')) {
		Write-Host "`r`t`t* [Failed] $CurProject               " -ForegroundColor Red
		$Failed = $true
	} elseif ($_.StartsWith('-- Rebuilding ') -and $_.EndsWith(' - Complete')) {
		Write-Host "`r`t`t* [Complete] $CurProject               " -ForegroundColor Cyan
	}
	$_
}

if ($CMake[-2] -ne '-- Generating done') {
	Write-Host "`tRebuild failed!" -ForegroundColor Red
} else {
	Write-Host "`tRebuild complete!" -ForegroundColor Green
	Invoke-Item "$PSScriptRoot/Build"

	Show-Concerns
}
