#$AzureDevOpsPAT = "lzeeyltevzjbg26wul2zxdsva3zx6t74oxdq6kx5lyj4miqyj4yq" #This is a secret PAT that is not necessary when the script is running on prem
#$AzureDevOpsPAT = $Env:SYSTEM_ACCESSTOKEN #This will enable this script to run on the build agent.
$AzureDevOpsPAT = $Env:AGENTHANDLERSECRETPAT
#AzureDevOpsPAT "$(AGENTHANDLERSECRETPAT)"
$BuildPoolID = $Env:BuildPoolIDNumber
#$BuildPoolID = 24 #Use this to test locally
# $EC2InstanceIDArray = @($Env:AwsLinuxAzureDevOpsAgentInstanceID)
# $EC2InstanceIDArray = @{ #this hashtable can be used for testing locally, however without AWS credentials (and installing the AWS Powershell tools) the stop and status indicators will not work
#     "AzureDevOps-Prod-LinuxAgent-1.0-EC2_04" = "i-0b6d5aa4c7d5e7f53"; 
#     "AzureDevOps-Prod-LinuxAgent-1.0-EC2_10" = "i-0cc4c7329acf8e8a0"; 
#     "AzureDevOps-Prod-LinuxAgent-1.0-EC2_11" = "i-06e0336bd0c1d100e"
# }
$EC2InstanceIDArray = @{}   
$BuildAgentsToStop = @()
$BuildAgents = @()

$TestUri = "https://dev.azure.com/SWBC-FigWebDev/_apis/distributedtask/pools/24?api-version=6.0"

$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }

$BuildUri = "https://dev.azure.com/SWBC-FigWebDev/_apis/distributedtask/pools/$BuildPoolID/jobrequests"

Write-Host "Making call to $BuildUri"
#Write-Host "The PAT to access AzureDevOps API is a "$AzureDevOpsPAT.GetType()" and is "$AzureDevOpsPAT.
if ($null -eq $AzureDevOpsPAT) {Write-Error "The PAT is empty."}
    else {Write-Host "The PAT is not empty."}

$RequestAgentPoolJobs = (Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json")

$TestWorkItem = (Invoke-RestMethod -Uri $TestUri -Method Get -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json")

if ($null -eq $TestWorkItem) {Write-Error "The WorkItemTest is empty."}
    else {Write-Host "The WorkItemTest is not empty."}

Write-Host $TestWorkItem.createdOn "is when the magic began!"

Write-Host "Found "$RequestAgentPoolJobs.value.count" recent builds."

foreach ($build in $RequestAgentPoolJobs.value) {
    if ($BuildAgents -notcontains $build.reservedAgent.name) {$BuildAgents += $build.reservedAgent.name}
}

Write-Host "Found "$BuildAgents.Count" different build servers."
Write-Host "Those build agents are: " $BuildAgents "."

# $AWSSearchString = $EC2InstanceIDArray.Keys -join ','

foreach ($agent in $BuildAgents) {
    $resultTextArray = Invoke-Command -verbose { aws ec2 describe-instances --filters Name=tag:Name,Values=$agent}
    $resultObject = @(ConvertFrom-Json (($resultTextArray) -join ' '))
    $instanceID = $resultObject.Reservations.Instances.InstanceId
    Write-Host $agent" instance ID is $instanceID"

    $EC2InstanceIDArray.Add($agent,$resultObject.Reservations.Instances.InstanceId)
}


Write-Host "Found "$EC2InstanceIDArray.Count" results from AWS for the build hosts above."


$EC2InstanceIDArray

$RequestAgentPoolJobs = (Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json")
Write-Host "Updated: Found "$RequestAgentPoolJobs.value.count" recent builds."

$waitingBuilds = @($RequestAgentPoolJobs.value | where {-not $_.assignTime})
#$waitingBuilds = $RequestAgentPoolJobs.value #Use this to test whether the logic works
#$waitingBuilds = @($RequestAgentPoolJobs.value | where {$_.requestId -eq 80097}) #use this to test whether the logic works


if ($waitingBuilds.count -gt 0) {Write-Host "Found "$waitingBuilds.count" builds in the queue; no agents stopped."}
else {
    Write-Host "No jobs in the queue; checking in progress jobs."

    #$inProgressBuilds = @($RequestAgentPoolJobs.value | where {-not $_.finishTime})
    #$inProgressBuilds = $RequestAgentPoolJobs.value | where {$_.reservedAgent.id -eq 43} #use this to test whether the logic works
    $inProgressBuilds = @($RequestAgentPoolJobs.value | where {($_.requestId -eq 80097) -or ($_.requestId -eq 71951)}) #use this to test whether the logic works

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
# Look up the instance ID by searching instances in prod publishing for the tag/reservedAgent.name
            }                                                           
        foreach ($element in $EC2InstanceIDArray.Keys) {
            if ($BuildAgentsToStop -notcontains $element) {
                    
                Write-Host "Preparing to stop agent $element AWS name"$EC2InstanceIDArray.$element
                #Write-Host $element
                        
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
            #Write-Host $build.requestId
            
        }
    }
# So now the hard part is going to be figuring out the ids of the different build agents, and associating them with the ids in ADO
# Proposal - Hashtable as an environmental variable.
# $AwsLinuxAzureDevOpsAgentInstanceID = @{ 24 = "i-0b6d5aa4c7d5e7f53"; 64 = "i-0b6d5aa4c7d5e7f53"; 65 = "i-0b6d5aa4c7d5e7f53"}


## ${name1, name 2, name3} - all the agents in the pool
## this.buildbox = name2 - preconfigured variable

# agent.machinename predefined 
# agent.name predefined

#Start script has the list
# race condition between when we query and when we shut down the instance