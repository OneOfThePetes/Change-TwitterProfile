Remove-Variable *
cls

if (!(Get-Module PSTwitterAPI))
{
    Install-Module PSTwitterAPI
    Import-Module PSTwitterAPI
}

$OAuthSettings = @{
  ApiKey = "YOU NEED TO CREATE THIS"
  ApiSecret = "YOU NEED TO CREATE THIS"
  AccessToken = "YOU NEED TO CREATE THIS"
  AccessTokenSecret = "YOU NEED TO CREATE THIS"
} #Don't show this bit ;)
Set-TwitterOAuthSettings @OAuthSettings -WarningAction SilentlyContinue

function Change-TwitterName {
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
    $NamePrefix = "YOUR USERNAME HERE"
    $NameSuffix =  (Get-Content -Path .\NameChangeNames.txt) | Get-Random

    Change-TwitterName "$($NamePrefix) - $($NameSuffix)"
    Start-Sleep -Seconds 30  
} 
