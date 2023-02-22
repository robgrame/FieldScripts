$CertIssuer = "Pirelli Enterprise CA"
$ServiceUri = "https://pirellioutestlg.azurewebsites.net/api/RequestMove"
$EventSource = "WXI-MoveOU"

function Get-AADRegistrationInfo
{
    $cs = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class DsregcmdResult
{
    public Guid DeviceId { get; set; }
    public Guid TenantId { get; set; }
    public string JoinUserEmail { get; set; }
    public string TenantDisplayName { get; set; }
    public UserResult UserInfo { get; set; }
}

public class UserResult
{
    public string UserEmail { get; set; }
    public Guid UserKeyId { get; set; }
    public string UserKeyname { get; set; }
}

public static class Dsregcmd
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DSREG_JOIN_INFO
    {
        public int joinType;
        public IntPtr pJoinCertificate;
        [MarshalAs(UnmanagedType.LPWStr)] public string DeviceId;
        [MarshalAs(UnmanagedType.LPWStr)] public string IdpDomain;
        [MarshalAs(UnmanagedType.LPWStr)] public string TenantId;
        [MarshalAs(UnmanagedType.LPWStr)] public string JoinUserEmail;
        [MarshalAs(UnmanagedType.LPWStr)] public string TenantDisplayName;
        [MarshalAs(UnmanagedType.LPWStr)] public string MdmEnrollmentUrl;
        [MarshalAs(UnmanagedType.LPWStr)] public string MdmTermsOfUseUrl;
        [MarshalAs(UnmanagedType.LPWStr)] public string MdmComplianceUrl;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserSettingSyncUrl;
        public IntPtr pUserInfo;
    }

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern void NetFreeAadJoinInformation(IntPtr pJoinInfo);

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetGetAadJoinInformation(string pcszTenantId, out IntPtr ppJoinInfo);
    
    public static DsregcmdResult GetInfo()
    {
        IntPtr ptrJoinInfo;
        Guid did, tid;
        var result = new DsregcmdResult();
        string tenantId = null;
        int retValue = NetGetAadJoinInformation(tenantId, out ptrJoinInfo);
        if (retValue != 0) return null;
        var joinInfo = Marshal.PtrToStructure<DSREG_JOIN_INFO>(ptrJoinInfo);
        Guid.TryParse(joinInfo.DeviceId, out did);
        result.DeviceId = did;
        Guid.TryParse(joinInfo.TenantId, out tid);
        result.TenantId = tid;
        result.JoinUserEmail = joinInfo.JoinUserEmail;
        result.TenantDisplayName = joinInfo.TenantDisplayName;
        NetFreeAadJoinInformation(ptrJoinInfo);

        return result;
    }
}
'@

    Add-Type -TypeDefinition $cs
    [Dsregcmd]::GetInfo()
}

$global:EventLogErrorAlreadyNotified = $false

function Write-LogMessage
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [int]$EventId,
        [Diagnostics.EventLogEntryType]$Level = [Diagnostics.EventLogEntryType]::Information,
        [switch]$NoHost
    )

    if (-not $NoHost) {
        Write-Host "[MoveOU] $Message"
    }

    try {
        Write-EventLog -LogName "Application" -Source $EventSource -EntryType $Level -Message $Message -EventId $EventId
    } catch {
        if (-not $global:EventLogErrorAlreadyNotified) {
            Write-Error "[MoveOU] Error writing to event log: $($_.Exception.Message)"
            $global:EventLogErrorAlreadyNotified = $true
        }
    }
}

Write-LogMessage -Message "Script execution started." -EventId 1

try {
    $ri = Get-AADRegistrationInfo

    $payload = @{
        UserName = $Env:USERNAME
        DomainName = $Env:USERDOMAIN
        UPN = (whoami /upn)
        TenantId = $ri.TenantId
        JoinUserEmail = $ri.JoinUserEmail
        ComputerAADId = $ri.DeviceId
        ComputerName = $Env:COMPUTERNAME
        ComputerSerialNumber = (Get-CimInstance -Class Win32_BIOS).SerialNumber
        OSVersion = (Get-CimInstance -Class Win32_OperatingSystem).Version
        OSDisplayVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
    }

    $payload

    $c = gci cert:\currentuser\My | ?{ $_.Issuer -match $CertIssuer } | select -First 1

    Write-LogMessage -Message "Using client certificate with thumbprint '$($c.Thumbprint)' issued by '$($c.Issuer)' to '$($c.Subject)'" -EventId 5
    Write-LogMessage -Message "Sending request to $ServiceUri :`r`n$($payload|ConvertTo-Json)" -EventId 3

    #$result = Invoke-RestMethod -Certificate $c -Method POST -Uri $ServiceUri -Body ($payload|ConvertTo-Json) -ContentType "application/json"

    Write-LogMessage -Message "Request sent. Result:`r`n$($result|ConvertTo-Json)" -EventId 4

} catch {
    Write-Error $_ 
    Write-Error "Exception: $($_.Exception.Message)"

    Write-LogMessage -NoHost -Message "$_`r`nException: $($_.Exception.Message)" -EventId 100 -Level [DiagnostEventLogEntryType]::Error
}

Write-LogMessage -Message "Script execution ended." -EventId 2
