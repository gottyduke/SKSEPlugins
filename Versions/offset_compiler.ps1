## not distributed to end user
#Requires -Version 5

$env:DKScriptVersion = '22O28'
$env:ScriptCulture = (Get-Culture).Name -eq 'zh-CN'

[IO.Directory]::SetCurrentDirectory($PSScriptRoot)
Set-Location $PSScriptRoot

# @@ functions
function E {
    param ([Parameter(ValueFromPipeline)][string]$log)
    process { Write-Host $log -ForegroundColor Red }
}

function S {
    param ([Parameter(ValueFromPipeline)][string]$log)
    process { Write-Host $log -ForegroundColor Green }
}

function W {
    param ([Parameter(ValueFromPipeline)][string]$log)
    process { Write-Host $log -ForegroundColor Yellow }
}

function L {
    param (
        [Parameter(Mandatory)][string]$en,
        [string]$zh
    )
	
    process {
        if ($env:ScriptCulture -and $zh) {
            return $zh
        }
        else {
            return $en
        }
    }
}

function H2B {
    param ([Parameter(ValueFromPipeline)][string]$hex)
    process { return [Byte[]] -split (($hex -replace '-') -replace '..', '0x$& ') }
}

# @@ shared define
class Patch {
    [UInt64]$offset
    [string]$patch
    [string]$validate
    [string]$desc
}

class DB {
    [Collections.Generic.List[Patch]]$patches

    [void]Add([Patch]$patch) {
        $pos = $this.patches.FindIndex({ $args[0].offset -eq $patch.offset })
        if ($pos -eq -1) {
            $this.patches.Add($patch)
        }
    }
    [void]Remove([UIntPtr]$offset) {
        if ($this.patches.Count) {
            $pos = $this.patches.FindIndex({ $args[0].offset -eq $offset })
            if ($pos -ne -1) {
                $this.patches.RemoveAt($pos)
            }
        }
    }
    [Patch]At([UIntPtr]$offset) {
        if ($this.patches.Count) {
            $pos = $this.patches.FindIndex({ $args[0].offset -eq $offset })
            if ($pos -ne -1) {
                return $this.patches[$pos]
            }
        }
        return $null
    }
}

# @@ process
$BinFiles = Get-ChildItem $PSScriptRoot -File | ? { $_.Extension -notin @('.ps1', '.ini', '.json') }
if ($BinFiles.Count -eq 0) {
    $(L 'unable to detect any binary file for editing' '未检测到当前目录下的可编辑文件!') | E
    Exit
}

for ($index = 0; $index -lt $BinFiles.Count; ++$index) {
    "[$($index)] $($BinFiles[$index].Name)"
}

$BinIndex = Read-Host $(L 'select the binary file for editing' '选择要编辑的二进制文件')
if ($BinIndex -gt $BinFiles.Count) {
    $(L 'non-existent option' '选项不存在!') | E
    Exit
}

[Byte[]]$file = [IO.File]::ReadAllBytes($BinFiles[$BinIndex])
"read in [$($file.Length)] bytes.." | S
'hex offset mode' | W

$json = [IO.File]::ReadAllText("$PSScriptRoot/patch_db.json") | ConvertFrom-Json
$DB = [DB]$json

while ($true) {
    $Op = Read-Host '<op> [<offset> <patch> <validate> [desc]]'
    $Ops = $Op -split '\s'
    if (!$Ops.Count) {
        continue
    }

    $roffset = 0
    [Byte[]]$rpatch = $null
    [Byte[]]$rvalidate = $null
    $rdesc = $null
    if ($Ops[4]) {
        $rdesc = $Ops[4]
    }
    if ($Ops[3]) {
        $rvalidate = $Ops[3] | H2B
    }
    if ($Ops[2]) {
        $rpatch = $Ops[2] | H2B
    }
    if ($Ops[1]) {
        $roffset = [Convert]::ToUInt64($Ops[1], 16)
    }

    switch ($Ops[0]) {
        '+' {
            $rfind = $DB.At($roffset)
            if ($rfind) {
                "patch already exist at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | E
                $rfind | Format-List
            }
            else {
                [Patch]$addition = @{
                    offset   = $roffset
                    patch    = [BitConverter]::ToString($rpatch)
                    validate = [BitConverter]::ToString($rvalidate)
                    desc     = $rdesc
                }
                $DB.Add($addition)
                "added patch at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | S
                $addition | Format-List
                $env:LastOp = $addition
            }
            break
        }
        '-' {
            $rfind = $DB.At($roffset)
            if ($rfind) {
                $DB.Remove($roffset)
                "removed patch at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | s
                "-------------------`n$($rfind | Format-List | Out-String)`n-------------------" | E
            }
            else {
                "none found at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | E
            }
            break
        }
        '*' {
            $rfind = $DB.At($roffset)
            if ($rfind) {
                [Patch]$addition = @{
                    offset   = $roffset
                    patch    = [BitConverter]::ToString($rpatch)
                    validate = [BitConverter]::ToString($rvalidate)
                    desc     = $rdesc
                }
                $DB.Remove($roffset)
                $DB.Add($addition)
                "modified patch at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | s
            }
            else {
                "none found at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | E
            }
            break
        }
        '@' {
            $rfind = $DB.At($roffset)
            if ($rfind) {
                $rfind | Format-List
            }
            else {
                "none found at 0x[$([Convert]::ToString($roffset, 16))] -> +[$($roffset)]" | E
            }
            break
        }
        '++' {
            $json = $DB | ConvertTo-Json -Depth 99
            [IO.File]::WriteAllText("$PSScriptRoot/new_patch_db.json", $json)
            "patch db has been written to file [new_patch_db.json]`npatches: $($DB.patches.Count)" | S
            break
        }
        '--' {
            $count = $DB.patches.Count
            $DB.patches.Clear()
            "patch db has been cleared`npatches: $($count)" | S
            break
        }
        default {
            'op list:' | W
            "`t+`tadd patch"
            "`t-`tremove patch"
            "`t*`tmodify patch"
            "`t@`tview patch detail"
            "`t++`tdump patch db to file"
            "`t--`tclear patch db"
            continue
        }
    }
}
