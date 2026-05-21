# PRTG EXE/Script Advanced Sensor
# Kubernetes Cluster Summary via WSL + kubectl
# Output format: PRTG JSON only

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Change only if your WSL distro name is different.
$Distro = "Ubuntu"

# kubectl path inside WSL
$KubectlPath = "/usr/local/bin/kubectl"

function Get-WslPath {
    $candidatePaths = @(
        "$env:SystemRoot\Sysnative\wsl.exe",
        "$env:SystemRoot\System32\wsl.exe",
        "C:\Windows\Sysnative\wsl.exe",
        "C:\Windows\System32\wsl.exe"
    )

    foreach ($path in $candidatePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw "wsl.exe not found. Checked paths: $($candidatePaths -join ', ')"
}

$WslPath = Get-WslPath

function Write-PrtgJson {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Payload
    )

    $json = $Payload | ConvertTo-Json -Depth 20 -Compress

    # Important:
    # Only write JSON. No Write-Host, no extra text, no banner.
    [Console]::Out.Write($json)
}

function Write-PrtgError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $payload = [ordered]@{
        prtg = [ordered]@{
            error = 1
            text  = $Message
        }
    }

    Write-PrtgJson -Payload $payload
    exit 0
}

function Invoke-Kubectl {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    if (-not (Test-Path $WslPath)) {
        throw "wsl.exe not found at path: $WslPath"
    }

    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        # Capture stdout and stderr separately.
        # This prevents warnings/errors from corrupting JSON parsing.
        $stdout = & $WslPath -d $Distro -- $KubectlPath @Arguments 2> $stderrFile
        $exitCode = $LASTEXITCODE

        $stderr = ""
        if (Test-Path $stderrFile) {
            $stderr = Get-Content -Raw -Path $stderrFile -ErrorAction SilentlyContinue
        }

        if ($exitCode -ne 0) {
            throw "kubectl command failed. WslPath=$WslPath Distro=$Distro ExitCode=$exitCode Args=$($Arguments -join ' ') Stderr=$stderr Stdout=$($stdout -join ' ')"
        }

        return ($stdout -join "`n")
    }
    finally {
        Remove-Item -Path $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

try {
    $nodesJsonRaw = Invoke-Kubectl @("get", "nodes", "-o", "json")
    $podsJsonRaw = Invoke-Kubectl @("get", "pods", "-A", "-o", "json")
    $deploymentsJsonRaw = Invoke-Kubectl @("get", "deployments", "-A", "-o", "json")
    $servicesJsonRaw = Invoke-Kubectl @("get", "services", "-A", "-o", "json")

    $nodesJson = $nodesJsonRaw | ConvertFrom-Json
    $podsJson = $podsJsonRaw | ConvertFrom-Json
    $deploymentsJson = $deploymentsJsonRaw | ConvertFrom-Json
    $servicesJson = $servicesJsonRaw | ConvertFrom-Json

    $nodes = @($nodesJson.items)
    $pods = @($podsJson.items)
    $deployments = @($deploymentsJson.items)
    $services = @($servicesJson.items)

    $nodesTotal = $nodes.Count
    $nodesReady = 0

    foreach ($node in $nodes) {
        $readyCondition = @($node.status.conditions) | Where-Object { $_.type -eq "Ready" } | Select-Object -First 1

        if ($null -ne $readyCondition -and $readyCondition.status -eq "True") {
            $nodesReady++
        }
    }

    $podsTotal = $pods.Count
    $podsRunning = @($pods | Where-Object { $_.status.phase -eq "Running" }).Count
    $podsPending = @($pods | Where-Object { $_.status.phase -eq "Pending" }).Count
    $podsFailed = @($pods | Where-Object { $_.status.phase -eq "Failed" }).Count

    $deploymentsTotal = $deployments.Count
    $deploymentsReady = 0

    foreach ($deployment in $deployments) {
        $desired = 0
        $ready = 0

        if ($null -ne $deployment.spec.replicas) {
            $desired = [int]$deployment.spec.replicas
        }

        if ($null -ne $deployment.status.readyReplicas) {
            $ready = [int]$deployment.status.readyReplicas
        }

        if ($desired -eq 0) {
            $deploymentsReady++
        }
        elseif ($ready -ge $desired) {
            $deploymentsReady++
        }
    }

    $servicesTotal = $services.Count

    $containerRestarts = 0

    foreach ($pod in $pods) {
        $containerStatuses = @($pod.status.containerStatuses)

        foreach ($containerStatus in $containerStatuses) {
            if ($null -ne $containerStatus.restartCount) {
                $containerRestarts += [int]$containerStatus.restartCount
            }
        }
    }

    $healthText = "Kubernetes cluster checked successfully. Nodes Ready: $nodesReady/$nodesTotal, Pods Running: $podsRunning/$podsTotal, Deployments Ready: $deploymentsReady/$deploymentsTotal"

    $payload = [ordered]@{
        prtg = [ordered]@{
            result = @(
                [ordered]@{
                    channel = "Nodes Total"
                    value   = $nodesTotal
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Nodes Ready"
                    value   = $nodesReady
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Pods Total"
                    value   = $podsTotal
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Pods Running"
                    value   = $podsRunning
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Pods Pending"
                    value   = $podsPending
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Pods Failed"
                    value   = $podsFailed
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Deployments Total"
                    value   = $deploymentsTotal
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Deployments Ready"
                    value   = $deploymentsReady
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Services Total"
                    value   = $servicesTotal
                    unit    = "Count"
                },
                [ordered]@{
                    channel = "Container Restarts"
                    value   = $containerRestarts
                    unit    = "Count"
                }
            )
            text = $healthText
        }
    }

    Write-PrtgJson -Payload $payload
    exit 0
}
catch {
    Write-PrtgError -Message "Kubernetes monitoring failed: $($_.Exception.Message)"
}