

# Define the path to your user file
$userFilePath = "C:\Temp\AADUsers.txt"
$collectionID = ''

# Check if the file exists
if (Test-Path $userFilePath) {
    # Read the user file line by line
    $upnList = Get-Content $userFilePath

    # Iterate through each UPN in the list
    foreach ($upn in $upnList) {
        # Use Get-AdUser to retrieve the SAMAccountName
        $user = Get-AdUser -Filter {UserPrincipalName -eq $upn}

        # Check if the user was found
        if ($user -ne $null) {
            $samAccountName = $user.SamAccountName
            Write-Host "SAM Account Name for $upn is $samAccountName"

            $domain = $user.DistinguishedName.Split(',') | Where-Object { $_ -like 'DC=*' } | ForEach-Object { $_ -replace 'DC=', '' }

            if ($domain[0] -eq 'MSINTUNE')
            {   
                $domain = 'MSINTUNE'
            }
            else {
                $domain = 'IT'
            }

            $cmuser = Get-CMUser -Name "$($domain)\$($user)" -CollectionId SMS00002

            if ($cmuser -ne $null){
                Add-CMUserCollectionIncludeMembershipRule -CollectionId $collectionID -ResourceID $cmuser.ResourceID
            } else{
                Write-Host "CM User with UPN $upn is not found in ConfigMgr."
            }


        } else {
            Write-Host "User with UPN $upn not found in AD."
        }
    }
} else {
    Write-Host "User file not found at $userFilePath."
}


