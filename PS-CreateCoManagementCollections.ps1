#Load Configuration Manager PowerShell Module
Import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-location $SiteCode":"

#Error Handling and output
$ErrorActionPreference= 'SilentlyContinue'

#Create Default Folder 
$CollectionFolder = @{Name ="CO - Co-Management"; ObjectType =5000; ParentContainerNodeId =0}
Set-WmiInstance -Namespace "root\sms\site_$($SiteCode.Name)" -Class "SMS_ObjectContainerNode" -Arguments $CollectionFolder -ComputerName $SiteCode.Root
$FolderPath =($SiteCode.Name +":\DeviceCollection\" + $CollectionFolder.Name)

#Set Default limiting collections
$LimitingCollection = 'Co-management Eligible Devices'

#Refresh Schedule
$Schedule = New-CMSchedule -RecurInterval Days -RecurCount 1


#Find Existing Collections
$ExistingCollections = Get-CMDeviceCollection -Name "*" | Select-Object CollectionID, Name

#List of Collections Query
$DummyObject = New-Object -TypeName PSObject 
$Collections = @()


# Exclude from Cloud Attach
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - NO CLOUD ATTACHED CLIENTS"}},
@{L="LimitingCollection" ; E={$LimitingCollection}},
@{L="Comment" ; E={"Collection sulla quale viene disabilitato il Cloud Attach, ovvero viene impedito l'upload dei device su Intune."}},
@{L="Query" ; E={""}},
@{L="Include" ; E={""}},
@{L="Exclude" ; E={""}}

# Exclude from Co-Management
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - NO CO-MANAGED CLIENTS"}},
@{L="LimitingCollection" ; E={$LimitingCollection}},
@{L="Comment" ; E={"Collection sulla quale viene escluso il Co-Management, ovvero viene impedito l'enrollment dei device su Intune."}},
@{L="Query" ; E={""}},
@{L="Include" ; E={""}},
@{L="Exclude" ; E={""}}


# Cloud Attached Clients
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Cloud Attached Clients"}},
@{L="LimitingCollection" ; E={$LimitingCollection}},
@{L="Comment" ; E={"Collection sulla quale viene abilitato il Cloud Attach, ovvero l'upload dei device su Intune."}},
@{L="Query" ; E={""}},
@{L="Include" ; E={""}},
@{L="Exclude" ; E={"CO - NO CLOUD ATTACHED CLIENTS"}}

# Co-Managed Clients
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Co-Managed Clients"}},
@{L="LimitingCollection" ; E={"CO - Cloud Attached Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene abilitato il Co-Management, ovvero l'enrollment dei client su Intune"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - Cloud Attached Clients"}},
@{L="Exclude" ; E={"CO - NO CO-MANAGED CLIENTS"}}



# Pilot ALL INTUNE Workloads
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - PILOT ALL WORKLOADS"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale vengono spostati tutti i workload su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={""}},
@{L="Exclude" ; E={""}}

# Pilot NO INTUNE Workloads
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - NO INTUNE WORKLOADS"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale vengono mantenuti tutti i workload su ConfigMgr per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={""}},
@{L="Exclude" ; E={""}}

# Pilot COMPLIANCE POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Intune Compliance Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload della Compliance su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}

# Pilot Device Configuration POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Device Configuration Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload della Device Configuration su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}

# Pilot Resource Access POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Resource Access Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload delle Resource Access Policies su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}

# Pilot Endpoint Protection POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Endpoint Protection Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload delle Endpoint Protection Policies su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}

# Pilot Windows Update POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Windows Update Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload delle Endpoint Protection Policies su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}

# Pilot Client Apps POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Client Apps Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload delle Endpoint Protection Policies su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}

# Pilot Client Apps POLICES
$Collections +=
$DummyObject |
Select-Object @{L="Name"; E={"CO - Pilot - Office Click-to-Run Apps Policies"}},
@{L="LimitingCollection" ; E={"CO - Co-Managed Clients"}},
@{L="Comment" ; E={"Collection sulla quale viene spostato il workload delle Endpoint Protection Policies su Intune per i client in Co-Management"}},
@{L="Query" ; E={""}},
@{L="Include" ; E={"CO - PILOT ALL WORKLOADS"}},
@{L="Exclude" ; E={"CO - NO INTUNE WORKLOADS"}}



#Check Existing Collections
$Overwrite = 1
$ErrorCount = 0
$ErrorHeader = "The script has already been run. The following collections already exist in your environment:`n`r"
$ErrorCollections = @()
$ErrorFooter = "Would you like to delete and recreate the collections above? (Default : No) "
$ExistingCollections | Sort-Object Name | ForEach-Object {If($Collections.Name -Contains $_.Name) {$ErrorCount +=1 ; $ErrorCollections += $_.Name}}

#Error
If ($ErrorCount -ge1) {
    Write-Host $ErrorHeader $($ErrorCollections | ForEach-Object {(" " + $_ + "`n`r")}) $ErrorFooter -ForegroundColor Yellow -NoNewline
    $ConfirmOverwrite = Read-Host "[Y/N]"
    If ($ConfirmOverwrite -ne "Y") {$Overwrite =0}
    }

#Create Collection And Move the collection to the right folder
If ($Overwrite -eq1) {
    
    $ErrorCount=0

    ForEach ($Collection In $($Collections | Sort-Object LimitingCollection -Descending)) {
        If ($ErrorCollections -Contains $Collection.Name)
            {
                Get-CMDeviceCollection -Name $Collection.Name | Remove-CMDeviceCollection -Force
                Write-host *** Collection $Collection.Name removed and will be recreated ***
            }
        }

        ForEach ($Collection In $($Collections)) {

            Try 
                {
                    New-CMDeviceCollection -Name $Collection.Name -Comment $Collection.Comment -LimitingCollectionName $Collection.LimitingCollection -RefreshSchedule $Schedule -RefreshType 2 | Out-Null
                 
                    if ($Collection.Include){
                        #$IncludeCollection = Get-CMDeviceCollection -Name $Collection.Include
                        Add-CMDeviceCollectionIncludeMembershipRule -CollectionName $Collection.Name -IncludeCollectionName $Collection.Include
                        Start-Sleep -Seconds 5
                    }
                    if ($Collection.Exclude){
                        #$ExcludeCollection = Get-CMDeviceCollection -Name $Collection.Exclude
                        Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $Collection.Name -ExcludeCollectionName $Collection.Exclude
                        Start-Sleep -Seconds 5
                    }
                    if ($Collection.Query){
                        Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $Collection.Query -RuleName $Collection.Name
                        Start-Sleep -Seconds 5

                    }
                    Write-host *** Collection $Collection.Name created ***
                }

            Catch {
                    Write-host "-----------------"
                    Write-host -ForegroundColor Red ("There was an error creating the: " + $Collection.Name + " collection.")
                    Write-host "-----------------"
                    $ErrorCount += 1
                    Pause
            }

            Try {
                    Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $Collection.Name)
                    Write-host *** Collection $Collection.Name moved to $CollectionFolder.Name folder***
                }

            Catch {
                    Write-host "-----------------"
                    Write-host -ForegroundColor Red ("There was an error moving the: " + $Collection.Name +" collection to " + $CollectionFolder.Name +".")
                    Write-host "-----------------"
                    $ErrorCount += 1
                    Pause
                }

    }

    If ($ErrorCount -ge1) {

            Write-host "-----------------"
            Write-Host -ForegroundColor Red "The script execution completed, but with errors."
            Write-host "-----------------"
            Pause
    }

    Else{
            Write-host "-----------------"
            Write-Host -ForegroundColor Green "Script execution completed without error. Co-Maanagement Collections created sucessfully."
            Write-host "-----------------"
            Pause
        }
}

Else {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("The following collections already exist in your environment:`n`r" + $($ErrorCollections | ForEach-Object {(" " +$_ + "`n`r")}) + "Please delete all collections manually or rename them before re-executing the script! You can also select Y to do it automaticaly")
        Write-host "-----------------"
        Pause
}
