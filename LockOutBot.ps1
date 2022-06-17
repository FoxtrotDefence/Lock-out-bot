function Unlock ($Com) {
 if ([bool] (Get-ADUser -Filter { SamAccountName -eq $Com}) -eq $false){Send-TelegramMessage -Text "$Com user not found"}
 else{
    $User = New-Object -TypeName PSObject -Property @{
    UserName = $com
    Locked = (Get-ADUser -Identity $Com -Properties * | Select-Object -ExpandProperty lockedout)}

    if($User.Locked -eq $false){Send-TelegramMessage -Text "$x user not locked"}
    else{Unlock-ADAccount -Identity $User.UserName; sleep 1}
    if ($User.Locked -eq "False"){
    Send-TelegramMessage -Text "$($User.UserName) Account Unlocked"
    $LockList.Remove($User.UserName)
    }elseif ($User.Locked -eq "True"){
    Send-TelegramMessage -Text "Had problem unlocking $($User.UserName)"
   }
 }
}
 
function list {
    if (((Search-ADAccount -LockedOut).SamAccountName).count -gt 0){
        Send-TelegramMessage -Text ("Locked Accounts:")
        foreach($z in (Search-ADAccount -LockedOut).SamAccountName){Send-TelegramMessage -Text ($z)}}                                    
    elseif(((Search-ADAccount -LockedOut).SamAccountName).count -eq 0){Send-TelegramMessage -Text ("No Locked Accounts")}      
}

#End Region

clear-host
$BotToken = "" #Token
$TelegramApiUri = "https://api.telegram.org/bot$($BotToken)"
$AllowedID = "" #AllowedID
$LockList = New-Object System.Collections.Generic.List[System.Object]

Function Send-TelegramMessage {
    param([string]$Text) 
    $Uri = $TelegramApiUri + "/sendMessage"
    $obj = @{chat_id = ([string]$AllowedID); text = [string]$text } | ConvertTo-Json

    $Result = Invoke-WebRequest -Method Post -ContentType "application/json;charset=utf-8" -Uri $Uri -Body $Obj -UseBasicParsing -ErrorAction SilentlyContinue
    if ($Result.StatusDescription -like "OK") {Write-Host -ForegroundColor Green -Object "$Text has been sent"}
    else {Write-Host -ForegroundColor Red -Object "An error occured while sending $($Text)"}
}
Function Get-TelegramUpdates() {
    $OffsetPath = "C:\TEMPoffset.txt"
    if (!(Test-Path $OffsetPath)) { New-Item -Path $OffsetPath -ItemType File} #check if temp file exist, if not create one.
    $Offset = Get-Content -Path $OffsetPath #read content of temp file
    $Uri = $TelegramApiUri + "/getUpdates"
    $ResultJson = Invoke-WebRequest -Uri $Uri -UseBasicParsing -Body @{offset = $Offset } | ConvertFrom-Json
    $Offset = $ResultJson.result[0].update_id
    if ($offset -gt 1000) {
        $Offset + 1 | Set-Content -Path $OffsetPath -Force
    }
    return $ResultJson.result[0]
}
function Get-TelegramMessages {
    param (
        [Parameter()]
        $AllowedID,
        [string]
        $TelegramApiUri
    )
    $result = Get-TelegramUpdates
    if ($result -like $null -or $result -like "") {
        return
    }
    $UserMessage = $result.message.text
    #Checks for your ID
    if ($AllowedID -notin "$AllowedID") {
        Send-TelegramMessage -Text "Your ID is $AllowedID, the script does not know you."
        return
    }
    else {
            switch -wildcard ( $UserMessage )
                {
                    "/unlock*" {unlock($UserMessage.Replace("/unlock ",""))}
                    "/list*" {list}
                    default {'Unnknown command'}
                }
     
           }
        }
        

#Loop to check for locked accounts and get commands from telegram
Do{ Start-Sleep 1
foreach ($x in (Search-ADAccount -LockedOut).SamAccountName){
    if($LockList.Contains($x) -eq $false){ #check if account is already on list
    $LockList.Add($x) # $LockList += $x if not add to locked list
    Send-TelegramMessage -Text "User $x is locked out, use /unlock $x to unlock" #send message that account is locked
    } 
    }
    Get-TelegramMessages -AllowedID $AllowedID -TelegramApiUri $TelegramApiUri #-ErrorAction Ignore #read new commands from telegram
}Until($false)
