# Exchange Message Tracking Log Integration for KUMA SIEM

## 1. Overview
This guide explains how to securely provide KUMA SIEM platform with access to Microsoft Exchange Message Tracking Logs stored on a Windows Server, without installing any agent on the Exchange machine.  
Data is collected by mounting the Exchange log folder on KUMA SIEM collector via Kerberos-authenticated CIFS (SMB) connection using a service account and keytab.

---

## 2. Components Used
- **Exchange Server** — where Message Tracking logs are located  
- **Active Directory Domain Controller (DC)** — to create the service account and keytab  
- **KUMA SIEM Collector** — where the mount and script will be configured  
- **Kerberos Keytab** — used for passwordless authentication between Linux and AD

---

## 3. Create the Service Account in Active Directory
Run the following commands on a Domain Controller (everything in red below should be changed to your values):

```powershell
$Password = ConvertTo-SecureString "YourStrongPassword!" -AsPlainText -Force
New-ADUser -Name "siem_user" `
  -SamAccountName "siem_user" `
  -UserPrincipalName "siem_user@EXAMPLE.LOCAL" `
  -AccountPassword $Password `
  -Enabled $true `
  -PasswordNeverExpires $true `
  -CannotChangePassword $true `
  -Description "Service account for SIEM Exchange log access"
```

---

## 4. Generate the Kerberos Keytab File
Run this command on the Domain Controller:

```powershell
ktpass /out "C:\temp\siem_user.keytab" `
  /princ siem_user@EXAMPLE.LOCAL `
  /mapuser EXAMPLE\siem_user `
  /ptype KRB5_NT_PRINCIPAL `
  /crypto AES256-SHA1 `
  /pass "YourStrongPassword!"
```

---

## 5. Assign Read Permissions on the Exchange Logs Folder
Grant **Read & Execute** permissions to the service account (`EXAMPLE\siem_user`) on the folder:

```
C:\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\MessageTracking
```

---

## 6. Prepare the KUMA SIEM Collector
Copy the keytab and run the provided setup script:

```bash
scp C:\temp\siem_user.keytab root@kuma.example.local:/root/siem_user.keytab
```

Save and run the script `exchange_mount_setup.sh`.  
It installs dependencies, places the keytab in `/etc/security/keytabs`, configures Kerberos renewal via `systemd` timer, mounts the Exchange share (`sec=krb5`), and verifies the setup.

---

## 7. Verify Operation
Run `klist` to verify the Kerberos ticket and check the mounted folder:

```bash
klist
mount | grep exchange
ls -l /mnt/exchange_logs | head
```

---

## 8. Optional Security Recommendations
- Restrict permissions on `/etc/security/keytabs` to `root:root` (`chmod 700`)  
- Use a dedicated read-only AD account  
- Rotate the service account password periodically and regenerate keytab  
- Monitor access and mount logs for anomalies

---

## Final Result
Exchange logs are securely mounted under `/mnt/exchange_logs` (read-only).  
The Kerberos ticket renews automatically every 8 hours.  
KUMA SIEM reads the Message Tracking logs directly with no need for local agents.
