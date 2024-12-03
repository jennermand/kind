function FunctionA {
    param (
        [string]$param1
    )
    Write-Host "Performing function A with parameter: $param1"
    # Add your code for function A here
}

function FunctionB {
    param (
        [string]$param1
    )
    Write-Host "Performing function B with parameter: $param1"
    # Add your code for function B here
}

function FunctionC {
    Write-Host "Performing function C..."
    # Add your code for function C here
}

# Define the menu options as a hashtable
$menuOptions = @{
    'a' = @{
        Description = "Perform function A"
        Action      = { FunctionA -param1 "exampleA" }
    }
    'b' = @{
        Description = "Perform function B"
        Action      = { FunctionB -param1 "exampleB" }
    }
    'x' = @{
        Description = "Exit"
        Action      = { FunctionC }
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "====================="
    Write-Host " Kubernetes Menu"
    Write-Host "====================="
    foreach ($key in $menuOptions.Keys) {
        Write-Host "$key : $($menuOptions[$key].Description)"
    }
    Write-Host "====================="
}

do {
    Show-Menu
    $choice = Read-Host "Enter your choice"

    if ($menuOptions.ContainsKey($choice)) {
        & $menuOptions[$choice].Action
        if ($choice -ne 'x') {
            Pause
        }
    }
    else {
        Write-Host "Invalid choice, please try again."
        Pause
    }
} while ($choice -ne 'x')

Write-Host "Exiting..."
