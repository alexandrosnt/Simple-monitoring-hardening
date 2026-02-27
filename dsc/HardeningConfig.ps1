Configuration HardeningConfig {
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost {

        # --- Firewall rules ---

        Script FirewallRuleHTTP {
            GetScript  = { @{ Result = (netsh advfirewall firewall show rule name="Allow HTTP") } }
            TestScript = {
                $rule = netsh advfirewall firewall show rule name="Allow HTTP" 2>$null
                return ($rule -match 'Allow HTTP')
            }
            SetScript  = {
                netsh advfirewall firewall add rule name="Allow HTTP" `
                    dir=in action=allow protocol=tcp localport=80
            }
        }

        Script FirewallRuleHTTPS {
            GetScript  = { @{ Result = (netsh advfirewall firewall show rule name="Allow HTTPS") } }
            TestScript = {
                $rule = netsh advfirewall firewall show rule name="Allow HTTPS" 2>$null
                return ($rule -match 'Allow HTTPS')
            }
            SetScript  = {
                netsh advfirewall firewall add rule name="Allow HTTPS" `
                    dir=in action=allow protocol=tcp localport=443
            }
        }

        Script FirewallRuleWinRM {
            GetScript  = { @{ Result = (netsh advfirewall firewall show rule name="Allow WinRM HTTPS") } }
            TestScript = {
                $rule = netsh advfirewall firewall show rule name="Allow WinRM HTTPS" 2>$null
                return ($rule -match 'Allow WinRM HTTPS')
            }
            SetScript  = {
                netsh advfirewall firewall add rule name="Allow WinRM HTTPS" `
                    dir=in action=allow protocol=tcp localport=5986
            }
        }

        Script FirewallRuleSSH {
            GetScript  = { @{ Result = (netsh advfirewall firewall show rule name="Allow SSH") } }
            TestScript = {
                $rule = netsh advfirewall firewall show rule name="Allow SSH" 2>$null
                return ($rule -match 'Allow SSH')
            }
            SetScript  = {
                netsh advfirewall firewall add rule name="Allow SSH" `
                    dir=in action=allow protocol=tcp localport=22
            }
        }

        Script FirewallRuleRDP {
            GetScript  = { @{ Result = (netsh advfirewall firewall show rule name="Allow RDP") } }
            TestScript = {
                $rule = netsh advfirewall firewall show rule name="Allow RDP" 2>$null
                return ($rule -match 'Allow RDP')
            }
            SetScript  = {
                netsh advfirewall firewall add rule name="Allow RDP" `
                    dir=in action=allow protocol=tcp localport=3389
            }
        }

        # --- Enable Windows Firewall on all profiles ---

        Script EnableFirewall {
            GetScript  = { @{ Result = (netsh advfirewall show allprofiles state) } }
            TestScript = {
                $output = netsh advfirewall show allprofiles state
                return (-not ($output -match 'OFF'))
            }
            SetScript  = {
                netsh advfirewall set allprofiles state on
            }
        }

        # --- Disable SMBv1 ---

        WindowsOptionalFeature DisableSMBv1 {
            Name   = 'SMB1Protocol'
            Ensure = 'Disable'
        }

        # --- Registry: disable autorun ---

        Registry DisableAutorun {
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
            ValueName = 'NoDriveTypeAutoRun'
            ValueType = 'Dword'
            ValueData = '255'
            Ensure    = 'Present'
        }

        # --- Registry: require NTLMv2 ---

        Registry RequireNTLMv2 {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            ValueName = 'LmCompatibilityLevel'
            ValueType = 'Dword'
            ValueData = '5'
            Ensure    = 'Present'
        }

        # --- Audit policy: logon events ---

        Script AuditLogonEvents {
            GetScript  = { @{ Result = (auditpol /get /subcategory:"Logon" 2>$null) } }
            TestScript = {
                $output = auditpol /get /subcategory:"Logon" 2>$null
                return ($output -match 'Success and Failure')
            }
            SetScript  = {
                auditpol /set /subcategory:"Logon" /success:enable /failure:enable
            }
        }

        Script AuditAccountLogon {
            GetScript  = { @{ Result = (auditpol /get /subcategory:"Credential Validation" 2>$null) } }
            TestScript = {
                $output = auditpol /get /subcategory:"Credential Validation" 2>$null
                return ($output -match 'Success and Failure')
            }
            SetScript  = {
                auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
            }
        }

        # --- Account lockout policy (brute-force protection) ---

        Script AccountLockoutPolicy {
            GetScript  = {
                $output = net accounts
                @{ Result = $output }
            }
            TestScript = {
                $output = net accounts
                $threshold = ($output | Select-String 'Lockout threshold') -match '5'
                $duration  = ($output | Select-String 'Lockout duration')  -match '30'
                $window    = ($output | Select-String 'Lockout observation window') -match '30'
                return ($threshold -and $duration -and $window)
            }
            SetScript  = {
                net accounts /lockoutthreshold:5 /lockoutduration:30 /lockoutwindow:30
            }
        }

        # --- Ensure OpenSSH Server is running ---

        WindowsFeature OpenSSHServer {
            Name   = 'OpenSSH-Server'
            Ensure = 'Present'
        }

        Script OpenSSHService {
            GetScript  = {
                $svc = Get-Service sshd -ErrorAction SilentlyContinue
                @{ Result = if ($svc) { $svc.Status } else { 'Absent' } }
            }
            TestScript = {
                $svc = Get-Service sshd -ErrorAction SilentlyContinue
                return ($svc -and $svc.Status -eq 'Running' -and $svc.StartType -eq 'Automatic')
            }
            SetScript  = {
                Set-Service sshd -StartupType Automatic
                Start-Service sshd
            }
            DependsOn  = '[WindowsFeature]OpenSSHServer'
        }
    }
}
