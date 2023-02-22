$CertIssuer = "Pirelli"
$ServiceUri = "https://pirellioutestlg.azurewebsites.net/api/RequestMove"

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

$c = gci cert:\currentuser\My | ?{ $_.Issuer -match $CertIssuer } | select -First 1

$payload

#Invoke-RestMethod -Certificate $c -Method POST -Uri $ServiceUri -Body ($payload|ConvertTo-Json) -ContentType "application/json"
