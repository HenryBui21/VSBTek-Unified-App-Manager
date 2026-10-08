
function Update-SessionEnvironment {
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan

    # Properly merge Machine and User paths
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"

    # Refresh other variables
    foreach ($scope in 'Machine', 'User') {
        foreach ($key in [System.Environment]::GetEnvironmentVariables($scope).Keys) {
            if ($key -ine 'Path') {
                $val = [System.Environment]::GetEnvironmentVariable($key, $scope)
                Set-Item -Path "Env:\$key" -Value $val
            }
        }
    }

    # Append chocolatey to path if not already there
    $chocoPath = "$env:ALLUSERSPROFILE\chocolatey\bin"
    if ($env:Path -notlike "*$chocoPath*") {
        $env:Path = "$env:Path;$chocoPath"
    }

    # Append WindowsApps (winget) to path if not already there
    $winAppsPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if ((Test-Path $winAppsPath) -and ($env:Path -notlike "*$winAppsPath*")) {
        $env:Path = "$env:Path;$winAppsPath"
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Disable-ConsoleQuickEdit {
    try {
        if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return }

        $code = @"
        using System;
        using System.Runtime.InteropServices;
        public static class ConsoleQuickEditHelper {
            const int STD_INPUT_HANDLE = -10;
            const uint ENABLE_QUICK_EDIT_MODE = 0x0040;
            const uint ENABLE_EXTENDED_FLAGS = 0x0080;
            [DllImport("kernel32.dll", SetLastError = true)]
            static extern IntPtr GetStdHandle(int nStdHandle);
            [DllImport("kernel32.dll", SetLastError = true)]
            static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
            [DllImport("kernel32.dll", SetLastError = true)]
            static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
            public static void Disable() {
                IntPtr handle = GetStdHandle(STD_INPUT_HANDLE);
                if (handle != IntPtr.Zero && GetConsoleMode(handle, out uint mode)) {
                    mode &= ~ENABLE_QUICK_EDIT_MODE;
                    mode |= ENABLE_EXTENDED_FLAGS;
                    SetConsoleMode(handle, mode);
                }
            }
        }
"@
        if (-not ([System.Management.Automation.PSTypeName]'ConsoleQuickEditHelper').Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }
        [ConsoleQuickEditHelper]::Disable()
    } catch {}
}

Export-ModuleMember -Function Update-SessionEnvironment, Test-Administrator, Disable-ConsoleQuickEdit
