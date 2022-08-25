#Requires -Version 5

$ErrorActionPreference = 'Stop'
[IO.Directory]::SetCurrentDirectory($PSScriptRoot)

$Diff = "$($PSScriptRoot)\Differ.txt"