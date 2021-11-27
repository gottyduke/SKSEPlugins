$ErrorActionPreference = 'Stop'

# clean build folder
Write-Host "`tCleaning build folder..."
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction Ignore

# generate CMakeLists.txt
$CMakeLists = @'
cmake_minimum_required(VERSION 3.21)

set(LINKAGE_OVERRIDE true)

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

# for managing all my plugins
Write-Host "`tGenerating CMakeLists.txt for projects below:"
$WorkSpaceDir = @("Library", "Plugins")
foreach($workSet in $WorkSpaceDir) {
	$CMakeLists = $CMakeLists + "`nset(GROUP $workSet)`n"
	$directory = Get-ChildItem $workSet -Directory -Recurse -ErrorAction SilentlyContinue | Resolve-Path -Relative
	foreach ($subDir in $directory) {
		if (Test-Path "$subDir/CMakeLists.txt" -PathType Leaf) {
			$projectDir = $subDir.Substring(2) -replace '\\', '/'
			Write-Host "`t`t$projectDir"
			$CMakeLists = $CMakeLists + "`nadd_subdirectory(`"$projectDir`")`n"
		}
	}
}

$CMakeLists = (Get-Date -UFormat "# Auto generated @ %R %B %d`n") + $CMakeLists
[IO.File]::WriteAllText("CMakeLists.txt", $CMakeLists)

# cmake
Write-Host "`tExecuting CMake..."
Invoke-Expression "cmake.exe -B $PSScriptRoot\Build -S $PSScriptRoot"