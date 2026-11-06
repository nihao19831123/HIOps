$destDir = "packages\php82_safe"
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}
$baseUrl = "https://rpms.remirepo.net/enterprise/8/php82/x86_64/"
$pkgs = @(
    "php-common-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-cli-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-fpm-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-bcmath-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-gd-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-ldap-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-mbstring-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-mysqlnd-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-pdo-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-xml-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-opcache-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm",
    "php-sodium-8.2.35-1.module_php.8.2.el8.remi.x86_64.rpm"
)
foreach ($pkg in $pkgs) {
    $target = Join-Path $destDir $pkg
    if (-not (Test-Path $target)) {
        Write-Host "Downloading $pkg..."
        curl.exe -s -L "$baseUrl$pkg" -o $target
    }
}
Get-ChildItem $destDir | Select-Object Name, Length
