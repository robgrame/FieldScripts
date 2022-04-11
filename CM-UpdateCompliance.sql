--declare @UserSIDs  nvarchar(max) = 'disabled'
declare @locale  nvarchar = @@Language
DECLARE @lcid int = dbo.fn_LShortNameToLCID(@Locale) 

--Set the CollectionID
declare @CollID nvarchar(8) = 'SMSDM003' --CollectionID for All Desktop and Server Clients

-- Create table to store list of updates 
--Remove previous temporary table if exists
IF OBJECT_ID(N'TempDB.DBO.#temp_UpdatesList') IS NOT NULL
BEGIN
	DROP TABLE #temp_UpdatesList
END



--Create table to store key update information per machine
CREATE TABLE #temp_UpdatesList(

	[CI_ID] [int] NOT NULL,
	[CI_UniqueID] [nvarchar](300) NOT NULL,
)

declare @cilist CIIDList_Type


insert into #temp_UpdatesList
output inserted.CI_ID into @cilist
select 

	upd.CI_ID
,	upd.CI_UniqueID
from fn_ListUpdateCIs(@lcid) as upd

-- Create table to store list of updates together with Product
--Remove previous temporary table if exists
IF OBJECT_ID(N'TempDB.DBO.#temp_ProductUpdateList') IS NOT NULL
BEGIN
	DROP TABLE #temp_ProductUpdateList
END

--Create table to store update classification for each update
CREATE TABLE #temp_ProductUpdateList(
	[CI_ID] [int] NOT NULL,
	[Product] [nvarchar](512) NULL
)

insert into #temp_ProductUpdateList
SELECT 
	CI_ID
,	CategoryInstanceName 
FROM fn_CICategoryInfo_All(@lcid) upc 
WHERE upc.CategoryTypeName = 'Product'



-- Create table to store list of updates together with Update Classification
--Remove previous temporary table if exists
IF OBJECT_ID(N'TempDB.DBO.#temp_UpdateClassificationUpdateList') IS NOT NULL
BEGIN
	DROP TABLE #temp_UpdateClassificationUpdateList
END

--Create table to store update classification for each update
CREATE TABLE #temp_UpdateClassificationUpdateList(
	[CI_ID] [int] NOT NULL,
	[UpdateClassification] [nvarchar](512) NULL
)

insert into #temp_UpdateClassificationUpdateList
SELECT 
	CI_ID
,	CategoryInstanceName 
FROM fn_CICategoryInfo_All(@lcid) upc 
WHERE upc.CategoryTypeName = 'UpdateClassification'



--Remove previous temporary table if exists
IF OBJECT_ID(N'TempDB.DBO.#temp_UpdatesDetail') IS NOT NULL
BEGIN
	DROP TABLE #temp_UpdatesDetail
END

--Create table to store key update information per machine
CREATE TABLE #temp_UpdatesDetail(
	[ArticleID] [nvarchar](64) NULL,
	[BulletinID] [nvarchar](1024) NULL,
	[Title] [nvarchar](1024) NULL,
	[InfoURL] [nvarchar](512) NULL,
	[CI_ID] [int] NOT NULL,
	[CI_UniqueID] [nvarchar](300) NOT NULL,
	[UpdateClassification] [nvarchar](512) NULL,
	[Product] [nvarchar](512) NULL,
	[SeverityLevel] [nvarchar](256) NOT NULL,
	[DatePosted] datetime not null,
	[IsSuperseded] nvarchar(3) not null,
	[IsExpired] nvarchar(3) not null
)


--Insert query results into Temporary table
 INSERT INTO #temp_UpdatesDetail
 --output inserted.CI_ID into @cilist
 SELECT distinct
		ui.ArticleID 
	,	ui.BulletinID
	,	UI.Title
	,	UI.InfoURL
	,	UI.CI_ID
	,	UI.CI_UniqueID
	,	uc.[UpdateClassification]as UpdateClassification
	,	prodl.Product
	,Case UI.Severity
		WHEN '10' THEN 'Critical'
		WHEN '8' THEN 'Important'
		WHEN '6' THEN 'Moderate'
		WHEN '2' THEN 'Low'
		WHEN '0' THEN 'None'
		ELSE 'Unknown'
	END AS SeverityLevel
	, ui.DatePosted
	, Superseded = 
		CASE
		when ui.IsSuperseded = 1 then 'Yes'
		when ui.IsSuperseded = 0 then 'No'
		END
	
, Expired = 
	case
		when ui.IsExpired = 1 then 'Yes'
		when ui.IsExpired = 0 then 'No'
	end
FROM fn_UpdateInfo(@lcid) ui
INNER JOIN #temp_UpdatesList sugl on sugl.CI_ID = ui.CI_ID
INNER JOIN #temp_UpdateClassificationUpdateList UC ON ui.CI_ID = UC.CI_ID
INNER JOIN #temp_ProductUpdateList prodl on ui.CI_ID = prodl.CI_ID
WHERE  
ui.CIType_ID in (1,8) 
and ui.IsHidden=0 
and prodl.Product not in ('Windows 10','Windows 10, version 1903 and later','Windows 7','Windows 11','Windows 10 LTSB','Windows 10 LTSC')

CREATE NONCLUSTERED INDEX [#temp_UpdatesDetail_IDX1] ON #temp_UpdatesDetail
(
	[UpdateClassification] ASC
)
CREATE NONCLUSTERED INDEX [#temp_UpdatesDetail_IDX2] ON #temp_UpdatesDetail
(
	[SeverityLevel] ASC
)
CREATE NONCLUSTERED INDEX [#temp_UpdatesDetail_IDX3] ON #temp_UpdatesDetail
(
	[ArticleID] ASC,
	[UpdateClassification] ASC,
	[SeverityLevel] ASC
)




-- Create table to store list of machine for a specific collection
--Remove previous temporary table if exists
IF OBJECT_ID(N'TempDB.DBO.#temp_MachineList') IS NOT NULL
BEGIN
	DROP TABLE #temp_MachineList
END

--Create table to store update classification for each update
CREATE TABLE #temp_MachineList
(
	[ResourceID] [int] NOT NULL,
	[MachineName] [nvarchar](16) NULL
)

insert into #temp_MachineList
SELECT 
	r.ResourceID
,	r.Netbios_Name0 
FROM v_r_system r
inner join v_FullCollectionMembership fcm on fcm.ResourceID = r.ResourceID and fcm.CollectionID = @CollID



select distinct
ml.ResourceID,
ml.MachineName,
cdl.AssignmentName,
ul.CI_ID,
'KB'+ul.ArticleID KB,
ul.BulletinID,
ul.Title,
ul.Product,
ul.UpdateClassification,
ul.SeverityLevel,
ul.DatePosted,
cdl.EnforcementDeadline,
ul.IsSuperseded,
ul.IsExpired,

ucs.Status [State], st.StateName,
(case when ctm.ResourceID is not null then '*' else '' end) [Targeted], 
(CASE WHEN ucs.Status = 3 THEN '*' ELSE '' END) AS [Installed],  
(CASE WHEN ucs.Status = 2 THEN '*' ELSE '' END) AS [Required],
(CASE WHEN ucs.Status = 1 THEN '*' ELSE '' END) AS [Update is not Required],
qfe.InstalledOn0 'InstalledDate'
from v_Update_ComplianceStatusAll ucs
left join #temp_UpdatesDetail ul on ul.CI_ID = ucs.CI_ID
inner join #temp_MachineList ml on ml.ResourceID = ucs.ResourceID
left join v_StateNames st on st.StateID = ucs.Status and st.TopicType = 500
left join v_CITargetedMachines  ctm on ctm.CI_ID=ucs.CI_ID and ctm.ResourceID =ml.ResourceID
inner join (
            select 
			atc.CI_ID,
			a.AssignmentName,
			a.EnforcementDeadline,
			atm.ResourceID
			from v_CIAssignment a 
			inner join v_CIAssignmentTargetedMachines atm on atm.AssignmentID = a.AssignmentID
			left join v_CIAssignmentToCI  atc on atc.AssignmentID=a.AssignmentID
			where a.AssignmentType in (1,5)
			
            ) cdl on cdl.CI_ID = ctm.CI_ID and cdl.ResourceID = ctm.ResourceID
left join V_GS_Quick_Fix_Engineering qfe on qfe.HotFixID0 = 'KB'+ul.ArticleID and qfe.ResourceID = ctm.ResourceID





