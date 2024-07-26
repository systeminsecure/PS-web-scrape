#get visual studio version

#$Installedversion = &"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -property catalog_productDisplayVersion

$InstalledVersion = "16.5.1" #Note: we need to fix 15.1 - 15.5

#Derive Major and minor version
$MajorVersion = ($Installedversion.split("."))[0]
$MinorVersion = ($Installedversion.split("."))[1]

# Version to URL
switch ($MajorVersion)
{
(17) {$URI="https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history";$vsversion="Visual Studio 2022"}
(16) {$URI="https://learn.microsoft.com/en-us/visualstudio/releases/2019/history";$vsversion="Visual Studio 2019"}
(15) {$URI="https://learn.microsoft.com/en-us/visualstudio/releasenotes/vs2017-relnotes-history";$vsversion="Visual Studio 2017"}
}

#Variables
$links = $Null
[array]$currentversionlinks = $null
[array]$latestversionlinks = $null
$printmesssage = $null

#Major version
If ($PSVersionTable.PSVersion.Major -ge 6){
    $Response = Invoke-WebRequest –Uri $URI –ErrorAction Stop
} else {
    $Response = Invoke-WebRequest –Uri $URI –UseBasicParsing –ErrorAction Stop
}
    
If (!($Response.Links))
    { throw "Response was not parsed as HTML"
    #Write-host("Response was not parsed as HTML, this machine does not have internet access") -ForegroundColor Red
} else {
    $uri = $uri.Replace( $("/"+($uri.split("/")[-1])),"")
    $links = ($Response.Links | where {($_.outerHTML -match "release-notes" -or $_.outerHTML -match "relnotes") -and $_.outerHTML -match "version"}) | select outerHTML,href,@{Name="fullURL";Expression={$uri +"/" + $_.href}},@{Name="releasename";Expression={$_.outerHTML.Split(">").split("<")[2]}}
}

#Select Minor version
$currentversionlink = ($links | ? {$_ -match "(\b$($MajorVersion).$($MinorVersion)\b)"}).fullURL


#Follow the links and pull patch releases for major.minor versions
If ($PSVersionTable.PSVersion.Major -ge 6){
    $LinkResponse = Invoke-WebRequest –Uri $currentversionlink –ErrorAction Stop
} else {
    $LinkResponse = Invoke-WebRequest –Uri $currentversionlink –UseBasicParsing –ErrorAction Stop
}
    
$currentversionlinks = $currentversionlinks + (($LinkResponse.RawContent -split '\r?\n') | where {$_ -match "version" -and $_ -match "<li>" -and $_ -match "self-bookmark"} | select @{Name="date";Expression={(((($_ -split("-"))[0] -replace("<li>","") -split("â"))[0].trim()) -replace("th",",")) -replace('\d+(st)',",") }},@{Name="version";Expression={((($_ -split("</a>"))[0].Trim()) -split('">'))[-1] }})
$latestminorversion = $currentversionlinks | select -first 1
$currentminorversion = $currentversionlinks | ? {$_.version -match "(\b$($InstalledVersion)\b)"} | select -first 1

write-host ("$($latestminorversion)") -ForegroundColor Yellow
write-host ("$($currentminorversion)") -ForegroundColor Yellow

break


#Lets also pull the latest version in the major release chain
$latestversionlink = ($links | ? {$_ -match "$($MajorVersion)"} | select -First 1).fullURL

If ($PSVersionTable.PSVersion.Major -ge 6){
    $LinkResponse = Invoke-WebRequest –Uri $latestversionlink –ErrorAction Stop
} else {
    $LinkResponse = Invoke-WebRequest –Uri $latestversionlink –UseBasicParsing –ErrorAction Stop
}
    
$latestversionlinks = $latestversionlinks + (($LinkResponse.RawContent -split '\r?\n') | where {$_ -match "version" -and $_ -match "<li>" -and $_ -match "self-bookmark"} | select @{Name="date";Expression={(((($_ -split("-"))[0] -replace("<li>","") -split("â"))[0].trim()) -replace("th",",")) -replace('\d+(st)',",")}},@{Name="version";Expression={((($_ -split("</a>"))[0].Trim()) -split('">'))[-1] }})
$latestmajorversion = $latestversionlinks | select -first 1

$InstalledBuild = [version]$InstalledVersion 
$LatestMinorBuild = [version]($latestminorversion.version -split('\b((?:\d+\.)+\d+)\b'))[1] #version\s+((?:\d+\.?)+)
$LatestMajorBuild = [version]($latestmajorversion.version -split('\b((?:\d+\.)+\d+)\b'))[1] #

#how far is the installed minor version away from the latest minor version?
if ((New-TimeSpan -Start $latestminorversion.date -End $latestmajorversion.date).days -gt 365){
$printmesssage = "Your Visual Studio install is more than 1 year out of date. You MUST UPDATE!"
} else {
    #now, for more recent versions lets check to see how far away it is from the latest minor version
    $ts = (New-TimeSpan -Start $currentminorversion.date -End $latestminorversion.date) 
    if($ts.Days -gt 180){
        $printmesssage = "Your Visual Studio install is $($ts.days) days out of date. You MUST UPDATE!"
    } else {
        $printmesssage = "Your Visual Studio install is $($ts.days) days behind the most current update."
    }
}


if ($currentminorversion -ne $null -and $latestminorversion -ne $null -and $latestmajorversion -ne $null){
    if ($InstalledBuild -ne $LatestMajorBuild){
        write-host("You are on $()$vsversion version $($InstalledVersion) ($($currentminorversion.date)) `n`rThe latest version in the minor version chain is $($latestminorversion.version) ($($latestminorversion.date)) `n`rThe most recent (supported) version in the major version chain is $($latestmajorversion.version) ($($latestmajorversion.date)) `n`r$($printmesssage)")
    } else {
        write-host("$($InstalledVersion)")
    }
}
