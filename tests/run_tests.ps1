$sensorPath = Join-Path $PSScriptRoot "..\sensor\src\HIOps.EndpointSensor.dll"
if (Test-Path $sensorPath) {
    $sensorBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $sensorPath))
    [System.Reflection.Assembly]::Load($sensorBytes) | Out-Null
}

$testPath = Join-Path $PSScriptRoot "TestRunner.dll"
$testBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $testPath))
$testAsm = [System.Reflection.Assembly]::Load($testBytes)

$programType = $testAsm.GetType("HIOps.TestHarness.Program")
$mainMethod = $programType.GetMethod("Main", [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::Public)
$mainMethod.Invoke($null, $null)
