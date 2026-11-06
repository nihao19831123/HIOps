$destDir = "packages\web_php"
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}
$baseUrl = "https://repo.openeuler.org/openEuler-22.03-LTS-SP4/everything/x86_64/Packages/"
$pkgs = @(
    "httpd-2.4.51-21.oe2203sp4.x86_64.rpm",
    "httpd-filesystem-2.4.51-21.oe2203sp4.noarch.rpm",
    "httpd-tools-2.4.51-21.oe2203sp4.x86_64.rpm",
    "openEuler-logos-httpd-1.0-9.oe2203sp4.noarch.rpm",
    "apr-1.7.0-6.oe2203sp4.x86_64.rpm",
    "apr-util-1.6.1-14.oe2203sp4.x86_64.rpm",
    "php-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-common-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-fpm-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-bcmath-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-gd-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-ldap-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-mbstring-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-mysqlnd-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-pdo-8.0.30-5.oe2203sp4.x86_64.rpm",
    "php-xml-8.0.30-5.oe2203sp4.x86_64.rpm",
    "libzip-1.8.0-4.oe2203sp4.x86_64.rpm",
    "oniguruma-6.9.6-1.oe2203sp4.x86_64.rpm"
)
foreach ($pkg in $pkgs) {
    $target = Join-Path $destDir $pkg
    if (-not (Test-Path $target)) {
        Write-Host "Downloading $pkg..."
        curl.exe -s -L "$baseUrl$pkg" -o $target
    }
}
Get-ChildItem $destDir | Measure-Object -Property Length -Sum
