<#
    .SYNOPSIS
        Update a Azure AD Named Location with Zscaler IPs
    .DESCRIPTION
        This scripts is able to update a ipNamedLocation with the IP ranges used for the Zscaler datacenters.
        For the access to Azure AD the Microsoft.Graph Powershell module is required.
        The scopes Policy.ReadWrite.ConditionalAccess and Policy.Read.All are required.
    .EXAMPLE
        PS> Connect-MgGraph -Scopes Policy.ReadWrite.ConditionalAccess, Policy.Read.All 
        PS> ./Update-AzureADZscalerLocation.ps1 -CloudName "zscloud.net" -NamedLocationName "Zscaler Data Centers"
    .NOTES
        THIS IS NO OFFICIAL SCRIPT PROVIDED BY ZSCALER. USE ON OWN RISK.
        Author: Seitle, Johannes <jseitle@zscaler.com, johannes@seitle.io>
#>

Param (
    [ValidateSet("zscalerbeta.net", "zscalerone.net", "zscalertwo.net", "zscalerthree.net", "zscaler.net", "zscloud.net")]
    [string] $CloudName = "zscloud.net",
    [Parameter(Mandatory = $true)]
    [string] $NamedLocationName
)

begin {
    if (-Not (Get-MgContext)) {
        throw "Please connect to Microsoft Graph (Connect-MgGraph)!"
    }
   
    $ipv6Regex = [regex]"(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))\/(\d{1,2})"
    $namedLocation = (Invoke-GraphRequest -Method GET -Uri ("v1.0/identity/conditionalAccess/namedLocations/?`$filter=displayName eq '{0}'" -f $NamedLocationName)).Value | Select-Object -First 1
    $allCloudDCs = Invoke-WebRequest -Method GET -Uri ("https://api.config.zscaler.com/{0}/cenr/json" -f $CloudName) | ConvertFrom-Json
    $allIPRanges = $allCloudDCs.$CloudName.PSObject.Properties.Value | ForEach-Object { $_.PSObject.Properties.Value.Range }
}
process {
    if (-Not $namedLocation) {
        throw "Location $NamedLocationName does not exist"
    }

    $namedLocation.ipRanges = @($allIPRanges | ForEach-Object {
        if ($ipv6Regex.match($_).Success) {
            $type = "iPv6CidrRange"
        }
        else {
            $type = "iPv4CidrRange"
        }

        return @{
            "@odata.type" = "#microsoft.graph.{0}" -f $type
            "cidrAddress" = $_
        }
    })

    Invoke-GraphRequest -Method PUT -Uri ("v1.0/identity/conditionalAccess/namedLocations/{0}" -f $namedLocation.id) -Body ($namedLocation | select -Property "@odata.type", displayName, ipRanges | ConvertTo-Json -Depth 3)
}