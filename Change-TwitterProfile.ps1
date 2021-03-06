Function Change-TwitterProfile
{
    param ( [bool]$ChangeBanner = $false,
            [bool]$ChangeAvatar = $false, 
            [bool]$ChangeProfileName = $false, 
            [bool]$ChangeScreenName = $false, 
            [bool]$ChangeDescription = $false, 
            [bool]$ChangeLocation = $false,
            [bool]$MinimalOutput = $false,
            [int]$RateLimit = 45 )

    #region functions collapse
    cd $PSScriptRoot
    $ThisScript = $MyInvocation.MyCommand.Name + ".ps1"
    $ThatScript = ("$($PSScriptRoot)\$($MyInvocation.MyCommand.Name).ps1")
    if ($Host.Name -eq "Windows PowerShell ISE Host") 
    {
        try 
        {
            $ErrorActionPreference = "Stop"
            & powershell "start pwsh {$($ThisScript)} -WindowStyle Maximized"
            break
        }
        catch
        {
            #Fix this
            & powershell "start powershell {$($ThatScript)} -WindowStyle Maximized"
            break
        }
    }

    $PSVer = (Get-Host | Select-Object Version).Version 
    if ($PSVer.Major -ge 6)
    {
        [int]$OSVer = ((((($PSVersionTable.os).split(" "))[$_.Count -1]).split("."))[0])     
        if ($OSVer -le 6)
        {
            $MinimalOutput = $true
        }
        elseif ($OSVer -ge 10)
        {
            $MinimalOutput = $false
        }
    }

    if ($PSVer.Major -lt 6)
    {
        $WinVer = (Get-WMIObject win32_operatingsystem).version
        if ([int]$WinVer.Split(".")[0] -le 6)
        {
            $TLS12Protocol = [System.Net.SecurityProtocolType] 'Ssl3 , Tls12' 
            [System.Net.ServicePointManager]::SecurityProtocol = $TLS12Protocol
            $MinimalOutput = $true
        }
        else
        {
            $MinimalOutput = $false
        }     
    }

    $OAuthSettings = @{
      ApiKey = (Get-Content -Path ".\creds\ApiKey.txt")
      ApiSecret = (Get-Content -Path ".\creds\ApiSecret.txt")
      AccessToken = (Get-Content -Path ".\creds\AccessToken.txt")
      AccessTokenSecret = (Get-Content -Path ".\creds\AccessTokenSecret.txt")
    } #From https://github.com/mkellerman/PSTwitterAPI/
    #Set-TwitterOAuthSettings @OAuthSettings -WarningAction SilentlyContinue

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
        
        try{
                Invoke-RestMethod @RestMethod_Params
           }
        catch
            {
                if ($_.Exception.Response.StatusCode.value__ -eq 429)
                {
                    Write-Host "===============Rate Limit Triggered! Waiting 900 Seconds=======================" -ForegroundColor Red -BackgroundColor Black
                    Start-Sleep 900
                }
            }
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

    Function Generate-ProfileName
    {
        param([string]$NamesPrefixFile,[string]$NamesSuffixFile,[int]$Length)    
        Do
        {
            $Name = "$(Get-RandomText $NamesPrefixFile) - $(Get-RandomText $NamesSuffixFile)"
        }
        Until ($Name.Length -le $Length)
        $Name
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

    Function Set-TwitterScreenName
    {
        param ([string]$ScreenName)
        Invoke-TwitterAPI `
        -OAuthSettings $OAuthSettings `
        -ResourceUrl $ResourceURLs.update_profile `
        -Method "POST" `
        -Parameters `
        @{
            "screen_name" = $ScreenName
        } | Out-Null

        Write-Host "Screen Name set to: " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
        Write-Host $ScreenName -ForegroundColor Green -BackgroundColor Black 
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

    Add-Type -Assembly 'System.Drawing'

    function GetPixelText ($color_fg, $color_bg) {
        "$([char]27)[38;2;{0};{1};{2}m$([char]27)[48;2;{3};{4};{5}m" -f $color_fg.r, $color_fg.g, $color_fg.b, $color_bg.r, $color_bg.g, $color_bg.b + [char]9600 + "$([char]27)[0m"
    } #From https://github.com/NotNotWrongUsually/OutConsolePicture

    function Out-ConsolePicture {
        [CmdletBinding()]
        param ([Parameter(Mandatory = $true, ParameterSetName = "FromPath", Position = 0)]
            [ValidateNotNullOrEmpty()][string[]]
            $Path,

            [Parameter(Mandatory = $true, ParameterSetName = "FromPipeline", ValueFromPipeline = $true)]
            [System.Drawing.Bitmap[]]$InputObject,
        
            [Parameter()]        
            [int]$Width,

            [Parameter()]
            [switch]$DoNotResize
        )
    
        begin {
            if ($PSCmdlet.ParameterSetName -eq "FromPath") {
                foreach ($file in $Path) {
                    try {
                        $image = New-Object System.Drawing.Bitmap -ArgumentList "$(Resolve-Path $file)"
                        $InputObject += $image
                    }
                    catch {
                        Write-Error "An error occurred while loading image. Supported formats are BMP, GIF, EXIF, JPG, PNG and TIFF."
                    }
                }
            }
        }
    
        process {
            $InputObject | ForEach-Object {
                if ($_ -is [System.Drawing.Bitmap]) {
                    # Resize image to console width or width parameter
                    if ($width -or (($_.Width -gt $host.UI.RawUI.WindowSize.Width) -and -not $DoNotResize)) {
                                if ($width) {
                            $new_width = $width
                        }
                                else {
                            $new_width = $host.UI.RawUI.WindowSize.Width
                        }
                        $new_height = $_.Height / ($_.Width / $new_width)
                        $resized_image = New-Object System.Drawing.Bitmap -ArgumentList $_, $new_width, $new_height
                        $_.Dispose()
                        $_ = $resized_image
                    }
                    $color_string = New-Object System.Text.StringBuilder
                    for ($y = 0; $y -lt $_.Height; $y++) {
                    if ($y % 2) {
                        continue
                    }
                    else {
                        [void]$color_string.append("`n")
                    }
                    for ($x = 0; $x -lt $_.Width; $x++) {
                        if (($y + 2) -gt $_.Height) {
                                $color_fg = $_.GetPixel($x, $y)
                                $color_bg = [System.Drawing.Color]::FromName($Host.UI.RawUI.BackgroundColor)
                                $pixel = "$([char]27)[38;2;{0};{1};{2}m$([char]27)[48;2;{3};{4};{5}m" -f $color_fg.r, $color_fg.g, $color_fg.b, $color_bg.r, $color_bg.g, $color_bg.b + [char]9600 + "$([char]27)[0m"
                                [void]$color_string.Append($pixel)
                            }
                        else {
                                $color_fg = $_.GetPixel($x, $y)
                                $color_bg = $_.GetPixel($x, $y + 1)
                                $pixel = "$([char]27)[38;2;{0};{1};{2}m$([char]27)[48;2;{3};{4};{5}m" -f $color_fg.r, $color_fg.g, $color_fg.b, $color_bg.r, $color_bg.g, $color_bg.b + [char]9600 + "$([char]27)[0m"
                                [void]$color_string.Append($pixel)
                            }
                    }
                }
                    $color_string.ToString()
                    $_.Dispose()
                }

            }
        }
    
        end {
        }
    } #From https://github.com/NotNotWrongUsually/OutConsolePicture

    cls

    #endregion

    #region edit these if you want

    #Avatars size 400x400px
    $AvatarDirectory = ".\images"

    #Banners size #1500x500px
    $BannerDirectory = ".\banners"

    #Name max 50 characters
    $NamesPrefixFile = ".\text\Prefix.txt"
    $NamesSuffixFile = ".\text\Suffix.txt"

    #Screen Name max 15 characters
    $ScreenNameFile = ".\text\ScreenNames.txt"

    #Description max 160 characters
    $DescriptionFile = ".\text\Description.txt"

    #Location max 150 characters
    $LocationFile = ".\text\Location.txt"

    #endregion

    #region loop
    while ($true) {
        $Time = Measure-Command `
        {     
            if ($ChangeAvatar -eq $true)
            {
                #Set Profile Avatar
                $ChosenAvatar = (Get-RandomImage -ImageDirectory $AvatarDirectory)          
                if ($MinimalOutput -eq $False)
                {
                    Out-ConsolePicture -Path $ChosenAvatar | Out-Host
                }
                Set-TwitterProfileAvatar -FileUrl $ChosenAvatar
            }

            if ($ChangeBanner -eq $true)
            {
                $ChosenBanner = (Get-RandomImage -ImageDirectory $BannerDirectory)
                if ($MinimalOutput -eq $False)
                {
                    Out-ConsolePicture -Path $ChosenBanner | Out-Host
                }
                Set-TwitterProfileBanner -FileUrl $ChosenBanner
            }

            #Set Profile Text Fields
            if ($ChangeProfileName -eq $true)
            {
                Set-TwitterProfileName -Name "$(Generate-ProfileName -NamesPrefixFile $NamesPrefixFile -NamesSuffixFile $NamesSuffixFile -Length 50)"
            }

            if ($ChangeScreenName -eq $true)
            {
                Set-TwitterScreenName -ScreenName (Get-RandomText $ScreenNameFile | where {$_.Length -le 15})
            }

            if ($ChangeDescription -eq $true)
            {
                Set-TwitterProfileDescription -Description (Get-RandomText $DescriptionFile | where {$_.Length -le 160})
            }

            if ($ChangeLocation -eq $true)
            {
                Set-TwitterProfileLocation -Location (Get-RandomText $LocationFile | where {$_.Length -le 150})
            }
        } 

        if ($Time.Seconds -lt $RateLimit)
        {
            $SleepTime = ($RateLimit - $Time.Seconds)
            Write-Host "===============Waiting $($SleepTime) Seconds=======================" -ForegroundColor Red -BackgroundColor Black
            Start-Sleep $SleepTime
        }
        else
        {
            Write-Host "===============Waiting 0 Seconds=======================" -ForegroundColor Red -BackgroundColor Black
        }
    }
    #endregion
}
#Unless these parameters are explicitly set to $true, they default to $false. RateLimit defaults to 45
Change-TwitterProfile `
    -ChangeBanner $false `
    -ChangeAvatar $false `
    -ChangeProfileName $true `
    -ChangeScreenName $false `
    -ChangeDescription $true `
    -ChangeLocation $true `
    -MinimalOutput $true `
    -RateLimit 60
