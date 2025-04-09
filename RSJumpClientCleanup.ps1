# Begin Log Function defintion
$LogPrefix = "RS_JumpClient_Cleanup_"
$LogDate = (Get-Date).tostring("yyyyMMdd-HHmmss")
$LogFile = $LogPrefix + $LogDate + ".txt"
Function Write-Log {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String]$msg
    )
    Add-Content $LogFile $msg
}
# End Log Function defintion

# Load API connection config from json
$apiJson = ".\auth\rs_api.json"
$apiConfig = Get-Content $apiJson | Convertfrom-Json

#Format ClientID and Secret in documented format for encoding.
$Credential = $apiConfig.ClientID + ":" + $apiConfig.Secret
#Encode credential to Base64 (UTF8, unicode will not work)
$EncodeCred = [Convert]::ToBase64String([System.Text.Encoding]::utf8.GetBytes($Credential))
#Create header and body for token request.
$Header = @{"Authorization" = "Basic $EncodeCred"}
$Body = @{"grant_type" = "client_credentials"}
#Get Auth bearer token
try {
    $AuthToken = Invoke-RestMethod -Method POST -Header $Header -body $Body -uri "$($apiConfig.baseURI)/oauth2/token" -ErrorAction Stop
    $headers= @{authorization= $AuthToken.token_type + ' '+ $AuthToken.access_token}
}
catch {
    Write-Error "ERROR obtaining Authentication Token."
    Write-Error $_
    Exit 1
}

$apiURI = $apiConfig.baseURI + "/api/config/v1/"
$perPg = 100
$pgNo = 1

$Gatherdata = $();
$jcURI = $apiURI + "jump-client?per_page=$($perPg)&current_page=$($pgNo)"
$AllJumpClients = $null;
$AllJumpClients = Invoke-WebRequest -Uri $jcURI -Method 'GET' -Headers $headers -ContentType "application/json"
[String]$totalClients = $AllJumpClients.Headers.'X-BT-Pagination-Total'
$totalClients = [Int]$totalClients
$totalPages = [math]::ceiling($totalClients / $perPg)  #total clients divided by clients-per-page, rounded up

# Processes through each page to fetch ALL jump clients into one object
do {
    try {
        $jcURI = $apiURI + "jump-client?per_page=$($perPg)&current_page=$($pgNo)"
        $AllJumpClients = $null;
        $ProgressPreference = 'SilentlyContinue'
        $AllJumpClients = Invoke-WebRequest -Uri $jcURI -Method 'GET' -Headers $headers -ContentType "application/json" -ErrorAction Stop
        $ProgressPreference = 'Continue'
    }
    catch [Exception] {
        $msg = "Error connecting to $apiURI"
        $e = $_.Exception.Message
        if ($_.Exception.Response) {
            $response = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($response)
            $msg = $reader.ReadToEnd()
        }
        $resp = "{0}\r`n{1}" -f $e, $msg
        Write-Error $resp
        Exit 1
    }
    $Gatherdata += ConvertFrom-Json -InputObject $AllJumpClients.Content.ToString();
    $pgNo++
	if ($totalClients -ge 1) { Write-Progress -Activity "Retrieving Jump Client list from Remote Support API" -Status "Progress:" -PercentComplete (($Gatherdata.Count)/$totalClients*100) }
} while ($pgNo -le $totalPages)

Write-Output "$($Gatherdata.Count) total Jump Clients found."

# convert jump clients object into array list
[System.Collections.ArrayList]$clientList = $Gatherdata
# create arrays for deletion of duplicate clients
[System.Collections.ArrayList]$oldClients = @()
[System.Collections.ArrayList]$dupClients = @()

$i = 0
$ucount = $clientList.Count
foreach ($client in $clientList) {
    $clientMatch = $clientlist | Where-Object {($_.name -eq $client.name) -and ($_.id -ne $client.id)}
    if ($clientMatch.Count -ge 1) {  #if there are duplicate clients for the same computer
        if ($client.needs_update -eq $true) { #if duplicate jump client is "Upgrade Pending"
            $oldClients += $client
        } else {
            # compare last connection of client to all duplicates and add to array for deletion if older
            $lastConnect = (Get-Date $client.last_connect_timestamp)
            [System.Collections.ArrayList]$matchConnect = @()
            foreach ($match in $clientMatch) {
                $matchConnect += (Get-Date $match.last_connect_timestamp)
            }
            # sort all duplicates, find oldest to compare to
            $oldestMatch = ($matchConnect | Sort-Object) | Select-Object -First 1
            if ($lastConnect -lt $oldestMatch) {
                $dupClients += $client
            }
        }
    }
    $i = $i+1
    if ($ucount -ge 1) { Write-Progress -Activity "Building List of duplicate jump clients" -Status "Progress:" -PercentComplete ($i/$ucount*100) }
}
Write-Output "$($oldClients.Count) duplicate out-of-date Jump Clients found."
Write-Output "$($dupClients.Count) other duplicate Jump Clients found."

if ($oldClients.Count -gt 0) {
    $i = 0
    $ucount = $oldClients.Count
    Write-Log "*****OUT OF DATE JUMP CLIENTS*****"
    foreach ($client in $oldClients) { 
        $remURI = $apiURI + "jump-client/$($client.id)"
        try {
            Invoke-WebRequest -Uri $remURI -Method 'DELETE' -Headers $headers -ContentType 'application/json' -ErrorAction Stop | Out-Null
            Write-Log "SUCCESS Removing duplicate jump client $($client.name)."
        }
        catch {
            Write-Log "ERROR Removing duplicate jump client $($client.name)."
            Write-Log $_
        }
        Write-Log "**********************************"
        $i = $i+1
        if ($ucount -ge 1) { Write-Progress -Activity "Removing out-of-date duplicate jump clients" -Status "Progress:" -PercentComplete ($i/$ucount*100) }
    }
}

if ($dupClients.Count -gt 0) {
    $i = 0
    $ucount = $dupClients.Count
    Write-Log "***OTHER DUPLICATE JUMP CLIENTS***"
    foreach ($client in $dupClients) {
        $remURI = $apiURI + "jump-client/$($client.id)"
        try {
            Invoke-WebRequest -Uri $remURI -Method 'DELETE' -Headers $headers -ContentType 'application/json' -ErrorAction Stop | Out-Null
            Write-Log "SUCCESS Removing duplicate jump client $($client.name)."
        }
        catch {
            Write-Log "ERROR Removing duplicate jump client $($client.name)."
            Write-Log $_
        }
        Write-Log "**********************************"
        $i = $i+1
        if ($ucount -ge 1) { Write-Progress -Activity "Removing other duplicate jump clients" -Status "Progress:" -PercentComplete ($i/$ucount*100) }
    }
}

if (Get-Content $LogFile -ErrorAction SilentlyContinue) {
    Write-Output "Results output to log file $($LogFile)."
}
else {
    Write-Warning "No duplicate clients to process."
}
