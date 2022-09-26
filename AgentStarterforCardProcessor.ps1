$AzureDevOpsPAT = "lzeeyltevzjbg26wul2zxdsva3zx6t74oxdq6kx5lyj4miqyj4yq"
$BuildPoolID = 31
$EC2InstanceIDArray = @{}   
$BuildAgents = @()
$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }
$BuildUri = "https://dev.azure.com/SWBC-FigWebDev/_apis/distributedtask/pools/$BuildPoolID/jobrequests"

Write-Host "Making call to $BuildUri"

if ($null -eq $AzureDevOpsPAT) {Write-Error "The PAT is empty."}
    else {Write-Host "The PAT is not empty."}

$RequestAgentPoolJobs = (Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json")

Write-Host "Found "$RequestAgentPoolJobs.value.count" recent builds."

foreach ($build in $RequestAgentPoolJobs.value) {
    if ($BuildAgents -notcontains $build.reservedAgent.name) {$BuildAgents += $build.reservedAgent.name}
}

Write-Host "Found "$BuildAgents.Count" different build servers."
Write-Host "Those build agents are: " $BuildAgents "."

foreach ($agent in $BuildAgents) {
    #$resultTextArray = Invoke-Command -verbose { aws ec2 describe-instances --filters Name=tag:Name,Values=$agent}
    #$resultTextArray = Invoke-Command -verbose { Get-EC2Instance -Filter @{name = 'tag:Name'; values = $agent}}
    $resultObject = Get-EC2Tag -Filter @{Name="tag:Name";Values=$agent} | Where-Object ResourceType -eq "instance"| Select-Object ResourceId
    $instanceID = $resultObject.ResourceId
    Write-Host $agent" instance ID is $instanceID"

    $EC2InstanceIDArray.Add($agent,$instanceID)
}


Write-Host "Found "$EC2InstanceIDArray.Count" results from AWS for the build hosts above."

$EC2InstanceIDArray

$EC2InstancesToStart = $EC2InstanceIDArray.Values | Sort-Object {Get-Random}

$StartTryCounter = 0

foreach ($element in $EC2InstancesToStart) 
        {
            $element = $element.trim()
            $status = Get-EC2InstanceStatus -InstanceId $element -IncludeAllInstance 1
            $instanceState = $status.InstanceState.Name.Value  
            Write-Host $element" is currently "$instanceState

            If ($instanceState -ne "Running")
                {
                Write-Host "Starting $element"
                Start-EC2Instance -InstanceId $element
                Break
                }
            else {Write-Host "Can't start $element, it's current " $instanceState
                $StartTryCounter++
                }
        }
if ($StartTryCounter -eq $EC2InstancesToStart.count) {Write-Host "All instances in the pool are currently running `nNot able to start a new instance."}
