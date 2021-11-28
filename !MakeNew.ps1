$ErrorActionPreference = "Stop"

# args
$a_name = $args[0]
$a_type = $args[1]

$Template = "$PSScriptRoot/Plugins/Template"
$Path

# checks
if ($a_type -eq 'P') {
    $Path = "$PSScriptRoot/Plugins"
} elseif ($a_type -eq 'L') {
    $Path = "$PSScriptRoot/Library"
} else {
    Write-Host "`tUnknown argument." -ForegroundColor Red
    Exit
}

if (Test-Path "$Path/$a_name" -PathType Container) {
    Write-Host "`tFolder with same name exists. Aborting." -ForegroundColor Red
    Exit
}

New-Item -Type dir $Path -Force | Out-Null

# template
if (Test-Path "$Template/CMakeLists.txt" -PathType Leaf) {
    Write-Host "`tFound Template project!" -ForegroundColor Green
} else {
    Write-Host "`tMissing Template project! Downloading." -ForegroundColor Red
    Remove-Item "$Template" -Recurse -Force -Confirm:$false -ErrorAction Ignore
    & git clone https://github.com/gottyduke/Template "$Template"
}

# populate
Copy-Item -Path "$Template/cmake" -Destination "$Path/$a_name/cmake" -Recurse
Copy-Item -Path "$Template/src" -Destination "$Path/$a_name/src" -Recurse
Copy-Item "$Template/CMakeLists.txt" -Destination "$Path/$a_name/CMakeLists.txt"

# CMakeLists.txt
$cmake = [IO.File]::ReadAllLines("$Path/$a_name/CMakeLists.txt")
$cmake[4] = "`t$a_name"
[IO.File]::WriteAllLines("$Path/$a_name/CMakeLists.txt", $cmake)

# update vcpkg.json accordinly
$vcpkg = [IO.File]::ReadAllText("$Template/vcpkg.json") | ConvertFrom-Json
$vcpkg.'name' = $a_name
$vcpkg.'description' = "Placeholding description"
$vcpkg = $vcpkg | ConvertTo-Json
[IO.File]::WriteAllText("$Path/$a_name/vcpkg.json", $vcpkg)

Write-Host "`tNew project <$a_name> generated." -ForegroundColor Green