<#PSScriptInfo
.VERSION 1.0.2
.GUID 1c2b2e57-0b15-4288-949d-9ebd514e1faa
.AUTHOR JDMSFT
.COMPANYNAME JDMSFT
.COPYRIGHT (c) 2021 JDMSFT. All Right Reserved.
.TAGS AzureAutomation Runbook AzureAD Application Credential Certificate Secret Expiration Notification Watcher Report AAD Cred Cert Expire Alert Notify Mail
.LICENSEURI https://github.com/jdmsft/AzureADAppCredWatcher/blob/master/LICENSE
.PROJECTURI https://github.com/jdmsft/AzureADAppCredWatcher
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    1.0.2   Fix license link
    1.0.1   Fix Automation Runbook default description (512 char limit)
    1.0.0   First release (list aad aplication certs and secrets + optionally send mail report using o365 mail account)
.PRIVATEDATA
#>

<#
.SYNOPSIS
    Azure AD Application Credential Watcher for Azure Automation (aka AzureADAppCredWatcher)

.DESCRIPTION
    Azure AD Application Credential Watcher (for Azure Automation) : Retrieve all Azure AD application credentials (secrets and certificates) and send a mail report via Office 365 mail account for <expire soon> and <expired> credentials statuses.

.PARAMETER ExpireSoonMonthThreshold
   Mandatory (with default of "12").
   Specify the default month threshold for <expire soon> state of your application credential

.PARAMETER AADConnectionName
    Mandatory (with default of "AADConnection").
    Specify the Automation connection name used as the Azure AD credential.

.PARAMETER EnableO365MailNotification
    Mandatory (with default of "$false").
    Enable or Disable mail notifications (using an Office 365 with Exchange Online mailbox account)

.PARAMETER O365CredentialName
    Mandatory (with default of "O365Credential").
    Specify the Automation connection name used as the Office 365 credential (with Exchange Online mailbox).

.PARAMETER MailRecipient
    Mandatory (with default of "alias@domain.com").
    Specify the mail recipient.

.PARAMETER EnableAppOutputDetails
    Mandatory (with default of "$false").
    Enable or Disable the full app detailed output (Enabme is not recommended when you have a lot of applications and/or a lot of credentials associated)

.NOTES

    PREREQUSITES (see https://github.com/jdmsft/AzureADAppCredWatcher#prerequisites for full details)

        /!\ REQUIRE AZURE AUTOMATION /!\
        Use this script as Azure Automation PowerShell runbook


        /!\ REQUIRE AZURE AD SERVICE PRINCIPAL /!\
        Like many apps / runbooks in Azure, Azure AD this runbook needs a service principal to run (also known as Automation RunAs Account / Automation Connection). This service principal needs to read Azure AD application data (e.g. Directory Reader).


        /!\ REQUIRE AZURE AUTOMATION ASSETS (Shared Resources) /!\
        * Module : AzureAD
        * Connection : an AzureServicePrincipal connection used by "AAD App Cred Watcher" to read your Azure AD applications. 
        * Certificate : used by above connection to authenticate with Azure Active Directory.
        * Schedule : to automate your runbook execution, you should define an Automation schedule associated to this runbook for a recurring mail report (we recommend a 1-month recurrence without expiration).

    PS MODULE DEPENDENCIES
    AzureAD (tested on v2.0.2.135)
#>
[CmdletBinding()]
param (
    [int]$ExpireSoonMonthThreshold = 12,
    [string]$AADConnectionName = 'AADConnection',
    [boolean]$EnableO365MailNotification = $false,
    [string]$O365CredentialName = 'O365Credential',
    [string]$MailRecipient = 'alias@domain.com',
    [boolean]$EnableOutputDetails = $false
)

If ($PSPrivateMetadata.JobId)
{
    Write-Verbose "Runbook environment : Azure Automation"
    Write-Output "AzureAD Connector for Azure Automation v1.0.0`n(c) 2020 - 2021 JDMSFT. All right Reserved."
    $ConnectorTimer = [system.diagnostics.stopwatch]::StartNew()

    Try
    {
        Write-Output "[CONNECTOR] Connecting to Azure AD ..."
        $AutomationConnection = Get-AutomationConnection -Name $AADConnectionName
        Connect-AzureAD `
            -TenantId $AutomationConnection.TenantId `
            -ApplicationId $AutomationConnection.ApplicationId `
            -CertificateThumbprint $AutomationConnection.CertificateThumbprint `
            | Out-Null
    }
    Catch 
    {
        If (!$AutomationConnection)
        {
            $ErrorMessage = "Connection $AutomationConnectionName not found."
            throw $ErrorMessage
        } 
        Else
        {
            Write-Error $($_) ; throw "[$($_.InvocationInfo.ScriptLineNumber)] $($_.InvocationInfo.Line.TrimStart()) >> $($_)"
        }
    }
    $ConnectorTimer.Stop()
    Write-Output "[CONNECTOR] Elapsed time : $($ConnectorTimer.Elapsed)"
}

Write-Output "`nAzure AD Application Credential Watcher v1.0.2`n(c) 2021 JDMSFT. All right Reserved.`n"
Write-Warning "[RUNBOOK] You defined $ExpireSoonMonthThreshold months as month threshold. Every application credential less than $ExpireSoonMonthThreshold months will be flagged as <expire soon> in the final report."

$output = @()
$today = Get-Date

Write-Verbose "[RUNBOOK] Fetching Azure AD applications ..."
$apps = Get-AzureADApplication
$apps | % {
    $appId = $_.AppId
    $appObjectId = $_.ObjectId
    $appName = $_.DisplayName
    $appCert = $_.KeyCredentials
    $appSecret = $_.PasswordCredentials

    If ($appCert) {$appCert | % { If ($_.EndDate -lt $today.AddMonths($ExpireSoonMonthThreshold)) { $credStatus = "Expire soon" } ElseIf ($_.EndDate -lt $today) { $credStatus = 'Expired' } Else { $credStatus = 'Valid' } ; $output += [PSCustomObject]@{Application = $appName ; ClientId = $appId ; ObjectId = $appObjectId ; CredentialType = 'Certificate' ; CredentialStatus = $credStatus ; CredentialRemainingDays = -[math]::Round(($today-$_.EndDate).TotalDays) ; CredentialId = $_.KeyId ; CredentialStart = $_.StartDate ; CredentialEnd = $_.EndDate } }}
    
    If ($appSecret) {$appSecret | % { If ($_.EndDate -lt $today.AddMonths($ExpireSoonMonthThreshold)) { $credStatus = "Expire soon" } ElseIf ($_.EndDate -lt $today) { $credStatus = 'Expired' } Else { $credStatus = 'Valid' } ; $output += [PSCustomObject]@{Application = $appName ; ClientId = $appId ; ObjectId = $appObjectId ; CredentialType = 'Secret' ; CredentialStatus = $credStatus ; CredentialRemainingDays = - [math]::Round(($today - $_.EndDate).TotalDays) ; CredentialId = $_.KeyId ; CredentialStart = $_.StartDate ; CredentialEnd = $_.EndDate } }}
}

If ($EnableOutputDetails) {$output | ft}

If ($output.CredentialStatus -contains "Expire soon") 
{
    Write-Verbose "[RUNBOOK] Triggering alert for <Expire soon> AAD applications ..."

    If ($EnableO365MailNotification)
    {
        $MailSubject  = "AAD App Credential Watcher : credential(s) expire soon !"
        $MailCredential = Get-AutomationPSCredential -Name $O365CredentialName

        Write-Output "[RUNBOOK] Send O365 mail for <Expire soon> AAD applications ..."
        Send-MailMessage -Credential $MailCredential -SmtpServer smtp.office365.com -Port 587 `
            -To $MailRecipient `
            -Subject $MailSubject `
            -Body (($output | ? {$_.CredentialStatus -eq "Expire soon"} | ConvertTo-Html | Out-String) + "`n`nRECOMMENDATION : Please renew your application credential before it expires if you still use the application and associated credential.") `
            -From $MailCredential.UserName `
            -BodyAsHtml `
            -UseSsl
    }
}

If ($output.CredentialStatus -contains "Expired") 
{ 
    Write-Verbose "[RUNBOOK] Triggering alert for <Expired> AAD application ..."

    If ($EnableO365MailNotification)
    {
        $MailSubject  = "AAD App Credential Watcher : credential(s) expired !"
        $MailCredential = Get-AutomationPSCredential -Name $O365CredentialName

        Write-Output "[RUNBOOK] Send O365 mail for <Expired> AAD applications ..."
        Send-MailMessage -Credential $MailCredential -SmtpServer smtp.office365.com -Port 587 `
            -To $MailRecipient `
            -Subject $MailSubject `
            -Body (($output | ? {$_.CredentialStatus -eq "Expired"} | ConvertTo-Html | Out-String) + "`n`nRECOMMENDATION : You could remove your expired application credential (if you have not renewed it voluntarily) to keep a good management of your apps and dismiss this alert.") `
            -From $MailCredential.UserName `
            -BodyAsHtml `
            -UseSsl
    }

}