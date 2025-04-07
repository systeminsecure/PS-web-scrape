<# SystemInsecure 2025-04-07
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
    #hide progress dialogs
    $tProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    foreach ($uri in $arrayURI){
        If ($PSVersionTable.PSVersion.Major -ge 6)
        {
            $Response = Invoke-WebRequest –Uri $URI –ErrorAction Stop
        }
        else 
        {
            $Response = Invoke-WebRequest –Uri $URI –UseBasicParsing –ErrorAction Stop
        }

        $ProgressPreference = $tProgressPreference # unhide further dialogs
        
        If (!($Response.Links))
            { throw "Response was not parsed as HTML"}

        $VersionOS = (((($Response.Links | where {$_.outerHTML -match "supLeftNavLink" -and $_.outerHTML -match "version"}).outerHTML[0]).split(">")[1]).split("<")[0]).replace(' update history','')
        Write-Output ("Loading patches from $($URI)")
        $VersionDataRaw = $VersionDataRaw + (($Response.Links | where {$_.outerHTML -match "supLeftNavLink" -and $_.outerHTML -match "KB"}) | Select outerHTML, tagName, class, data-bi-slot,href,@{name='Age';expression={((Get-Date)-([datetime]($_.outerHTML -split('(\w+\s\d+,\s\d{4})'))[1])).days}})
    }
    Return $VersionDataRaw

} #fixed ProgressPreference variable

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
    [void]$Table.Columns.AddRange(@('Name','OSRelease','OSBuild','CurrentInstalledUpdate','CurrentInstalledUpdateKB','CurrentInstalledUpdateDate','CurrentInstalledUpdateInCompliance','CurrentInstalledUpdateInfoURL','LatestAvailableUpdate','LatestAvailableUpdateKB','LatestAvailableUpdateDate','LatestAvailableUpdateInfoURL'))

    $OSBuild = "$(([string]$OSVersion).split(".")[2]).$(([string]$OSVersion ).split(".")[3])"
    $CurrentPatch = $VersionDataRaw | where {$_.outerHTML -match $OSBuild} | Select –First 1

    $WindowsBuildVersion = Switch ($(([string]$OSVersion).split(".")[2])) {
        "19044" {"Windows 10 ver 21H2"}
        "19045" {"Windows 10 ver 22H2"}
        "22000" {"Windows 11 ver 21H2"}
        "22621" {"Windows 11 ver 22H2"}
        "22631" {"Windows 11 ver 23H2"}
        "26100" {"Windows 11 ver 24H2"}
        default {"NOT SUPPORTED!!"} #Add (END OF LIFE) to any that are no longer in support
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
        $(if($CurrentPatch.age -lt 62 -and $CurrentPatch.age.Length -gt 0){"True"} else {"False"}),
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

[array]$MicrosoftUrls = @("https://aka.ms/WindowsUpdateHistory","https://support.microsoft.com/en-us/topic/windows-10-update-history-1b6aac92-bf01-42b5-b158-f80c6d93eb11","https://support.microsoft.com/en-us/topic/windows-11-version-22h2-update-history-ec4229c3-9c5f-4e75-9d6d-9025ab70fcce") # Win 10 21H1, Win 10 21H2, Win 10 22H2, Win 11

#Pull patch version info from Microsoft
write-output ("[Windows Patches]: Pulling patch levels from the Microsoft website...")
$VersionDataRaw = $null
$VersionDataRaw = Get-WindowsVersionInfo -arrayURI $MicrosoftUrls

# fix for missing versions
$VersionDataRaw = $VersionDataRaw + ($VersionDataRaw | ? {$_.outerHTML -like "*.1288*"} | select @{name='outerHTML';expression={("<a class=`"supLeftNavLink`" data-bi-slot=`"00`" href=`"/en-us/help/5006670`"October 21, 2021&#x2014;KB5006670 RTM 21H2 (OS Builds 19044.1288)</a>")}},tagName,class,data-bi-slot,@{name='href';expression={("https://blogs.windows.com/windows-insider/2021/10/21/preparing-the-windows-10-november-2021-update-for-release/")}},Age) #Windows 10 21H2 RTM 19044.1288
$VersionDataRaw = $VersionDataRaw + ($VersionDataRaw | ? {$_.outerHTML -like "*22621.608*"} | select @{name='outerHTML';expression={("<a class=`"supLeftNavLink`" data-bi-slot=`"00`" href=`"/en-us/help/5019311`">September 30, 2022&#x2014;KB5017308 Windows 11, version 22H2 (OS Builds 22621.608)</a>")}},tagName,class,data-bi-slot,@{name='href';expression={("https://support.microsoft.com/help/5019311")}},Age) #Windows 11 21H2 RTM 22621.608
$VersionDataRaw = $VersionDataRaw + ($VersionDataRaw | ? {$_.outerHTML -like "*22621.*"} | select -first 1 @{name='outerHTML';expression={("<a class=`"supLeftNavLink`" data-bi-slot=`"00`" href=`"/en-us/help/5019311`">September 27, 2022&#x2014;KB5019311 Windows 11, version 22H2 (OS Builds 22621.525)</a>")}},tagName,class,data-bi-slot,@{name='href';expression={("https://support.microsoft.com/help/5019311")}},@{name='Age';expression={((Get-Date)-([datetime]"2022-09-27").days)}}) #Windows 11 21H2 RTM 22621.525
$VersionDataRaw = $VersionDataRaw + ($VersionDataRaw | ? {$_.outerHTML -like "*19045.*"} | select -first 1 @{name='outerHTML';expression={("<a class=`"supLeftNavLink`" data-bi-slot=`"00`" href=`"/en-us/help/5017308`">September 13, 2022&#x2014;KB5017308 Windows 10, version 22H2 RTM (OS Builds 19045.2006)</a>")}},tagName,class,data-bi-slot,@{name='href';expression={("https://support.microsoft.com/help/KB5017308")}},@{name='Age';expression={((Get-Date)-([datetime]"2022-09-13").days)}}) #Windows 10 22H2 RTM 19045.2006
$VersionDataRaw = $VersionDataRaw + ($VersionDataRaw | ? {$_.outerHTML -like "*22631.*"} | select -first 1 @{name='outerHTML';expression={("<a class=`"supLeftNavLink`" data-bi-slot=`"00`" href=`"/en-us/help/5031354`">September 26, 2023&#x2014;KB5031354 Windows 11, version 23H2 RTM (OS Builds 22631.2428)</a>")}},tagName,class,data-bi-slot,@{name='href';expression={("https://blogs.windows.com/windows-insider/2023/09/26/releasing-windows-11-version-23h2-to-the-release-preview-channel/")}},@{name='Age';expression={((Get-Date)-([datetime]"2023-09-26").days)}}) #Windows 11 23H2 RTM 22631.2428

# # of Windows patches
Write-Output ("[Windows Patches]: loaded $($VersionDataRaw.count)")

