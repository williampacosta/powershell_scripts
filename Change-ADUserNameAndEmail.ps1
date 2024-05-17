# Author: William P Acosta
# Description: Use this script to change a user's Display name and primary SMTP address in Active Directory.

Import-Module ActiveDirectory

# Define exit codes
$exitCodes = @{
    Success = 0
    InvalidUser = 1
    UpdateFailed = 2
    RenameFailed = 3
    EmailUpdateFailed = 4
}

# Input Network account and new name
$alias = Read-Host -Prompt 'Input Network Account'
if (-not (Get-ADUser -Identity $alias -ErrorAction SilentlyContinue)) {
    Write-Host "Error: User not found"
    exit $exitCodes.InvalidUser
}

Write-Host "Input New Name for User"
$First = Read-Host -Prompt 'First Name'
$Last = Read-Host -Prompt 'Last Name'

# Input custom domain
$domain = Read-Host -Prompt 'Input Custom Domain'

# Update AD user fields
$DisplayName = "$Last $First"
try {
    Set-ADUser $alias -DisplayName $DisplayName -GivenName $First -Surname $Last
} catch {
    Write-Host "Error: Failed to update user attributes"
    exit $exitCodes.UpdateFailed
}

# Rename AD object
try {
    $DistinguishedName = Get-ADUser $alias | Select-Object -ExpandProperty DistinguishedName
    Rename-ADObject -Identity $DistinguishedName -NewName $DisplayName
} catch {
    Write-Host "Error: Failed to rename AD object"
    exit $exitCodes.RenameFailed
}

# Find current email address and primary SMTP
try {
    $OldEmail = Get-ADUser $alias -Properties mail | Select-Object -ExpandProperty mail
    $OldPrimarySMTP = (Get-ADUser $alias -Properties proxyaddresses).proxyaddresses | Where-Object { $_ -like 'SMTP:*' }
} catch {
    Write-Host "Error: Failed to retrieve email addresses"
    exit $exitCodes.EmailUpdateFailed
}

# Build new email addresses
$NewPrimarySMTP = "SMTP:$First.$Last@$domain"
$NewSecondarySMTP = "smtp:$First.$Last@$domain.mail.onmicrosoft.com"

# Update email addresses
try {
    $proxyAddresses = @("smtp:$OldEmail", $NewPrimarySMTP, $NewSecondarySMTP)
    if ($OldPrimarySMTP) {
        Set-ADUser -Identity $alias -Remove @{ProxyAddresses = $OldPrimarySMTP} -Add @{ProxyAddresses = $proxyAddresses}
    } else {
        Set-ADUser -Identity $alias -Add @{ProxyAddresses = $proxyAddresses}
    }
    Set-ADUser $alias -EmailAddress "$First.$Last@$domain"
} catch {
    Write-Host "Error: Failed to update email addresses"
    exit $exitCodes.EmailUpdateFailed
}

Write-Host "Complete"
exit $exitCodes.Success
