<# SystemInsecure
Original script from https://smsagent.blog/2021/04/20/get-the-current-patch-level-for-windows-10-with-powershell/
Heavily modified for my use cases.
#>

Function Convert-ParsedArray {
    Param($Array)
    
    $ArrayList = New-Object System.Collections.ArrayList
    foreach ($item in $Array)
    {      
        [void]$ArrayList.Add([PSCustomObject]@{
            Update = $item.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' – ')
            KB = "KB" + $item.href.Split('/')[-1]
            InfoURL = "https://support.microsoft.com" + $item.href
            OSBuild = $item.outerHTML.Split('(OS ')[1].Split()[1] # Just for sorting
        })
    }
    Return $ArrayList
}

Function Get-WindowsVersionInfo {
    Param(
            [Parameter(Mandatory)]
            $arrayURI
            )
    foreach ($uri in $arrayURI){
        If ($PSVersionTable.PSVersion.Major -ge 6)
        {
            $Response = Invoke-WebRequest –Uri $URI –ErrorAction Stop
        }
        else 
        {
            $Response = Invoke-WebRequest –Uri $URI –UseBasicParsing –ErrorAction Stop
        }
    
        If (!($Response.Links))
            { throw "Response was not parsed as HTML"}

        $VersionOS = (((($Response.Links | where {$_.outerHTML -match "supLeftNavLink" -and $_.outerHTML -match "version"}).outerHTML[0]).split(">")[1]).split("<")[0]).replace(' update history','')
        Write-host("Loading patches from $($URI)") -ForegroundColor Cyan
        $VersionDataRaw = $VersionDataRaw + (($Response.Links | where {$_.outerHTML -match "supLeftNavLink" -and $_.outerHTML -match "KB"}) | Select outerHTML, tagName, class, data-bi-slot,href,@{name='Age';expression={((Get-Date)-([datetime]($_.outerHTML -split('(\w+\s\d+,\s\d{4})'))[1])).days}})
    }
    Return $VersionDataRaw

}

Function Parse-WindowsVersionKBs {
    Param(
            [Parameter(Mandatory)]
            $VersionDataRaw,
            [Parameter(Mandatory)]
            $MachineName,
            [Parameter(Mandatory)]
            $OSVersion,
            [Parameter(Mandatory=$false)]
            $ExcludePreview = $true,
            [Parameter(Mandatory=$false)]
            $ExcludeOutofBand = $true
        )
    
    $Table = New-Object System.Data.DataTable
    [void]$Table.Columns.AddRange(@('Name','OSRelease','OSBuild','CurrentInstalledUpdate','CurrentInstalledUpdateKB','CurrentInstalledUpdateDate','CurrentInstalledUpdateInN-2','CurrentInstalledUpdateInfoURL','LatestAvailableUpdate','LastestAvailableUpdateKB','LatestAvailableUpdateDate','LastestAvailableUpdateInfoURL'))

    $OSBuild = "$(([string]$OSVersion).split(".")[2]).$(([string]$OSVersion ).split(".")[3])"
    $CurrentPatch = $VersionDataRaw | where {$_.outerHTML -match $OSBuild} | Select –First 1

    $WindowsBuildVersion = Switch ($(([string]$OSVersion).split(".")[2])) {
        "19044" {"Windows 10 ver 21H2"}
        "19045" {"Windows 10 ver 22H2"}
        "22000" {"Windows 11 ver 21H2"}
        "22621" {"Windows 11 ver 22H2"}
        default {"NOT SUPPORTED!!"}
    }

    If ($CurrentPatch -ne $null){

        If ($ExcludePreview -and $ExcludeOutofBand)
        {
            $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $OSBuild.Split('.')[0] -and $_.outerHTML -notmatch "Out-of-band" -and $_.outerHTML -notmatch "Preview"} | Select –First 1
        }
        ElseIf ($ExcludePreview)
        {
            $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $OSBuild.Split('.')[0] -and $_.outerHTML -notmatch "Preview"} | Select –First 1
        }
        ElseIf ($ExcludeOutofBand)
        {
            $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $OSBuild.Split('.')[0] -and $_.outerHTML -notmatch "Out-of-band"} | Select –First 1
        }
        Else
        {
            $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $OSBuild.Split('.')[0]} | Select –First 1
        }

        [void]$Table.Rows.Add(
        $MachineName,
        $WindowsBuildVersion,
        $OSBuild,
        $CurrentPatch.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' – '),
        "KB" + $CurrentPatch.href.Split('/')[-1],
        ($CurrentPatch.outerHTML -split('(\w+\s\d+,\s\d{4})'))[1],
        $(if($CurrentPatch.age -lt 62){"True"} else {"False"}),
        "https://support.microsoft.com" + $CurrentPatch.href,
        $LatestAvailablePatch.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' – '),
        "KB" + $LatestAvailablePatch.href.Split('/')[-1],
        ($LatestAvailablePatch.outerHTML -split('(\w+\s\d+,\s\d{4})'))[1],
        "https://support.microsoft.com" + $LatestAvailablePatch.href
        )
    } else {
        [void]$Table.Rows.Add(
        $MachineName,
        $WindowsBuildVersion,
        $OSBuild+" Not in catalog",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        ""
        )
    }

    Return $Table
    
}

# --==Example use==--

$arrURI = @("https://aka.ms/WindowsUpdateHistory","https://support.microsoft.com/en-us/help/5018680") # Win 10 21H1, Win 10 21H2, Win 10 22H2, Win 11

#Pull patch version info from Microsoft
$VersionDataRaw = $null
$VersionDataRaw = Get-WindowsVersionInfo -arrayURI $arrURI
Write-Host("Patches loaded: $($VersionDataRaw.count)") -ForegroundColor Cyan

#Device build is "10.0.19044.1826", and we will pass 19044.1826
Parse-WindowsVersionKBs -VersionDataRaw $VersionDataRaw -OSVersion "19044.1826" -MachineName "<my cosmetic machine name> #Returns an array which you can parse further or output to CSV
