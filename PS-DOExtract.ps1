# By Johan Arwidmark|March 25th, 2022|Delivery Optimization, Intune

# Get data from previously saved log files
$SavedLogsPath = "C:\Demo\DOLogs"
$ETLFiles = Get-ChildItem $SavedLogsPath -File -Filter "dosvc*.etl" | Sort-Object Name
$DOLogsOutPut = Get-DeliveryOptimizationLog -Path $ETLFiles.FullName


# Get all unique functions, and save to a text file
$ListFunctions = $DOLogsOutPut | Select Function -Unique | Sort-Object Function
$ListFunctions | Out-File C:\Demo\DOFunctions.txt

 
# Get data from the Get-DeliveryOptimizationLog cmdlet
$DOLogsOutPut = Get-DeliveryOptimizationLog
# Save log output to a text file
$DOLogsOutPut | Out-File C:\Demo\DOLogOutPut.txt

# Show info about download and local network info
# This assumes you have gathered the logs into the $DOLogsOutPut array per the preceding examples
$InternalAnnounceExportFile = "C:\Demo\InternalAnnounce.csv"
$InternalAnnounce = $DOLogsOutPut | Where-Object {($_.Function -eq "CAnnounceSequencer::_InternalAnnounce")}
$InternalAnnounce = $InternalAnnounce | Select-Object @{N="Message";E={$_.Message -replace "Swarm.*announce request:",""}},TimeCreated,Level,LevelName,Function,ErrorCode 
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name ContentId -Value (($_.Message | ConvertFrom-Json).ContentId) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name AltCatalogId -Value (($_.Message | ConvertFrom-Json).AltCatalogId) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name PeerId -Value (($_.Message | ConvertFrom-Json).PeerId) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name ReportedIp -Value (($_.Message | ConvertFrom-Json).ReportedIp) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name SubnetMask -Value (($_.Message | ConvertFrom-Json).SubnetMask) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Ipv6 -Value (($_.Message | ConvertFrom-Json).Ipv6) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name IsBackground -Value (($_.Message | ConvertFrom-Json).IsBackground) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name ClientCompactVersion -Value (($_.Message | ConvertFrom-Json).ClientCompactVersion) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Uploaded -Value (($_.Message | ConvertFrom-Json).Uploaded) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Downloaded -Value (($_.Message | ConvertFrom-Json).Downloaded) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name DownloadedCdn -Value (($_.Message | ConvertFrom-Json).DownloadedCdn) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name DownloadedDoinc -Value (($_.Message | ConvertFrom-Json).DownloadedDoinc) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Left -Value (($_.Message | ConvertFrom-Json).Left) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name JoinRequestEvent -Value (($_.Message | ConvertFrom-Json).JoinRequestEvent) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name RestrictedUpload -Value (($_.Message | ConvertFrom-Json).RestrictedUpload) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name PeersWanted -Value (($_.Message | ConvertFrom-Json).PeersWanted) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name GroupId -Value (($_.Message | ConvertFrom-Json).GroupId) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Scope -Value (($_.Message | ConvertFrom-Json).Scope) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name UploadedBPS -Value (($_.Message | ConvertFrom-Json).UploadedBPS) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name DownloadedBPS -Value (($_.Message | ConvertFrom-Json).DownloadedBPS) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name HttpDelayLeftSecs -Value (($_.Message | ConvertFrom-Json).HttpDelayLeftSecs) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Profile -Value (($_.Message | ConvertFrom-Json).Profile) -PassThru}
$InternalAnnounce = $InternalAnnounce | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name Seq -Value (($_.Message | ConvertFrom-Json).Seq) -PassThru}
$InternalAnnounce | Export-csv -Path $InternalAnnounceExportFile -NoTypeInformation
 
# Show IP address of DO peers the machine connected to
$ConnectionCompleteExportFile = "C:\Demo\DOPeers.csv"
$ConnectionComplete = $DOLogsOutPut | Where-Object {($_.Function -eq "CConnMan::ConnectionComplete")}
$ConnectionComplete = $ConnectionComplete | Select-Object @{N="PeerIP";E={($_.Message | Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value}},TimeCreated,Level,LevelName,Function,ErrorCode
$ConnectionComplete | Export-csv -Path $ConnectionCompleteExportFile -NoTypeInformation
 
# Show External IP address and Country Code
$CallServiceExportFile = "C:\Demo\ExternalIPsAndCountry.csv"
$CallService = $DOLogsOutPut | Where-Object {($_.Function -eq "CServiceConfigProvider::_CallService") -and ($_.Message -match "GEO(:)? response:")}
$CallService = $CallService | Select-Object @{N="Message";E={$_.Message -replace "GEO response: ",""}},TimeCreated,Level,LevelName,Function,ErrorCode 
$CallService = $CallService | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name ExternalIpAddress -Value (($_.Message | ConvertFrom-Json).ExternalIpAddress) -PassThru}
$CallService = $CallService | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name CountryCode -Value (($_.Message | ConvertFrom-Json).CountryCode) -PassThru}
$CallService | Export-csv -Path $CallServiceExportFile -NoTypeInformation
