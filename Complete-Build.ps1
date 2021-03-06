# First, some utility functions (hat tip stuartleeks)
function PascalName($name){
    $parts = $name.Split(" ")
    for($i = 0 ; $i -lt $parts.Length ; $i++){
        $parts[$i] = [char]::ToUpper($parts[$i][0]) + $parts[$i].SubString(1).ToLower();
    }
    $parts -join ""
}
function GetHeaderBreak($headerRow, $startPoint=0){
    $i = $startPoint
    while( $i + 1  -lt $headerRow.Length)
    {
        if ($headerRow[$i] -eq ' ' -and $headerRow[$i+1] -eq ' '){
            return $i
            break
        }
        $i += 1
    }
    return -1
}
function GetHeaderNonBreak($headerRow, $startPoint=0){
    $i = $startPoint
    while( $i + 1  -lt $headerRow.Length)
    {
        if ($headerRow[$i] -ne ' '){
            return $i
            break
        }
        $i += 1
    }
    return -1
}
function GetColumnInfo($headerRow){
    $lastIndex = 0
    $i = 0
    while ($i -lt $headerRow.Length){
        $i = GetHeaderBreak $headerRow $lastIndex
        if ($i -lt 0){
            $name = $headerRow.Substring($lastIndex)
            New-Object PSObject -Property @{ HeaderName = $name; Name = PascalName $name; Start=$lastIndex; End=-1}
            break
        } else {
            $name = $headerRow.Substring($lastIndex, $i-$lastIndex)
            $temp = $lastIndex
            $lastIndex = GetHeaderNonBreak $headerRow $i
            New-Object PSObject -Property @{ HeaderName = $name; Name = PascalName $name; Start=$temp; End=$lastIndex}
       }
    }
}
function ParseRow($row, $columnInfo) {
    $values = @{}
    $columnInfo | ForEach-Object {
        if ($_.End -lt 0) {
            $len = $row.Length - $_.Start
        } else {
            $len = $_.End - $_.Start
        }
        $values[$_.Name] = $row.SubString($_.Start, $len).Trim()
    }
    New-Object PSObject -Property $values
}
function ConvertFrom-Docker(){
    begin{
        $positions = $null;
    }
    process {
        if($positions -eq $null) {
            # header row => determine column positions
            $positions  = GetColumnInfo -headerRow $_  #-propertyNames $propertyNames
        } else {
            # data row => output!
            ParseRow -row $_ -columnInfo $positions
        }
    }
    end {
    }
}

$containerRegistryName = 'kubecontainerregistry.azurecr.io'

$numberOfDockerImagesLines = (docker images | Measure-Object).Count
if ($numberOfDockerImagesLines -lt 2) {
    'No images yet, running docker-compose build'
    Start-Process docker-compose.exe -ArgumentList 'build' -Wait
}
$taggedTalkNotesBack = docker images | ConvertFrom-Docker | Where Repository -eq "$containerRegistryName/scaled/talknotesback"
if (!($taggedTalkNotesBack)) {
    'Tagging talk notes back'
    docker tag talknotesback "$containerRegistryName/scaled/talknotesback"
}
$taggedTalkNotesFront = docker images | ConvertFrom-Docker | Where Repository -eq "$containerRegistryName/scaled/talknotesfront"
if (!($taggedTalkNotesFront)) {
    'Tagging talk notes front'
    docker tag talknotesfront "$containerRegistryName/scaled/talknotesfront"
}
$pushedImages = docker images $containerRegistryName | ConvertFrom-Docker
$backPushed = $pushedImages | where Repository -Like '*talknotesback'
$frontPushed = $pushedImages | where Repository -Like '*talknotesfront'

if (!$backPushed -or !$frontPushed) {
    $credentials = Get-Credential -Message 'Private registry username and password'
    docker login -u $credentials.UserName -p $credentials.GetNetworkCredential().Password $containerRegistryName
    if (!$backPushed) {
        docker push "$containerRegistryName/scaled/talknotesback"
    }
    if (!$frontPushed) {
        docker push "$containerRegistryName/scaled/talknotesfront"
    }
}
