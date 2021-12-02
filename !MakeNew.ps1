# args
param (
    [Parameter(Mandatory)][string]$Name,
    [Alias('message', 'm')][string]$Description,
    [Alias('install', 'i')][string]$Destination,
    [Alias('vcpkg', 'v')][string[]]$AddDependencies = @()
)

$ErrorActionPreference = "Stop"

# templates
$Path = "$PSScriptRoot/Plugins"
$Json = @'
{
    "name":  "",
    "version-string":  "1.0.0",
    "description":  "",
    "license":  "MIT",
    "dependencies":  [
                         "spdlog"
                     ],
    "script-version": "",
    "build-config": "",
    "build-target": "",
    "install-name": ""
}
'@ | ConvertFrom-Json

# checks
if (Test-Path "$Path/$Name" -PathType Container) {
    Write-Host "`tFolder with same name exists. Aborting." -ForegroundColor Red
    Exit
}

New-Item -Type dir $Path -Force | Out-Null

# update
if (Test-Path "$env:SKSETemplatePath/CMakeLists.txt" -PathType Leaf) {
    Write-Host "`tFound Template project!" -ForegroundColor Green
} else {
    Write-Host "`t! Missing Template project! Downloading..." -ForegroundColor Red -NoNewline
    Remove-Item "$PSScriptRoot/Plugins/Template" -Recurse -Force -Confirm:$false -ErrorAction Ignore
    & git clone https://github.com/gottyduke/Template "$PSScriptRoot/Plugins/Template" -q
    $env:SKSETemplatePath = "$PSScriptRoot/Plugins/Template"
    Write-Host "`t* Installed Template project                " -ForegroundColor Yellow -NoNewline
}

# populate
Copy-Item "$env:SKSETemplatePath/cmake" "$Path/$Name/cmake" -Recurse -Force
Copy-Item "$env:SKSETemplatePath/src" "$Path/$Name/src" -Recurse -Force
Copy-Item "$env:SKSETemplatePath/CMakeLists.txt" "$Path/$Name/CMakeLists.txt" -Force

# Author name
$main = [IO.File]::ReadAllText("$Path/$Name/src/main.cpp") -replace 'Dropkicker', $env:SKSEPluginAuthor
[IO.File]::WriteAllLines("$Path/$Name/src/main.cpp", $main)

# generate vcpkg.json
$Json.'name' = $Name
if ($Description) {
    $Json.'description' = $Description
}
if ($AddDependencies) {
    $Json.'dependencies' += $AddDependencies
    $Json.'dependencies' = $Json.'dependencies' | Select-Object -Unique | Sort-Object
}
if ($Destination) {
    $Json.'install-name' = $Destination
} else {
    $Json.'install-name' = $Name
}
$Json = $Json | ConvertTo-Json
[IO.File]::WriteAllText("$Path/$Name/vcpkg.json", $Json)

# CMakeLists
$CMake = [IO.File]::ReadAllLines("$Path/$Name/CMakeLists.txt") -replace 'Template', $Name
[IO.File]::WriteAllLines("$Path/$Name/CMakeLists.txt", $CMake)

Write-Host "`tNew project <$Name> generated." -ForegroundColor Green

# SIG # Begin signature block
# MIIR2wYJKoZIhvcNAQcCoIIRzDCCEcgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUvaiR8+tsXYlYlGw0U3Hz//Q8
# 84yggg1BMIIDBjCCAe6gAwIBAgIQZAPCkAxHzpxOvoeEUruLiDANBgkqhkiG9w0B
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBRtQWvAIkJCkB/9QVyz5rTEMn7EizANBgkqhkiG
# 9w0BAQEFAASCAQCOeoNYG4dV5EusT9wpxMVoQY8djEGyb50YiPTqlcCvVAq5/XPw
# aUMfE8Rrm+XLZT+K+Q2Bam5LUfWe8wh6ZUi6KuhK/Mx4TKz3cbp+0Unl8Yq43/ML
# 7i4odbTxoLxEd3+nTFQb8ai+hiK6EGWyA7PkW9puBgHHeAgiVrjLz79RaUA2ZTSI
# rWRbWAc0AZe8oC6MVMtK9XIed3CJtfnk6Ux2UwVffkBBOYO9jOO9U+Ucf3o3A9Hi
# a8dUoAe9GkhUkh6NwYMbg4gNJWoQN89lEfK1tJ6WUN3QkioGAve/tTPwxLs6oDNR
# RB5V+Idr6WKqc/bwn2jhzBFsekHYA5Ak9MkvoYICMDCCAiwGCSqGSIb3DQEJBjGC
# Ah0wggIZAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0ECEA1CSuC+Ooj/YEAhzhQA
# 8N0wDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yMTEyMDIxMzU2NDhaMC8GCSqGSIb3DQEJBDEiBCDVOoDs
# luX99ICCZxsYITUrRsfYxAdvR2JHRcFz/JOOZzANBgkqhkiG9w0BAQEFAASCAQBB
# dltg8zTSNSKfMK6fBhLu27wkrCCPUce3mAkp37bdi6kgLiYt9pT6ifzn9ivvDrBZ
# t+Ppb05UNU/Qm6gdsQKaeMiW4bFS5stlTVxk/xu2MbRhGZreJd700sYZ5RJgKlia
# eQsbYxs67HBuv/uca5HcZnDXOEnhB1kPwcs5mCPrncqagjQnwHWsa+V5oZI073KF
# fcKmRjBm03gcFsW335xSsx/i8ByHbPT8tgEQNvQIjN8ove9frGnxOs+nH4ckk0sC
# ZY9MzrNHZTYe+zfG5cH93OjKwWqg/UNkxqOieBDkeqeeXRmpFFmyjCHYtMhO8T4H
# 7rXKj+BJctJOE174zEfj
# SIG # End signature block
