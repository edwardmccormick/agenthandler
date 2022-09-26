$AzureDevOpsPAT = "lzeeyltevzjbg26wul2zxdsva3zx6t74oxdq6kx5lyj4miqyj4yq"
$BuildPoolID = 31

$EC2InstanceIDArray = @{}   
$BuildAgentsToStop = @()
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
    #$resultTextArray = Invoke-Command -verbose { Get-EC2Instance -Filter @{name = 'tag:Name'; values = $agent}}
    $resultObject = Get-EC2Tag -Filter @{Name="tag:Name";Values=$agent} | Where-Object ResourceType -eq "instance"| Select-Object ResourceId
    $instanceID = $resultObject.ResourceId
    Write-Host $agent" instance ID is $instanceID"

    $EC2InstanceIDArray.Add($agent,$instanceID)
}


Write-Host "Found "$EC2InstanceIDArray.Count" results from AWS for the build hosts above."


$EC2InstanceIDArray

$RequestAgentPoolJobs = (Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json")
Write-Host "Updated: Found "$RequestAgentPoolJobs.value.count" recent builds."

$waitingBuilds = @($RequestAgentPoolJobs.value | where {-not $_.assignTime})

if ($waitingBuilds.count -gt 0) {Write-Host "Found "$waitingBuilds.count" builds in the queue; no agents stopped."}
else {
    Write-Host "No jobs in the queue; checking in progress jobs."

    $inProgressBuilds = @($RequestAgentPoolJobs.value | where {-not $_.finishTime})
    
    if ($inProgressBuilds.count -eq 0)
    {Write-Host "No jobs in progress, stopping all build hosts."
    
        foreach ($element in $EC2InstanceIDArray.Values) 
        {
            $element = $element.trim()
            $status = Get-EC2InstanceStatus -InstanceId $element -IncludeAllInstance 1
            $instanceState = $status.InstanceState.Name.Value  
            Write-Host $element" is currently "$instanceState

            If ($instanceState -ne "Stopped")
                {
                Write-Host "Stopping EC2 Instance ID: $element."
                $throwaway = Stop-EC2Instance -InstanceId $element
                }
        }
    }
    else {
        Write-Host "Found "$inProgressBuilds.count" builds currently in progress."

        foreach ($build in $inProgressBuilds) {
            Write-Host "Build started at"$build.receiveTime" GMT on host agent"$build.reservedAgent.name"-"$EC2InstanceIDArray.($build.reservedAgent.name)"."
            if ($BuildAgentsToStop -notcontains $build.reservedAgent.name) {$BuildAgentsToStop += $build.reservedAgent.name
                                                                            Write-Host "Can't stop "$build.reservedAgent.name"without breaking things." }
            }                                                           
        foreach ($element in $EC2InstanceIDArray.Keys) {
            if ($BuildAgentsToStop -notcontains $element) {
                    
                Write-Host "Preparing to stop agent $element AWS name"$EC2InstanceIDArray.$element
                      
                $status = Get-EC2InstanceStatus -InstanceId $EC2InstanceIDArray.$element.trim() -IncludeAllInstance 1
                $instanceState = $status.InstanceState.Name.Value  
                Write-Host $element" is currently "$instanceState

                If ($instanceState -ne "Stopped")
                    {
                        Write-Host "Stopping EC2 Instance $element"
                        $throwaway = Stop-EC2Instance -InstanceId $EC2InstanceIDArray.$element
                    }
                }
            }

            
        }
    }