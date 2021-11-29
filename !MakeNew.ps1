# args
param (
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ValidateSet('P', 'L')][char]$Type,
    [string]$Destination,
    [string]$Description,
    [string[]]$AddDependencies = @()
)

$ErrorActionPreference = "Stop"

# templates
$Template = "$PSScriptRoot/Plugins/Template"
$Path = ""
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
if ($Type -eq 'P') {
    $Path = "$PSScriptRoot/Plugins"
} elseif ($Type -eq 'L') {
    $Path = "$PSScriptRoot/Library"
} else {
    Write-Host "`tUnknown argument." -ForegroundColor Red
    Exit
}

if (Test-Path "$Path/$Name" -PathType Container) {
    Write-Host "`tFolder with same name exists. Aborting." -ForegroundColor Red
    Exit
}

New-Item -Type dir $Path -Force | Out-Null

# update
if (Test-Path "$Template/CMakeLists.txt" -PathType Leaf) {
    Write-Host "`tFound Template project!" -ForegroundColor Green
} else {
    Write-Host "`tMissing Template project! Downloading." -ForegroundColor Red
    Remove-Item "$Template" -Recurse -Force -Confirm:$false -ErrorAction Ignore
    & git clone https://github.com/gottyduke/Template "$Template"
}

# populate
Copy-Item -Path "$Template/cmake" -Destination "$Path/$Name/cmake" -Recurse
Copy-Item -Path "$Template/src" -Destination "$Path/$Name/src" -Recurse
Copy-Item "$Template/CMakeLists.txt" -Destination "$Path/$Name/CMakeLists.txt"

# CMakeLists.txt
$cmake = [IO.File]::ReadAllLines("$Path/$Name/CMakeLists.txt")
$cmake[4] = "`t$Name"
[IO.File]::WriteAllLines("$Path/$Name/CMakeLists.txt", $cmake)

# generate vspkg.json
$Json.'name' = $Name
if ($Description) {
    $Json.'description' = $Description
}
if ($AddDependencies) {
    $Json.'dependencies' += $AddDependencies
    $Json.'dependencies' = $Json.'dependencies' | Sort-Object
}
if ($Destination) {
    $Json.'install-name' = $Destination
} else {
    $Json.'install-name' = $Name
}

$Json = $Json | ConvertTo-Json
[IO.File]::WriteAllText("$Path/$Name/vcpkg.json", $Json)

Write-Host "`tNew project <$Name> generated." -ForegroundColor Green

# SIG # Begin signature block
# MIIR2wYJKoZIhvcNAQcCoIIRzDCCEcgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURkP0ahcwCztJBHPCIPeDs1SC
# lweggg1BMIIDBjCCAe6gAwIBAgIQNkaQTCtrQ7NPmyNqlKMtlDANBgkqhkiG9w0B
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBRNj6k7FnE+IJcxRSoX02LKIkPxuzANBgkqhkiG
# 9w0BAQEFAASCAQBCVo4AbotwzN5aNJ1KXSr2kEMn20Dn2zxcrF4TXehpp8tiH+KB
# w8a4MEIF9cXsAZlRTjmR8qCG7NnlQve5TQiyjNjDi9BcczpB9ChtFfJef0sR/yBS
# dCurvqav3ZRawGUsHQAzfkapLkO3jWWCVqL2F3Phmyg2PVBI2dpeV8r/cJA0vsMa
# KzPFqN9wzU6ZBY3zITM/cjHmlUgvK9HI9h62cluGf1C5G9kBqPs/Qt9ZPOl1gxcy
# V7gllJ/bN+kQFd6b3d/XH67RUy1JwEg1BXk0qfyBz9RXVZ0M7cuMQSp8KZNLt9HB
# PKAMj+zZR/E5wouNPO2pW/BY2KFMegbZn6OYoYICMDCCAiwGCSqGSIb3DQEJBjGC
# Ah0wggIZAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0ECEA1CSuC+Ooj/YEAhzhQA
# 8N0wDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0yMTExMjkyMTQxMDRaMC8GCSqGSIb3DQEJBDEiBCAvu1fa
# 8+ACpYGjcyG+FRkan1qVUkcDt3MpSro1vQ23GDANBgkqhkiG9w0BAQEFAASCAQBj
# HHrawlMjs2JRSy0Ge9SoP+AdgRfxeCgaVDhMCFJ4icSJZkzt0bXALPewdbMhJa0l
# tPIPR3ipPx2rwPhxHkfIKT7/oSxjE78smQlftMtf1ZsFx33Q8HKIaKPlwY4JPd3t
# KOXariKKGD4Gi/+TKWC/bJZMBgfJ1Fov7sbPWezzbLcC2iAThLZuJce6mfcyQlAW
# TDryEmGbz3l21NhAhm0/Y4SxHp1tNPQMjJMJvMx1DfXKE+7IqVOR67XhUBaQHkwD
# UdRqGID2XKGtLHnFpvIab5Bjhb1L0erN/G7SPAMAOGsO6rNQVSahUwys9P10Mhxb
# Yqzp0WD14J2vTe3PRob0
# SIG # End signature block
