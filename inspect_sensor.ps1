$bytes = [System.IO.File]::ReadAllBytes("C:\Users\wufeng\Documents\HIOps-发布版-20261021\client-agent\HIOps.EndpointSensor.exe")
$asm = [System.Reflection.Assembly]::Load($bytes)
$t = $asm.GetType("HIOps.EndpointSensor.ForensicOrchestrator")
$methods = $t.GetMethods([System.Reflection.BindingFlags]'Static,Public,NonPublic,Instance')
foreach ($m in $methods) {
    Write-Host "Method: $($m.Name)"
    $body = $m.GetMethodBody()
    if ($body) {
        $il = $body.GetILAsByteArray()
        Write-Host "  IL length: $($il.Length)"
    }
}

$tray = $asm.GetType("HIOps.EndpointSensor.UI.SysTrayCompanion")
$trayMethods = $tray.GetMethods([System.Reflection.BindingFlags]'Static,Public,NonPublic,Instance')
foreach ($m in $trayMethods) {
    if ($m.Name -like "*Report*") {
        Write-Host "Tray Method: $($m.Name)"
    }
}
