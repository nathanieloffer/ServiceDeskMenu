# Requires ActiveDirectory module
Import-Module ActiveDirectory

# Path to log file
$LogFile = "C:\HelpDesk\AD_Actions_Log.csv"

# Ensure log file exists with headers
if (-not (Test-Path $LogFile)) {
    "DateTime,UserID,Action" | Out-File $LogFile
}

function Show-Menu {
    Clear-Host
    Write-Host "==============================="
    Write-Host "   Help Desk AD Tool (v5.1)"
    Write-Host "==============================="
    Write-Host "1. User Lookup"
    Write-Host "2. Unlock User Account"
    Write-Host "3. Reset User Password"
    Write-Host "4. Exit"
    Write-Host "==============================="
}

function Log-Action($UserID, $Action) {
    $entry = "{0},{1},{2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $UserID, $Action
    Add-Content -Path $LogFile -Value $entry
}

# Validate format and existence in AD, return user object
function Get-ValidUser {
    param(
        [string]$Prompt = "Enter the username (sAMAccountName)"
    )
    $pattern = '^(we\d+|wex\d+|ext\d+)$'
    do {
        $UserID = Read-Host $Prompt
        if ($UserID -match $pattern) {
            try {
                $user = Get-ADUser -Identity $UserID -Properties LastLogonDate, AccountExpirationDate, PasswordLastSet, Enabled, LockedOut, PasswordExpired -ErrorAction Stop
                return $user
            }
            catch {
                Write-Host "UserID '$UserID' matches the pattern but does not exist in Active Directory." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid UserID format. Must start with 'we', 'wex', or 'ext' followed by numbers." -ForegroundColor Yellow
        }
    } while ($true)
}

function User-Lookup {
    $user = Get-ValidUser
    Write-Host "User: $($user.SamAccountName)"
    Write-Host "Last Logon Date: $($user.LastLogonDate)"
    Write-Host "Account Expiration Date: $($user.AccountExpirationDate)"
    Write-Host "Password Last Changed: $($user.PasswordLastSet)"

    # Colour-coded flags
    if ($user.Enabled) {
        Write-Host "Active: True" -ForegroundColor Green
    } else {
        Write-Host "Active: False" -ForegroundColor Red
    }

    if ($user.LockedOut) {
        Write-Host "Locked Out: True" -ForegroundColor Red
    } else {
        Write-Host "Locked Out: False" -ForegroundColor Green
    }

    if ($user.PasswordExpired) {
        Write-Host "Password Expired: True" -ForegroundColor Red
    } else {
        Write-Host "Password Expired: False" -ForegroundColor Green
    }

    Pause
}

function Unlock-User {
    $user = Get-ValidUser
    try {
        Unlock-ADAccount -Identity $user.SamAccountName
        Write-Host "User $($user.SamAccountName) unlocked successfully." -ForegroundColor Green
        Log-Action -UserID $user.SamAccountName -Action "Unlocked"
    }
    catch {
        Write-Host "Failed to unlock user $($user.SamAccountName)." -ForegroundColor Red
    }
    Pause
}

function Reset-Password {
    $user = Get-ValidUser

    # Hard-coded temporary password (adjust to your policy)
    $TempPassword = ConvertTo-SecureString "TempPass123!" -AsPlainText -Force

    try {
        # Reset the password
        Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword $TempPassword -Reset -ErrorAction Stop

        # Force user to change password at next logon
        Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $true -ErrorAction Stop

        # Unlock account if locked
        if ($user.LockedOut) {
            Unlock-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
            Write-Host "Account was locked. It has now been unlocked." -ForegroundColor Green
            Log-Action -UserID $user.SamAccountName -Action "Password Reset + Unlock (Hard-coded, Change at Logon)"
        } else {
            Log-Action -UserID $user.SamAccountName -Action "Password Reset (Hard-coded, Change at Logon)"
        }

        Write-Host "Password for $($user.SamAccountName) reset successfully." -ForegroundColor Green
        Write-Host "'User must change password at next logon' has been set." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to reset password for $($user.SamAccountName)." -ForegroundColor Red
    }
    Pause
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "Select an option"
    switch ($choice) {
        "1" { User-Lookup }
        "2" { Unlock-User }
        "3" { Reset-Password }
        "4" { break }
        default { Write-Host "Invalid selection. Try again." -ForegroundColor Yellow; Pause }
    }
} while ($true)

