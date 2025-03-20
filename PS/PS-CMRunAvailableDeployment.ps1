param (
    [string]$LogLevel = "Verbose",  # Options: Error, Warning, Info, Debug, Verbose
    [ValidateSet("Application","Package")]
    [string]$DeploymentType = "Application",
    [string]$scopeID ,
    [string]$appId,
    [string]$packageID,
    [ValidateSet("Install", "Uninstall")]
    [string]$Action = "Install"
    
)

# Validate that $scopeID and $appId are provided when $DeploymentType is "Application"
if ($DeploymentType -eq "Application" -and (-not $scopeID -and -not $appId)) {
    Write-Error "Both 'scopeID' and 'appId' parameters are required when 'DeploymentType' is 'Application'."
    exit
}

# Validate that $packageID is provided when $DeploymentType is "Package"
if ($DeploymentType -eq "Package" -and -not $packageID) {
    Write-Error "'packageID' parameter is required when 'DeploymentType' is 'Package'."
    exit
}

# Adjust preference variables based on log level
switch ($LogLevel.ToLower()) {
    "error"   { $ErrorActionPreference = "Continue"; $WarningPreference = "SilentlyContinue"; $InformationPreference = "SilentlyContinue"; $DebugPreference = "SilentlyContinue"; $VerbosePreference = "SilentlyContinue" }
    "warning" { $ErrorActionPreference = "Continue"; $WarningPreference = "Continue"; $InformationPreference = "SilentlyContinue"; $DebugPreference = "SilentlyContinue"; $VerbosePreference = "SilentlyContinue" }
    "info"    { $ErrorActionPreference = "Continue"; $WarningPreference = "Continue"; $InformationPreference = "Continue"; $DebugPreference = "SilentlyContinue"; $VerbosePreference = "SilentlyContinue" }
    "debug"   { $ErrorActionPreference = "Continue"; $WarningPreference = "Continue"; $InformationPreference = "Continue"; $DebugPreference = "Continue"; $VerbosePreference = "SilentlyContinue" }
    "verbose" { $ErrorActionPreference = "Continue"; $WarningPreference = "Continue"; $InformationPreference = "Continue"; $DebugPreference = "Continue"; $VerbosePreference = "Continue" }
    default   { Write-Error "Invalid LogLevel specified. Use Error, Warning, Info, Debug, or Verbose." }
}

# Define the namespace and class
$namespace = "root\ccm\clientSDK"

if ($DeploymentType -eq "Package") {

    Write-Information "Installing Package with ID: $packageID"

    $class = "CCM_Program"
    $id = $packageID
} else {

    Write-Information "Installing Application with ID: $appId"

    $class = "CCM_Application"
    $id = "$scopeID/$appId"
}


# Connect to the WMI namespace
Write-Debug "Connecting to WMI namespace $namespace and class $class"
$wmiConnection = Get-WmiObject -Namespace $namespace -Class $class
Write-Verbose "Connected to WMI namespace $namespace and class $class"

# determine the reboot pending status
Write-Debug "Checking if a reboot is pending on the client machine..."
$clientRebootState = Invoke-CimMethod -Namespace $namespace -ClassName CCM_ClientUtilities -MethodName 'DetermineIfRebootPending'
if ($clientRebootState.RebootPending) {
    Write-Warning "Reboot is pending on the client machine"
}
Write-Debug "No reboot is pending on the client machine."

# Invoke SCCM Client Machine Policy Retrieval & Evaluation Cycle asynchronously
Write-Debug "Starting machine policy retrieval job..."
$policyJob = Start-Job -ScriptBlock {
    Invoke-CimMethod -Namespace $namespace -ClassName CCM_ClientUtilities -MethodName 'GetMachinePolicy'
}

# Wait for the policy retrieval job to complete
Wait-Job -Job $policyJob

# Check if the policy retrieval job completed successfully
if ($policyJob.State -eq 'Completed') {
    Write-Debug "Machine policy retrieval completed successfully."
} else {
    Write-Error "Machine policy retrieval failed. Please check the SCCM client logs for more information."
    exit
}

if ($DeploymentType -eq "Application") {

    # Query for available Application deployments
    $deployments = Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class"

    # Display the results
    foreach ($deployment in $deployments) {
        Write-Debug "-----------------------------------"
        Write-Debug "Id: $($deployment.Id)"
        Write-Debug "RunspaceId: $($deployment.RunspaceId)" 
        Write-Debug "Deployment Name: $($deployment.Name)"
        Write-Debug "Full Name: $($deployment.FullName)"
        Write-Debug "Name: $($deployment.Name)"

        if ($deployment.IsMachineTarget) {
            Write-Debug "Target: Machine"
        } else {
            Write-Debug "Target: User"
        }
        if ($deployment.IsEnforcementEnabled) {
            Write-Debug "Enforcement: Enabled"
        } else {
            Write-Debug "Enforcement: Disabled"
        }

        if ($deployment.IsSupersedence) {
            Write-Debug "Supersedence: Enabled"
        } else {
            Write-Debug "Supersedence: Disabled"
        }

        if ($deployment.InstallState) {
            Write-Debug "Installed" 
        } else {
            Write-Debug "NOT Installed"
        }

        Write-Debug "-----------------------------------"
    }

} elseif ($DeploymentType -eq "Package") {

    # Query for available Package deployments
    $packages = Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class"

    # Display the results
    foreach ($package in $packages) {
        Write-Debug "-----------------------------------"
        Write-Debug "Package ID: $($package.PackageID)"
        Write-Debug "Program ID: $($package.ProgramID)"
        Write-Debug "Package Name: $($package.PackageName)"
        Write-Debug "Program Name: $($package.ProgramName)"
        Write-Debug "-----------------------------------"
    }
}


# Check for desired Application deployment

if ($DeploymentType -eq "Application") {
    $deployment = Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE Id = '$id'"
    if ($deployment) {
        Write-Information "Found deployment for Application ID $id"
        
        $Args = @{EnforcePreference = [UINT32] 0
            Id = "$($deployment.id)"
            IsMachineTarget = $deployment.IsMachineTarget
            IsRebootIfNeeded = $False
            Priority = 'High'
            Revision = "$($deployment.Revision)"
        }       
        
        Write-Debug "Installing Application..."

        Invoke-CimMethod -Namespace "root\ccm\clientSDK" -ClassName CCM_Application -MethodName 'Install' -Arguments $Args

        $installStatus = (Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE Id = '$id'").InstallState    
        while ($installStatus -ne 'Installed' ) {
            Write-Debug "Package installation in progress..."
            Start-Sleep -Milliseconds 2000
            $installStatus = (Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE Id = '$id'").InstallState
                
            Write-Debug "Application installation status: $installStatus"
        }

        #check the installation status
        $installStatus = (Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE Id = '$id'").InstallState
        if ($installStatus -eq 'Installed') {
            Write-Information "Application installed successfully."
        } else {
            Write-Error "Application installation failed. Please check the SCCM client logs for more information."
        }
    } 
    } elseif ($DeploymentType -eq "Package") {
        $package = Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE PackageID = '$id'"
        if ($package) {
            Write-Information "Found deployment for package ID $id"
            Write-Information "Package Name: $($package.PackageName)"
            Write-Information "Package ID: $($package.PackageID)"
            Write-Information "Program ID: $($package.PackageID)"
            
            Write-Debug "Installing package..."

            $Args = @{
                PackageID = $package.PackageID
                ProgramID = $package.ProgramID
             }   

            Invoke-CimMethod -Namespace "root\ccm\clientSDK" -ClassName 'CCM_ProgramsManager' -Name 'ExecuteProgram' -Arguments $Args

            $installStatus = (Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE PackageID = '$id'").LastRunStatus
            while ($installStatus -ne 'Succeeded' ) { # LastRunStatus have to written 'Succeeded' is with double ee
                Write-Debug "Package installation in progress..."
                Start-Sleep -Milliseconds 2000
                $installStatus = (Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE PackageID = '$id'").LastRunStatus
                    
                Write-Debug "Package installation Status: $installStatus"
            }

            #Check the Package Installation status
            $installStatus = (Get-WmiObject -Namespace $namespace -Query "SELECT * FROM $class WHERE PackageID = '$id'").LastRunStatus
            if ($installStatus -eq 'Succeeded') { # LastRunStatus have to written 'Succeeded' is with double ee
                Write-Information "Package installed successfully."
            } else {
                Write-Error "Package installation failed. Please check the SCCM client logs for more information."
            }
        } else {
            Write-Error "No deployment found for package ID $id"
        }
    }
    
# Disconnect from the WMI namespace
$wmiConnection = $null
Write-Debug "Disconnected from WMI namespace $namespace and class $class" 


