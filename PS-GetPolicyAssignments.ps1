
<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

####################################################

function Get-AuthToken {

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )
    
    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    
    $tenant = $userUpn.Host
    
    Write-Host "Checking for AzureAD module..."
    
        $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    
        if ($AadModule -eq $null) {
    
            Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
            $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    
        }
    
        if ($AadModule -eq $null) {
            write-host
            write-host "AzureAD Powershell module not installed..." -f Red
            write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
            write-host "Script can't continue..." -f Red
            write-host
            exit
        }
    
    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version
    
        if($AadModule.count -gt 1){
    
            $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
    
            $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }
    
                # Checking if there are multiple versions of the same module found
    
                if($AadModule.count -gt 1){
    
                $aadModule = $AadModule | select -Unique
    
                }
    
            $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
            $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    
        }
    
        else {
    
            $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
            $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    
        }
    
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    
    $resourceAppIdURI = "https://graph.microsoft.com"
    
    $authority = "https://login.microsoftonline.com/$Tenant"
    
        try {
    
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    
        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
    
        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result
    
            # If the accesstoken is valid then create the authentication header
    
            if($authResult.AccessToken){
    
            # Creating header for Authorization token
    
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $authResult.AccessToken
                'ExpiresOn'=$authResult.ExpiresOn
                }
    
            return $authHeader
    
            }
    
            else {
    
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
    
            }
    
        }
    
        catch {
    
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    
        }
    
    }
    
    ####################################################
    
    Function Get-DeviceConfigurationPolicy(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    
        try {
    
            if($Name){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=displayName eq '$name'"
            (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).value
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
    
            }
    
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

    
    Function Get-DeviceConfigurationPolicyAssignment(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policy assignment from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets a device configuration policy assignment
    .EXAMPLE
    Get-DeviceConfigurationPolicyAssignment $id guid
    Returns any device configuration policy assignment configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicyAssignment
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true,HelpMessage="Enter id (guid) for the Device Configuration Policy you want to check assignment")]
        $id
    )
    
    $graphApiVersion = "Beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    
        try {
    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id/groupAssignments"
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
    
    Function Add-DeviceConfigurationPolicyAssignment(){
    
    <#
    .SYNOPSIS
    This function is used to add a device configuration policy assignment using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and adds a device configuration policy assignment
    .EXAMPLE
    Add-DeviceConfigurationPolicyAssignment -ConfigurationPolicyId $ConfigurationPolicyId -TargetGroupId $TargetGroupId
    Adds a device configuration policy assignment in Intune
    .NOTES
    NAME: Add-DeviceConfigurationPolicyAssignment
    #>
    
    [cmdletbinding()]
    
    param
    (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ConfigurationPolicyId,
    
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $TargetGroupId,
    
        [parameter(Mandatory=$true)]
        [ValidateSet("Included","Excluded")]
        [ValidateNotNullOrEmpty()]
        [string]$AssignmentType
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceConfigurations/$ConfigurationPolicyId/assign"
        
        try {
    
            if(!$ConfigurationPolicyId){
    
                write-host "No Configuration Policy Id specified, specify a valid Configuration Policy Id" -f Red
                break
    
            }
    
            if(!$TargetGroupId){
    
                write-host "No Target Group Id specified, specify a valid Target Group Id" -f Red
                break
    
            }
    
            # Checking if there are Assignments already configured in the Policy
            $DCPA = Get-DeviceConfigurationPolicyAssignment -id $ConfigurationPolicyId
    
            $TargetGroups = @()
    
            if(@($DCPA).count -ge 1){
                
                if($DCPA.targetGroupId -contains $TargetGroupId){
    
                Write-Host "Group with Id '$TargetGroupId' already assigned to Policy..." -ForegroundColor Red
                Write-Host
                break
    
                }
    
                # Looping through previously configured assignements
    
                $DCPA | foreach {
    
                $TargetGroup = New-Object -TypeName psobject
         
                    if($_.excludeGroup -eq $true){
    
                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.exclusionGroupAssignmentTarget'
         
                    }
         
                    else {
         
                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
         
                    }
    
                $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value $_.targetGroupId
    
                $Target = New-Object -TypeName psobject
                $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
    
                $TargetGroups += $Target
    
                }
    
                # Adding new group to psobject
                $TargetGroup = New-Object -TypeName psobject
    
                    if($AssignmentType -eq "Excluded"){
    
                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.exclusionGroupAssignmentTarget'
         
                    }
         
                    elseif($AssignmentType -eq "Included") {
         
                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
         
                    }
         
                $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value "$TargetGroupId"
    
                $Target = New-Object -TypeName psobject
                $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
    
                $TargetGroups += $Target
    
            }
    
            else {
    
                # No assignments configured creating new JSON object of group assigned
                
                $TargetGroup = New-Object -TypeName psobject
    
                    if($AssignmentType -eq "Excluded"){
    
                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.exclusionGroupAssignmentTarget'
         
                    }
         
                    elseif($AssignmentType -eq "Included") {
         
                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
         
                    }
         
                $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value "$TargetGroupId"
    
                $Target = New-Object -TypeName psobject
                $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
    
                $TargetGroups = $Target
    
            }
    
        # Creating JSON object to pass to Graph
        $Output = New-Object -TypeName psobject
    
        $Output | Add-Member -MemberType NoteProperty -Name 'assignments' -Value @($TargetGroups)
    
        $JSON = $Output | ConvertTo-Json -Depth 3
    
        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"
    
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
    
    Function Get-AADGroup(){
    
    <#
    .SYNOPSIS
    This function is used to get AAD Groups from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Groups registered with AAD
    .EXAMPLE
    Get-AADGroup
    Returns all users registered with Azure AD
    .NOTES
    NAME: Get-AADGroup
    #>
    
    [cmdletbinding()]
    
    param
    (
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        $GroupName,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $id,
        [parameter(Mandatory=$false)]
        [switch]$Members
    )
    
    # Defining Variables
    $graphApiVersion = "v1.0"
    $Group_resource = "groups"
        
        try {
    
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=id eq '$id'"
            (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
    
            }
            
            elseif($GroupName -eq "" -or $GroupName -eq $null){
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
            
            }
    
            else {
                
                if(!$Members){
    
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
                (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
                
                }
                
                elseif($Members){
                
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
                $Group = (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
                
                    if($Group){
    
                    $GID = $Group.id
    
                    $Group.displayName
                    write-host
    
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$GID/Members"
                    (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).Value
    
                    }
    
                }
            
            }
    
        }
    
        catch {
    
        $ex = $_.Exception
        $errorResponse = $ex.Response.ToString()
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
    
    #region Authentication


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
    

    
    write-host
    
    # Checking if authToken exists before running authentication
    if($authToken){
    
        # Setting DateTime to Universal time to work in all timezones
        $DateTime = (Get-Date).ToUniversalTime()
    
        # If the authToken exists checking when it expires
        $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes
    
            if($TokenExpires -le 0){
    
            write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
            write-host
        
            # Getting the authorization token   
            try {
                $connection = Invoke-RestMethod -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token -Method POST -Body $body
                $authToken = $connection.access_token

                write-host "Authentication Token acquired " -ForegroundColor DarkGreen

                if ($null -ne $authToken) {
                    $headers = @{Authorization="Bearer $authToken"}
                }
            }
            catch [System.Exception] {
                    Write-Warning -Message "Failed to retrieve authentication token"
            }

    
            }
    }
    
    # Authentication doesn't exist, calling Get-AuthToken function
    
    else {
        write-host "Authentication Token does not exist " -ForegroundColor Red
        write-host "Acquiring a new Authentication Token " -ForegroundColor Green
        
        # Getting the authorization token   
        try {
                $connection = Invoke-RestMethod -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token -Method POST -Body $body
                $authToken = $connection.access_token

                write-host "Authentication Token acquired " -ForegroundColor DarkGreen

                if ($null -ne $authToken) {
                    $headers = @{Authorization="Bearer $authToken"}
                }
        }
        catch [System.Exception] {
                Write-Warning -Message "Failed to retrieve authentication token"
        }

    
    }
    
    #endregion


    $intunePolicies = Get-DeviceConfigurationPolicy
    $intunePolicyArray = @()


    foreach ($policy in $intunePolicies){

        $policyAssignments = Get-DeviceConfigurationPolicyAssignment -id $policy.id

     
        if ($policyAssignments){
            $IntunePolicyAssignmentsArray = @()
            foreach($policyAssignment in $policyAssignments){
                
                
                $AssignmentGroup = Get-AADGroup -id $policyAssignment.targetGroupId

                $policyAssignmentDetails = new-object -TypeName PSObject
                $policyAssignmentDetails | Add-Member -MemberType NoteProperty -Name "ID" -Value $policyAssignment.id
                $policyAssignmentDetails | Add-Member -MemberType NoteProperty -Name "IncludedGroupID" -Value $policyAssignment.targetGroupId
                $policyAssignmentDetails | Add-Member -MemberType NoteProperty -Name "GroupName" -Value $AssignmentGroup.displayName
                $policyAssignmentDetails | Add-Member -MemberType NoteProperty -Name "Excluded" -Value $policyAssignment.excludeGroup

                $IntunePolicyAssignmentsArray += $policyAssignmentDetails
            }

            [System.Collections.ArrayList]$IntunePolicyAssignmentsArrayList = $IntunePolicyAssignmentsArray

        }





        # Create custom PSObject
        $policyInfo = new-object -TypeName PSObject

        $policyInfo | Add-Member -MemberType NoteProperty -Name "Id" -Value $policy.id -Force
        $policyInfo | Add-Member -MemberType NoteProperty -Name "DataType" -Value $policy.'@odata.type' -Force
        $policyInfo | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $policy.displayName -Force
        $policyInfo | Add-Member -MemberType NoteProperty -Name "Description" -Value $policy.description -Force
        $policyInfo | Add-Member -MemberType NoteProperty -Name "CreationDateTime" -Value $policy.createdDateTime -Force
        $policyInfo | Add-Member -MemberType NoteProperty -Name "LastModifiedDateTime" -Value $policy.lastModifiedDateTime -Force
        if ($IntunePolicyAssignmentsArrayList){
            $policyInfo | Add-Member -MemberType NoteProperty -Name "PolicyAssignment" -Value $IntunePolicyAssignmentsArrayList -Force
        }
        


        $intunePolicyArray += $policyInfo
    }

    [System.Collections.ArrayList]$intunePolicyArrayList = $intunePolicyArray
