
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
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Export-ModuleMember -Function Update-SessionEnvironment, Test-Administrator
