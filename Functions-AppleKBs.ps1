<# SystemInsecure v0.2 2024-10-01

Scrapes the Apple KB web article containing the versions and dates released, and puts the information into an array for use elsewhere 
(eg comparing to the version retrieved from EDR or MDM)

#>

Function GetApplePageResponse {
    param(
             [Parameter(Mandatory)]
             $URI
         )

    #hide progress dialogs
    $tProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    If ($PSVersionTable.PSVersion.Major -ge 6)
            {
                $Response = Invoke-WebRequest –Uri $URI –ErrorAction Stop
            }
            else 
            {
                $Response = Invoke-WebRequest –Uri $URI –UseBasicParsing –ErrorAction Stop
            }

    $ProgressPreference = $tProgressPreference # unhide further dialogs

    Return $Response.Content

}

Function CleanPageResponse {
    param(
             [Parameter(Mandatory)]
             $Content
             )

    #Peel away erroneus table info
    $Table = $((($Content -Split("<tbody>")))[1]) #strip text above table
    $Table = ($Table -split("</tbody>"))[0] #strip text below table
    $Table = ($Table -Split("</th>"))[3] #strip table headers
    $Table = ($Table.Substring(5,$Table.length - 5)) #strip first </tr>
    $Table = ($Table -Split("</tr>")) #break result into array for further use

    Return $Table


}

Function CreateRecordSet {

    param(
             [Parameter(Mandatory)]
             $RawDataSet,
             [Parameter(Mandatory=$False)]
             $Days
             )

    $output = @()
    $i=0
    Foreach ($record in $RawDataSet){

        $record = $record -replace("<br>","")
        $record = $record -replace("`n","")
        $record = $record -replace("<tr>","")
        if ($record -like "*<a href*"){
            $recordversion = "<td>"+$(($record -split('">'))[3])
            $recordreleasedate = "<td>"+$(($record -split('">'))[7])
        }
        $record = ($record -split ("<td>")) #split into 4 element array
        $version = ($($recordversion) -split('(\d{1,2}(\.{0,1}\d+){1,3})'))[1] #Version number
        $releasedate = ($recordreleasedate -split('(\d+[\s]\w+[\s]\d+)'))[1]
        $recordtext = ((($recordversion) -split('<'))[1] -split('>'))[-1]

        if ($version -notlike "*.*"){
            $version = $version + ".0"
        }

        #if (! ((([version]$version).Minor -le 0) -and (([version]$version).build -eq -1) -and (([version]$version).revision -eq -1)) ) {
            if ($version -ne $null -and $releasedate -ne $null){
                #Write-host ("$($version) / $($releasedate) / $($recordtext) [$($i)]")
                $result = [PSCustomObject] @{
                    "Version"=$($version)
                    "Release_Date"=$(([datetime]$releasedate).ToString("yyyy-MM-dd"))
                    "Age" = ((Get-Date)-([datetime]$releasedate)).days
                    "Text"=$recordtext
                    }
                $output = $output + $result
            }
        #}
        $i++
    }

    If ($Days -ne $null) {
        Return $output | Sort Release_date -Descending | ? {$_.Age -le $Days}
    } else {
        Return $output | Sort Release_date -Descending
    }


}



# --==Example==--
Write-host("`nPulling patch levels from the Apple website...`n") -ForegroundColor Cyan
$Content = GetApplePageResponse -URI "https://support.apple.com/en-us/HT201222"
$Table = CleanPageResponse -Content $Content
$AlliOS = $Table | ? {$_ -like "* and iPadOS*" -and $_ -notlike "*Rapid*"}
$AllMacOS = $Table | ? {$_ -like "*macOS*" -and $_ -notlike "*Safari*" -and $_ -notlike "*Xcode*" -and $_ -notlike "*Firmware*"  -and $_ -notlike "*Garage*" -and $_ -notlike "*Rapid*"}

$iOSAllVersions = CreateRecordSet -RawDataSet $AlliOS | sort Version -Descending
$iOSverCurrent = (CreateRecordSet -RawDataSet $AlliOS -Days 30).Version | Select-Object -unique
$iOSVerNminus2 = (CreateRecordSet -RawDataSet $AlliOS -Days 95| ? {$_.Age -gt 30}).Version | Select-Object -unique #Note day 30 to 95 included.
$MacOSAllVersions = CreateRecordSet -RawDataSet $AllMacOS | sort Version -Descending
$MacOSverCurrent = (CreateRecordSet -RawDataSet $AllMacOS -Days 30).Version | Select-Object -unique
$MacOSVerNminus2 = (CreateRecordSet -RawDataSet $AllMacOS -Days 95 | ? {$_.Age -gt 30}).Version | Select-Object -unique #Note day 30 to 95 included.

# You should be able to use the resulting returned arrays for comparison against another recordset to filter which need updates.

<#



Chagelog:
- 0.1 initial version 2023-08-01
- 0.2 Fix for parsing changes in Apples KB page 2024-10-01 JD

#>
