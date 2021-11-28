$ErrorActionPreference = 'Stop'

$Header = (Get-Date -UFormat "# Auto generated @ %R %B %d`n") + "cmake_minimum_required(VERSION 3.19) `n`nset(LINKAGE_OVERRIDE "
$CMakeLists
$isAE

# build configuration
if ($args[0] -eq 'MT') {
	$Header = $Header + "FALSE CACHE BOOL `"`")`n"
	Write-Host "`t***** Building Static MultiThreaded *****`n`tvcpkg : x64-windows-static" -ForegroundColor DarkGreen
} elseif ($args[0] -eq 'MD') {
	$Header = $Header + "TRUE CACHE BOOL `"`")`n"
	Write-Host "`t***** Building Runtime MultiThreadedDLL *****`n`tvcpkg : x64-windows-static-md" -ForegroundColor Red
} else { # trigger zero_check
	if (-Not (Test-Path "$PSScriptRoot/CMakeLists.txt" -PathType Leaf)) {
		Write-Host "`tRun !Rebuild in MT or MD mode first." -ForegroundColor Red
		Exit
	}

	$file = [IO.File]::ReadAllText("$PSScriptRoot/CMakeLists.txt")
	[IO.File]::WriteAllLines("$PSScriptRoot/CMakeLists.txt", $file)
	Write-Host "`t++ ZERO_CHECK ++"
	Exit
}

# build target
Push-Location $env:CommonLibSSEPath
if ($args[1] -eq 'AE') {
	Write-Host "`tTarget: Anniversary Edition" -ForegroundColor Yellow
	& git checkout -f master -q
	$isAE = 'TRUE'
} elseif ($args[1] -eq 'SE') {
	Write-Host "`tTarget: Special Edition" -ForegroundColor Blue
	& git checkout -f 575f84a -q
	$isAE = 'FALSE'
} else {
	Write-Host "`tUnknown game version specified!" -ForegroundColor Red
	Pop-Location
	Exit
}
Pop-Location
$Header = $Header + "set(ANNIVERSARY_EDITION $isAE CACHE BOOL `"`")`n`n"

# clean build folder
Write-Host "`tCleaning build folder..."
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction Ignore

# generate CMakeLists.txt
$Header = 

$CMakeLists = $Header + @'
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

# use custom CMakeLists for CommonLibSSE
configure_file(
	${CMAKE_CURRENT_SOURCE_DIR}/Library/ClibCustomCMakeLists.txt.in
	${CMAKE_CURRENT_SOURCE_DIR}/Library/CommonLibSSE/CMakeLists.txt
	COPYONLY
)

'@

# for managing all my plugins
Write-Host "`tGenerating CMakeLists.txt for projects below:"
$WorkSpaceDir = @('Library', 'Plugins')
foreach($workSet in $WorkSpaceDir) {
	$CMakeLists = $CMakeLists + "`nset(GROUP $workSet)`n"
	Get-ChildItem $workSet -Directory -Recurse -ErrorAction SilentlyContinue | Resolve-Path -Relative | ForEach-Object {
		if (Test-Path "$PSScriptRoot/$_/CMakeLists.txt" -PathType Leaf) {
			$projectDir = $_.Substring(2) -replace '\\', '/'
			Write-Host "`t`t$projectDir" -ForegroundColor Cyan
			$CMakeLists = $CMakeLists + "`nadd_subdirectory(`"$projectDir`")`n"
		}
	}
}

[IO.File]::WriteAllText("$PSScriptRoot/CMakeLists.txt", $CMakeLists)

# cmake
Write-Host "`tExecuting CMake..." -ForegroundColor Yellow
& cmake.exe -B $PSScriptRoot\Build -S $PSScriptRoot
# SIG # Begin signature block
# MIIR2wYJKoZIhvcNAQcCoIIRzDCCEcgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUctA8jqkwBRe016sSZHRJ6nGb
# vx6ggg1BMIIDBjCCAe6gAwIBAgIQNkaQTCtrQ7NPmyNqlKMtlDANBgkqhkiG9w0B
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBRCklo0p/Trwti1Y7cazrUYVAm3azANBgkqhkiG
# 9w0BAQEFAASCAQC7iDOvGv4CyolvPXuUMX2Hqc7Qh80ueZmmZ9sEivEKNJRDqbHG
# UyaOEFB3/r6vfzwZZ/IcY7yr9sLw/UjRNP83bDbKj2zo/AuxTHe9mi8QMrD8Ki+c
# DmV8x5yHeKRGjjUA3qASAAbFTb/pkYvI+WykGWptIx/UEAGuGXrBndKP188JD67o
# uDrBK876ywDYXq+BgKg1jgp0uazfnueGRHDr2z2OZgh0NWMp7B5w7FuznQnzOWwo
# 6rpBhgTYLEVVjbYzOVHrUsKmh19OZRgEoDtbI8lWqYanehi9ZR512qQ6fcyvXGSU
# Gjch4ZQkWpHB5vNE8V6Lp/IPnAanTSNdd3mtoYICMDCCAiwGCSqGSIb3DQEJBjGC
# Ah0wggIZAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0ECEA1CSuC+Ooj/YEAhzhQA
# 8N0wDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yMTExMjgxNjA1NTdaMC8GCSqGSIb3DQEJBDEiBCCn63tV
# nFiJ97poC2cVC/0Kj+dWDWhzkiP6yMGKIz1gZzANBgkqhkiG9w0BAQEFAASCAQCV
# h4dTbfZwBB1bcfy4ldnwNrjUuubF2Y3KnkkdxoYVCPY2bNyYnl+e9Igwg5PdO9kG
# AxSpMdD/CJAZ5AtH8M9HxCsM7POqeSxgpPngy0JHVsqpf7onolv4iglu2vyKJxPH
# PnHwTDxJ1yT51m9lryYVecf1GORX4jXeVhB+jNOC96Sa3GfH54uf3NpxGstV4zfh
# 1GS0eQaHE78OVINWHrnA7Cr+zD8NaknjAr45o6GfYBVZ3rq4OR5acqbVpVwzXxKF
# OuEOMOCAAckvJapqnFXKJ7fQ3A6jHPfwTt2OiGtBZqtkUmO8XnB0bAumBkErykrp
# 3c6c/90jUES5cCMiwgHF
# SIG # End signature block
