#$AzureDevOpsPAT = "lzeeyltevzjbg26wul2zxdsva3zx6t74oxdq6kx5lyj4miqyj4yq" #This is a secret PAT that is not necessary when the script is running on prem
$AzureDevOpsPAT = $Env:SYSTEM_ACCESSTOKEN #This will enable this script to run on the build agent.
#$AzureDevOpsPAT = $Env:AGENTHANDLERSECRETPAT
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
$BuildAgents = @()

$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }

$BuildUri = "https://dev.azure.com/SWBC-FigWebDev/_apis/distributedtask/pools/$BuildPoolID/jobrequests"

Write-Host "Making call to $BuildUri"
#Write-Host "The PAT to access AzureDevOps API is a "$AzureDevOpsPAT.GetType()" and is "$AzureDevOpsPAT.
if ($null -eq $AzureDevOpsPAT) {Write-Error "The PAT is empty."}
    else {Write-Host "The PAT is not empty."}

$RequestAgentPoolJobs = (Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json")

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

    if ($instanceID -ne $null) {$EC2InstanceIDArray.Add($agent,$resultObject.Reservations.Instances.InstanceId)}
    else {
         $EC2InstanceIDArray = @{ #this hashtable can be used for testing locally, however without AWS credentials (and installing the AWS Powershell tools) the stop and status indicators will not work
            "AzureDevOps-Prod-LinuxAgent-1.0-EC2_04" = "i-0b6d5aa4c7d5e7f53"; 
            "AzureDevOps-Prod-LinuxAgent-1.0-EC2_10" = "i-0cc4c7329acf8e8a0"; 
            "AzureDevOps-Prod-LinuxAgent-1.0-EC2_11" = "i-06e0336bd0c1d100e"
            }
        Break    
        }
}


Write-Host "Found "$EC2InstanceIDArray.Count" results from AWS for the build hosts above."

$EC2InstanceIDArray

$EC2InstancesToStart = $EC2InstanceIDArray.Values | Sort-Object {Get-Random}

$StartTryCounter = 0

# If the agent is currently running, let it run. If it isn't, add it to the list to start.
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
if ($StartTryCounter -eq $EC2InstancesToStart.count) {Write-Host "All instances in the pool are currently running /n Not able to start a new instance."}
