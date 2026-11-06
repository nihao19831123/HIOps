$destDir = "packages\zabbix7"
$baseUrl = "https://repo.zabbix.com/zabbix/7.0/rhel/8/x86_64/"
$pkgs = @(
    "zabbix-server-mysql-7.0.5-release1.el8.x86_64.rpm",
    "zabbix-web-7.0.5-release1.el8.noarch.rpm",
    "zabbix-web-mysql-7.0.5-release1.el8.noarch.rpm",
    "zabbix-web-deps-7.0.5-release1.el8.noarch.rpm",
    "zabbix-apache-conf-7.0.5-release1.el8.noarch.rpm",
    "zabbix-sql-scripts-7.0.5-release1.el8.noarch.rpm",
    "zabbix-agent2-7.0.5-release1.el8.x86_64.rpm",
    "zabbix-selinux-policy-7.0.5-release1.el8.x86_64.rpm",
    "zabbix-js-7.0.5-release1.el8.x86_64.rpm"
)
foreach ($pkg in $pkgs) {
    $target = Join-Path $destDir $pkg
    if (-not (Test-Path $target)) {
        Write-Host "Downloading $pkg..."
        curl.exe -s -L "$baseUrl$pkg" -o $target
    } else {
        Write-Host "Already exists: $pkg"
    }
}
Get-ChildItem $destDir
