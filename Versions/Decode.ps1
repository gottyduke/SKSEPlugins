#Requires -Version 5

$ErrorActionPreference = 'Stop'
[IO.Directory]::SetCurrentDirectory($PSScriptRoot)

Add-Type -AssemblyName PresentationCore, PresentationFramework

$BinFiles = Get-ChildItem $PSScriptRoot -File -Filter *.bin
if ($BinFiles.Count -eq 0) {
    [System.Windows.MessageBox]::Show('未检测到当前目录下的bin文件!', '提示', 'OK', 'Warning') | Out-Null
    Exit
}

for ($index= 0; $index -lt $BinFiles.Count; ++$index) {
    Write-Host "[$($index)] $($BinFiles[$index].Name)"
}

$BinIndex = Read-Host '选择要解码的bin文件'
if ($BinIndex -gt $BinFiles.Count) {
    Write-Host '选项不存在!' -ForegroundColor Red
    Exit
}

$Bin = [System.IO.BinaryReader]::new([System.IO.File]::Open($BinFiles[$BinIndex], [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))
$Output = [System.IO.StreamWriter]::new("$($PSScriptRoot)\$($BinFiles[$BinIndex].BaseName).txt")
$Output.WriteLine("ID`tOffset`n==`t======")

# Version
try {
    $Head = $Bin.ReadUInt32()
    if ($Head -gt 2) { 
        # Fallout 4 Address Library
        Write-Host 'bin版本: Fallout4'

        $null = $Bin.ReadUInt32()
        for ($pair = 0; $pair -lt $Head; ++$pair) {
            $Output.WriteLine("$($Bin.ReadUInt64())`t$([System.Convert]::ToString($Bin.ReadUInt64(), 16).ToUpper())")
        }
    } elseif (($Head -eq 1) -or ($Head -eq 2)) {
        # Skyrim Address Library
        $Version
        for ($ver = 0; $ver -lt 4; ++$ver) {
            $Version += "-$($Bin.ReadUInt32())"
        }
        $ModuleNameLength = $Bin.ReadUInt32()
        $Version = "$($Bin.ReadChars($ModuleNameLength))" + $Version -replace '\s', ''
        Write-Host "bin版本: $($Version)"

        $PtrSize = $Bin.ReadUInt32()
        if ($PtrSize -ne 8) {
            throw '数据大小不匹配!'
        }

        $Head = $Bin.ReadUInt32()
        [Byte]$type = 0
        [Byte]$low = 0
        [Byte]$high = 0
        [Byte]$b1 = 0
        [Byte]$b2 = 0
        [UInt16]$w1 = 0
        [UInt16]$w2 = 0
        [UInt32]$d1 = 
        [UInt32]$d2 = 0
        [UInt64]$q1 = 0
        [UInt64]$q2 = 0
        [UInt64]$pvid = 0
        [UInt64]$poffset = 0
        [UInt64]$tpoffset = 0

        for ($index = 0; $index -lt $Head; ++$index) {
            $type = $Bin.ReadByte();
			$low = $type -band 0xF;
			$high = $type -shr 4;

			switch ($low) {
                0 { $q1 = $Bin.ReadUInt64(); break} 
                1 { $q1 = $pvid + 1; break } 
                2 { $b1 = $Bin.ReadByte(); $q1 = $pvid + $b1; break } 
                3 { $b1 = $Bin.ReadByte(); $q1 = $pvid - $b1; break } 
                4 { $w1 = $Bin.ReadUInt16(); $q1 = $pvid + $w1; break } 
                5 { $w1 = $Bin.ReadUInt16(); $q1 = $pvid - $w1; break } 
                6 { $w1 = $Bin.ReadUInt16(); $q1 = $w1; break } 
                7 { $d1 = $Bin.ReadUInt32(); $q1 = $d1; break }
                default { throw "未知掩码! 位置[$($index)]" }
			}

			$tpoffset = if (($high -band 8) -ne 0) { $poffset / $PtrSize } else { $poffset }

			switch ($high -band 7) {
                0 { $q2 = $Bin.ReadUInt64(); break} 
                1 { $q2 = $tpoffset + 1; break } 
                2 { $b2 = $Bin.ReadByte(); $q2 = $tpoffset + $b2; break } 
                3 { $b2 = $Bin.ReadByte(); $q2 = $tpoffset - $b2; break } 
                4 { $w2 = $Bin.ReadUInt16(); $q2 = $tpoffset + $w2; break } 
                5 { $w2 = $Bin.ReadUInt16(); $q2 = $tpoffset - $w2; break } 
                6 { $w2 = $Bin.ReadUInt16(); $q2 = $w2; break } 
                7 { $d2 = $Bin.ReadUInt32(); $q2 = $d2; break }
                default { throw "未知掩码! 位置[$($index)]" }
			}

			if (($high -band 8) -ne 0) {
				$q2 *= $PtrSize;
            }

            $Output.WriteLine("$($q1)`t$([System.Convert]::ToString($q2, 16).ToUpper())")

			$poffset = $q2;
			$pvid = $q1; 
        }

    } else {
        throw '不明格式的bin文件!'
    }

    Write-Host "解码完成!`n总数据: $($Head)" -ForegroundColor Green
} finally {
    $Output.Close()
}

