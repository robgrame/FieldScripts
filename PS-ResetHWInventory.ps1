$HardwareInventoryID = '{00000000-0000-0000-0000-000000000001}'
Get-WmiObject -ComputerName $comp -Namespace   'Root\CCM\INVAGT' -Class 'InventoryActionStatus' -Filter "InventoryActionID='$HardwareInventoryID'" | Remove-WmiObject
Start-Sleep -s 15
Invoke-WmiMethod -computername $comp -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList $HardwareInventoryID 
