# Get Windows 365 Alerts from Microsoft Graph API
# This script retrieves alert records from the Device Management monitoring endpoint
# Uses only REST API calls - no PowerShell modules required

param(
    [Parameter(HelpMessage = "Output file path for JSON response (optional)")]
    [string]$OutputPath,
    
    [Parameter(HelpMessage = "Tenant ID (required for authentication)")]
    [string]$TenantId = "d6dbad84-5922-4700-a049-c7068c37c884",
    
    [Parameter(HelpMessage = "Request offline access for longer token validity")]
    [switch]$OfflineAccess,
    
    [Parameter(HelpMessage = "Use Azure CLI for authentication instead of device code flow")]
    [switch]$UseAzureCLI
)

# Function to check if Azure CLI is installed and get token
function Get-AccessTokenFromAzureCLI {
    try {
        # Check if Azure CLI is installed
        $azVersion = az --version 2>$null
        if (-not $azVersion) {
            Write-Host "Azure CLI is not installed. Please install it or use device code flow." -ForegroundColor Red
            return $null
        }
        
        Write-Host "Using Azure CLI for authentication..." -ForegroundColor Yellow
        
        # Check if already logged in
        $account = az account show 2>$null | ConvertFrom-Json
        if (-not $account) {
            Write-Host "Not logged into Azure CLI. Please run: az login" -ForegroundColor Red
            return $null
        }
        
        Write-Host "Getting access token from Azure CLI..." -ForegroundColor Gray
        
        # Get access token for Microsoft Graph
        $tokenResponse = az account get-access-token --resource https://graph.microsoft.com --only-show-errors | ConvertFrom-Json
        
        if ($tokenResponse -and $tokenResponse.accessToken) {
            Write-Host "Successfully obtained access token from Azure CLI!" -ForegroundColor Green
            return $tokenResponse.accessToken
        }
        else {
            Write-Error "Failed to obtain access token from Azure CLI"
            return $null
        }
    }
    catch {
        Write-Error "Failed to get access token from Azure CLI: $($_.Exception.Message)"
        return $null
    }
}

# Function to get access token using device code flow
function Get-AccessTokenDeviceCode {
    param(
        [string]$TenantId,
        [string]$ClientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e", # Microsoft Graph PowerShell Client ID
        [bool]$OfflineAccess = $false
    )
    
    Write-Host "Using device code flow for authentication..." -ForegroundColor Yellow
    
    # Device code flow endpoints
    $deviceCodeUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode"
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    
    # Required scope for Device Management
    $scope = "https://graph.microsoft.com/CloudPC.Read.All"
    
    # Add offline access if requested
    if ($OfflineAccess) {
        $scope += " offline_access"
        Write-Host "Requesting offline access for extended session..." -ForegroundColor Cyan
    }
    
    try {
        # Request device code
        $deviceCodeBody = @{
            client_id = $ClientId
            scope = $scope
        }
        
        $deviceCodeResponse = Invoke-RestMethod -Uri $deviceCodeUrl -Method POST -Body $deviceCodeBody -ContentType "application/x-www-form-urlencoded"
        
        # Display user instructions
        $expiresInMinutes = [math]::Round($deviceCodeResponse.expires_in / 60, 1)
        Write-Host "`nPlease complete the authentication:" -ForegroundColor Green
        Write-Host "1. Open a web browser and go to: $($deviceCodeResponse.verification_uri)" -ForegroundColor Cyan
        Write-Host "2. Enter the code: $($deviceCodeResponse.user_code)" -ForegroundColor Cyan
        Write-Host "3. Sign in with your Microsoft account" -ForegroundColor Cyan
        Write-Host "`nCode expires in: $expiresInMinutes minutes" -ForegroundColor Yellow
        Write-Host "Waiting for authentication..." -ForegroundColor Yellow
        
        # Poll for token
        $tokenBody = @{
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
            client_id = $ClientId
            device_code = $deviceCodeResponse.device_code
        }
        
        $timeout = [DateTime]::Now.AddSeconds($deviceCodeResponse.expires_in)
        $startTime = [DateTime]::Now
        
        do {
            Start-Sleep -Seconds $deviceCodeResponse.interval
            
            # Show progress every 30 seconds
            $elapsed = ([DateTime]::Now - $startTime).TotalSeconds
            if ($elapsed % 30 -lt $deviceCodeResponse.interval) {
                $remaining = [math]::Round(($timeout - [DateTime]::Now).TotalMinutes, 1)
                if ($remaining -gt 0) {
                    Write-Host "Still waiting... $remaining minutes remaining" -ForegroundColor Gray
                }
            }
            
            try {
                $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method POST -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
                return $tokenResponse.access_token
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 400) {
                    try {
                        # Handle error response for newer PowerShell versions
                        $errorContent = $_.ErrorDetails.Message | ConvertFrom-Json
                    }
                    catch {
                        # Fallback for older PowerShell versions
                        try {
                            $errorResponse = $_.Exception.Response.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($errorResponse)
                            $errorContent = $reader.ReadToEnd() | ConvertFrom-Json
                        }
                        catch {
                            $errorContent = @{ error = "unknown_error"; error_description = "Unable to parse error response" }
                        }
                    }
                    
                    if ($errorContent.error -eq "authorization_pending") {
                        continue
                    }
                    elseif ($errorContent.error -eq "authorization_declined") {
                        throw "Authentication was declined by the user"
                    }
                    elseif ($errorContent.error -eq "expired_token") {
                        Write-Host "`nThe device code has expired. Please run the script again." -ForegroundColor Red
                        throw "The device code has expired. Please run the script again."
                    }
                    else {
                        throw "Authentication error: $($errorContent.error_description)"
                    }
                }
                else {
                    throw $_.Exception.Message
                }
            }
        } while ([DateTime]::Now -lt $timeout)
        
        Write-Host "`nAuthentication timed out. Please run the script again." -ForegroundColor Red
        throw "Authentication timed out. Please run the script again."
    }
    catch {
        Write-Error "Failed to get access token: $($_.Exception.Message)"
        return $null
    }
}

# Function to get Windows 365 alerts using REST API
function Get-Windows365Alerts {
    param(
        [string]$AccessToken
    )
    
    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
        'User-Agent' = 'PowerShell-GraphAPI-Client'
    }
    
    $graphUri = "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRecords"
    
    try {
        Write-Host "Retrieving Windows 365 alerts..." -ForegroundColor Yellow
        
        # Use Invoke-WebRequest for consistency
        $webResponse = Invoke-WebRequest -Uri $graphUri -Headers $headers -Method GET -UseBasicParsing
        
        # Parse the JSON response
        $response = $webResponse.Content | ConvertFrom-Json
        
        Write-Host "Successfully retrieved alerts!" -ForegroundColor Green
        Write-Host "Total alerts found: $($response.value.Count)" -ForegroundColor Cyan
        
        return $response
    }
    catch {
        # Handle different PowerShell versions for error response
        $statusCode = $null
        $statusDescription = $null
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            $statusDescription = $_.Exception.Response.StatusDescription
        }
        elseif ($_.Exception.Message) {
            $statusDescription = $_.Exception.Message
        }
        
        Write-Error "Failed to retrieve alerts. Status: $statusCode - $statusDescription"
        
        if ($statusCode -eq 403 -or $_.Exception.Message -match "403") {
            Write-Host "Access denied. Please ensure you have the required permissions:" -ForegroundColor Red
            Write-Host "- CloudPC.Read.All" -ForegroundColor Red
            Write-Host "- DeviceManagementConfiguration.Read.All" -ForegroundColor Red
            Write-Host "- Or appropriate admin role (Intune Administrator, Global Administrator, etc.)" -ForegroundColor Red
        }
        elseif ($statusCode -eq 401 -or $_.Exception.Message -match "401") {
            Write-Host "Authentication failed. Please run the script again." -ForegroundColor Red
        }
        
        return $null
    }
}

# Function to get inaccessible Cloud PC reports using REST API
function Get-InaccessibleCloudPCReports {
    param(
        [string]$AccessToken
    )
    
    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
        'User-Agent' = 'PowerShell-GraphAPI-Client'
    }
    
    $graphUri = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/reports/getInaccessibleCloudPcReports"
    
    # JSON payload for the POST request
    $payload = @{
        "top" = 50
        "skip" = 0
        "search" = ""
        "filter" = ""
        "select" = @(
            "cloudPcId",
            "userPrincipalName",
            "cloudPcName",
            "provisioningStatus",
            "deviceHealthStatus",
            "deviceHealthStatusDateTime",
            "systemStatus",
            "systemStatusDateTime",
            "region",
            "lastConnectionFailureDatetime",
            "lastEventDatetime",
            "eligibleCrossRegion",
            "lastFleetWorkItemStatus",
            "lastFleetWorkItemType",
            "recentConnectionError"
        )
        "orderBy" = @(
            "cloudPcName"
        )
    }
    
    $jsonPayload = $payload | ConvertTo-Json -Depth 5
    
    try {
        Write-Host "Retrieving inaccessible Cloud PC reports..." -ForegroundColor Yellow
        
        # Use Invoke-WebRequest with POST method
        $webResponse = Invoke-WebRequest -Uri $graphUri -Headers $headers -Method POST -Body $jsonPayload -UseBasicParsing
        
        # Handle encoding conversion to UTF-8
        $responseContent = $webResponse.Content
        if ($webResponse.Content -is [byte[]]) {
            # Convert byte array to UTF-8 string
            $responseContent = [System.Text.Encoding]::UTF8.GetString($webResponse.Content)
        }
        elseif ($webResponse.RawContent -and $webResponse.Headers.'Content-Type' -notmatch 'charset=utf-8') {
            # Try to detect and convert encoding if not UTF-8
            try {
                $bytes = [System.Text.Encoding]::Default.GetBytes($responseContent)
                $responseContent = [System.Text.Encoding]::UTF8.GetString($bytes)
            }
            catch {
                Write-Host "Warning: Could not convert response encoding, using original content" -ForegroundColor Yellow
            }
        }
        
        # Parse the JSON response
        $rawResponse = $responseContent | ConvertFrom-Json
        
        # Transform the tabular response format to standard format
        $transformedResponse = @{
            value = @()
            totalRowCount = $rawResponse.TotalRowCount
        }
        
        if ($rawResponse.Values -and $rawResponse.Schema) {
            Write-Host "Processing tabular response format..." -ForegroundColor Gray
            Write-Host "Schema columns: $($rawResponse.Schema.Count), Data rows: $($rawResponse.Values.Count)" -ForegroundColor Gray
            
            # Create objects from the tabular data
            foreach ($row in $rawResponse.Values) {
                $cloudPcObject = @{}
                
                # Map each value to its corresponding column name
                for ($i = 0; $i -lt $rawResponse.Schema.Count; $i++) {
                    $columnName = $rawResponse.Schema[$i].Column
                    $value = $row[$i]
                    
                    # Handle null values and convert types if needed
                    if ($value -eq $null -or $value -eq "") {
                        $cloudPcObject[$columnName] = $null
                    } else {
                        $cloudPcObject[$columnName] = $value
                    }
                }
                
                $transformedResponse.value += $cloudPcObject
            }
        }
        
        Write-Host "Successfully retrieved inaccessible Cloud PC reports!" -ForegroundColor Green
        Write-Host "Total inaccessible Cloud PCs found: $($transformedResponse.value.Count)" -ForegroundColor Cyan
        
        return $transformedResponse
    }
    catch {
        # Handle different PowerShell versions for error response
        $statusCode = $null
        $statusDescription = $null
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            $statusDescription = $_.Exception.Response.StatusDescription
        }
        elseif ($_.Exception.Message) {
            $statusDescription = $_.Exception.Message
        }
        
        Write-Error "Failed to retrieve inaccessible Cloud PC reports. Status: $statusCode - $statusDescription"
        
        if ($statusCode -eq 403 -or $_.Exception.Message -match "403") {
            Write-Host "Access denied. Please ensure you have the required permissions:" -ForegroundColor Red
            Write-Host "- CloudPC.Read.All" -ForegroundColor Red
            Write-Host "- DeviceManagementConfiguration.Read.All" -ForegroundColor Red
            Write-Host "- Or appropriate admin role (Intune Administrator, Global Administrator, etc.)" -ForegroundColor Red
        }
        elseif ($statusCode -eq 401 -or $_.Exception.Message -match "401") {
            Write-Host "Authentication failed. Please run the script again." -ForegroundColor Red
        }
        
        return $null
    }
}

# Main script execution
Write-Host "=== Windows 365 Alerts Retriever ===" -ForegroundColor Magenta
Write-Host "This script retrieves Windows 365 alert records from Microsoft Graph API" -ForegroundColor White
Write-Host "No PowerShell modules required - uses only REST API calls!" -ForegroundColor Green
Write-Host ""

# Get access token using preferred method
$accessToken = $null

if ($UseAzureCLI) {
    Write-Host "Using Azure CLI authentication method..." -ForegroundColor Cyan
    $accessToken = Get-AccessTokenFromAzureCLI
}
else {
    Write-Host "Using device code flow authentication method..." -ForegroundColor Cyan
    $accessToken = Get-AccessTokenDeviceCode -TenantId $TenantId -OfflineAccess $OfflineAccess
}

if (-not $accessToken) {
    Write-Host "Failed to obtain access token. Exiting." -ForegroundColor Red
    Write-Host ""
    Write-Host "Available authentication methods:" -ForegroundColor Yellow
    Write-Host "1. Device code flow (default): .\Get-Windows365Alerts.ps1" -ForegroundColor White
    Write-Host "2. Azure CLI: .\Get-Windows365Alerts.ps1 -UseAzureCLI" -ForegroundColor White
    Write-Host ""
    Write-Host "For Azure CLI method, ensure you're logged in: az login" -ForegroundColor Gray
    exit 1
}

Write-Host "Authentication successful!" -ForegroundColor Green
Write-Host ""

# Get alerts using REST API
$alertsResponse = Get-Windows365Alerts -AccessToken $accessToken

# Get inaccessible Cloud PC reports using REST API
$inaccessibleReportsResponse = Get-InaccessibleCloudPCReports -AccessToken $accessToken

# Process and display results
if ($alertsResponse -or $inaccessibleReportsResponse) {
    if ($OutputPath) {
        # Save combined JSON to file if requested
        try {
            $combinedOutput = @{
                "alerts" = $alertsResponse
                "inaccessibleCloudPCs" = $inaccessibleReportsResponse
                "retrievedAt" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $jsonOutput = $combinedOutput | ConvertTo-Json -Depth 10
            $jsonOutput | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Combined JSON response saved to: $OutputPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to save output to file: $($_.Exception.Message)"
        }
    }
    
    # Display alerts table
    if ($alertsResponse -and $alertsResponse.value -and $alertsResponse.value.Count -gt 0) {
        Write-Host "`n=== Windows 365 Alerts Table ===" -ForegroundColor Magenta
        Write-Host "Total Alerts Found: $($alertsResponse.value.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        # Create table with key alert information
        $alertTable = $alertsResponse.value | Select-Object @{
            Name = 'Alert Type'
            Expression = { 
                if ($_.alertRuleTemplate.displayName) { 
                    $_.alertRuleTemplate.displayName 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Status'
            Expression = { 
                if ($_.status) { 
                    $_.status 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Severity'
            Expression = { 
                if ($_.alertRuleTemplate.severity) { 
                    $_.alertRuleTemplate.severity 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Detected Date'
            Expression = { 
                if ($_.detectedDateTime) { 
                    try {
                        [DateTime]::Parse($_.detectedDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                    } catch {
                        $_.detectedDateTime
                    }
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Resolved Date'
            Expression = { 
                if ($_.resolvedDateTime) { 
                    try {
                        [DateTime]::Parse($_.resolvedDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                    } catch {
                        $_.resolvedDateTime
                    }
                } else { 
                    'Not Resolved' 
                }
            }
        }, @{
            Name = 'Alert ID'
            Expression = { 
                if ($_.id) { 
                    $_.id
                } else { 
                    'Unknown' 
                }
            }
        }
        
        # Display the alerts table with full column widths
        $alertTable | Format-Table -Property * -AutoSize -Wrap
    }
    else {
        Write-Host "`n=== No Alerts Found ===" -ForegroundColor Yellow
        Write-Host "No Windows 365 alerts were found in your tenant." -ForegroundColor White
    }
    
    # Display inaccessible Cloud PC reports table
    if ($inaccessibleReportsResponse -and $inaccessibleReportsResponse.value -and $inaccessibleReportsResponse.value.Count -gt 0) {
        Write-Host "`n=== Inaccessible Cloud PC Reports ===" -ForegroundColor Magenta
        Write-Host "Total Inaccessible Cloud PCs: $($inaccessibleReportsResponse.value.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        # Create table with key Cloud PC information
        $cloudPcTable = $inaccessibleReportsResponse.value | Select-Object @{
            Name = 'Cloud PC Name'
            Expression = { 
                if ($_.cloudPcName) { 
                    $_.cloudPcName 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'User'
            Expression = { 
                if ($_.userPrincipalName) { 
                    $_.userPrincipalName 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Provisioning Status'
            Expression = { 
                if ($_.provisioningStatus) { 
                    $_.provisioningStatus 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Device Health'
            Expression = { 
                if ($_.deviceHealthStatus) { 
                    $_.deviceHealthStatus 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'System Status'
            Expression = { 
                if ($_.systemStatus) { 
                    $_.systemStatus 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Region'
            Expression = { 
                if ($_.region) { 
                    $_.region 
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Last Connection Failure'
            Expression = { 
                if ($_.lastConnectionFailureDatetime) { 
                    try {
                        [DateTime]::Parse($_.lastConnectionFailureDatetime).ToString("yyyy-MM-dd HH:mm:ss")
                    } catch {
                        $_.lastConnectionFailureDatetime
                    }
                } else { 
                    'Unknown' 
                }
            }
        }, @{
            Name = 'Cloud PC ID'
            Expression = { 
                if ($_.cloudPcId) { 
                    $_.cloudPcId
                } else { 
                    'Unknown' 
                }
            }
        }
        
        # Display the Cloud PC table with full column widths
        $cloudPcTable | Format-Table -Property * -AutoSize -Wrap
    }
    else {
        Write-Host "`n=== No Inaccessible Cloud PCs Found ===" -ForegroundColor Yellow
        Write-Host "No inaccessible Cloud PCs were found in your tenant." -ForegroundColor White
    }
    
    # Display combined summary statistics
    if ($alertsResponse -and $alertsResponse.value -and $alertsResponse.value.Count -gt 0) {
        Write-Host "`n=== Alert Summary Statistics ===" -ForegroundColor Magenta
        
        # Status summary
        $statusSummary = $alertsResponse.value | Group-Object -Property status | Sort-Object Count -Descending
        if ($statusSummary) {
            Write-Host "`nAlerts by Status:" -ForegroundColor Cyan
            $statusSummary | ForEach-Object {
                $status = if ($_.Name) { $_.Name } else { "Unknown" }
                Write-Host "  $status`: $($_.Count)" -ForegroundColor White
            }
        }
        
        # Severity summary
        $severitySummary = $alertsResponse.value | Group-Object -Property { $_.alertRuleTemplate.severity } | Sort-Object Count -Descending
        if ($severitySummary) {
            Write-Host "`nAlerts by Severity:" -ForegroundColor Cyan
            $severitySummary | ForEach-Object {
                $severity = if ($_.Name) { $_.Name } else { "Unknown" }
                Write-Host "  $severity`: $($_.Count)" -ForegroundColor White
            }
        }
        
        # Alert type summary
        $alertTypes = $alertsResponse.value | Group-Object -Property { $_.alertRuleTemplate.displayName } | Sort-Object Count -Descending
        if ($alertTypes) {
            Write-Host "`nAlerts by Type:" -ForegroundColor Cyan
            $alertTypes | ForEach-Object {
                $alertType = if ($_.Name) { $_.Name } else { "Unknown" }
                Write-Host "  $alertType`: $($_.Count)" -ForegroundColor White
            }
        }
        
        # Recent alerts (last 5)
        $recentAlerts = $alertsResponse.value | Where-Object { $_.detectedDateTime } | Sort-Object detectedDateTime -Descending | Select-Object -First 5
        if ($recentAlerts) {
            Write-Host "`nMost Recent Alerts:" -ForegroundColor Cyan
            $recentAlerts | ForEach-Object {
                $alertType = if ($_.alertRuleTemplate.displayName) { $_.alertRuleTemplate.displayName } else { "Unknown Alert" }
                $status = if ($_.status) { $_.status } else { "Unknown Status" }
                $detectedDate = if ($_.detectedDateTime) { 
                    try {
                        [DateTime]::Parse($_.detectedDateTime).ToString("yyyy-MM-dd HH:mm")
                    } catch {
                        $_.detectedDateTime
                    }
                } else { "Unknown Date" }
                
                Write-Host "  [$detectedDate] $alertType - $status" -ForegroundColor White
            }
        }
    }
    
    # Display Cloud PC summary statistics
    if ($inaccessibleReportsResponse -and $inaccessibleReportsResponse.value -and $inaccessibleReportsResponse.value.Count -gt 0) {
        Write-Host "`n=== Cloud PC Summary Statistics ===" -ForegroundColor Magenta
        
        # Provisioning status summary
        $provisioningSummary = $inaccessibleReportsResponse.value | Group-Object -Property provisioningStatus | Sort-Object Count -Descending
        if ($provisioningSummary) {
            Write-Host "`nCloud PCs by Provisioning Status:" -ForegroundColor Cyan
            $provisioningSummary | ForEach-Object {
                $status = if ($_.Name) { $_.Name } else { "Unknown" }
                Write-Host "  $status`: $($_.Count)" -ForegroundColor White
            }
        }
        
        # Device health summary
        $healthSummary = $inaccessibleReportsResponse.value | Group-Object -Property deviceHealthStatus | Sort-Object Count -Descending
        if ($healthSummary) {
            Write-Host "`nCloud PCs by Device Health:" -ForegroundColor Cyan
            $healthSummary | ForEach-Object {
                $health = if ($_.Name) { $_.Name } else { "Unknown" }
                Write-Host "  $health`: $($_.Count)" -ForegroundColor White
            }
        }
        
        # Region summary
        $regionSummary = $inaccessibleReportsResponse.value | Group-Object -Property region | Sort-Object Count -Descending
        if ($regionSummary) {
            Write-Host "`nCloud PCs by Region:" -ForegroundColor Cyan
            $regionSummary | ForEach-Object {
                $region = if ($_.Name) { $_.Name } else { "Unknown" }
                Write-Host "  $region`: $($_.Count)" -ForegroundColor White
            }
        }
    }
}
else {
    Write-Host "No data retrieved from either API or an error occurred." -ForegroundColor Red
    exit 1
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green
