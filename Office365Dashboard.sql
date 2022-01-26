SELECT DISTINCT
r.ResourceID DeviceID,
r.Name0 DeviceName,
cast(comgmt.mdmworkloads as bigint) CoManagementFlag,
comgmt.ComgmtPolicyPresent,
comgmt.HybridAADJoined,
comgmt.AADJoined,
comgmt.MDMEnrolled,
comgmt.MDMProvisioned,

CASE WHEN OFI.Platform0 = '' THEN 'Unknown' WHEN OFI.Platform0 IS NULL THEN 'Unknown' ELSE OFI.Platform0 END Platform,
CASE 
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6' THEN 'Monthly Enterprise'
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60'	THEN 'Current'
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be'	THEN 'Current (Preview)'
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114'	THEN 'Semi-Annual Enterprise'
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf'	THEN 'Semi-Annual Enterprise (Preview)'
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f'	THEN 'Beta'
	WHEN OFI.CDNBaseUrl0 = 'http://officecdn.microsoft.com/pr/f2e724c1-748f-4b47-8fb8-8e0d210e9208' THEN 'Office 2019 Perpetual'
ELSE 'Office 365 Not Detected'
END AS 'Channel',
CASE 
	WHEN OFI.VersionToReport0 = '' THEN 'Unknown'
	WHEN OFI.VersionToReport0 IS NULL THEN 'Unknown' 
	--ELSE OFI.VersionToReport0
	when ofi.VersionToReport0 like '16.0.14729.%' then '2112'
	when ofi.VersionToReport0 like '16.0.14701.%' then '2111'
	when ofi.VersionToReport0 like '16.0.14527.%' then '2110'
	when ofi.VersionToReport0 like '16.0.14430.%' then '2109'
	when ofi.VersionToReport0 like '16.0.14326.%' then '2108'
	when ofi.VersionToReport0 like '16.0.14228.%' then '2107'
	when ofi.VersionToReport0 like '16.0.14131.%' then '2106'
	when ofi.VersionToReport0 like '16.0.14026.%' then '2105'
	when ofi.VersionToReport0 like '16.0.13929.%' then '2104'
	when ofi.VersionToReport0 like '16.0.13901.%' then '2103'
	when ofi.VersionToReport0 like '16.0.13801.%' then '2102'
	when ofi.VersionToReport0 like '16.0.13628.%' then '2101'
	when ofi.VersionToReport0 like '16.0.13530.%' then '2012'
	when ofi.VersionToReport0 like '16.0.13530.%' then '2011'
	when ofi.VersionToReport0 like '16.0.13530.%' then '2010'
	when ofi.VersionToReport0 like '16.0.13127.%' then '2008'
	when ofi.VersionToReport0 like '16.0.12527.%' then '2002'
	when ofi.VersionToReport0 like '16.0.11929.%' then '1908'
END ProductVersion,
CASE 
	WHEN OFI.VersionToReport0 = '' THEN 'Unknown'
	WHEN OFI.VersionToReport0 IS NULL THEN 'Unknown' 
	ELSE OFI.VersionToReport0
END Build,
OFI.ClientFolder0 ClientFolder,
OFI.InstallationPath0 InstallationPath,
CASE
	WHEN OFI.UpdatesEnabled0 = 'False' THEN 'No'
	WHEN OFI.UpdatesEnabled0 = 'True' THEN 'Yes'
	ELSE OFI.UpdatesEnabled0
END UpdatesEnabled,
LastScenario0 'Last Scenario',
CASE
	WHEN LastScenarioResult0 = '' THEN 'Unknown'
	WHEN LastScenarioResult0 IS NULL THEN 'Unknown'
	ELSE LastScenarioResult0
END 'Last Scenario Result',
WS.LastHWScan,
GPOChannel0,
AutoUpgrade0,
CASE
	WHEN CCMManaged0 = '' THEN 'No'
	WHEN CCMManaged0 IS NULL THEN 'No'
	ELSE 'Yes'
END CCMManaged,
r.User_Name0 UserName
FROM v_GS_OFFICE365PROPLUSCONFIGURATIONS OFI
left JOIN V_R_SYSTEM r ON r.ResourceID = OFI.ResourceID
left JOIN v_GS_WORKSTATION_STATUS AS WS ON WS.ResourceID = r.ResourceID
left join v_ClientCoManagementState comgmt on comgmt.ResourceID = ofi.ResourceID
where cast(comgmt.mdmworkloads as bigint) > 129 and cast(comgmt.mdmworkloads as bigint) < 255

