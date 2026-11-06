$base = "https://download.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/Packages/n/"
$wc = New-Object System.Net.WebClient
$html = $wc.DownloadString($base)
$regex = New-Object System.Text.RegularExpressions.Regex('net-snmp-libs-[0-9\.\-_a-zA-Z]+x86_64\.rpm')
$m = $regex.Match($html)
if ($m.Success) {
    Write-Output $m.Value
    $dlUrl = "$base$($m.Value)"
    Write-Output "Downloading $dlUrl..."
    $wc.DownloadFile($dlUrl, "packages\test_libs\$($m.Value)")
    Write-Output "Downloaded!"
} else {
    Write-Output "Not found"
}
