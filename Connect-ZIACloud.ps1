[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = "Default")]
    [string] $Username,
    [Parameter(Mandatory = $true, ParameterSetName = "Default")]
    [string] $Password,
    [Parameter(Mandatory = $true, ParameterSetName = "Default")]
    [string] $APIKey,
    [Parameter(ParameterSetName = "Default")]
    [ValidateSet("zscalerbeta.net", "zscalerone.net", "zscalertwo.net", "zscalerthree.net", "zscaler.net", "zscloud.net")]
    [string] $CloudName = "zscloud.net",
    [Parameter(Mandatory = $true, ParameterSetName = "Refresh")]
    [switch] $RefreshAuth
)

begin
{
    function Obfuscate-ApiKey {
        param (
            [string]
            #Your API key
            $APIKey,
            [string]
            #Timestamp
            $Timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        )
    
        $high = $Timestamp.substring($Timestamp.length - 6)
        $low = ([int]$high -shr 1).toString()
        $obfuscatedApiKey = ''
    
        while ($low.length -lt 6) {
            $low = '0' + $low
        }
    
        for ($i = 0; $i -lt $high.length; $i++) {
            $obfuscatedApiKey += $APIKey[[int64]($high[$i].toString())]
        }
    
        for ($j = 0; $j -lt $low.length; $j++) {
            $obfuscatedApiKey += $APIKey[[int64]$low[$j].ToString() + 2]
        }
    
        return $obfuscatedApiKey
    }

    if (-Not $global:ziaAPIConfig) {
        $global:ziaAPIConfig = @{}
    }

    if (-Not $RefreshAuth) {
        $global:ziaAPIConfig["usedCloud"] = $CloudName
        $global:ziaAPIConfig["baseUrl"] = "https://zsapi.{0}/api/v1" -f $global:ziaAPIConfig["usedCloud"]
        
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $global:ziaAPIConfig["auth"] = @{
            "username" = $Username
            "password" = $Password
            "apiKey" = Obfuscate-ApiKey -APIKey $APIKey -Timestamp $timestamp
            "timestamp" =  $timestamp
        }
    }		
}
process
{
    $authBody = $global:ziaAPIConfig["auth"] | ConvertTo-Json -Compress		
    $authUri = "{0}/authenticatedSession" -f $global:ziaAPIConfig["baseUrl"]
    
    try {
        $request = Invoke-WebRequest -Method POST -Uri $authUri -Body $authBody -ContentType "application/json" -SessionVariable apiSession
        $global:ziaAPIConfig["session"] = $apiSession
    }
    catch {
        Write-Error "Authentication failed!"
        throw $_
    }		
}
end
{
    Write-Host "Authentication was successful." -NoNewLine
    Write-Host " DONE" -ForegroundColor Green
    Write-Host ($global:ziaAPIConfig | ConvertTo-Json)
}