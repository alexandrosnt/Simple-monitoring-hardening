Configuration IISConfig {
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost {

        # --- Install IIS features ---

        WindowsFeature WebServer {
            Name   = 'Web-Server'
            Ensure = 'Present'
        }

        WindowsFeature WebMgmtConsole {
            Name      = 'Web-Mgmt-Console'
            Ensure    = 'Present'
            DependsOn = '[WindowsFeature]WebServer'
        }

        # --- Site directories ---

        File DefaultSiteDir {
            DestinationPath = 'C:\inetpub\wwwroot'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        File StagingSiteDir {
            DestinationPath = 'C:\inetpub\staging'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # --- Default index.html ---

        File DefaultIndex {
            DestinationPath = 'C:\inetpub\wwwroot\index.html'
            Contents        = @'
<!DOCTYPE html>
<html>
<head><title>Default Web Site</title></head>
<body><h1>Default Web Site</h1><p>Managed by PowerShell DSC</p></body>
</html>
'@
            Ensure          = 'Present'
            Type            = 'File'
            DependsOn       = '[File]DefaultSiteDir'
        }

        File StagingIndex {
            DestinationPath = 'C:\inetpub\staging\index.html'
            Contents        = @'
<!DOCTYPE html>
<html>
<head><title>Staging Site</title></head>
<body><h1>Staging Site</h1><p>Managed by PowerShell DSC</p></body>
</html>
'@
            Ensure          = 'Present'
            Type            = 'File'
            DependsOn       = '[File]StagingSiteDir'
        }

        # --- App pool and staging site via WebAdministration ---

        Script StagingAppPool {
            GetScript  = {
                Import-Module WebAdministration
                $pool = Get-Item "IIS:\AppPools\StagingPool" -ErrorAction SilentlyContinue
                @{ Result = if ($pool) { $pool.Name } else { 'Absent' } }
            }
            TestScript = {
                Import-Module WebAdministration
                return (Test-Path "IIS:\AppPools\StagingPool")
            }
            SetScript  = {
                Import-Module WebAdministration
                New-WebAppPool -Name "StagingPool"
            }
            DependsOn  = '[WindowsFeature]WebServer'
        }

        Script StagingSite {
            GetScript  = {
                Import-Module WebAdministration
                $site = Get-Website -Name "staging" -ErrorAction SilentlyContinue
                @{ Result = if ($site) { $site.Name } else { 'Absent' } }
            }
            TestScript = {
                Import-Module WebAdministration
                $site = Get-Website -Name "staging" -ErrorAction SilentlyContinue
                return ($null -ne $site)
            }
            SetScript  = {
                Import-Module WebAdministration
                New-Website -Name "staging" `
                    -PhysicalPath "C:\inetpub\staging" `
                    -ApplicationPool "StagingPool" `
                    -Port 8080
            }
            DependsOn  = @('[Script]StagingAppPool', '[File]StagingSiteDir')
        }
    }
}
