$outDir = "zabbix7_bundle"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Path "$outDir\rpms" -Force | Out-Null

# 1. Zabbix 7.0 packages (9)
Copy-Item "packages\zabbix7\*.rpm" "$outDir\rpms\"

# 2. Apache and system dependencies (10)
Get-ChildItem "packages\web_php\*.rpm" | Where-Object { $_.Name -notlike "php-*" } | ForEach-Object {
    Copy-Item $_.FullName "$outDir\rpms\"
}

# 3. Security compliant PHP 8.2.35 packages (12)
Copy-Item "packages\php82_safe\*.rpm" "$outDir\rpms\"

# 4. MariaDB full packages (8)
Copy-Item "packages\mariadb\*.rpm" "$outDir\rpms\"

# 5. Installer script
Copy-Item "install_zabbix7_offline.sh" "$outDir\install.sh"

Write-Host "Total RPMs in bundle:" (Get-ChildItem "$outDir\rpms\*.rpm").Count

if (Test-Path "zabbix7-offline-bundle.tar.gz") { Remove-Item -Force "zabbix7-offline-bundle.tar.gz" }
tar.exe -czvf zabbix7-offline-bundle.tar.gz zabbix7_bundle
Get-Item zabbix7-offline-bundle.tar.gz | Select-Object Name, Length
