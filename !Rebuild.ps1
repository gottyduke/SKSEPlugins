#Requires -Version 5

# args
param(
	[ValidateSet('MT', 'MD', 'BOOTSTRAP', '')][string]$Mode0,
	[ValidateSet('AE', 'SE', 'REDO', '')][string]$Mode1,
	[ValidateSet(0)]$CustomCLib
)

$ErrorActionPreference = 'Stop'

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$admin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$env:RebuildInvoke = $true
$env:DKScriptVersion = '11201'
$env:BuildConfig = $Mode0
$env:BuildTarget = $Mode1

Write-Host "`tDKScriptVersion $env:DKScriptVersion`t$Mode0`t$Mode1`n"

# @@BOOTSTRAP
if ($Mode0 -eq 'BOOTSTRAP') {
	if (-not $admin) {
		Write-Host "`tExecute with admin privilege to continue!" -ForegroundColor Red
		Exit
	}
	Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
	Add-Type -AssemblyName System.Windows.Forms | Out-Null

	if ($Mode1 -eq 'REDO') {
		Write-Host "`tBOOTSTRAP REDO, please wait..." -ForegroundColor Red -NoNewline
		[Environment]::SetEnvironmentVariable('CommonLibSSEPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('CustomCommonLibSSEPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('DKUtilPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('SkyrimSEPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('SkyrimAEPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('MO2SkyrimSEPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('MO2SkyrimAEPath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('SKSETemplatePath', $null, 'Machine')
		[Environment]::SetEnvironmentVariable('SKSEPluginAuthor', $null, 'Machine')
		Write-Host "`r`tBOOTSTRAP initiated!        " -ForegroundColor Yellow
	}

	function Initialize-Repo {
		param (
			[string]$EnvName,
			[string]$RepoName,
			[string]$Token,
			[string]$Path,
			[string]$RemoteUrl
		)

		$CurrentEnv = [Environment]::GetEnvironmentVariable($EnvName, 'Machine')
		if (-not (Test-Path "$CurrentEnv/$Token" -PathType Leaf)) {
			Write-Host "`n`t! Missing $RepoName" -ForegroundColor Red -NoNewline
		
			if (Test-Path "$PSScriptRoot/$Path/$Token" -PathType Leaf) {
				Write-Host "`r`t* Located local $RepoName, mapping latest" -ForegroundColor Green
			} else {
				Remove-Item "$PSScriptRoot/$Path" -Recurse -Force -Confirm:$false -ErrorAction Ignore
				Write-Host "`r`t- Bootstrapping $EnvName..." -ForegroundColor Yellow -NoNewline
				& git clone $RemoteUrl $Path -q
				Write-Host "`r`t- Installed $RepoName, mapping path" -ForegroundColor Green
			}
		
			$CurrentEnv = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$PSScriptRoot/$Path")
			[System.Environment]::SetEnvironmentVariable($EnvName, $CurrentEnv, 'Machine')
			Write-Host "`t`t- $EnvName has been set to [$CurrentEnv]"
		} else {
			Write-Host "`n`t* Checked out $RepoName" -ForegroundColor Green
		}
	}

	function Find-Game {
		param (
			[string]$EnvName,
			[string]$GameName
		)
		
		$CurrentEnv = [Environment]::GetEnvironmentVariable($EnvName, 'Machine')
		if (-not (Test-Path "$CurrentEnv/SkyrimSE.exe" -PathType Leaf)) {
			Write-Host "`n`t! Missing $GameName" -ForegroundColor Red -NoNewline
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Add build support for $($GameName)?`nMake sure to select correct version of game if proceeding.", 36, 'Game Build Support')		
			while ($Result -eq 6) {
				$SkyrimFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
					Title = "Select $($GameName) Executable"
					Filter = 'Skyrim Game (SkyrimSE.exe) | SkyrimSE.exe'
				}
			
				$SkyrimFile.ShowDialog() | Out-Null
				if (Test-Path $SkyrimFile.Filename -PathType Leaf) {
					$CurrentEnv = Split-Path $SkyrimFile.Filename
					Write-Host "`r`t* Located $GameName" -ForegroundColor Green
					[System.Environment]::SetEnvironmentVariable($EnvName, $CurrentEnv, 'Machine')
					Write-Host "`t`t- $EnvName has been set to [$CurrentEnv]"
					break
				} else {
					$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Unable to locate $($GameName), try again?", 52, 'Game Build Support')		
				}
			}
		} else {
			Write-Host "`n`t* Checked out $GameName" -ForegroundColor Green
		}

		$MO2EnvName = 'MO2' + $EnvName
		if (Test-Path "$([Environment]::GetEnvironmentVariable($MO2EnvName, 'Machine'))/mods" -PathType Container) {
			Write-Host "`t* Enabled MO2 support for $GameName" -ForegroundColor Green
		} else {
			$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Enable MO2 support for $($GameName)?`nMO2 Support: Allows plugin to be directly copied to MO2 directory for faster debugging.", 36, 'MO2 Support')
			while ($Result -eq 6) {
				$MO2Dir = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
					Description = "Select MO2 directory for $($GameName), containing /mods, /profiles, and /override folders."
					ShowNewFolderButton = $false
				}
	
				$MO2Dir.ShowDialog() | Out-Null
				if (Test-Path "$($MO2Dir.SelectedPath)/mods" -PathType Container) {
					[System.Environment]::SetEnvironmentVariable($MO2EnvName, $MO2Dir.SelectedPath, 'Machine')
					break
				} else {
					$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Not a valid MO2 path, try again?`nMO2 directory contains /mods, /profiles, and /override folders", 52, 'MO2 Support')
				}
			}
		}
	}

	Write-Host "`t>>> Checking out requirements... <<<" -ForegroundColor Yellow

	# VCPKG_ROOT
	Initialize-Repo 'VCPKG_ROOT' 'VCPKG' 'vcpkg.exe' 'vcpkg' 'https://github.com/microsoft/vcpkg' 
	& .\vcpkg\bootstrap-vcpkg.bat | Out-Null
	& .\vcpkg\vcpkg.exe integrate install | Out-Null

	# CommonLibSSEPath
	Initialize-Repo 'CommonLibSSEPath' 'CommonLib' 'CMakeLists.txt' 'Library/CommonLibSSE' 'https://github.com/Ryan-rsm-McKenzie/CommonLibSSE'
	if (-not (Test-Path "$env:CustomCommonLibSSEPath/CMakeLists.txt" -PathType Leaf)) {
		$Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Enable custom CLib support?', 36, 'Custom CLib support') 
		while ($Result -eq 6) {
			$CustomCLibDir = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
				Description = 'Select custom CLib directory, containing CMakeLists.txt'
			}
		
			$CustomCLibDir.ShowDialog() | Out-Null
			if (Test-Path "$($CustomCLibDir.SelectedPath)/CMakeLists.txt" -PathType Leaf) {
				Write-Host "`t* Located custom CLib`n`t`t# To use custom CLib in build, append parameter '0' to the !Rebuild command."
				[System.Environment]::SetEnvironmentVariable('CustomCommonLibSSEPath', $CustomCLibDir.SelectedPath, 'Machine')
				Write-Host "`t- CustomCommonLibSSEPath has been set to [$($CustomCLibDir.SelectedPath)]" -ForegroundColor Green
				break
			} else {
				$Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Unable to locate valid CMakeLists.txt, try again?', 52, 'Custom CLib support')		
			}
		}
	} else {
		Write-Host "`t* Checked out custom CLib" -ForegroundColor Green
	}

	# DKUtilPath
	Initialize-Repo 'DKUtilPath' 'DKUtil' 'CMakeLists.txt' 'Library/DKUtil' 'https://github.com/gottyduke/DKUtil'

	# SKSETemplatePath
	Initialize-Repo 'SKSETemplatePath' 'SKSETemplate' 'CMakeLists.txt' 'Plugins/Template' 'https://github.com/gottyduke/Template'

	# SkyrimSEPath
	Find-Game 'SkyrimSEPath' 'Skyrim Special Edition (1.5.97)'

	# SkyrimAEPath
	Find-Game 'SkyrimAEPath' 'Skyrim Anniversary Edition (1.6.xxx)'

	$Author = [Microsoft.VisualBasic.Interaction]::InputBox('Input the mod author name:', 'Author', 'Anon')
	Write-Host "`n`t* Plugin author: $Author" -ForegroundColor Magenta
	[System.Environment]::SetEnvironmentVariable('SKSEPluginAuthor', $Author, 'Machine')

	Write-Host "`n`t>>> Bootstrapping has finished! <<<" -ForegroundColor Green
	Write-Host "`tRestart current command line interface to apply settings."
	Exit
}

# CMakeLists.txt
$Header = (Get-Date -UFormat "# Auto generated @ %R %B %d`n") + "cmake_minimum_required(VERSION 3.19) `n`nset(LINKAGE_OVERRIDE "
$IsAE
$Boiler = @'
set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")

if (LINKAGE_OVERRIDE)

set(VCPKG_TARGET_TRIPLET "x64-windows-static-md" CACHE STRING "")
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" CACHE STRING "")

else()

set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "")
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>" CACHE STRING "")

endif()

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# info
project(
	skse64
	LANGUAGES CXX
)

# update script for sourcelist.cmake generation
execute_process(COMMAND powershell -ExecutionPolicy Bypass -File "${CMAKE_CURRENT_SOURCE_DIR}/!Update.ps1" "DISTRIBUTE")

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(SKSE_SUPPORT_XBYAK ON)
set(DKUTIL_DEBUG_BUILD ON)

# out-of-source builds only
if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
	message(
		FATAL_ERROR
			"In-source builds are not allowed."
	)
endif()

'@
$Trail = "`n`nset(GROUP CLib)`n"
$CMakeLists
[string[]]$Dependencies
$Triplet

# @@Build Config
if ($Mode0 -eq 'MT') {
	$Header += "FALSE CACHE BOOL `"`")`n"
	$Triplet = "x64-windows-static"
	Write-Host "`t***** Static MultiThreaded *****" -ForegroundColor DarkGreen
} elseif ($Mode0 -eq 'MD') {
	$Header += "TRUE CACHE BOOL `"`")`n"
	$Triplet = "x64-windows-static-md"
	Write-Host "`t***** Runtime MultiThreadedDLL *****" -ForegroundColor DarkMagenta
} else { # trigger zero_check
	if (-not (Test-Path "$PSScriptRoot/CMakeLists.txt" -PathType Leaf)) {
		Write-Host "`tRun !Rebuild in MT or MD mode first." -ForegroundColor Red
		Exit
	}

	$file = [IO.File]::ReadAllText("$PSScriptRoot/CMakeLists.txt")
	[IO.File]::WriteAllLines("$PSScriptRoot/CMakeLists.txt", $file)
	Write-Host "`t++ ZERO_CHECK ++"
	Exit
}

# @@Build Target
if ($Mode1 -eq 'AE' -and $env:SkyrimAEPath) {
	Write-Host "`tTarget: Anniversary Edition" -ForegroundColor Yellow
	$IsAE = 'TRUE'
} elseif ($Mode1 -eq 'SE' -and $env:SkyrimSEPath) {
	Write-Host "`tTarget: Special Edition" -ForegroundColor Yellow
	$IsAE = 'FALSE'
} else {
	Write-Host "`tUnknown game version specified!`n`tOR:`n`tIncorrect BOOTSTRAP" -ForegroundColor Red
	Exit
}

# @@Custom CLib 0
$Resolved = ""
if (($CustomCLib -eq 0) -and (Test-Path "$env:CustomCommonLibSSEPath/CMakeLists.txt" -PathType Leaf)) {
	Write-Host "`t==> Rebasing custom CLib <==" -ForegroundColor Red
	$Trail += "message(CHECK_START `"Rebuilding CustomCommonLib`")`n"
	$Resolved = (Resolve-Path $env:CustomCommonLibSSEPath -Relative) -replace '\\', '/'
} else {
	if (Test-Path "$env:CommonLibSSEPath/CMakeLists.txt" -PathType Leaf) {
		Push-Location $env:CommonLibSSEPath
		try {
			if ($Mode1 -eq 'AE') {
				Write-Host "`t==> Rebasing latest CLib <==" -ForegroundColor Green
				$Trail += "`nmessage(CHECK_START `"Rebuilding LatestCommonLib`")`n"
				& git checkout -f master -q
			} elseif ($Mode1 -eq 'SE') {
				Write-Host "`t==> Rebasing legacy CLib <==" -ForegroundColor Green
				$Trail += "`nmessage(CHECK_START `"Rebuilding LegacyCommonLib`")`n"
				& git checkout -f 575f84a -q
			}
		} finally {
			Pop-Location
		}
		$Resolved = (Resolve-Path $env:CommonLibSSEPath -Relative) -replace '\\', '/'
	} else {
		Write-Host "`t==> Rebasing default CLib failed <==`n`tCommonLibSSEPath not set or incorrect" -ForegroundColor Red
		Exit
	}
}
$Trail += 'set($ENV{CommonLibSSEPath} '
$Trail += "`"$Resolved`")`n"
# use custom CMakeLists for CommonLibSSE
$Trail += @'

configure_file(
	$ENV{DKUtilPath}/cmake/CLibCustomCMakeLists.txt.in
	$ENV{CommonLibSSEPath}/CMakeLists.txt
	COPYONLY
)

'@
$Trail += "add_subdirectory(`"$Resolved`" `"Build/CLib`")`n"
$Trail += "message(CHECK_PASS `"Complete`")`n`n"

# clib dependencies
$vcpkg = [IO.File]::ReadAllText("$env:CommonLibSSEPath/vcpkg.json") | ConvertFrom-Json
$Dependencies += $vcpkg.'dependencies'

# ae switch
$Header += "set(ANNIVERSARY_EDITION $IsAE CACHE BOOL `"`")`n`n"

# clean build folder
Write-Host "`tCleaning build folder..."
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction Ignore

# manage all sub projects
Write-Host "`tBuilding CMake targets..."
@('Library', 'Plugins') | ForEach-Object {
	$Trail += "set(GROUP $_)`n`n"
	Get-ChildItem $_ -Directory -Exclude ('*CommonLibSSE*','*Template*') -Recurse | Resolve-Path -Relative | ForEach-Object {
		if (Test-Path "$PSScriptRoot/$_/CMakeLists.txt" -PathType Leaf) {
			$projectDir = $_.Substring(2) -replace '\\', '/'
			$Trail += "message(CHECK_START `"Rebuilding $projectDir`")`n"
			$Trail += "add_subdirectory(`"$projectDir`")`n"
			$Trail += "message(CHECK_PASS `"Complete`")`n`n"
			$vcpkg = [IO.File]::ReadAllText("$PSScriptRoot/$_/vcpkg.json") | ConvertFrom-Json
			$Dependencies += $vcpkg.'dependencies'
		}
	}
}

$CMakeLists = $Header + $Boiler + $Trail
[IO.File]::WriteAllText("$PSScriptRoot/CMakeLists.txt", $CMakeLists)

# build dependencies
Write-Host "`tBuilding dependencies..."
Write-Host "`t`t= [$Triplet]"
$Dependencies = $Dependencies | Select-Object -Unique | Sort-Object
$Installed = Get-ChildItem -Path $env:VCPKG_ROOT\installed\$Triplet\share -Directory -Force -ErrorAction SilentlyContinue
$Dependencies.ForEach({
	if ($Installed -and $Installed.Name.Contains($_)) {
		Write-Host "`t`t* [Installed] $_" -ForegroundColor Green
	} else {
		Write-Host "`t`t! [Building] $_" -ForegroundColor Red -NoNewline
		& $env:VCPKG_ROOT\vcpkg install ${_}:$Triplet | Out-Null
		Write-Host "`r`t`t* [Complete] $_" -ForegroundColor Green
	}
})

# cmake
Write-Host "`tBuilding solution..."
$CurProject
$CMake = & cmake.exe -B $PSScriptRoot/Build -S $PSScriptRoot | ForEach-Object {
	if ($_.StartsWith('-- Rebuilding ') -and -not ($_.EndsWith(' - Complete'))) {
		$CurProject = $_.Substring(14)
		Write-Host "`t`t! [Building] $CurProject" -ForegroundColor Yellow -NoNewline
	} elseif ($_.StartsWith('-- Rebuilding ') -and $_.EndsWith(' - Complete')) {
		Write-Host "`r`t`t* [Complete] $CurProject" -ForegroundColor Cyan
	}

	$_
}

if ($CMake[-3] -eq '-- Configuring done') {
	Write-Host "`tRebuild complete" -ForegroundColor Green
	$LegacyPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$PSScriptRoot/Build/skse64.sln")
	& explorer.exe /select, $LegacyPath
} else {
	Write-Host "`tRebuild failed" -ForegroundColor Red
}