<# SystemInsecure 2023-08-01
These functions were built by me from scratch
#>

Function GetApplePageResponse {
    param(
             [Parameter(Mandatory)]
             $URI
         )

    If ($PSVersionTable.PSVersion.Major -ge 6)
            {
                $Response = Invoke-WebRequest –Uri $URI –ErrorAction Stop
            }
            else 
            {
                $Response = Invoke-WebRequest –Uri $URI –UseBasicParsing –ErrorAction Stop
            }
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
$Table = ($Table.Substring(6,$Table.length - 6)) #strip first </tr>
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
            $record = "<td>"+$(($record -split('">'))[1])
        }
        $record = ($record -split ("<td>")) #split into 4 element array
        $version = ($($record[1]) -split('(\d{1,2}(\.{0,1}\d+){1,3})'))[1] #Version number
        $releasedate = ($record[-1] -split('(\d+[\s]\w+[\s]\d+)'))[1]
        $recordtext = (($record[2]) -split('<'))[0]

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
