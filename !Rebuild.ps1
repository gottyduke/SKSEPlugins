# args
param(
	[string]$Mode0,
	[string]$Mode1,
	[string]$CustomCLib
)

$env:DKScriptVersion = '11129'
$env:BuildConfig = $Mode0
$env:BuildTarget = $Mode1

$ErrorActionPreference = 'Stop'

$Header = (Get-Date -UFormat "# Auto generated @ %R %B %d`n") + "cmake_minimum_required(VERSION 3.19) `n`nset(LINKAGE_OVERRIDE "
$isAE
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

# build configuration
if ($Mode0 -eq 'MT') {
	$Header = $Header + "FALSE CACHE BOOL `"`")`n"
	Write-Host "`t***** Building Static MultiThreaded *****`n`tvcpkg : x64-windows-static" -ForegroundColor DarkGreen
} elseif ($Mode0 -eq 'MD') {
	$Header = $Header + "TRUE CACHE BOOL `"`")`n"
	Write-Host "`t***** Building Runtime MultiThreadedDLL *****`n`tvcpkg : x64-windows-static-md" -ForegroundColor Red
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

# build target
if ($Mode1 -eq 'AE') {
	Write-Host "`tTarget: Anniversary Edition" -ForegroundColor Yellow
	$isAE = 'TRUE'
} elseif ($Mode1 -eq 'SE') {
	Write-Host "`tTarget: Special Edition" -ForegroundColor Blue
	$isAE = 'FALSE'
} else {
	Write-Host "`tUnknown game version specified!" -ForegroundColor Red
	Pop-Location
	Exit
}

# clib integration
$Resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CustomCLib)
if ($CustomCLib -and (Test-Path "$Resolved/CMakeLists.txt" -PathType Leaf)) { # manual assign path
	Write-Host "`t==> Rebasing custom CLib <==" -ForegroundColor Red
	$env:CommonLibSSEPath = $Resolved
	$Resolved = (Resolve-Path $Resolved -Relative) + " $PSScriptRoot/Build/Clib" -replace '\\', '/'
	$Trail = $Trail + "add_subdirectory($Resolved)`n`n"
} elseif ($CustomCLib -eq '0') { # default env flag
	Write-Host "`t==> Rebasing custom CLib <==" -ForegroundColor Red
	$Resolved = (Resolve-Path $env:CommonLibSSEPath -Relative) + " $PSScriptRoot/Build/Clib" -replace '\\', '/'
	$Trail = $Trail + "add_subdirectory($Resolved)`n`n"
} else {
	Push-Location $env:CommonLibSSEPath
	if ($Mode1 -eq 'AE') {
		Write-Host "`t==> Rebasing latest CLib <==" -ForegroundColor Green
		& git checkout -f master -q
	} elseif ($Mode1 -eq 'SE') {
		Write-Host "`t==> Rebasing legacy CLib <==" -ForegroundColor Green
		& git checkout -f 575f84a -q
	}
	Pop-Location	
	
	# use custom CMakeLists for CommonLibSSE
	$Trail = $Trail + @'

configure_file(
	${CMAKE_CURRENT_SOURCE_DIR}/Library/ClibCustomCMakeLists.txt.in
	$ENV{CommonLibSSEPath}/CMakeLists.txt
	COPYONLY
)

add_subdirectory($ENV{CommonLibSSEPath})

'@
}
$Header = $Header + "set(ANNIVERSARY_EDITION $isAE CACHE BOOL `"`")`n`n"

# clean build folder
Write-Host "`tCleaning build folder..."
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction Ignore

# manage all sub projects
Write-Host "`tGenerating CMakeLists.txt for projects below:"
@('Library', 'Plugins') | ForEach-Object {
	$Trail = $Trail + "`nset(GROUP $_)`n"
	Get-ChildItem $_ -Directory -Exclude 'CommonLibSSE' -Recurse -ErrorAction SilentlyContinue | Resolve-Path -Relative | ForEach-Object {
		if (Test-Path "$PSScriptRoot/$_/CMakeLists.txt" -PathType Leaf) {
			$projectDir = $_.Substring(2) -replace '\\', '/'
			Write-Host "`t`t$projectDir" -ForegroundColor Cyan
			$Trail = $Trail + "add_subdirectory(`"$projectDir`")`n"
		}
	}
}

$CMakeLists = $Header + $Boiler +$Trail
[IO.File]::WriteAllText("$PSScriptRoot/CMakeLists.txt", $CMakeLists)

# cmake
Write-Host "`tExecuting CMake..." -ForegroundColor Yellow
& cmake.exe -B $PSScriptRoot/Build -S $PSScriptRoot
# SIG # Begin signature block
# MIIR2wYJKoZIhvcNAQcCoIIRzDCCEcgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnhLo5xB6j5FsTHKqdrVWb+/H
# U5Gggg1BMIIDBjCCAe6gAwIBAgIQNkaQTCtrQ7NPmyNqlKMtlDANBgkqhkiG9w0B
# AQsFADAbMRkwFwYDVQQDDBBBVEEgQXV0aGVudGljb2RlMB4XDTIxMTEyODE1MTMy
# N1oXDTIyMTEyODE1MzMyN1owGzEZMBcGA1UEAwwQQVRBIEF1dGhlbnRpY29kZTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANoBGMeVEUQXzEw352NicaE9
# H9qoHFmrmW68zQjba83QxL/7J60JXEOJJNfwmpuo3sJ98y2InmjOezppuNLsAAfH
# E280/6I4LYNvNj3HYGlWj9VJw5me7PImeMUJcahxLXTzSaUYBjo4xN/Y4THhKKY6
# CSSgP6ZFfQ2/U/JSuun7UIj7p2FQKfVo+Ig46INmkHN/J/Xp3LoGfFVJLszeLcvR
# RkcNtRM+9goAEJEQOXjWXNNDykyK/4Sewdknd0aKPUgRvZBgdlWvWcEhCamO9jOv
# N8azWT7qOkTLGwZ7EdzzW+6KUA+SjXgeYvFjAEu4Gvj0mIrnSgR7eY4hCdM37o0C
# AwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0G
# A1UdDgQWBBQgLXQ3KqF1NorX3f6viGK+8dWA8zANBgkqhkiG9w0BAQsFAAOCAQEA
# cgLeEdX+96c5JJ+WnzABZX4hpjXuIv8E9S+gbuEryEi1ikoe9CfU9atkytG+denQ
# E+7drWb1TGQx4BIOmmNCE3j1vbrzct3aYMIjodDaYPmC/2/5bjuAW14b3Zg1Pull
# 9MaVwH/xxM6iF4KlVzkk42iB7/A3HkgoScXn1n28xVBigvB8wQdZG/sZXmPtTGTE
# 2KdyffvwmkDUBDt1s2/ufPpUpBLMjVDk1dK2Kn3zd29osUL0A42OzkIo/egtu3fz
# 6vt5EH9LceFwEnTnWEE2mZkHcmOiYf0GG+bUwYXoPGd1YX8ZnSozdb66oIpUKSnY
# ZmPzyWZE5c9A8Y6RxPIM9zCCBP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0w
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
# AQEwLzAbMRkwFwYDVQQDDBBBVEEgQXV0aGVudGljb2RlAhA2RpBMK2tDs0+bI2qU
# oy2UMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqG
# SIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3
# AgEVMCMGCSqGSIb3DQEJBDEWBBQOEh/oCot1Fr+2jXPxvU8SEiYKbzANBgkqhkiG
# 9w0BAQEFAASCAQAJ09IECKTiUec6SMNlNzGMvI8QEpvdk1Wu9nmm+W/VodzeT3Qu
# SzLlxaL1te0Nv0i3F6rCiVgjkThCPe8iS6ztAj51nJJuYlrzqVKzJ+CdWXCIUfyG
# BQm8RXU9cuG3Uk/REZ+mfQu6khFH63hkmEZDKxKTEZl8fzLe8DP75SqWNkaGuG7s
# KlM3EVIBn3rbbNBuvlsbyU+p6lJWf53555WhXOqX1j4m3nW9EcpYl/CTNetGhafe
# iVJHGyqVIRCy+zO0jofMELam4DkYijIkcan37XK00BxrapTH6P3KWBMaUwISlnkq
# X8wBK7nR1dkgM4Cs3qo9rKINezMJR+5NsA7MoYICMDCCAiwGCSqGSIb3DQEJBjGC
# Ah0wggIZAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0ECEA1CSuC+Ooj/YEAhzhQA
# 8N0wDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yMTExMjkxMjM5NTBaMC8GCSqGSIb3DQEJBDEiBCCJsjh/
# yiEqKTtscAVXFwSVNE0UoO0Svb/mUX3EbgmVczANBgkqhkiG9w0BAQEFAASCAQCK
# LdoS+nWXrhMUgi3UtluP3FVrI0jHMZ/gRdJtcuG/kwoBMLJ9WfX/WiShMH18AlBm
# DAdsmoJYfAnYB99mKbdSqwOfCx+LoMtk6/vWGg7PZ6O4TK9OopaZ9gG67vUX0HNH
# +V5cdcYWgy4UFwgVIeFXnLDV+bU9SxT0Vj4lOTu9mGRymv8c9e1jQFYB/VG3RLWI
# ml4pc8G18SwHAkq8uyh4byx++lipIYzokZVSDt8L4gnNi3Kb+r5m2fp7XW73McT+
# Isp+sxFrzbETe6VNx8FGpEaMVGtLDE/CfvMu6CTPIh3a5p0hPcw0Vl7cRvCnkZJQ
# zSDmCVHn5HafoPYPaVVo
# SIG # End signature block
