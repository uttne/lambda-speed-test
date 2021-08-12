$OLD_DIR = Get-Location

$WORK_DIR = $(Split-Path -Parent $MyInvocation.MyCommand.Path)

Set-Location $(Join-Path $WORK_DIR "src/Simple")

$FUNCTION_NAME = "lambda-speed-test-dotnet-core-3_1-simple"
$PAYLOAD = "test"

function New-Function($memorySize=256){
    if(dotnet lambda list-functions | sls $FUNCTION_NAME){
        Write-Output "'$FUNCTION_NAME' is existed."
        return
    }
    dotnet lambda deploy-function --function-name $FUNCTION_NAME --function-memory-size $memorySize | Out-Null
    Write-Output "'$FUNCTION_NAME' create. (MemSize: $memorySize)"
}

function Invoke-Function(){
    $result = dotnet lambda invoke-function --function-name $FUNCTION_NAME --payload $PAYLOAD
    $result = $result -join ' '
    $result -match 'REPORT RequestId: ([0-9a-z-]+).+Duration: ([\d.]+).+Billed Duration: ([\d.]+).+Memory Size: ([\d.]+).+Max Memory Used: ([\d.]+)'
    
    return @{
        RequestId = $Matches.1;
        Duration = $Matches.2 -as [double];
        BilledDuration = $Matches.3 -as [double];
        MemorySize = $Matches.4 -as [double];
        MaxMemoryUsed = $Matches.5 -as [double];
    }
}

function Remove-Function(){
    if(dotnet lambda list-functions | sls $FUNCTION_NAME){
        dotnet lambda delete-function --function-name $FUNCTION_NAME | Out-Null
        Write-Output "'$FUNCTION_NAME' delete."
        return
    }
    Write-Output "'$FUNCTION_NAME' is not found."
}

function Measure-Cold($memorySize=256){
    Write-Output "************* Cold Start Measurement ************"

    $list = @()
    $max = 10
    for($i = 1; $i -le $max; $i++){
        $progress = $i / $max * 100
        Write-Progress -Activity "Cold Start Measurement" -Status "Create Function" -PercentComplete $progress -CurrentOperation "$progress %"
        New-Function $memorySize

        Write-Progress -Activity "Cold Start Measurement" -Status "Invoke Function" -PercentComplete $progress -CurrentOperation "$progress %"
        $result = Invoke-Function
        $list += $result.BilledDuration

        Write-Progress -Activity "Cold Start Measurement" -Status "Remove Function" -PercentComplete $progress -CurrentOperation "$progress %"
        Remove-Function
    }
    

    Write-Output "-------------------------------------------------"
    Write-Output "Cold Start Measurement Billed Duration (Memory Size: $memorySize)"
    $list | Measure-Object -Average -Sum -Maximum -Minimum
    Write-Output "*************************************************"
    
    Write-Output ""
}


function Measure-Hot($memorySize=256){
    Write-Output "************* Hot Start Measurement *************"

    Write-Progress -Activity "Hot Start Measurement" -Status "Create Function" -PercentComplete 0 -CurrentOperation "0 %"
    New-Function $memorySize
    Write-Progress -Activity "Hot Start Measurement" -Status "First Invoke Function" -PercentComplete 0 -CurrentOperation "0 %"
    Invoke-Function | Out-Null

    $list = @()
    $max = 10
    for($i = 1; $i -le $max; $i++){
        $progress = $i / $max * 100
        
        Write-Progress -Activity "Hot Start Measurement" -Status "Invoke Function" -PercentComplete $progress -CurrentOperation "$progress %"
        $result = Invoke-Function
        $list += $result.BilledDuration
    }

    Write-Progress -Activity "Hot Start Measurement" -Status "Remove Function" -PercentComplete 100 -CurrentOperation "100 %"
    Remove-Function
    

    Write-Output "-------------------------------------------------"
    Write-Output "Hot Start Measurement Billed Duration (Memory Size: $memorySize)"
    $list | Measure-Object -Average -Sum -Maximum -Minimum
    Write-Output ""
}

try{
    Measure-Cold

    Measure-Hot
}
finally{
    Set-Location $OLD_DIR
}