<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

Original script (Assign-ProfileToDevice) can be found at:
https://github.com/microsoftgraph/powershell-intune-samples/tree/master/AppleEnrollment

Based on the script of Dan Zabinski https://github.com/DanZab
#>

Function Get-AzureADAccessToken {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TenantId,
        [Parameter(Mandatory=$true)]
        [string]$ClientId,
        [Parameter(Mandatory=$true)]
        [string]$ClientSecret
    )
    $Body = @{
        "grant_type"    = "client_credentials"
        "client_id"     = $ClientId
        "client_secret" = $ClientSecret
        "scope"         = "https://graph.microsoft.com/.default"
    }
    $Params = @{
        "Uri"         = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        "Method"      = "Post"
        "ContentType" = "application/x-www-form-urlencoded"
        "Body"        = $Body
    }
    $AuthResponse = Invoke-RestMethod @Params
    return $AuthResponse
}


    
Function Get-DEPOnboardingSettings {

<#
.SYNOPSIS
This function retrieves the DEP onboarding settings for your tenant. DEP Onboarding settings contain information such as Token ID, which is used to sync DEP and VPP
.DESCRIPTION
The function connects to the Graph API Interface and gets a retrieves the DEP onboarding settings.
.EXAMPLE
Get-DEPOnboardingSettings
Gets all DEP Onboarding Settings for each DEP token present in the tenant
.NOTES
NAME: Get-DEPOnboardingSettings
#>
    
[cmdletbinding()]
    
Param(
[parameter(Mandatory=$false)]
[string]$tokenid
)
    
    $graphApiVersion = "beta"
    
        try {
    
                if ($tokenid){
                
                $Resource = "deviceManagement/depOnboardingSettings/$tokenid/"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
                        
                }
    
                else {
                
                $Resource = "deviceManagement/depOnboardingSettings/"
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
                
                }
                    
            }
        
        catch {
    
                $ex = $_.Exception
                if ($ex.Response -eq $null) {
                    Write-Host "Request to $Uri failed with exception $($ex.Message)" -f Red
                    write-host
                    break
                }
                else {
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
    
    } 
    
    ####################################################
    
    Function Get-DEPProfiles(){
    
    <#
    .SYNOPSIS
    This function is used to get a list of DEP profiles by DEP Token
    .DESCRIPTION
    The function connects to the Graph API Interface and gets a list of DEP profiles based on DEP token
    .EXAMPLE
    Get-DEPProfiles
    Gets all DEP profiles
    .NOTES
    NAME: Get-DEPProfiles
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings/$id/enrollmentProfiles"
    
        try {
    
            $SyncURI = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            Invoke-RestMethod -Uri $SyncURI -Headers $authToken -Method GET
    
        }
    
        catch {
    
        Write-Host
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
    
    Function Assign-ProfileToDevice(){
    
    ####################################################
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        $id,
        [Parameter(Mandatory=$true)]
        $DeviceSerialNumber,
        [Parameter(Mandatory=$true)]
        $ProfileId
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings/$id/enrollmentProfiles('$ProfileId')/updateDeviceProfileAssignment"
    
        try {
    
            $DevicesArray = $DeviceSerialNumber -split ","
    
            $JSON = @{ "deviceIds" = $DevicesArray } | ConvertTo-Json
    
            Test-JSON -JSON $JSON
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"
    
            Write-Host "Success: " -f Green -NoNewline
            Write-Host "Device assigned!"
            Write-Host
    
            $AssignedProfileStatus = "Success"
    
        }
    
        catch {
    
            Write-Host
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "Response content:`n$responseBody" -f Red
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
            write-host
            
            $AssignedProfileStatus = "Failed"
        }
    
        Return $AssignedProfileStatus
    
    }
    
    ####################################################
    
    Function Get-IntuneDevice ($IntuneDeviceSerial) {
        $DeviceSerialNumber = $IntuneDeviceSerial
    
        # If variable contains spaces, remove them
        $DeviceSerialNumber = $DeviceSerialNumber.replace(" ","")
    
        If(!($DeviceSerialNumber)){
        
            $IntuneDeviceResult = "No Serial Number entered"
        }
        Else {
            $graphApiVersion = "beta"
            $Resource = "deviceManagement/depOnboardingSettings/$($id)/importedAppleDeviceIdentities?`$filter=discoverySource eq 'deviceEnrollmentProgram' and contains(serialNumber,'$DeviceSerialNumber')"
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            $SearchResult = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
    
            If (!($SearchResult)){
        
                $IntuneDeviceResult = "Device Not Found"
                Write-Host -ForegroundColor Yellow "$IntuneDeviceResult"
    
            } Else {
        
                $IntuneDeviceResult = "Device Found"
    
            }
        }
    
        Return $IntuneDeviceResult
    }
    
    Function Get-TokensAndProfiles($TokenList) {
        $FinalList =@()
    
        ForEach ($token in $TokenList) {
            $TokenId = $token.id
            $TokenName = $token.TokenName
    
            $Profiles = (Get-DEPProfiles -id $TokenId).value
    
            ForEach ($Profile in $Profiles) {
                $ProfileName = $Profile.DisplayName
                $ProfileId = $Profile | Select-Object -ExpandProperty id
    
                $Object = New-Object PSObject -Property @{
                    TokenName = $TokenName
                    TokenId = $TokenId
                    ProfileName = $ProfileName
                    ProfileId = $ProfileId
                }
    
                $FinalList += $Object
            }
        }
    
        $FinalList | Select TokenName, ProfileName | Sort ProfileName | Format-Table
    
        Write-Host "Would you like to create a CSV Input template? (" -NoNewline
        Write-Host -ForegroundColor Green "[Enter]" -NoNewline
        Write-Host " / " -NoNewline
        Write-Host -ForegroundColor Green "Y " -NoNewline
        Write-Host "for Yes, " -NoNewline
        Write-Host -ForegroundColor Red "N " -NoNewline
        Write-Host "for No) " -NoNewline
    
        $Prompt = Read-Host
    
        If ($Prompt -eq "" -or $Prompt -eq "y") {
            $SampleCSV = @()
            For ($i=1;$i -le $FinalList.count; $i++) {
                if ($i -lt 10) {
                    $SampleSerialNumber = "X00XX00XXXX$i"
                } elseif ($i -ge 10 -and $i -lt 100) {
                    $SampleSerialNumber = "X00XX$iXXXX1"
                } elseif ($i -ge 100) {
                    $SampleSerialNumber = "X$iX00XXXX1"
                }
    
                $SampleObject = New-Object PSObject -Property @{
                    DeviceSerialNumber = $SampleSerialNumber
                    Token = $FinalList[$i -1].TokenName
                    Profile = $FinalList[$i -1].ProfileName
                }
    
                $SampleCSV += $SampleObject
            }
    
            $SampleCSV = $SampleCSV | Select DeviceSerialNumber, Token, Profile
    
            Save-Output -FileName "$(Get-Date -Format yyyy-MM_HHmm)_IntuneProfileSample.csv" -DataOutput $SampleCSV
        }
    }
    
    Function Get-InputFile(){
        $InputFolderPath = "$((Get-Location).Path)\input"
        Try {
            $FileList = Get-ChildItem $InputFolderPath
        }
        Catch {
            Write-Host -ForegroundColor Red "Input folder not found at " -NoNewline
            Write-Host -ForegroundColor Yellow $InputFolderPath
    
            $FileList = "None"
        }
    
        Do {
            If ($FileList -ne "none") {
                Write-Host "Pleaes choose your input file: "
                For ($i=0; $i -le ($FileList.Count - 1); $I++){
                    Write-Host -BackgroundColor White " " -NoNewline
                    Write-Host -ForegroundColor Black -BackgroundColor White ($i + 1) -NoNewline
                    Write-Host -BackgroundColor White " " -NoNewline
                    Write-Host " " -NoNewline
                    Write-Host $FileList[$i]
                }
                Write-Host -ForegroundColor Black -BackgroundColor White " F " -NoNewline
                Write-Host " to enter custom file path"
                
                Write-Host -ForegroundColor Black -BackgroundColor White " X " -NoNewline
                Write-Host " or " -NoNewline
                Write-Host -ForegroundColor Black -BackgroundColor White " Exit " -NoNewline
                Write-Host " to cancel"
                Write-Host `n
    
                $UserInput = Read-Host "Please enter your selection"
            }
            Else {
                $UserInput = "F"
            }
            
            Switch -Regex ($UserInput) {
                '\d+' {
                    [int]$Selection = $UserInput
                    $Selection = $Selection - 1
                    $InputFile = "$($InputFolderPath)\$($FileList[$Selection].Name)"
    
                    If ($Status) {Clear-Variable Status}
                }
                "F" {
                    Write-Host "Please enter the full file path for the input file (type " -NoNewline
                    Write-Host -ForegroundColor Yellow "X" -NoNewline
                    Write-Host " or " -NoNewline
                    Write-Host -ForegroundColor Yellow "Exit" -NoNewline
                    Write-Host " to cancel): " -NoNewline
                    $CustomFilePath = Read-Host
    
                    Switch ($CustomFilePath) {
                        "Exit" {Write-Host "Cancelling script"; Exit}
                        "X" {Write-Host "Cancelling script"; Exit}
                        default {
                            if (Test-Path $CustomFilePath) {
                                $InputFile = $CustomFilePath
                                Clear-Variable error
                            }
                            else {
                                Write-Host -ForegroundColor Red "Invalid File Path"
                                $Status = "error"
                            }
                                ; Break}
                    }
                }
                "Exit" {Write-Host "Cancelling script"; Exit}
                "X" {Write-Host "Cancelling script"; Exit}
                default {$Status = "error"; break}
            }
            
        } While ($Status)
    
        return $InputFile
    }
    
    Function Save-Output ($FileName, $DataOutput) {
        $CurrentFolderPath = "$((Get-Location).Path)"
        $OutputPath = "$CurrentFolderPath\$FileName"
    
        $DataOutput | Export-CSV $OutputPath -NoTypeInformation
    
        Write-Host "Output saved to:"
        Write-Host -ForegroundColor Yellow "$OutputPath"
    
        Set-Clipboard -Value $OutputPath
    }
    
####################################################

#region Authentication


    

# Initialize Tenand and App Registration IDs
$tenantId = ""
$clientId = ""
$clientSecret = ""



    
    # Checking if authToken exists before running authentication
    if($global:authToken){
    
        # check if the token has expired
        $TokenExpires = ($global:authToken.expiresOn.datetime - (Get-Date).ToUniversalTime()).Minutes
            
            if($TokenExpires -le 0){
    
                write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
                
                # Token is expired, calling Get-AuthToken function
                write-host "Getting new Authentication Token" -ForegroundColor Green
                $global:authToken = Get-AzureADAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret
                write-host "New Authentication Token received" -ForegroundColor Green
    
                }

    
            
    }    
    else {
    
        write-host "No Authentication Token found" -ForegroundColor Yellow
    
        # Getting the authorization token
        write-host "Getting new Authentication Token" -ForegroundColor Green
        $global:authToken = Get-AzureADAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret
        write-host "New Authentication Token received" -ForegroundColor Green
    
    }
    
    #endregion
    
    ####################################################

    # Main script body

    $Options = @("List all Tokens and Profiles",`
        "Assign profiles to multiple devices (requires a csv input)",`
        "Assign a profile to a single device","Terminate script")
    
    Write-Host "Choose what you would like to do:"
    for ($i=1;$i -le $Options.count; $i++) {
        Write-Host "$i. $($Options[$i-1])"
    }
    Write-Host 
    [int]$ScriptPrompt = Read-Host "Enter the value for the option you would like "
    
    #region DEP Tokens
    
    
    $tokens = (Get-DEPOnboardingSettings)
    
    if($tokens){
        Switch ($ScriptPrompt) {
            default {Write-Host -ForegroundColor Yellow "No value selected"}
            1 {
                Get-TokensAndProfiles $tokens
            }
            2 {
                Write-Host `n
                Write-Host "Select a CSV input file. If you do not have one, use the 'List all Tokens and Profiles' function to generate a sample."
                Write-Host
    
                $InputCSV = Get-InputFile
    
                $DeviceList = Import-CSV $InputCSV
    
                $FinalList = @()
    
                ForEach ($Device in $DeviceList) {
                    If ($null -eq $id) {
                        $AssignedTokenName = $Device.Token
                        $SelectedToken = $tokens | Where-Object { $_.TokenName -eq "$AssignedTokenName" }
                        $id = $SelectedToken | Select-Object -ExpandProperty id
                    }
    
                    Write-Host "Assigning $($Device.DeviceSerialNumber) to $($Device.Token) $($Device.Profile)"
                    $DeviceSerial = $Device.DeviceSerialNumber
                    $DeviceCheck = Get-IntuneDevice $DeviceSerial
    
                    If ($DeviceCheck -eq "Device Found") {
                        $AssignedTokenName = $Device.Token
                        $AssignedProfileName = $Device.Profile
    
                        $SelectedToken = $tokens | Where-Object { $_.TokenName -eq "$AssignedTokenName" }
                        $SelectedTokenId = $SelectedToken | Select-Object -ExpandProperty id
    
                        $Profiles = (Get-DEPProfiles -id $id).value
                        $SelectedProfile = $Profiles | Where-Object { $_.DisplayName -eq "$AssignedProfileName" }
                        $SelectedProfileId = $SelectedProfile | Select-Object -ExpandProperty id
    
                        $ProfileStatus = Assign-ProfileToDevice -id $SelectedTokenId -DeviceSerialNumber $DeviceSerial -ProfileId $SelectedProfileId
    
                        If ($ProfileStatus -eq "Success") {
                            $DeviceStatus = "Assigned to profile $AssignedProfileName"
                        } Else {
                            $DeviceStatus = "Failed to assign profile"
                        }
                    }
                    Else {
                        $DeviceStatus = "Not Found"
                    }
    
                    $Object = New-Object PSObject -Property @{
                        DeviceSerial = $DeviceSerial
                        Status = $DeviceStatus
                    }
    
                    $FinalList += $Object
                }
    
                $FinalList = $FinalList | Select DeviceSerial, Status
                
                Save-Output -FileName "$(Get-Date -Format yyyy-MM_HHmm)_IntuneProfileAssignments.csv" -DataOutput $FinalList
            }
            3 {
                    
                    $DeviceSerialNumberPrompt = Read-Host "Please enter device serial number"
                    Get-IntuneDevice $DeviceSerialNumberPrompt
    
                    $tokencount = @($tokens).count
    
                    if ($tokencount -gt 1){
    
                    write-host "Listing DEP tokens..." -ForegroundColor Yellow
                    Write-Host
                    $DEP_Tokens = $tokens.tokenName | Sort-Object -Unique
    
                    $menu = @{}
    
                    for ($i=1;$i -le $DEP_Tokens.count; $i++) 
                    { Write-Host "$i. $($DEP_Tokens[$i-1])" 
                    $menu.Add($i,($DEP_Tokens[$i-1]))}
    
                    Write-Host
                    [int]$ans = Read-Host 'Select the token you wish you to use (numerical value)'
                    $selection = $menu.Item($ans)
                    Write-Host
    
                        if ($selection){
    
                        $SelectedToken = $tokens | Where-Object { $_.TokenName -eq "$Selection" }
    
                        $SelectedTokenId = $SelectedToken | Select-Object -ExpandProperty id
                        $id = $SelectedTokenId
    
                        }
    
                    }
    
                    elseif ($tokencount -eq 1) {
    
                        $id = (Get-DEPOnboardingSettings).id
        
                    }
    
                    ####################################################
    
                    # Device lookup region
    
                    ####################################################
    
                    $Profiles = (Get-DEPProfiles -id $id).value
    
                    if($Profiles){
                    
                    Write-Host
                    Write-Host "Listing DEP Profiles..." -ForegroundColor Yellow
                    Write-Host
    
                    $enrollmentProfiles = $Profiles.displayname | Sort-Object -Unique
    
                    $menu = @{}
    
                    for ($i=1;$i -le $enrollmentProfiles.count; $i++) 
                    { Write-Host "$i. $($enrollmentProfiles[$i-1])" 
                    $menu.Add($i,($enrollmentProfiles[$i-1]))}
    
                    Write-Host
                    $ans = Read-Host 'Select the profile you wish to assign (numerical value)'
    
                        # Checking if read-host of DEP Profile is an integer
                        if(($ans -match "^[\d\.]+$") -eq $true){
    
                            $selection = $menu.Item([int]$ans)
    
                        }
    
                        if ($selection){
       
                            $SelectedProfile = $Profiles | Where-Object { $_.DisplayName -eq "$Selection" }
                            $SelectedProfileId = $SelectedProfile | Select-Object -ExpandProperty id
                            $ProfileID = $SelectedProfileId
    
                        }
    
                        else {
    
                            Write-Host
                            Write-Warning "DEP Profile selection invalid. Exiting..."
                            Write-Host
                            break
    
                        }
    
                    }
    
                    else {
        
                        Write-Host
                        Write-Warning "No DEP profiles found!"
                        break
    
                    }
    
                    ####################################################
    
                    $Status = Assign-ProfileToDevice -id $id -DeviceSerialNumber $DeviceSerialNumber -ProfileId $ProfileID
    
                    Write-Host
                    Read-Host "Press Enter to finish"
                    Exit
            }
            4 {
                # Terminate script
                write-host "Terminating script" -ForegroundColor Yellow
                Exit
            }
    
        }
        # End of Switch Statement
    
    } Else {
        
        Write-Warning "No DEP tokens found!"
        Write-Host
        break
    
    }
