$base = "https://repo.openeuler.org/openEuler-22.03-LTS-SP4/OS/x86_64/Packages/"
$pkgs = @(
    "OpenIPMI-2.0.32-3.oe2203sp4.x86_64.rpm",
    "unixODBC-2.3.7-3.h1.oe2203sp4.x86_64.rpm",
    "libevent-2.1.12-8.oe2203sp4.x86_64.rpm"
)
foreach ($p in $pkgs) {
    $out = "C:\Users\wufeng\Documents\HIOps-发布版-20261021\packages\test_libs\$p"
    if (!(Test-Path "C:\Users\wufeng\Documents\HIOps-发布版-20261021\packages\test_libs")) {
        New-Item -ItemType Directory "C:\Users\wufeng\Documents\HIOps-发布版-20261021\packages\test_libs" | Out-Null
    }
    if (!(Test-Path $out)) {
        Write-Host "Downloading $p..."
        Invoke-WebRequest -Uri "$base$p" -OutFile $out
    }
}
Write-Host "Download complete."
