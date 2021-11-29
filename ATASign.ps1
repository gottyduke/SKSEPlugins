$codeCertificate = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=ATA Authenticode"}

Set-AuthenticodeSignature -FilePath .\!MakeNew.ps1 -Certificate $codeCertificate -TimeStampServer http://timestamp.digicert.com
Set-AuthenticodeSignature -FilePath .\!Rebuild.ps1 -Certificate $codeCertificate -TimeStampServer http://timestamp.digicert.com
Set-AuthenticodeSignature -FilePath .\!Update.ps1 -Certificate $codeCertificate -TimeStampServer http://timestamp.digicert.com