$url = "https://repo.openeuler.org/openEuler-22.03-LTS-SP4/OS/x86_64/Packages/"
$req = [System.Net.WebRequest]::Create($url)
$resp = $req.GetResponse()
$reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
$html = $reader.ReadToEnd()
$reader.Close()
$resp.Close()

$regex = New-Object System.Text.RegularExpressions.Regex('href="([^"]+\.rpm)"')
$matches = $regex.Matches($html)
$list = @()
foreach ($m in $matches) {
    $val = $m.Groups[1].Value
    if ($val -match 'OpenIPMI|unixODBC|libevent') {
        $list += $val
    }
}
$list
