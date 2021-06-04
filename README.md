# Azure AD App Credential Watcher

Azure AD Application Credential Watcher (for Azure Automation) : Retrieve all Azure AD application credentials (secrets and certificates) and send a mail report via Office 365 mail account for <expire soon> and <expired> credentials statuses.

## What is it?

**Azure AD App Credential Watcher** is an **Azure Automation** solution (PowerShell runbook) that help you to list all Azure AD applications secrets and certificates expiration statuses. And optionnaly send a mail report relying on Office 365 mailbox account (Exchange Online). See [Prerequistes below](https://github.com/jdmsft/AzureADAppCredWatcher#prerequisites) to use this solution.

You can use this runbook to:

* List all Azure AD application credentials in the console output
* Send mail report (via Office 365 mail account) for Azure application credentials with <expire soon> and <expired> statuses
* Or both!

## Prerequisites

* An Azure Automation Account
* A Azure AD Service Principal with certificate and read access to your Azure AD application you want to watch (e.g. Global Reader)
* An Automation Connection (type = AzureServicePrincipal) refering to your Azure AD Service Principal
* An Automation Certificate for the Automation Account
* An Automation Schedule if you want to send report reccurently (e.g. monthly)
* An Office 365 mail account credential to use as the account that send the mail notification (if you want to enable mail notification)
