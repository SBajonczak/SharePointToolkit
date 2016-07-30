# Get all Webs on all Sitecollection on all Webapplications and writ it into a file
Get-SPWebApplication http://sharepointServer| Get-SPSite -Limit All | Get-SPWeb -Limit All | Select Title, URL, ID, ParentWebID | Export-CSV C:\Allwebs.csv -NoTypeInformation
# Load the Data into a variable
$webs = Import-Csv C:\AllWebs.csv
###
# The GroupMapping.csv contains the existing Mapping and has the following format:
# Name, User 
# Name = The Group Name
# User = The user that is assigned to this group
###
$importedGroupDefinition  = import-csv C:\GroupMapping.csv  -Delimiter ';' 
# MissingGroupInMapping.txt contains the Groups in SharePoint that has no mapping defined in the GroupMapping.csv
"Domain; Name; URL" >> "c:\MissingGroupInMapping.txt"

# Iterate each found web
foreach ($webEntry in $webs){
   $web = Get-SPWeb  $webEntry.Url
   # Check if an Assignment exists
   if ($web.HasUniqueRoleAssignments -eq $true){

	# Now Get the group
       $adGroups = $web.Users| where { $_.IsDomainGroup -eq $true }
       if ($adGroups.Length -gt 0){
           # There exists a ad group
           $webEntry.Url >> "c:\log.txt"
           # Iterate ewach group
           foreach($adGroup in $adGroups){
               # Do some convertions
               $output = $adGroup.Name.split('\')[0]+";" + $adGroup.Name.split('\')[1] + ";" + $web.Url
               $groupName = $adGroup.Name;
               if ($adGroup.Name.Contains('\')){
                    $groupName =  $adGroup.Name.split('\')[1];
               }

               # Check if Group exists in Excel
               $users = $importedGroupDefinition | where {$_.Name.ToLower() -eq $groupName.ToLower()}
               if ($users.Length -eq 0){ 
					## Group not exists
					write-host  $output
					$output >> "C:\MissingGroupInMapping.txt"  
               }
               else
               {
                write-host $web.Url
                #Match found no do the following
                # 1. Create new Group (if not exists)
                # 2. Assign Permssion Role to the Group
                # 3. Assign the Users to this group)
                
                # Do Step #1 

                $newGroupName= "SP-" + $groupName
                try{
                    write-host "Try to get SP Group " + $newGroupName
                    $group=$web.SiteGroups[$newGroupName]
                    if ($group -eq $null){
                        write-host "Create new SP Group " + $newGroupName
                        $user =Get-SPUser -Identity "de\butterch" -Web $web
                        $group=$web.SiteGroups.Add($newGroupName,$user,$user,"Replacement for the AD-Groups") 
                        $group=$web.SiteGroups[$newGroupName] 
                    } 
                }
                catch{
                
                    
                }
                
                $users = $importedGroupDefinition | where {$_.Name -match $groupName} | select User
                if ($users.Length -eq 0)
                {
                    $missingUser= "Missing User for Group: " + $groupName
                    $missingUser >> "c:\missingUsers.txt"
                }
                else
                {
                    foreach($user in $users){
                        if (!($user -eq $null)){
                            try{
                                $wUser= $web.EnsureUser($user.User)
                                $group.AddUser($wUser)
                                write-host "      Added user to group"  + $user.User
                            }
                            catch{
                            
                            }
                        }
                    }
                }
                
                # Do Step #2
                # Reg existing Permission to web
                $RoleAssignments = $web.RoleAssignments | where { $_.Member.GetType().Name.ToString() -eq "SPUser" -and  $_.Member -like "*"+ $groupName.ToLower() -or $_.Member.DisplayName -like $groupName.ToLower() }
                if (!($RoleAssignments -eq $null))
			     {
                    foreach($assignment in $RoleAssignments){
                        foreach($roledefBinding in $assignment.RoleDefinitionBindings){
        
                            if (!($roledefBinding.Name -eq "Beschränkter Zugriff")){
                                Write-host "     Assign web permission " + $roleDefBinding.Name
                                $roleAssignment=New-Object Microsoft.SharePoint.SPRoleAssignment($group) 
                                $roleDefinition=$web.RoleDefinitions[$roledefBinding.Name] 
                                $roleAssignment.RoleDefinitionBindings.Add($roleDefinition) 
                                $web.RoleAssignments.Add($roleAssignment); 
                            }
                            else
                            {
                                Write-host "Beschränkter Zugriff wird im Nachgang korrigiert"
                            }
                        }
                    }
                }
                #exit
                # to Each list
                foreach ($list in $web.Lists){
                    if ($list.HasUniqueRoleAssignments){

                        $lolderRoleAssignments = $list.RoleAssignments | where { $_.Member.GetType().Name.ToString() -eq "SPUser" -and  $_.Member -like "*"+ $groupName.ToLower() -or $_.Member.DisplayName -like $groupName.ToLower() }
                        if (!($lolderRoleAssignments -eq $null))
					    {
                            
                            foreach($lassignment in $lolderRoleAssignments){
                                foreach($lroledefBinding in $lassignment.RoleDefinitionBindings){
                                    if (!($lroledefBinding.Name -eq "Beschränkter Zugriff") -and !($lroledefBinding.Name -eq "")){
                                    write-host "List" + $list.Title
                                    write-host "      Assign list Permission" $froledefBinding.Name;
                                    $lroleAssignment=New-Object Microsoft.SharePoint.SPRoleAssignment($group) 
                                    $lroleDefinition=$web.RoleDefinitions[$lroledefBinding.Name] 
                                    $lroleAssignment.RoleDefinitionBindings.Add($lroleDefinition) 
                                    $list.RoleAssignments.Add($lroleAssignment); 
                                    }
                                }
                            } 
                        }
                    }
                }
                # to each Folder in list 
                foreach ($list in $web.Lists){
                   foreach ($folder in $list.Folders){
                    if ($folder.HasUniqueRoleAssignments){
                        $folderRoleAssignments = $folder.RoleAssignments | where { $_.Member.GetType().Name.ToString() -eq "SPUser" -and  $_.Member -like "*"+ $groupName.ToLower() -or $_.Member.DisplayName -like $groupName.ToLower() }
                        if (!($folderRoleAssignments -eq $null))
						{
                            foreach($fassignment in $folderRoleAssignments){
                                foreach($froledefBinding in $fassignment.RoleDefinitionBindings){
                                    if (!($froledefBinding.Name -eq "") -and !($froledefBinding.Name -eq "Beschränkter Zugriff")){
                                    write-host "Folder " + $folder.Title
                                    write-host "      Assign Folder Permission" $froledefBinding.Name;
                                    $froleAssignment=New-Object Microsoft.SharePoint.SPRoleAssignment($group) 
                                    $froleDefinition=$web.RoleDefinitions[$froledefBinding.Name] 
                                    $froleAssignment.RoleDefinitionBindings.Add($froleDefinition) 
                                    $folder.RoleAssignments.Add($froleAssignment); 
                                    }
                                }
                            } 
                        }
                }

                   }
                }
                
                
                $adGroup.Name >> "c:\log.txt"
                foreach ($user in $users){
                     "          " + $user.USer >> "c:\log.txt"
                }
               }
          }
       }
   }
}



