# Get Windows 365 Alerts from Microsoft Graph API
# This script retrieves alert records from the Device Management monitoring endpoint
# Uses Microsoft Graph PowerShell module to avoid app registration requirements

param(
    [Parameter(HelpMessage = "Output file path for JSON response (optional)")]
    [string]$OutputPath,
    
    [Parameter(HelpMessage = "Tenant ID (optional, will use current tenant if not specified)")]
    [string]$TenantId = "d6dbad84-5922-4700-a049-c7068c37c884",
    
    [Parameter(HelpMessage = "Use alternative authentication method (REST API with device code)")]
    [switch]$UseRestAPI,
    
    [Parameter(HelpMessage = "Request offline access for longer token validity (REST API method only)")]
    [switch]$OfflineAccess
)

# Function to check and install Microsoft Graph PowerShell module
function Install-GraphModule {
    Write-Host "Checking for Microsoft Graph PowerShell module..." -ForegroundColor Yellow
    
    $modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.DeviceManagement")
    
    foreach ($module in $modules) {
        if (!(Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing $module..." -ForegroundColor Yellow
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
                Write-Host "$module installed successfully!" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to install $module`: $($_.Exception.Message)"
                return $false
            }
        }
        else {
            Write-Host "$module is already installed." -ForegroundColor Green
        }
    }
    return $true
}

# Function to connect to Microsoft Graph using PowerShell module
function Connect-ToGraph {
    param(
        [string]$TenantId
    )
    
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    
    try {
        # Import required modules
        Import-Module Microsoft.Graph.Authentication -Force
        Import-Module Microsoft.Graph.DeviceManagement -Force
        
        # Required scopes
        $scopes = @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementManagedDevices.Read.All"
        )
        
        # Connect to Graph
        if ($TenantId -and $TenantId -ne "common") {
            Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
        }
        else {
            Connect-MgGraph -Scopes $scopes -NoWelcome
        }
        
        # Verify connection
        $context = Get-MgContext
        if ($context) {
            Write-Host "Successfully connected to Microsoft Graph!" -ForegroundColor Green
            Write-Host "Tenant: $($context.TenantId)" -ForegroundColor Cyan
            Write-Host "Account: $($context.Account)" -ForegroundColor Cyan
            return $true
        }
        else {
            Write-Error "Failed to establish Graph connection"
            return $false
        }
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return $false
    }
}

# Function to get Windows 365 alerts using Graph PowerShell module
function Get-Windows365AlertsWithModule {
    try {
        Write-Host "Retrieving Windows 365 alerts using Graph PowerShell module..." -ForegroundColor Yellow
        
        # Use Invoke-MgGraphRequest for beta endpoint
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRecords" -Method GET
        
        Write-Host "Successfully retrieved alerts!" -ForegroundColor Green
        Write-Host "Total alerts found: $($response.value.Count)" -ForegroundColor Cyan
        
        return $response
    }
    catch {
        Write-Error "Failed to retrieve alerts: $($_.Exception.Message)"
        
        if ($_.Exception.Message -match "403") {
            Write-Host "Access denied. Please ensure you have the required permissions:" -ForegroundColor Red
            Write-Host "- DeviceManagementConfiguration.Read.All" -ForegroundColor Red
            Write-Host "- DeviceManagementManagedDevices.Read.All" -ForegroundColor Red
        }
        
        return $null
    }
}

# Function to get access token using device code flow (fallback method)
function Get-AccessToken {
    param(
        [string]$TenantId = "d6dbad84-5922-4700-a049-c7068c37c884",
        [string]$ClientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e", # Microsoft Graph PowerShell Client ID
        [bool]$OfflineAccess = $false
    )
    
    Write-Host "Using REST API authentication method..." -ForegroundColor Yellow
    
    # Device code flow endpoint
    $deviceCodeUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode"
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    
    # Required scope for Device Management
    $scope = "https://graph.microsoft.com/CloudPC.Read.All"
    
    # Add offline access if requested (provides refresh token and longer session)
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
                        # Fallback for older PowerShell versions or different error formats
                        try {
                            $errorResponse = $_.Exception.Response.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($errorResponse)
                            $errorContent = $reader.ReadToEnd() | ConvertFrom-Json
                        }
                        catch {
                            # If all else fails, create a basic error object
                            $errorContent = @{ error = "unknown_error"; error_description = "Unable to parse error response" }
                        }
                    }
                    
                    if ($errorContent.error -eq "authorization_pending") {
                        # Continue polling
                        continue
                    }
                    elseif ($errorContent.error -eq "authorization_declined") {
                        throw "Authentication was declined by the user"
                    }
                    elseif ($errorContent.error -eq "expired_token") {
                        Write-Host "`nThe device code has expired. You can:" -ForegroundColor Red
                        Write-Host "1. Run the script again to get a new code" -ForegroundColor Yellow
                        Write-Host "2. Or use the Graph PowerShell module method (run without -UseRestAPI)" -ForegroundColor Yellow
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
        
        Write-Host "`nAuthentication timed out. You can:" -ForegroundColor Red
        Write-Host "1. Run the script again to get a new code" -ForegroundColor Yellow
        Write-Host "2. Or use the Graph PowerShell module method (run without -UseRestAPI)" -ForegroundColor Yellow
        throw "Authentication timed out. Please run the script again."
    }
    catch {
        Write-Error "Failed to get access token: $($_.Exception.Message)"
        return $null
    }
}

# Function to get Windows 365 alerts
function Get-Windows365Alerts {
    param(
        [string]$AccessToken
    )
    
    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
    }
    
    $graphUri = "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRecords"
    
    try {
        Write-Host "Retrieving Windows 365 alerts..." -ForegroundColor Yellow
        
        $response = Invoke-RestMethod -Uri $graphUri -Headers $headers -Method GET
        
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
Write-Host "This script will retrieve Windows 365 alert records from Microsoft Graph API" -ForegroundColor White
Write-Host ""

# Choose authentication method
if ($UseRestAPI) {
    Write-Host "Using REST API authentication method..." -ForegroundColor Cyan
    
    # Get access token
    $accessToken = Get-AccessToken -TenantId $TenantId -OfflineAccess $OfflineAccess

    if (-not $accessToken) {
        Write-Host "Failed to obtain access token. Exiting." -ForegroundColor Red
        exit 1
    }

    Write-Host "Authentication successful!" -ForegroundColor Green
    Write-Host ""

    # Get alerts using REST API
    $alertsResponse = Get-Windows365Alerts -AccessToken $accessToken
}
else {
    Write-Host "Using Microsoft Graph PowerShell module (recommended)..." -ForegroundColor Cyan
    
    # Check and install Graph module if needed
    if (-not (Install-GraphModule)) {
        Write-Host "Failed to install required modules. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Connect to Graph
    if (-not (Connect-ToGraph -TenantId $TenantId)) {
        Write-Host "Failed to connect to Microsoft Graph. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Get alerts using Graph module
    $alertsResponse = Get-Windows365AlertsWithModule
    
    # Disconnect from Graph
    Disconnect-MgGraph | Out-Null
}

if ($alertsResponse) {
    if ($OutputPath) {
        # Save JSON to file if requested
        try {
            $jsonOutput = $alertsResponse | ConvertTo-Json -Depth 10
            $jsonOutput | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "JSON response saved to: $OutputPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to save output to file: $($_.Exception.Message)"
        }
    }
    
    # Display results in table format
    if ($alertsResponse.value -and $alertsResponse.value.Count -gt 0) {
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
                    $_.id.Substring(0, [Math]::Min(8, $_.id.Length)) + "..." 
                } else { 
                    'Unknown' 
                }
            }
        }
        
        # Display the table
        $alertTable | Format-Table -AutoSize -Wrap
        
        # Display summary statistics
        Write-Host "`n=== Summary Statistics ===" -ForegroundColor Magenta
        
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
    else {
        Write-Host "`n=== No Alerts Found ===" -ForegroundColor Yellow
        Write-Host "No Windows 365 alerts were found in your tenant." -ForegroundColor White
        Write-Host "This could mean:" -ForegroundColor Gray
        Write-Host "  - No alerts have been triggered" -ForegroundColor Gray
        Write-Host "  - Alerts may have been resolved and archived" -ForegroundColor Gray
        Write-Host "  - You may not have access to view alerts" -ForegroundColor Gray
    }
}
else {
    Write-Host "No alerts retrieved or an error occurred." -ForegroundColor Red
    exit 1
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green
