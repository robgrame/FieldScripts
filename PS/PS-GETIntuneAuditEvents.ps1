####################################################

Function Get-AuditCategories(){
    
    <#
    .SYNOPSIS
    This function is used to get all audit categories from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets all audit categories
    .EXAMPLE
    Get-AuditCategories 
    Returns all audit categories configured in Intune
    .NOTES
    NAME: Get-AuditCategories
    #>
        
    [cmdletbinding()]
        
    param
    (
        $Name
    )
        
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/auditEvents/getAuditCategories"
        
        try {
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
        
        }
        
        catch {
        
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
        
        }
        
    }
    
    ####################################################
    
    Function Get-AuditEvents(){
        
    <#
    .SYNOPSIS
    This function is used to get all audit events from a specific category using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets audit events from a specific audit category
    .EXAMPLE
    Get-AuditEvents -category "Application"
    Returns audit events from the category "Application" configured in Intune
    Get-AuditEvents -category "Application" -days 7
    Returns audit events from the category "Application" in the past 7 days configured in Intune
    .NOTES
    NAME: Get-AuditEvents
    #>
        
    [cmdletbinding()]
        
    param
    (
        [Parameter(Mandatory=$true)]
        $Category,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,30)]
        [Int]$days
    )
        
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/auditEvents"
    
    if($days){ $days }
    else { $days = 1 }
    
    $daysago = "{0:s}" -f (get-date).AddDays(-$days) + "Z"
        
        try {
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=category eq '$Category' and activityDateTime gt $daysago"
        Write-Verbose $uri
        (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
        
        }
        
        catch {
        
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
        
        }
        
    }
    
    ####################################################
    
   

    # Populate with the App Registration details and Tenant ID
    $appid = ''
    $tenantid = ''
    $secret = ''
    
    $body =  @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $appid
        Client_Secret = $secret
    }
    
     # Acquire authentication token
     try {
        $connection = Invoke-RestMethod -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token -Method POST -Body $body
        $AccessToken = $connection.access_token
        if ($AccessToken -ne $null) {
            $headers = @{Authorization="Bearer $AccessToken"}
        }
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to retrieve authentication token"
    } 

    $EventsTable = @{}

    if ($headers){
    
        $AuditCategories = Get-AuditCategories
        
        if($AuditCategories){
        
            foreach($Category in $AuditCategories){
        
            $Events = Get-AuditEvents -Category "$Category"
        
                if($Events){
                    
                        foreach($Event in ($Events | Sort-Object -Property activityDateTime)){
        
                            $DisplayName = $Event.displayname
                            $ID = $Event.id
                            $ComponentName = $Event.componentName
                            $ActivityType = $Event.activityType
                            $ActivityDateTime = $Event.activityDateTime
                            $Application = $Event.actor.applicationDisplayName
                            $ActivityResult = $Event.activityResult
                            $UPN = $Event.actor.userPrincipalName
                            $ResourceDN = $Event.resources.displayName
                            $ResourceType = $Event.resources.type
                            $ResourceId = $Event.resources.resourceId

        
                            Write-Output "Displayname: $DisplayName, Component Name: $ComponentName, ActivityType: $ActivityType, Activity Date Time: $ActivityDateTime, Application: $Application, Activity Result: $ActivityResult, UPN: $UPN, Resource Name: $ResourceDN, Resource Type: $ResourceType, Resource ID: $ResourceId"

                    }
                    
                }
            }
        }
    }

