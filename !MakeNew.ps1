# args
param (
    [Parameter(Mandatory)][string]$Name,
    [Alias('message', 'm')][string]$Description,
    [Alias('install', 'i')][string]$Destination = $Name,
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
    "features": {
        "mo2-install": {
            "description": ""
        }
    }
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
$Json.'name' = $Name.ToLower()
if ($Description) {
    $Json.'description' = $Description
}
if ($AddDependencies) {
    $Json.'dependencies' += $AddDependencies
    $Json.'dependencies' = $Json.'dependencies' | Select-Object -Unique | Sort-Object
}
$Json.'features'.'mo2-install'.'description' = $Destination
$Json = $Json | ConvertTo-Json
[IO.File]::WriteAllText("$Path/$Name/vcpkg.json", $Json)

# CMakeLists
$CMake = [IO.File]::ReadAllLines("$Path/$Name/CMakeLists.txt") -replace 'Template', $Name
[IO.File]::WriteAllLines("$Path/$Name/CMakeLists.txt", $CMake)

Write-Host "`tNew project <$Name> generated." -ForegroundColor Green

