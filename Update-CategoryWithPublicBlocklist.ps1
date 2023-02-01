<#
    .SYNOPSIS
        Update a Zscaler Internet Access URL category with domains from a DNS blocklist.
    .DESCRIPTION
        This script can be used to update a Zscaler Internet Access URL category based on a DNS blocklist.
        Example blocklist: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

        As ZIA has a soft limit of 25,000 URLs by default, you might need to get in contact with your sales contact to raise this limit.
        Zscaler Ranges & Limitations: https://help.zscaler.com/zia/ranges-limitations
    .EXAMPLE
        PS> ./Connect-ZIACloud.ps1 -Username admin@<TENANT_ID>.zscloud.net -Password "<ADMIN_PASSWORD" -APIKey "<API_KEY>" -CloudName zscloud.net
        PS> ./Update-CategoryWithPublicBlocklist.ps1 -CategoryToUpdate "WEB_BANNERS" -Blocklist "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" -URLLimit 1000 -ActivateChanges
    .PARAMETER CategoryToUpdate
        Name of the category to update.
    .PARAMETER BlockList
        URLs to blocklists that should be used.
    .PARAMETER URLLimit
        The script will only use the first 25,000 urls by default. You can change the limit using this parameter.
    .PARAMETER ActivateChanges
        Activate all changes after updating the category. (ONLY USE FOR TESTING OR MAKE SURE YOU CAN ACTIVATE ALL CHANGES).
        Uses the /status/activate endpoint.
    .NOTES
        THIS IS NO OFFICIAL SCRIPT PROVIDED BY ZSCALER. USE ON OWN RISK.
        Author: Seitle, Johannes <jseitle@zscaler.com, johannes@seitle.io>
#>

Param (
    $CategoryToUpdate = "WEB_BANNERS",
    [string[]] $BlockList = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
    [int] $URLLimit = 25000,
    [switch] $ActivateChanges
)

begin {
    if (-Not $global:ziaAPIConfig) {
        throw "Please connect to Zscaler Internet Access API (Connect-ZIACloud)!"
    }

    $category = Invoke-RestMethod -Method GET -Uri "$($Global:ziaAPIConfig.baseUrl)/urlCategories/$CategoryToUpdate" -WebSession $Global:ziaAPIConfig["session"]
    
    $blocklistURLs = @() 
    foreach ($list in $BlockList) {
        $blocklistURLs += (Invoke-WebRequest -Method GET -Uri $list | Select-Object -ExpandProperty Content).split("`n") `
                            | Where-Object {$_ -notmatch "^\#" -and $_ -notmatch "^\s*$"} `
                            | ForEach-Object {
                                (($_ -replace "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}") `
                                    -replace "^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))\/(\d{1,2})").Trim()
                            }
                            | Where-Object {$_ -match "^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$"}
    }
    $blocklistURLs = $blocklistURLs | Select-Object -First $URLLimit | Sort-Object -Unique
}
process {
    $category.urls = $blocklistURLs
    Invoke-RestMethod -Method PUT -Uri "$($Global:ziaAPIConfig.baseUrl)/urlCategories/$CategoryToUpdate" -Body ($category | ConvertTo-Json -Compress) -WebSession $Global:ziaAPIConfig["session"]
}
end {
    if ($ActivateChanges) {
        Invoke-RestMethod -Method POST -Uri "$($Global:ziaAPIConfig.baseUrl)/status/activate" -WebSession $Global:ziaAPIConfig["session"]
    }
}