# PRTG Kubernetes WSL Custom Sensor

A lightweight PRTG EXE/Script Advanced Sensor for monitoring Kubernetes cluster summary metrics through WSL and `kubectl`.

This project is designed for lab, demo, webinar and technical validation environments where:

- PRTG Network Monitor runs on Windows
- Kubernetes runs inside WSL
- `kubectl` is available inside the WSL distribution
- PRTG collects Kubernetes metrics through a custom PowerShell sensor

The sensor returns PRTG-compatible JSON and creates multiple monitoring channels inside PRTG.

## What This Sensor Monitors

The custom sensor collects the following Kubernetes summary metrics:

| Channel | Description |
|---|---|
| Nodes Total | Total number of Kubernetes nodes |
| Nodes Ready | Number of nodes in Ready state |
| Pods Total | Total number of pods across all namespaces |
| Pods Running | Number of pods in Running state |
| Pods Pending | Number of pods in Pending state |
| Pods Failed | Number of pods in Failed state |
| Deployments Total | Total number of deployments across all namespaces |
| Deployments Ready | Number of deployments with ready replicas matching desired replicas |
| Services Total | Total number of Kubernetes services |
| Container Restarts | Total container restart count across all pods |

## Architecture

```text
PRTG EXE/Script Advanced Sensor
        ↓
Batch Wrapper
        ↓
PowerShell Script
        ↓
wsl.exe
        ↓
kubectl
        ↓
Kubernetes API
        ↓
PRTG JSON Output
```

## Repository Files

```text
kubernetes_monitors.ps1
```

Main PowerShell script. It executes `kubectl` inside WSL, collects Kubernetes object data and returns PRTG-compatible JSON.

```text
kubernetes_monitors_runner.bat
```

Batch wrapper used by PRTG to run the PowerShell script in a controlled way.

## Requirements

### Windows Side

- Windows with WSL enabled
- PRTG Network Monitor installed
- PRTG Probe running on the Windows machine
- PowerShell available
- Access to the PRTG custom sensor directory

Default PRTG EXE/Script Advanced sensor path:

```text
C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML
```

### WSL Side

- WSL distribution, for example Ubuntu
- `kubectl` installed inside WSL
- A working Kubernetes context
- Access to the target Kubernetes cluster

Validate inside WSL:

```bash
kubectl get nodes
kubectl get pods -A
which kubectl
```

Expected `kubectl` path used by this script:

```text
/usr/local/bin/kubectl
```

If your `kubectl` path is different, update this variable inside `kubernetes_monitors.ps1`:

```powershell
$KubectlPath = "/usr/local/bin/kubectl"
```

## Installation

Copy both files into the PRTG EXE/Script Advanced sensor directory:

```text
C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML
```

Files:

```text
kubernetes_monitors.ps1
kubernetes_monitors_runner.bat
```

Unblock both files from Administrator PowerShell:

```powershell
Unblock-File "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\kubernetes_monitors.ps1"
Unblock-File "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\kubernetes_monitors_runner.bat"
```

## Manual Test

Test the PowerShell script:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\kubernetes_monitors.ps1"
```

Test the batch wrapper:

```powershell
cmd.exe /c "`"C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\kubernetes_monitors_runner.bat`""
```

Expected output starts like this:

```json
{"prtg":{"result":[{"channel":"Nodes Total","value":3,"unit":"Count"}
```

The script output must contain only valid PRTG JSON. Any additional banner, debug text, warning or shell message can break the PRTG sensor parsing.

## PRTG Sensor Configuration

In PRTG:

```text
Device
→ Add Sensor
→ EXE/Script Advanced
```

Recommended settings:

| Setting | Value |
|---|---|
| Sensor Type | EXE/Script Advanced |
| EXE/Script | kubernetes_monitors_runner.bat |
| Sensor Name | Kubernetes Cluster Summary |
| Parameters | Empty |
| Environment | Default |
| Security Context | Use security context of PRTG probe service |
| Timeout | 60 seconds |
| Result Handling | Store result in case of error |

## Important: PRTG Probe Service User Context

WSL distributions and `kubectl` contexts are user-specific.

If the script works in an interactive PowerShell session but fails inside PRTG, the PRTG Probe Service is probably running under a different account, such as Local System.

For lab/demo environments, configure the PRTG Probe Service to run with the Windows user that has access to WSL and the Kubernetes context.

Steps:

```text
services.msc
→ PRTG Probe Service
→ Properties
→ Log On
→ This account
→ Enter the Windows user account
→ Apply
→ Restart the service
```

Example:

```text
.\yusuf
```

After restarting the service, rescan the PRTG sensor.

## Troubleshooting

### Sensor returns XML/JSON schema errors

Possible causes:

- The wrong sensor type was selected
- Use `EXE/Script Advanced`, not the basic EXE/Script sensor
- The script returns extra text before or after the JSON
- PowerShell profile/banner text is being printed
- The batch wrapper is not selected in PRTG

Use:

```text
kubernetes_monitors_runner.bat
```

not:

```text
kubernetes_monitors.ps1
```

directly, unless your PRTG environment handles PowerShell scripts reliably.

### wsl.exe not found

PRTG may run in a 32-bit process context. The script checks both:

```text
C:\Windows\Sysnative\wsl.exe
C:\Windows\System32\wsl.exe
```

If this still fails, verify that WSL is installed and accessible from the account running the PRTG Probe Service.

### kubectl command failed

Validate inside WSL:

```bash
kubectl get nodes
kubectl get pods -A
```

Then verify the WSL distro name:

```powershell
wsl -l -v
```

If your distro is not named `Ubuntu`, update this variable in the PowerShell script:

```powershell
$Distro = "Ubuntu"
```

### Script works manually but fails in PRTG

This is usually a service account context issue.

Fix:

- Run the PRTG Probe Service with the Windows user that owns the WSL/kubectl context
- Restart the PRTG Probe Service
- Rescan the sensor

## Security Notes

This project is intended for lab, demo and controlled technical validation environments.

For production environments:

- Prefer direct Kubernetes API access with a read-only service account
- Use RBAC with least privilege
- Avoid running monitoring services with broad interactive user privileges
- Avoid exposing Kubernetes or Docker APIs unnecessarily
- Store credentials and scripts with appropriate filesystem permissions

## License

Add your preferred license before publishing this repository.

Recommended options:

- MIT License for open sharing
- Apache-2.0 for broader enterprise-friendly usage

## Author

Prepared by Yusuf Dalbudak for PRTG Kubernetes monitoring lab and webinar scenarios.
