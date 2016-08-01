
# Get the Distinguished Name with this filter
$groupNameToFind="myGroup"
$strFilter = "(&(objectCategory=group)(cn="+ $groupNameToFind +"))"

function Get-AdResults($filter){
    $objDomain = New-Object System.DirectoryServices.DirectoryEntry
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $objSearcher.SearchRoot = $objDomain
    $objSearcher.PageSize = 1000
    $objSearcher.Filter = $filter
    write-host "Using filter: "  $objSearcher.Filter
    $objSearcher.SearchScope = "Subtree"
    $colResults = $objSearcher.FindAll()
    return $colResults
}



$results=Get-AdResults($strFilter)

foreach ($objResult in $results)
{
    $distinguishedName = $objResult.Properties["adspath"]
    $members= Get-AdResults("(&(objectCategory=user)(memberOf="+ $distinguishedName+ "))")
    foreach ($member in $members)
    {
    write-host $member
    }
}
    
