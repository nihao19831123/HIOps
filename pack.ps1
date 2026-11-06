$outDir = "zabbix7_bundle"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Path "$outDir\rpms" -Force | Out-Null
Copy-Item "packages\zabbix7\*.rpm" "$outDir\rpms\"
Copy-Item "packages\web_php\*.rpm" "$outDir\rpms\"
Copy-Item "install_zabbix7_offline.sh" "$outDir\install.sh"

if (Test-Path "zabbix7-offline-bundle.tar.gz") { Remove-Item -Force "zabbix7-offline-bundle.tar.gz" }
tar.exe -czvf zabbix7-offline-bundle.tar.gz zabbix7_bundle
Get-Item zabbix7-offline-bundle.tar.gz
