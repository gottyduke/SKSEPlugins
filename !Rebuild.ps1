$ErrorActionPreference = 'Stop'

# generate CMakeLists.txt
$Header = "cmake_minimum_required(VERSION 3.21) `n`nset(LINKAGE_OVERRIDE "

if ($args[0] -eq "MT") {
	Write-Host "`t***** Building Static MultiThreaded *****`n`tvcpkg : x64-windows-static" -ForegroundColor DarkGreen
	$Header = $Header + "false)`n`n"
} elseif ($args[0] -eq "MD") {
	Write-Host "`t***** Building Runtime MultiThreadedDLL *****`n`tvcpkg : x64-windows-static-md" -ForegroundColor Red
	$Header = $Header + "true)`n`n"
} else { # trigger zero_check
	if (-Not (Test-Path 'CMakeLists.txt' -PathType Leaf)) {
		Write-Host "`tRun !Rebuild in MT or MD mode first." -ForegroundColor Red
		Exit
	}

	$file = [IO.File]::ReadAllText('CMakeLists.txt')
	[IO.File]::WriteAllLines('CMakeLists.txt', $file)
	Write-Host "`t++ ZERO_CHECK ++"
	Exit
}

# clean build folder
Write-Host "`tCleaning build folder..."
Remove-Item "$PSScriptRoot/Build" -Recurse -Force -Confirm:$false -ErrorAction Ignore

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
$WorkSpaceDir = @("Library", "Plugins")
foreach($workSet in $WorkSpaceDir) {
	$CMakeLists = $CMakeLists + "`nset(GROUP $workSet)`n"
	Get-ChildItem $workSet -Directory -Recurse -ErrorAction SilentlyContinue | Resolve-Path -Relative | ForEach-Object {
		if (Test-Path "$_/CMakeLists.txt" -PathType Leaf) {
			$projectDir = $_.Substring(2) -replace '\\', '/'
			Write-Host "`t`t$projectDir" -ForegroundColor Cyan
			$CMakeLists = $CMakeLists + "`nadd_subdirectory(`"$projectDir`")`n"
		}
	}
}

$CMakeLists = (Get-Date -UFormat "# Auto generated @ %R %B %d`n") + $CMakeLists
[IO.File]::WriteAllText('CMakeLists.txt', $CMakeLists)

# cmake
Write-Host "`tExecuting CMake..." -ForegroundColor Yellow
& cmake.exe -B $PSScriptRoot\Build -S $PSScriptRoot