$destDir = "packages\mariadb"
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}
$baseUrl = "https://repo.openeuler.org/openEuler-22.03-LTS-SP4/OS/x86_64/Packages/"
$pkgs = @(
    "mariadb-10.5.25-1.oe2203sp4.x86_64.rpm",
    "mariadb-server-10.5.25-1.oe2203sp4.x86_64.rpm",
    "mariadb-common-10.5.25-1.oe2203sp4.x86_64.rpm",
    "mariadb-connector-c-3.1.13-4.oe2203sp4.x86_64.rpm",
    "mariadb-errmsg-10.5.25-1.oe2203sp4.x86_64.rpm",
    "libaio-0.3.113-9.oe2203sp4.x86_64.rpm",
    "perl-DBI-1.643-3.oe2203sp4.x86_64.rpm",
    "perl-DBD-MariaDB-1.21-3.oe2203sp4.x86_64.rpm"
)
foreach ($pkg in $pkgs) {
    $target = Join-Path $destDir $pkg
    if (-not (Test-Path $target)) {
        Write-Host "Downloading $pkg..."
        curl.exe -s -L "$baseUrl$pkg" -o $target
    }
}
Get-ChildItem $destDir | Select-Object Name, Length
