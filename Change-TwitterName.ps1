Remove-Variable *
cls

if (!(Get-Module PSTwitterAPI))
{
    try
    {
        Import-Module PSTwitterAPI -ErrorAction SilentlyContinue
    }
    catch
    {
        if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) 
        {
            if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) 
            {
                $CommandLine = "Install-Module PSTwitterAPI -Force"
                Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
                Break
            }
        } 
        Import-Module PSTwitterAPI 
    }  
}

$OAuthSettings = @{
  ApiKey = (Get-Content -Path ".\creds\ApiKey.txt")
  ApiSecret = (Get-Content -Path ".\creds\ApiSecret.txt")
  AccessToken = (Get-Content -Path ".\creds\AccessToken.txt")
  AccessTokenSecret = (Get-Content -Path ".\creds\AccessTokenSecret.txt")
}
Set-TwitterOAuthSettings @OAuthSettings -WarningAction SilentlyContinue

function Xoge-ProfileRename {
    [CmdletBinding()]
    Param(
        [string]$name
    )
    Begin {

        [hashtable]$Parameters = $PSBoundParameters
        [string]$Method      = 'POST'
        [string]$Resource    = '/account/update_profile'
        [string]$ResourceUrl = 'https://api.twitter.com/1.1/account/update_profile.json'

    }
    Process {

        # Find & Replace any ResourceUrl parameters.
        $UrlParameters = [regex]::Matches($ResourceUrl, '(?<!\w):\w+')
        ForEach ($UrlParameter in $UrlParameters) {
            $UrlParameterValue = $Parameters["$($UrlParameter.Value.TrimStart(":"))"]
            $ResourceUrl = $ResourceUrl -Replace $UrlParameter.Value, $UrlParameterValue
        }

        $OAuthSettings = Get-TwitterOAuthSettings -Resource $Resource
        Invoke-TwitterAPI -Method $Method -ResourceUrl $ResourceUrl -Parameters $Parameters -OAuthSettings $OAuthSettings | Out-Null
        $Parameters.Values
    }
    End {

    }
}

while ($true) {
    $NamePrefix = (Get-Content -Path ".\names\Prefix.txt")
    $NameSuffix =  (Get-Content -Path ".\names\Suffix.txt")

    if ($NamePrefix.Count -gt 1)
    {
        $NamePrefix = (Get-Content -Path ".\names\Prefix.txt") | Get-Random
    }
    if ($NameSuffix.Count -gt 1)
    {
        $NameSuffix =  (Get-Content -Path ".\names\Suffix.txt") | Get-Random
    }

    Xoge-ProfileRename "$($NamePrefix) - $($NameSuffix)"
    Start-Sleep -Seconds 3 
} 
