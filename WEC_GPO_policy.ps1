# Import the Group Policy module
Import-Module GroupPolicy

# Define GPO names and OU paths
$GPOName_DC = "Audit Settings for DCs"
$GPOName_ServersNotebooks = "Audit Settings for Servers and Notebooks"
$OUPath_DC = "OU=Domain Controllers,DC=yourdomain,DC=local"
$OUPath_Servers = "OU=Servers,DC=yourdomain,DC=local"
$OUPath_Notebooks = "OU=Notebooks,DC=yourdomain,DC=local"

# Create GPOs for DCs and Servers/Notebooks
$NewGPO_DC = New-GPO -Name $GPOName_DC -Comment "Audit Settings for Domain Controllers"
$NewGPO_ServersNotebooks = New-GPO -Name $GPOName_ServersNotebooks -Comment "Audit Settings for Servers and Notebooks"
Write-Host "Created GPOs: $GPOName_DC and $GPOName_ServersNotebooks"

# Link GPOs to the respective OUs
New-GPLink -Name $GPOName_DC -Target $OUPath_DC
Write-Host "Linked GPO '$GPOName_DC' to OU: $OUPath_DC"
New-GPLink -Name $GPOName_ServersNotebooks -Target $OUPath_Servers
New-GPLink -Name $GPOName_ServersNotebooks -Target $OUPath_Notebooks
Write-Host "Linked GPO '$GPOName_ServersNotebooks' to OUs: $OUPath_Servers and $OUPath_Notebooks"

# Function to set audit policies for a GPO
function Set-AuditPolicy {
    param (
        [string]$GPOName,
        [string]$Subcategory,
        [string]$SuccessSetting,
        [string]$FailureSetting = ""
    )
    Write-Host "Setting $Subcategory in $GPOName with Success=$SuccessSetting and Failure=$FailureSetting"
    Auditpol.exe /set /subcategory:"$Subcategory" /success:$SuccessSetting /failure:$FailureSetting
}

# Apply DC-specific settings for all categories
Write-Host "Applying DC-specific settings"
$DCSettings = @(
    @{Subcategory="Audit Kerberos Authentication Service"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Kerberos Service Ticket Operations"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Application Group Management"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Computer Account Management"; Success="Success"},
    @{Subcategory="Audit Distribution Group Management"; Success="Success"},
    @{Subcategory="Audit Other Account Management Events"; Success="Success"},
    @{Subcategory="Audit Security Group Management"; Success="Success"},
    @{Subcategory="Audit User Account Management"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit DPAPI Activity"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit PNP Activity"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Process Creation"; Success="Success"},
    @{Subcategory="Audit Detailed Directory Service Replication"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Directory Service Access"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Directory Services Changes"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Directory Service Replication"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Account Lockout"; Failure="Failure"},
    @{Subcategory="Audit Logoff"; Success="Success"},
    @{Subcategory="Audit Logon"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Other Logon / Logoff Events"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Special Logon"; Success="Success"},
    @{Subcategory="Audit File System"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Other Object Access Events"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Registry"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Removable Storage"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Policy Change"; Success="Success"},
    @{Subcategory="Audit Authentication Policy Change"; Success="Success"},
    @{Subcategory="Audit Authorization Policy Change"; Success="Success"},
    @{Subcategory="Audit MPSSVC Rule-Level Policy Change"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Non Sensitive Privilege Use"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Sensitive Privilege Use"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Other System Events"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Security State Change"; Success="Success"},
    @{Subcategory="Audit Security System Extension"; Success="Success"}
)

foreach ($Setting in $DCSettings) {
    Set-AuditPolicy -GPOName $GPOName_DC -Subcategory $Setting.Subcategory -SuccessSetting $Setting.Success -FailureSetting $Setting.Failure
}

# Apply shared settings for servers and notebooks
Write-Host "Applying shared settings for Servers and Notebooks"
$CommonSettings = @(
    @{Subcategory="Audit Other Account Management Events"; Success="Success"},
    @{Subcategory="Audit Security Group Management"; Success="Success"},
    @{Subcategory="Audit User Account Management"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit DPAPI Activity"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit PNP Activity"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Process Creation"; Success="Success"},
    @{Subcategory="Audit Account Lockout"; Failure="Failure"},
    @{Subcategory="Audit Logoff"; Success="Success"},
    @{Subcategory="Audit Logon"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Other Logon / Logoff Events"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Special Logon"; Success="Success"},
    @{Subcategory="Audit File System"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Other Object Access Events"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Registry"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Removable Storage"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Policy Change"; Success="Success"},
    @{Subcategory="Audit Authentication Policy Change"; Success="Success"},
    @{Subcategory="Audit Authorization Policy Change"; Success="Success"},
    @{Subcategory="Audit MPSSVC Rule-Level Policy Change"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Non Sensitive Privilege Use"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Sensitive Privilege Use"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Other System Events"; Success="Success"; Failure="Failure"},
    @{Subcategory="Audit Security State Change"; Success="Success"},
    @{Subcategory="Audit Security System Extension"; Success="Success"}
)

foreach ($Setting in $CommonSettings) {
    Set-AuditPolicy -GPOName $GPOName_ServersNotebooks -Subcategory $Setting.Subcategory -SuccessSetting $Setting.Success -FailureSetting $Setting.Failure
}

# Apply policy updates
gpupdate /force
Write-Host "Audit policies have been configured and Group Policy updated."
