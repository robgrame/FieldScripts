<#
.Synopsis
  The purpose of this script is to change the download settings of the Applications, Packages and Software Update Deployments in order to allow clients connected via VPN making   use of CMG to leverage internet dowloads
.DESCRIPTION

.EXAMPLE
    The script dows not require any parameters
   Set-CMDeploymentsFallbackBehaviour.ps1
.REQUIREMENTS

   ConfigMgr-Console must be installed
   ConfigMgr-Drive must be loaded

.NOTES
    FileName:    Set-CMDeploymentsFallbackBehaviour.ps1
    Author:      Roberto Gramellini MSFT
    Contact:     @robgrame
    Created:     2021-12-14
    Updated:     2021-12-14
    Version history:
    1.0.0 - (2021-12.-14) Script created
#>

#Load Configuration Manager PowerShell Module
Import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5)+ '\ConfigurationManager.psd1')

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-location $SiteCode":"

#Error Handling and output
Clear-Host
$ErrorActionPreference= 'SilentlyContinue'


Function Set-CMApplicationsDownloadFallback{

    Begin{
        Write-Host
        Write-Host -ForegroundColor White ("Processing APPLICATIONS")
        $apps = Get-CMApplication 

    }
    
    process{



        foreach ($app in $apps) {

            #[XML]$appXML = $app.SDMPackageXML
            #$appName = $appXML.AppMgmtDigest.Application.Title.InnerText
            Write-Host -ForegroundColor Yellow ("Verifying application: " + $app.LocalizedDisplayName + "")

            $dts = Get-CMDeploymentType -ApplicationName $app.LocalizedDisplayName #| Select-Object LocalizedDisplayName

            foreach ($dt in $dts) {
                #[XML]$appDTXML = $dt.SDMPackageXML
                #$appDTXMLType= $appDTXML.AppMgmtDigest.DeploymentType
                $appDTName = $dt.LocalizedDisplayName
                $dtTech = $dt.Technology
                Write-Host  
                Write-Host -ForegroundColor White ("Evaluating deployment type: " + $dt.LocalizedDisplayName + " with Technology: " + $dt.Technology)

                try {

                    if ($dt.Technology -eq "MSI" ){
                        Set-CMMsiDeploymentType -ApplicationName $app.LocalizedDisplayName -DeploymentTypeName $dt.LocalizedDisplayName -SlowNetworkDeploymentMode Download
                        Write-Host -ForegroundColor Green ("Application " + $app.LocalizedDisplayName + " Deployment Type " + $dt.LocalizedDisplayName + " updated to Download")
                    }
                    elseif ($dt.Technology -eq "Script") {
                        Set-CMScriptDeploymentType -ApplicationName $app.LocalizedDisplayName -DeploymentTypeName $dt.LocalizedDisplayName -SlowNetworkDeploymentMode Download
                        Write-Host -ForegroundColor Green ("Application " + $app.LocalizedDisplayName + " Deployment Type " + $dt.LocalizedDisplayName + " updated to Download")
                    }
                    else {
                        Write-Host -ForegroundColor Red ("Application " + $app.LocalizedDisplayName + " Deployment Type " + $dt.LocalizedDisplayName + " does not support Content Fallback setting.")
                    }
                    
                }
                catch {
                    Write-Host -ForegroundColor Red ("Unable to update Application " + $pkg.Name + " to download fallback. Exception: " + $Error[0])
                    
                }
                

            }
        }
    }

    end{
        Write-Host
        Write-Host -ForegroundColor Green ("PROCESSING APPLICATIONS COMPLETED")
    }
}


function Set-CMPackageDownloadFallback {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        Write-Host
        Write-Host -ForegroundColor White ("Processing PACKAGES")


        $pkgs = Get-CMPackage
        
    }
    
    process {

        foreach ($pkg in $pkgs){

            $pkgDeployment = Get-CMPackageDeployment -PackageId $pkg.PackageId
            if ($pkgDeployment -ne $null){
                Write-Host  
                Write-Host -ForegroundColor White ("Evaluating pakcage: " + $pkg.Name)
                try {
                    Write-Host -ForegroundColor White ("Updating package " + $pkg.Name + " to download fallback")
                    Set-CMPackageDeployment -PackageName $pkg.Name -CollectionId $pkgDeployment.CollectionID -StandardProgramName $pkgDeployment.ProgramName -SlowNetworkOption DownloadContentFromDistributionPointAndLocally
                    Write-Host -ForegroundColor Green ("Updated package " + $pkg.Name + " to download fallback")
                }
                catch {
                    
                    Write-Host -ForegroundColor Red ("Unable to update package " + $pkg.Name + " to download fallback. Exception: " + $Error[0])
                }

            }

        }
        
    }
    
    end {
        Write-Host     
        Write-Host -ForegroundColor Green ("PROCESSING PACKAGES COMPLETED")
        
    }
}


function Set-CMSoftwareUpdateDownloadFallback {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        Write-Host
        Write-Host -ForegroundColor White ("Processing SOFTWARE UPDATE DEPLOYMENTS")

        $SUDeployments = Get-CMSoftwareUpdateDeployment
        
        
    }
    
    process {

        foreach($SUDep in $SUDeployments){
            Write-Host
            Write-Host -ForegroundColor White ("Evaluating Software Update Group: " + $SUDep.AssignmentName)

            try {
                Write-Host -ForegroundColor Yellow ("Updating Software Update Deployment " + $SUDep.AssignmentName)
                Set-CMSoftwareUpdateDeployment -inputObject $SUDep -ProtectedType NoInstall -UnprotectedType NoInstall -DownloadFromMicrosoftUpdate $true
                Write-Host -ForegroundColor Green ("Updated Software Update Deployment " + $SUDep.AssignmentName)
            }
            catch {
                Write-Host -ForegroundColor Red ("Unable to update Software Update Deployment " + $SUDep.AssignmentName + " to download fallback. Exception: " + $Error[0])
                
            }


 
        }



        
    }
    
    end {
        Write-Host     
        Write-Host -ForegroundColor Green ("PROCESSING SOFTWARE UPDATE DEPLOYMENTS COMPLETED")
        
    }
}


Set-CMApplicationsDownloadFallback
Set-CMPackageDownloadFallback
Set-CMSoftwareUpdateDownloadFallback
