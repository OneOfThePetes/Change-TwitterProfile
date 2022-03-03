#region functions collapse
$PSVer = (Get-Host | Select-Object Version).Version 

if (!($PSVer.Major -ge 6))
{
    $TLS12Protocol = [System.Net.SecurityProtocolType] 'Ssl3 , Tls12' 
    [System.Net.ServicePointManager]::SecurityProtocol = $TLS12Protocol
}

$OAuthSettings = @{
  ApiKey = (Get-Content -Path ".\creds\ApiKey.txt")
  ApiSecret = (Get-Content -Path ".\creds\ApiSecret.txt")
  AccessToken = (Get-Content -Path ".\creds\AccessToken.txt")
  AccessTokenSecret = (Get-Content -Path ".\creds\AccessTokenSecret.txt")
} #From https://github.com/mkellerman/PSTwitterAPI/
Set-TwitterOAuthSettings @OAuthSettings -WarningAction SilentlyContinue

$ResourceURLs = `
@{
    "update_profile" = "https://api.twitter.com/1.1/account/update_profile.json"
    "update_profile_image" = "https://api.twitter.com/1.1/account/update_profile_image.json"
    "update_profile_banner" = "https://api.twitter.com/1.1/account/update_profile_banner.json"
    "media_upload" = "https://upload.twitter.com/1.1/media/upload.json"
}

function Get-Eposh {

    [CmdletBinding()]
    Param (
        [int]$Eposh
    )

    Process {

        If ($Eposh) {
            [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Eposh))
        } Else {
            $unixEpochStart = New-Object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
            [DateTime]::UtcNow - $unixEpochStart
        }

    }

} #From https://github.com/mkellerman/PSTwitterAPI/

function Get-OAuthParameters {

    [OutputType('System.Management.Automation.PSCustomObject')]
    Param($ApiKey, $ApiSecret, $AccessToken, $AccessTokenSecret, $Method, $ResourceUrl, $Parameters, $Body)

    Process{

        Try {

            ## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
	        ## Base64 allows for an '=' but Twitter does not.  If this is found, replace it with some alphanumeric character
	        $OAuthNonce = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes("$([System.DateTime]::Now.Ticks.ToString())12345"))).Replace('=', 'g')

            ## Find the total seconds since 1/1/1970 (epoch time)
		    $OAuthTimestamp = [System.Convert]::ToInt64((Get-Eposh).TotalSeconds).ToString();

            ## EscapeDataString the parameters
            $EscapedParameters = @{}
            foreach($Param in $($Parameters.Keys)){
                $EscapedParameters[$Param] = "$([System.Uri]::EscapeDataString($Parameters[$Param]))".Replace("!","%21").Replace("'","%27").Replace("(","%28").Replace(")","%29").Replace("*","%2A")
            }

            ## Build the enpoint url
            $EndPointUrl = "${ResourceUrl}?"
            $EscapedParameters.GetEnumerator() | Where-Object { $_.Value -is [string] } | Sort-Object Name | ForEach-Object { $EndPointUrl += "$($_.Key)=$($_.Value)&" }
            $EndPointUrl = $EndPointUrl.TrimEnd('&')

            ## Build the signature
            $SignatureBase = "$([System.Uri]::EscapeDataString("${ResourceUrl}"))&"
			$SignatureParams = @{
				'oauth_consumer_key' = $ApiKey;
				'oauth_nonce' = $OAuthNonce;
				'oauth_signature_method' = 'HMAC-SHA1';
				'oauth_timestamp' = $OAuthTimestamp;
				'oauth_token' = $AccessToken;
				'oauth_version' = "1.0";
            }
            $EscapedParameters.Keys | ForEach-Object { $SignatureParams.Add($_ , $EscapedParameters.Item($_)) }

			## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
			## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
			$SignatureParams.GetEnumerator() | Sort-Object Name | ForEach-Object { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }

            $SignatureBase = $SignatureBase.Substring(0,$SignatureBase.Length-3)
			$SignatureBase = $Method+'&' + $SignatureBase

			## Create the hashed string from the base signature
			$SignatureKey = [System.Uri]::EscapeDataString($ApiSecret) + "&" + [System.Uri]::EscapeDataString($AccessTokenSecret);

			$hmacsha1 = New-Object System.Security.Cryptography.HMACSHA1;
			$hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);
			$OAuthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));

			## Build the authorization headers using most of the signature headers elements.  This is joining all of the 'Key=Value' elements again
			## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
			$OAuthParameters = $SignatureParams
			$OAuthParameters.Add('oauth_signature', $OAuthSignature)

            $OAuthString = 'OAuth '
            $OAuthParameters.GetEnumerator() | Sort-Object Name | ForEach-Object { $OAuthString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
            $OAuthString = $OAuthString.TrimEnd(', ')
            Write-Verbose "Using authorization string '$OAuthString'"

            $OAuthParameters.Add('endpoint_url', $EndPointUrl)
            $OAuthParameters.Add('endpoint_method', $Method)
            $OAuthParameters.Add('endpoint_authorization', $OAuthString)

            # If Body is required, change contenttype to json
            # Example: Send-TwitterDirectMessages_EventsNew
            If ($Body) {
                $OAuthParameters.Add('endpoint_contentType', "application/json")
                $OAuthParameters.Add('endpoint_body', "$($Body | ConvertTo-Json -Depth 99 -Compress)")
            } Else {
                $OAuthParameters.Add('endpoint_contentType', "application/x-www-form-urlencoded")
            }

            Return $OAuthParameters

        } Catch {
			Write-Error $_.Exception.Message
		}

    }

} #From https://github.com/mkellerman/PSTwitterAPI/

function Invoke-TwitterAPI {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$ResourceUrl,
        [Parameter(Mandatory)]
        [string]$Method,
        [Parameter(Mandatory=$false)]
        $Parameters,
        [Parameter(Mandatory=$false)]
        $Body,
        [Parameter(Mandatory)]
        $OAuthSettings
    )

    $OAuthParameters_Params = @{}
    $OAuthParameters_Params['ApiKey'] = $OAuthSettings.ApiKey
    $OAuthParameters_Params['ApiSecret'] = $OAuthSettings.ApiSecret
    $OAuthParameters_Params['AccessToken'] = $OAuthSettings.AccessToken
    $OAuthParameters_Params['AccessTokenSecret'] = $OAuthSettings.AccessTokenSecret
    $OAuthParameters_Params['Method'] = $Method
    $OAuthParameters_Params['ResourceUrl'] = $ResourceUrl
    $OAuthParameters_Params['Parameters'] = $Parameters
    $OAuthParameters_Params['Body'] = $Body
    $OAuthParameters = Get-OAuthParameters @OAuthParameters_Params

    $RestMethod_Params = @{}
    $RestMethod_Params['Uri'] = $OAuthParameters.endpoint_url
    $RestMethod_Params['Method'] = $OAuthParameters.endpoint_method
    $RestMethod_Params['Headers'] = @{ 'Authorization' = $OAuthParameters.endpoint_authorization }
    $RestMethod_Params['ContentType'] = $OAuthParameters.endpoint_contenttype
    $RestMethod_Params['Body'] = $OAuthParameters.endpoint_body
    Invoke-RestMethod @RestMethod_Params

} #From https://github.com/mkellerman/PSTwitterAPI/

Function Get-RandomImage
{
    param ([string]$ImageDirectory)
    ((Get-ChildItem -Path $ImageDirectory -File | Get-Random) | select FullName).Fullname
}

Function Get-RandomText
{
    param ([string]$FileLocation)
    Get-Content -Path $FileLocation | Get-Random
}

Function Set-TwitterProfileName
{
    param ([string]$Name)
    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.update_profile `
    -Method "POST" `
    -Parameters `
    @{
        "name" = $Name
    } | Out-Null

    Write-Host "Name set to: " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    Write-Host $Name -ForegroundColor Green -BackgroundColor Black 
}

Function Set-TwitterProfileDescription
{
    param ([string]$Description)
    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.update_profile `
    -Method "POST" `
    -Parameters `
    @{
        "description" = $Description
    } | Out-Null
    Write-Host "Description set to: " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    Write-Host $Description -ForegroundColor Green -BackgroundColor Black

}

Function Set-TwitterProfileLocation
{
    param ([string]$Location)
    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.update_profile `
    -Method "POST" `
    -Parameters `
    @{
        "location" = $Location
    } | Out-Null
    Write-Host "Location set to: " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    Write-Host $Location -ForegroundColor Green -BackgroundColor Black

}

Function Set-TwitterProfileBanner
{
    param ([string]$FileUrl)
    $File = Get-Item -Path $FileURL
    $FileFullname = $File.FullName

    if ($FileFullname.EndsWith(".png"))
    {
        $Mime = "image/png"
    }
    elseif ($FileFullname.EndsWith(".jpg"))
    {
        $Mime = "image/jpg"
    }

    $TotalBytes = (Get-ChildItem $FileFullname).Length
    $bufferSize = 3333 # should be a multiplier of 3
    $buffer = New-Object byte[] $bufferSize
    $reader = [System.IO.File]::OpenRead($FileFullname)
    
    [System.Collections.ArrayList]$img = @()
    do {
        $bytesread = $reader.Read($buffer, 0, $bufferSize)
        $null = $img.Add([Convert]::ToBase64String($Buffer, 0, $bytesread))
    } while ($bytesread -eq $bufferSize)
    $reader.Dispose()

    $Init = Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.media_upload `
    -Method "POST" `
    -Parameters `
    @{
        "command" = "INIT"
        "total_bytes" = $File.Length
        "media_type" = $Mime
    }

    $x = 0 
    Write-Host "Uploading Banner... " -ForegroundColor Red -BackgroundColor Black -NoNewline
    Write-Host "Please wait... " -ForegroundColor Magenta -BackgroundColor Black -NoNewline
    foreach ($chunk in $img) 
    {
        Invoke-TwitterAPI `
        -OAuthSettings $OAuthSettings `
        -ResourceUrl $ResourceURLs.media_upload `
        -Method "POST" `
        -Parameters `
        @{
            "command" = "APPEND"
            "media_id" = $Init.media_id
            "media_data" = $img[$x]
            "segment_index" = $x
        } | Out-Null
        $x++
    }

    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.media_upload `
    -Method "POST" `
    -Parameters `
    @{
        "command" = "FINALIZE"
        "media_id" = $Init.media_id
    }  | Out-Null

    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.update_profile_banner `
    -Method "POST" `
    -Parameters `
    @{
        "media_id" = $Init.media_id
    }   | Out-Null

    Write-Host "Banner set to: " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    Write-Host (($File.FullName).Split("\")[$_.count -1]) -ForegroundColor Green -BackgroundColor Black
}

Function Set-TwitterProfileAvatar
{
    param ([string]$FileUrl)
    $File = Get-Item -Path $FileURL
    $FileFullname = $File.FullName

    if ($FileFullname.EndsWith(".png"))
    {
        $Mime = "image/png"
    }
    elseif ($FileFullname.EndsWith(".jpg"))
    {
        $Mime = "image/jpg"
    }

    $TotalBytes = (Get-ChildItem $FileFullname).Length
    $bufferSize = 3333 # should be a multiplier of 3
    $buffer = New-Object byte[] $bufferSize
    $reader = [System.IO.File]::OpenRead($FileFullname)
    
    [System.Collections.ArrayList]$img = @()
    do {
        $bytesread = $reader.Read($buffer, 0, $bufferSize)
        $null = $img.Add([Convert]::ToBase64String($Buffer, 0, $bytesread))
    } while ($bytesread -eq $bufferSize)
    $reader.Dispose()

    $Init = Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.media_upload `
    -Method "POST" `
    -Parameters `
    @{
        "command" = "INIT"
        "total_bytes" = $File.Length
        "media_type" = $Mime
    }

    $x = 0
    Write-Host "Uploading Avatar... " -ForegroundColor Red -BackgroundColor Black -NoNewline
    Write-Host "Please wait... " -ForegroundColor Magenta -BackgroundColor Black -NoNewline
    foreach ($chunk in $img) 
    {
        Invoke-TwitterAPI `
        -OAuthSettings $OAuthSettings `
        -ResourceUrl $ResourceURLs.media_upload `
        -Method "POST" `
        -Parameters `
        @{
            "command" = "APPEND"
            "media_id" = $Init.media_id
            "media_data" = $img[$x]
            "segment_index" = $x
        } | Out-Null
        $x++
    } 

    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.media_upload `
    -Method "POST" `
    -Parameters `
    @{
        "command" = "FINALIZE"
        "media_id" = $Init.media_id
    }  | Out-Null

    Invoke-TwitterAPI `
    -OAuthSettings $OAuthSettings `
    -ResourceUrl $ResourceURLs.update_profile_image `
    -Method "POST" `
    -Parameters `
    @{
        "media_id" = $Init.media_id
    } | Out-Null

    Write-Host "Avatar set to: " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    Write-Host (($File.FullName).Split("\")[$_.count -1]) -ForegroundColor Green -BackgroundColor Black
}

cls
#endregion

#region edit these if you want

$SleepTime = 30 #Twitter rate limit throttle.
$AvatarDirectory = ".\images" #400x400
$BannerDirectory = ".\banners" #Character limit 160
$NamesPrefixFile = ".\text\Prefix.txt"
$NamesSuffixFile = ".\text\Suffix.txt"
$DescriptionFile = ".\text\Description.txt"
$LocationFile = ".\text\Location.txt"

#endregion

#region loop
while ($true) {

    Set-TwitterProfileName -Name "$(Get-RandomText $NamesPrefixFile) - $(Get-RandomText $NamesSuffixFile)"
    Set-TwitterProfileDescription -Description (Get-RandomText $DescriptionFile)
    Set-TwitterProfileLocation -Location (Get-RandomText $LocationFile)

    Set-TwitterProfileAvatar -FileUrl (Get-RandomImage -ImageDirectory $AvatarDirectory)
    Set-TwitterProfileBanner -FileUrl (Get-RandomImage -ImageDirectory $BannerDirectory)

    Write-Host "===============Waiting $($SleepTime) Seconds=======================" -ForegroundColor Red -BackgroundColor Black

    Start-Sleep $SleepTime

}
#endregion

