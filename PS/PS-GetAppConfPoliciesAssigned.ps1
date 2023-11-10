
# Declare variables

$appClientID     = ""  #  <-insert your own app ID here
$clientSecret = "" #  <-insert your own secret here
$tenantid = ""             #  <-insert your own tenant id here


# Function to get the device name from the device ID
# TO BE IMPLEMENTED
function GetDeviceName {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		$devideId
	)


    
}

function GetDeviceId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $deviceName
    )

    $uri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

 

    $jsonDevices = Invoke-RestMethod -Method GET -Uri $uri -ContentType "application/json" -Headers $headers | ConvertTo-Json
    
    #cycle through the devices and find the one that matches the name
    $devices = $jsonDevices | ConvertFrom-Json
    $deviceId = $devices.value | Where-Object {$_.deviceName -eq $deviceName} | Select-Object id
    

    return $deviceId
}
 

 
Function GetAppConfPolicyAssigned 
{

	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		$devideId
	)

        $uri = 'https://graph.microsoft.com/beta/deviceManagement/reports/getConfigurationPoliciesReportForDevice'
        $payload = @{
        select = @(
            "PolicyName"
            "PolicyId"
            "PolicyStatus"
            "PspdpuLastModifiedTimeUtc"
        )
        filter = "(PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.ManagedDeviceMobileAppConfigBase')  and (IntuneDeviceId eq '$($devideId)')"
        }
 

    $jsonPolicies = Invoke-RestMethod -Method POST -Uri $uri -Body ($payload|ConvertTo-Json) -ContentType "application/json" -Headers $headers | ConvertTo-Json
    return $jsonPolicies
}


function GetAppConfPolicies($deviceName) {
    $deviceId = GetDeviceId -deviceName $deviceName | Select-Object -ExpandProperty id
    $appPolicies = GetAppConfPolicyAssigned($deviceId)

    $policies = $appPolicies | ConvertFrom-Json 
    $devicePoliciesArray = @()

    foreach ($policy in $policies.Values) {
        switch ($policy[2]) {
            0 { $policyStatus = "Unknown" }
            2 { $policyStatus = "Success" }
            4 { $policyStatus = "Error" }
            6 { $policyStatus = "Conflict" }
        }

        if ($policy[2] -eq "2") {
            $policy[2] = "Not Applicable"
        }

        $tempPolItem = New-Object -TypeName PSObject
        $tempPolItem | Add-Member -MemberType NoteProperty -Name DeviceId -Value $deviceId
        $tempPolItem | Add-Member -MemberType NoteProperty -Name DeviceName -Value $deviceName
        $tempPolItem | Add-Member -MemberType NoteProperty -Name PolicyName -Value $policy[1]
        $tempPolItem | Add-Member -MemberType NoteProperty -Name PolicyId -Value $policy[0]
        $tempPolItem | Add-Member -MemberType NoteProperty -Name PolicyStatus -Value $policyStatus
        $tempPolItem | Add-Member -MemberType NoteProperty -Name PolicyAppliedUTC -Value $policy[3]
        $devicePoliciesArray += $tempPolItem
    }

    return $devicePoliciesArray #| Format-Table -AutoSize
}

# Authenticate to Azure AD
	
$body =  @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $appClientID
    Client_Secret = $clientSecret
}

 # Acquire authentication token
 try {
    $connection = Invoke-RestMethod -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token -Method POST -Body $body
    $AccessToken = $connection.access_token
    if ($null -ne $AccessToken) {

                $headers = @{Authorization="Bearer $AccessToken"}
    }
}
catch [System.Exception] {
    Write-Warning -Message "Failed to retrieve authentication token"
} 




$deviceName = Read-Host "Enter device name: " 
$deviceNameFile = Read-Host "If you want you can specify the file to read device names from: "


if (($null -eq $deviceName -or $deviceName -eq "") -and ($null -eq $deviceNameFile -or $deviceNameFile -eq "")) {

    Write-Host "You must enter a device name or a file name"
    exit


    }
    else{
            
        if ($null -eq $deviceNameFile -or $deviceNameFile -eq "") {

            GetAppConfPolicies -deviceName $deviceName

        }
        else {
            $deviceListName = Get-Content $deviceNameFile
            write-host "Device names $($deviceListName.Count) read from file: $deviceNameFile"

            $deviceObjects = @()

            foreach ($deviceItem in $deviceListName) {

                $policyArray =  GetAppConfPolicies -deviceName $deviceItem
                $policyArray | ForEach-Object {
                    
                    $deviceObjects += $_
                }
                $deviceObjects | Format-Table #| Export-Csv -Path "C:\temp\devicePolicies.csv" -NoTypeInformation
            }


        }

    }
















