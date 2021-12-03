#Requires -Version 5

# args
param(
	[ValidateSet('MT', 'MD', 'BOOTSTRAP', '')][string]$Mode0,
	[ValidateSet('AE', 'SE', '')][string]$Mode1,
	[ValidateSet(0)]$CustomCLib
)

$ErrorActionPreference = 'Stop'

$env:RebuildInvoke = $true
$env:DKScriptVersion = '11203'
$env:BuildConfig = $Mode0
$env:BuildTarget = $Mode1

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$admin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "`tDKScriptVersion $env:DKScriptVersion`t$Mode0`t$Mode1`n"

# @@BOOTSTRAP
if ($Mode0 -eq 'BOOTSTRAP') {
	if (-not $admin) {
		Write-Host "`tExecute with admin privilege to continue!" -ForegroundColor Red
		Exit
	}

	$Signed = Get-AuthenticodeSignature "$PSScriptRoot\!Rebuild.ps1"
	if ($Signed.Status -ne 'Valid') {
		Write-Host "`t! Self signing updating..." -ForegroundColor Yellow -NoNewline
		$scriptCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=DKScriptSelfCert' }
		if (-not $scriptCert) {
			$authenticode = New-SelfSignedCertificate -Subject 'DKScriptSelfCert' -CertStoreLocation Cert:\LocalMachine\My -Type CodeSigningCert
			foreach($store in @('Root', 'TrustedPublisher')) {
				$Cert = [System.Security.Cryptography.X509Certificates.X509Store]::new($store, 'LocalMachine')
				$Cert.Open('ReadWrite')
				$Cert.Add($authenticode)
				$Cert.Close()
			}
		}
		$scriptCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=DKScriptSelfCert' }
		@('!MakeNew.ps1', '!Rebuild.ps1', '!Update.ps1') | ForEach-Object {
			Set-AuthenticodeSignature "$PSScriptRoot/$_" -Certificate $scriptCert -TimeStampServer 'http://timestamp.digicert.com' | Out-Null
		}

		$Signed = Get-AuthenticodeSignature "$PSScriptRoot\!Rebuild.ps1"
		if ($Signed.Status -ne 'Valid') {
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
		Start-Job {[Environment]::SetEnvironmentVariable($using:env, $null, 'Machine')} | Out-Null
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
		
		$CurrentEnv = [System.Environment]::GetEnvironmentVariable($EnvName, 'Machine')
		if (Test-Path "$CurrentEnv/$Token" -PathType Leaf) {
			Write-Host "`n`t* Checked out $RepoName" -ForegroundColor Green
			return
		} elseif (Test-Path "$PSScriptRoot/$Path/$Token" -PathType Leaf) {
			Write-Host "`n`t* Located local $RepoName   " -ForegroundColor Green
			Push-Location $Path
			try {
				& git checkout -f master -q
			} finally {
				Pop-Location
			}
		} else {
			Remove-Item "$PSScriptRoot/$Path" -Recurse -Force -Confirm:$false -ErrorAction Ignore
			Write-Host "`n`t- Bootstrapping $RepoName..." -ForegroundColor Yellow -NoNewline
			& git clone $RemoteUrl $Path -q
			Write-Host "`r`t- Installed $RepoName               " -ForegroundColor Green
		}
		
		Write-Host "`t`t- Mapping path, please wait..." -NoNewline
		$CurrentEnv = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$PSScriptRoot/$Path")
		Start-Job {[System.Environment]::SetEnvironmentVariable($using:EnvName, $using:CurrentEnv, 'Machine')} | Out-Null
		Write-Host "`r`t`t- $EnvName has been set to [$CurrentEnv]               "
	}

	function Find-Game {
		param (
			[string]$EnvName,
			[string]$GameName
		)
		
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
				Start-Job {[System.Environment]::SetEnvironmentVariable($using:EnvName, $using:CurrentEnv, 'Machine')} | Out-Null
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
				Start-Job {[System.Environment]::SetEnvironmentVariable($using:MO2EnvName, $using:MO2Dir, 'Machine')} | Out-Null
				Write-Host "`r`t* Enabled MO2 support for $GameName               " -ForegroundColor Green
				break
			} else {
				$Result = [Microsoft.VisualBasic.Interaction]::MsgBox("Not a valid MO2 path, try again?`n`nMO2 directory contains /mods, /profiles, and /override folders", 52, 'MO2 Support')
			}
		}
	}

	Write-Host "`t>>> Checking out requirements... <<<" -ForegroundColor Yellow

	# VCPKG_ROOT
	Initialize-Repo 'VCPKG_ROOT' 'VCPKG' 'vcpkg.exe' 'vcpkg' 'https://github.com/microsoft/vcpkg'
	$env:VCPKG_ROOT = [System.Environment]::GetEnvironmentVariable('VCPKG_ROOT', 'Machine')
	Start-Job {
		& $env:VCPKG_ROOT\bootstrap-vcpkg.bat
		& $env:VCPKG_ROOT\vcpkg.exe integrate install
	} | Out-Null

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
			Start-Job {[System.Environment]::SetEnvironmentVariable('CustomCommonLibSSEPath', $using:CustomCLibDir, 'Machine')} | Out-Null
			Write-Host "`t`t- CustomCommonLibSSEPath has been set to [$($CustomCLibDir)]"
			Write-Host "`t`t# To use custom CommonLib in build, append parameter '0' to the !Rebuild command."
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

	$Author
	while (-not $Author) {
		$Author = [Microsoft.VisualBasic.Interaction]::InputBox("Input the mod author name:`n`nThis is used for !MakeNew command to generate projects", 'Author', 'Anon')
	}
	Start-Job {[System.Environment]::SetEnvironmentVariable('SKSEPluginAuthor', $using:Author, 'Machine')} | Out-Null
	Write-Host "`n`t* Plugin author: $Author" -ForegroundColor Magenta

	Write-Host "`n`t>>> Bootstrapping finishing up... <<<" -ForegroundColor Green
	Get-Job | Wait-Job | Out-Null
	Get-Job | Remove-Job | Out-Null

	Write-Host "`n`tRestart current command line interface to complete BOOTSTRAP."
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

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

set(SKSE_SUPPORT_XBYAK ON)
set(DKUTIL_DEBUG_BUILD ON)

# out-of-source builds only
if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
	message(FATAL_ERROR "In-source builds are not allowed.")
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
	"$ENV{DKUtilPath}/cmake/CLibCustomCMakeLists.txt.in"
	"$ENV{CommonLibSSEPath}/CMakeLists.txt"
	COPYONLY
)

'@
$Trail += "add_subdirectory(`"$Resolved`" `"CLib`")`n"
$Trail += "message(CHECK_PASS `"Complete`")`n`n"

# clib dependencies
$vcpkg = [IO.File]::ReadAllText("$env:CommonLibSSEPath/vcpkg.json") | ConvertFrom-Json
$Dependencies += $vcpkg.'dependencies'
$Dependencies += 'xbyak'

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
			$vcpkg = [IO.File]::ReadAllText("$PSScriptRoot/$_/vcpkg.json") | ConvertFrom-Json
			$Dependencies += $vcpkg.'dependencies'

			$projectDir = $_.Substring(2) -replace '\\', '/'
			$Trail += "message(CHECK_START `"Rebuilding $projectDir`")`n"
			$Trail += "add_subdirectory(`"$projectDir`")`n"
			$Trail += "message(CHECK_PASS `"Complete`")`n`n"
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
		Write-Host "`r`t`t* [Complete] $_               " -ForegroundColor Green
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
		Write-Host "`r`t`t* [Complete] $CurProject               " -ForegroundColor Cyan
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

# SIG # Begin signature block
# MIIR2wYJKoZIhvcNAQcCoIIRzDCCEcgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUc4JonWZ3z8Fg1GyN1rI2cTYd
# ss6ggg1BMIIDBjCCAe6gAwIBAgIQZAPCkAxHzpxOvoeEUruLiDANBgkqhkiG9w0B
# AQsFADAbMRkwFwYDVQQDDBBES1NjcmlwdFNlbGZDZXJ0MB4XDTIxMTIwMjEyMzYz
# MFoXDTIyMTIwMjEyNTYzMFowGzEZMBcGA1UEAwwQREtTY3JpcHRTZWxmQ2VydDCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9d3xGpFZgLEPcI1mIG8OPB
# GjeIk3zIyaanh/Z7XRcL3kz21M5/k/hATY9JRjMzciJVLnFT46vW2DRCJrp0oKyA
# Uj2oE2jrvrUueS7Pu9WVVDN+nIWbW1lzlDutZ7uEMRaAQT8OgpsRTY/nA11Fvipb
# kwK4tgpAjMQdxrqstxB+nbV9AcsgRh4YdzpkjoDm2Di8CQw5pEaBw2wAJO1GxH+D
# UjU1xlbqRdgJVhjMMyg7p4LqwUQoZs7lAFINBwqC13m2qMr/m0lsgNny/0l8IRV/
# m5RyAihlc8KvZbk/4oWs5hZjaOc5PKKi+d4wPpNw2T799bJSjOFEAcvPtqoK80EC
# AwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0G
# A1UdDgQWBBSxj44nD0I+OD6c+ON8obenSrsbczANBgkqhkiG9w0BAQsFAAOCAQEA
# J3YfLurEb8s51SBiDcuB2P00jHcZxYKwUNOqUfvjOUuvQu2UFKAbuM6y3ku6fMHC
# s5Sp/WKnxPsa4aN+TgEi4ZB1f8G8VOsxnJd45t53BcBppxDY+YnaaP+M9iH0c+Bv
# 5uKwl0+PwxsLyG1q2kTC7kjDO8zsBBwkHmksnZK7R7GgeStmftmylBaggFbbRAj9
# en0IJocxsDYpbUxevTvwlHFlw1FvUbotDeug6Rlz7v/UPslNEi4JaylIpBju72me
# AKkhNgwJyELUVr3iNQ1AG80QVaf6Yg6hzMcQTv1M/lOSl+wK+6SBgJ973eXT9FeJ
# +7lIvb7kxLaPhIOLBMi72DCCBP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0w
# DQYJKoZIhvcNAQELBQAwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0
# IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNl
# cnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTAeFw0yMTAxMDEwMDAw
# MDBaFw0zMTAxMDYwMDAwMDBaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjEwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDC5mGEZ8WK9Q0IpEXKY2tR1zoR
# Qr0KdXVNlLQMULUmEP4dyG+RawyW5xpcSO9E5b+bYc0VkWJauP9nC5xj/TZqgfop
# +N0rcIXeAhjzeG28ffnHbQk9vmp2h+mKvfiEXR52yeTGdnY6U9HR01o2j8aj4S8b
# Ordh1nPsTm0zinxdRS1LsVDmQTo3VobckyON91Al6GTm3dOPL1e1hyDrDo4s1SPa
# 9E14RuMDgzEpSlwMMYpKjIjF9zBa+RSvFV9sQ0kJ/SYjU/aNY+gaq1uxHTDCm2mC
# tNv8VlS8H6GHq756WwogL0sJyZWnjbL61mOLTqVyHO6fegFz+BnW/g1JhL0BAgMB
# AAGjggG4MIIBtDAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDBBBgNVHSAEOjA4MDYGCWCGSAGG/WwHATApMCcGCCsG
# AQUFBwIBFhtodHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwHwYDVR0jBBgwFoAU
# 9LbhIB3+Ka7S5GGlsqIlssgXNW4wHQYDVR0OBBYEFDZEho6kurBmvrwoLR1ENt3j
# anq8MHEGA1UdHwRqMGgwMqAwoC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9z
# aGEyLWFzc3VyZWQtdHMuY3JsMDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5j
# b20vc2hhMi1hc3N1cmVkLXRzLmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUF
# BzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6
# Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1l
# c3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggEBAEgc3LXpmiO85xrnIA6O
# Z0b9QnJRdAojR6OrktIlxHBZvhSg5SeBpU0UFRkHefDRBMOG2Tu9/kQCZk3taaQP
# 9rhwz2Lo9VFKeHk2eie38+dSn5On7UOee+e03UEiifuHokYDTvz0/rdkd2NfI1Jp
# g4L6GlPtkMyNoRdzDfTzZTlwS/Oc1np72gy8PTLQG8v1Yfx1CAB2vIEO+MDhXM/E
# EXLnG2RJ2CKadRVC9S0yOIHa9GCiurRS+1zgYSQlT7LfySmoc0NR2r1j1h9bm/cu
# G08THfdKDXF+l7f0P4TrweOjSaH6zqe/Vs+6WXZhiV9+p7SOZ3j5NpjhyyjaW4em
# ii8wggUxMIIEGaADAgECAhAKoSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUA
# MGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQg
# Um9vdCBDQTAeFw0xNjAxMDcxMjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1l
# c3RhbXBpbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLu
# S82Pf92puoKZxTlUKFe2I0rEDgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8
# V9PD4X4I1moUADj3Lh477sym9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/
# fpX786O6Ij4YrBHk8JkDbTuFfAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpc
# t1HhoXkUxk0kIzBdvOw8YGqsLwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCos
# p+R1PrqYD4R/nzEU1q3V8mTLex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyv
# z9qsEPXdrKzpVv+TAgMBAAGjggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGl
# sqIlssgXNW4wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0T
# AQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaG
# NGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwUAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYI
# KwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9
# bAcBMA0GCSqGSIb3DQEBCwUAA4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9L
# hL/KzwMC/cWnww4gQiyvd/MrHwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHY
# fBli6F6CJR7Euhx7LCHi1lssFDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSH
# Y4yRUiyvKYnleB/WCxSlgNcSR3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5
# KHW3mWOFIoxhynmUfln8jA/jb7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwII
# fEmuE7bhfEJCKMYYVs9BNLZmXbZ0e/VWMyIvIjayS6JKldj1po5SMYIEBDCCBAAC
# AQEwLzAbMRkwFwYDVQQDDBBES1NjcmlwdFNlbGZDZXJ0AhBkA8KQDEfOnE6+h4RS
# u4uIMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqG
# SIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3
# AgEVMCMGCSqGSIb3DQEJBDEWBBSWiLVj7aOz4o0A0gYlM+X1HCA2mzANBgkqhkiG
# 9w0BAQEFAASCAQCR1hkPOMCNzbTyptRYV5FzckqOTYe2JnGzgabxMwTFymZR5Yxa
# 4XJLWSTv8dbi0xhONHXmYyVHsjhraX9BOG0ulz5blp/3Zvk3U2Mr5JkFewGIE8Vf
# lGW+pB84OgXGl78iqtSTJeIfv6G9a8uVo2ZG1iNsKeOVJ4Es0hz7cZh/Qd2C8DsV
# ylVX+0PzqmZp6wLR/kWcPwRcc2FoqK52ZHcII35TeZ186qozSgQjChWNYG9ITlHm
# mDPjplJkwoRtoHr9f/6D5bQkzrPNYdq9tGJ+zFNgx0F6xGUOWYg8LIGoUFXCzJ8W
# Gg4niYzynY94cRU0T3iyW5rEQckUA3nFvy08oYICMDCCAiwGCSqGSIb3DQEJBjGC
# Ah0wggIZAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0ECEA1CSuC+Ooj/YEAhzhQA
# 8N0wDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yMTEyMDMxNzIxNTFaMC8GCSqGSIb3DQEJBDEiBCCqMTOE
# GTGLd0k1amVTurQ3VT2BRgdEVHeitxpRAxGsWzANBgkqhkiG9w0BAQEFAASCAQBO
# Vyvrm42PrFX9L4K4j3l2UsDBsUdvDKeA0LuYOZGwidFXAc45eydwUrzfaykkgKrs
# PEAg2FwU0PKHLloNHVQcL4iGK2cLadFFA4A83ZNSFAoqOjsV51XZ9AeCptvXIlL2
# P1NCIEXirDCuS9ZjGKSYJWbVuLbLrGq2EqN5etaS3ZqjwPCcLoFuYH3ScI1YOyfF
# 7iUi/RkblXq50/AQmvzj0kSdYXnyXaw9HubjArNTEsWScer8Gg9v9pccTtSKBbWw
# byU5vFXzz95eKtQ5EHzYlgRVOFLxZmWXJ1J++ZLWP7yJJqbCpansA06MIv7cPFKR
# HCgDRse4nzECOMW6Br6/
# SIG # End signature block
