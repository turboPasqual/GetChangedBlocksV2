<# 
# GetChangedBlocksV2

.SYNOPSIS

    Powershell script to measure the amount of disk changes on VMware VMs each time it is run.


.DESCRIPTION

    This scripts measures the amount of disk changes on VMware VMs each time it is run.
    The main/original purpose is to get real data of the daily and weekly incremental changes of your
	VMs in order to size your data protection / backup solution properly.
    It measures all VM virtual disks for which Change Block Tracking (CBT) has been enabled.
    The first time it is run, it creates a file containing baseline data (CBT change IDs and times).
    Each subsequent run measures changes since the last run.
    Additionally once a day/week (first run) it measures changes since the last day/week.
    Note that every run creates a short-lived snapshot on every VM that has CBT enabed.


.NOTES

    Version:            2.3
    Author:             Pasqual Döhring
    Creation Date:      2022-01-11
    Purpose/Change:     Changed the version number to be more consistent with the script name.
                        Fixed a minor bug with the timestamp of snapshots.
                        Created a simple Excel file to analyse the results (_Data_Analysis.xlsx).
                        Added parameter "-FilterScript" to the readme.


    Version:            1.2
    Author:             Pasqual Döhring
    Creation Date:      2021-07-13
    Purpose/Change:     Suppress VMware Customer Experience Improvement Program message.
                        Ignore Invalid server certificate warning.
                        New parameter "-OutputJSON". By omitting this switch, the script does not generate normal output. Instead JSON is used as an output at the command line.
                        New parameter "-NoDataFiles". By omitting this switch, the script does not generate any data file output. The base files get still generated since they are needed.
                        Fixed an error when a VM had no disks at all.
                        Got rid of unnecessary steps for VMs that are excluded.
                        Fixed OverFlowException when disks of VMs where too big.
                        Added the possibility to provide vcenter credentials by username and password. (-Username, -Password)
                        VMs can now be excluded by the parameter "-FilterScript". This is based by the properties of a VM (type: VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine).
                            By using a FilterScript you just include(!) those VMs for which the script is true.
                            Example: -FilterScript '$_.Name -notlike "*test*"'
                            Example: -FilterScript '$_.Name -like "PleaseIncludeMe*" -and $_.PowerState -eq "PoweredOn"'

    Version:            1.1
    Author:             Pasqual Döhring
    Creation Date:      2021-02-11
    Purpose/Change:     Added the ability to filter by the datacenter and the cluster of VMware in case you don't want to track the whole vCenter.
                        Datacenter and cluster of each VM are added to the csv files.
                        (Attention: This breaks compatibility with existing Baseline and Data files and increases runtime by roughly 10 percent!)
                        The script now automatically tries to remove leftover snapshots.

    Version:            1.0
    Author:             Pasqual Döhring
    Creation Date:      2021-02-04
    Purpose/Change:     This script is based on a script from Carlo Giuliani, Canada, 2016. Thanks a lot for the great work so far!
                        Base script can be found here: (https://www.experts-exchange.com/articles/27059/A-PowerShell-script-to-measure-VM-data-change-rates-using-Changed-Block-Tracking-CBT.html)
                        It is (nearly) a complete rewrite to handle with a lot of things in the old version that I did not like or that did not work well.
                        It can now handle login to the vcenter with single sign on or saved credentials to better work with scripts.
                        It cleans up the generated snapshots nearly all the time.
                        It has a lot more error handling and output of VMs and disks that did not get tracked (e.g. VMs without CBT oder independent disks).
                        It supports the addition of new virtual disks even after the baseline has been established.
                        It keeps track of daily and weekly changes.
                        The code is much more commented and cleaned up (hopefully).
                        If you need to exclude VMs from this script, look for 'Exclude VMs that are sensitive to snapshots' in the script.

 
.COMPONENT

    Requires VMware PowerCLI to be installed: https://www.vmware.com/support/developer/PowerCLI/


.LINK

    This project on GitHub: https://github.com/turboPasqual/GetChangedBlocksV2


.Parameter vCenter

    Network name or IP address of the vCenter.
    Alias: vc
    Mandatory


.Parameter Datacenter

    If the Datacenter gets set, only the VMs inside the given datacenter get tracked.
    Alias: dc
    Optional


.Parameter Cluster

    If the Cluster gets set, only the VMs inside the given cluster get tracked.
    Alias: dc
    Optional


.Parameter SingleSignOn

    Omit this switch if you want to use single sign on with your windows account to the vCenter.
    Alias: sso
    Optional


.Parameter Username

    Username to use for the vCenter connection. Must be used in combination with -Password.
    Alias: sso
    Optional


.Parameter Password

    Plain text password to use for the vCenter connection. Must be used in combination with -Username.
    Alias: sso
    Optional


.Parameter weekDay

    Weekday for getting weekly changes. English weekdays.
    Optional
    Default: Saturday


.Parameter OutputJSON

    By omitting this switch, the script does not generate normal output. Instead JSON is used as an output at the command line.
    Optional


.Parameter NoDataFiles

    By omitting this switch, the script does not generate any data file output. The base files get still generated since they are needed.
    Optional


.Parameter FilterScript

    VMs can be excluded by this parameter. This is based by the properties of a VM (type: VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine). By using a FilterScript you just include(!) those VMs for which the script is true.
    Optional


.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local
    Running the script against 'vcenter.mycompany.local' without single sign on.
    At first run you are getting asked for credentials which get saved in a credential file for later runs.


.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -SingleSignOn
    Running the script against 'vcenter.mycompany.local' with single sign on.


.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -SingleSignOn -weekDay Friday
    Running the script against 'vcenter.mycompany.local' with single sign on.
    Using Friday as the day to check for the weekly changes.


.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -Datacenter 'MyFancyDatacenter' -Username "domain\admin" -Password "PWD123"
    Running the script against 'vcenter.mycompany.local' with explicit user credentials. Using just the VMs inside the datacenter 'MyFancyDatacenter'.


.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -FilterScript '$_.Name -notlike "*test*"'


.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -FilterScript '$_.Name -like "PleaseIncludeMe*" -and $_.PowerState -eq "PoweredOn"'


.EXAMPLE

    powershell.exe -File C:\Script\GetChangedBlocksV2.ps1 -vCenter vcenter.loc -FilterScript "$_.Name -notmatch \"importantVM\" -and $_.Name -notlike \"vcenter*\""

#>

[CmdletBinding(DefaultParametersetname="CredLogon")]
Param (
    [Parameter(ParameterSetName = 'CredLogon',
    Mandatory=$true,
    HelpMessage="Network name or IP address of the vCenter.")]
    [Parameter(ParameterSetName = 'UserLogon',
    Mandatory=$true,
    HelpMessage="Network name or IP address of the vCenter.")]
    [Parameter(ParameterSetName = 'SSOLogon',
    Mandatory=$true,
    HelpMessage="Network name or IP address of the vCenter.")]
    [ValidateNotNullOrEmpty()]
    [Alias("vc")]
    [string]
    $vCenter,

    [Parameter(ParameterSetName = 'UserLogon',
    Mandatory=$true,
    HelpMessage="Username for the vCenter connection.")]
    [Alias("user")]
    [ValidateNotNullOrEmpty()]
    [string]
    $UserName,

    [Parameter(ParameterSetName = 'UserLogon',
    Mandatory=$true,
    HelpMessage="Plain text password for the vCenter connection.")]
    [ValidateNotNull()]
    [Alias("pwd")]
    [string]
    $Password,

    [Parameter(ParameterSetName = 'SSOLogon',
    Mandatory=$true,
    HelpMessage="Set to `$True if you want to use single sign on with your windows account to the vCenter. Default: `$False")]
    [Alias("sso")]
    [switch]
    $SingleSignOn,

    [Parameter(ParameterSetName = 'CredLogon',
    HelpMessage="If the Datacenter gets set, only the VMs inside the given datacenter get tracked.")]
    [Parameter(ParameterSetName = 'UserLogon',
    HelpMessage="If the Datacenter gets set, only the VMs inside the given datacenter get tracked.")]
    [Parameter(ParameterSetName = 'SSOLogon',
    HelpMessage="If the Datacenter gets set, only the VMs inside the given datacenter get tracked.")]
    [Alias("dc")]
    [string]
    $Datacenter = "",

    [Parameter(ParameterSetName = 'CredLogon',
    HelpMessage="If the Cluster gets set, only the VMs inside the given cluster get tracked.")]
    [Parameter(ParameterSetName = 'UserLogon',
    HelpMessage="If the Cluster gets set, only the VMs inside the given cluster get tracked.")]
    [Parameter(ParameterSetName = 'SSOLogon',
    HelpMessage="If the Cluster gets set, only the VMs inside the given cluster get tracked.")]
    [Alias("cl")]
    [string]
    $Cluster = "",

    [Parameter(ParameterSetName = 'CredLogon',
    HelpMessage="Scriptblock to exclude VMs that shall not be snapped.")]
    [Parameter(ParameterSetName = 'UserLogon',
    HelpMessage="Scriptblock to exclude VMs that shall not be snapped.")]
    [Parameter(ParameterSetName = 'SSOLogon',
    HelpMessage="Scriptblock to exclude VMs that shall not be snapped.")]
    [string]
    $FilterScript = '$true',

    [Parameter(ParameterSetName = 'CredLogon',
    HelpMessage="Weekday for getting weekly changes. English weekdays. Default: Saturday")]
    [Parameter(ParameterSetName = 'UserLogon',
    HelpMessage="Weekday for getting weekly changes. English weekdays. Default: Saturday")]
    [Parameter(ParameterSetName = 'SSOLogon',
    HelpMessage="Weekday for getting weekly changes. English weekdays. Default: Saturday")]
    [string]
    [ValidateSet("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")]
    $weekDay = "Saturday",

    [Parameter(ParameterSetName = 'CredLogon',
    HelpMessage="Omit if you want the script to output the results as JSON. Every normal output will be omitted.")]
    [Parameter(ParameterSetName = 'UserLogon',
    HelpMessage="Omit if you want the script to output the results as JSON. Every normal output will be omitted.")]
    [Parameter(ParameterSetName = 'SSOLogon',
    HelpMessage="Omit if you want the script to output the results as JSON. Every normal output will be omitted.")]
    [switch]
    $OutputJSON,

    [Parameter(ParameterSetName = 'CredLogon',
    HelpMessage="Omit if you do not want the script to output the results into data files.")]
    [Parameter(ParameterSetName = 'UserLogon',
    HelpMessage="Omit if you do not want the script to output the results into data files.")]
    [Parameter(ParameterSetName = 'SSOLogon',
    HelpMessage="Omit if you do not want the script to output the results into data files.")]
    [switch]
    $NoDataFiles
)


# Setting StrictMode to prevent programming errors
Set-StrictMode -Version Latest

# Base names for data files
[String]$Basefile = 'Baselines.csv'
[String]$Datafile = 'Data.csv'
[String]$DailyDatafile = 'DataDaily.csv'
[String]$WeeklyDatafile = 'DataWeekly.csv'
[String]$SnapErrorFile = 'VMsWithSnapshotErrors.csv'
[String]$IndependentDiskFile = 'IndependentDisks.csv'
[String]$NoCBTVMFile = 'VMsWithoutCBT.csv'

# Path to this Script
[String]$global:scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
[String]$global:scriptName = Split-Path -Leaf $MyInvocation.MyCommand.Definition
[String]$global:scriptFullname = $MyInvocation.MyCommand.Definition

# Setting full file names for data files
$Basefile = $global:scriptPath + '\' + $vCenter + '\' + $Basefile
$Datafile = $global:scriptPath + '\' + $vCenter + '\' + $Datafile
$DailyDatafile = $global:scriptPath + '\' + $vCenter + '\' + $DailyDatafile
$WeeklyDatafile = $global:scriptPath + '\' + $vCenter + '\' + $WeeklyDatafile
$SnapErrorFile = $global:scriptPath + '\' + $vCenter + '\' + $SnapErrorFile
$IndependentDiskFile = $global:scriptPath + '\' + $vCenter + '\' + $IndependentDiskFile
$NoCBTVMFile = $global:scriptPath + '\' + $vCenter + '\' + $NoCBTVMFile
$CredFile = $global:scriptPath + '\' + $vCenter + '\cred'
$LogFile = $global:scriptFullname + '.log'



#####################
### FUNCTIONS START
#####################

# Function to generate a more or less standardized object for CSV output
function Generate-InfoObject {
    Param(
        # Virtual Machine object
        [Parameter(Mandatory=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]
        $vm,

        # Timestamp as string
        [Parameter(Mandatory=$false)]
        [String]
        $TimeStamp = '',

        # Errormessage as string
        [Parameter(Mandatory=$false)]
        [String]
        $ErrorMessage = '',

        # Additional Values for the object to implement. (Array of hashtables)
        [Parameter(Mandatory=$false)]
        [Hashtable[]]
        $AdditionalValues
    )

    Process{
        # Generate the basic object.
        $objReturn = New-Object 'PSObject' | Select-Object `
            @{Name='VmName';Expression={$vm.name}},
            @{Name='UUID';Expression={$vm.PersistentId}},
            @{Name='Datacenter';Expression={$vm.Datacenter}},
            @{Name='Cluster';Expression={$vm.Cluster}},
            @{Name='CumulatedDiskCapacityGB';Expression={$vm.CumulatedDiskCapacity}},
            @{Name='VmGBUsed';Expression={$vm.UsedSpaceGB}},
            @{Name='TimeStamp';Expression={$TimeStamp}},
            @{Name='ErrorMessage';Expression={$ErrorMessage}}

        # Add each value from $AdditionalValues
        foreach ($value in $AdditionalValues) {
            foreach($key in $value.Keys){
                $objReturn | Add-Member -MemberType NoteProperty -Name $key -Value $value[$key]
            }
        }

        return $objReturn
    }
}

# Function to remove snapshot of a VM asynchronously but wait for the end anyway. This helps to handle rare problems that occur whithout '-RunAsync'.
function AsyncRemove-Snapshot([VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot]$snapshot) {
    # Remove snap
    [VMware.VimAutomation.ViCore.Types.V1.Task]$task = Remove-Snapshot $snapshot -Confirm:$false -ErrorAction SilentlyContinue -RunAsync

    # Wait until the end
    while ('Running','Queued' -contains $task.State) {
        Start-Sleep 1
        $task = Get-Task -ID $task.id
    }
}

# Function to create snapshot of a VM asynchronously but wait for the end anyway. This helps to handle rare problems that occur whithout '-RunAsync'.
function AsyncNew-Snapshot([VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$vm){
    [VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot]$snapshot = $null
    [int]$random = Get-Random
    [String]$description = "for change block tracking script, $TimeStamp, $random" # unique descriptor to identify the snapshot later on

    # Create snap
    [VMware.VimAutomation.ViCore.Types.V1.Task]$task = New-Snapshot -VM $vm -Name 'Temp for CBT baseline - Delete immediately ' -Description $description -ErrorAction Stop -RunAsync

    # Wait until the end
    while ('Running','Queued' -contains $task.State) {
        Start-Sleep 1
        $task = Get-Task -ID $task.id
    }

    # Catch error
    if ($task.State -eq 'Error') {
        throw [String]$task.ExtensionData.Info.Error.Fault + " : " + $task.ExtensionData.Info.Error.LocalizedMessage
    }

    # Find the snapshot and return it
    [VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot]$snapshot = $vm | Get-Snapshot | ?{$_.name -match '\sCBT\s'} | ?{$_.Description -eq $description}
    return $snapshot
}

# Function to calculate the changes for a special snapshot since the a reference snapshot (given by the $ChangeId). The results get returned as a standardized object for CSV output.
function Calculate-Changes([VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot]$snapshot, [VMware.Vim.VirtualDisk]$snapdisk, [String]$DiskKey, [String]$ChangeId, [String]$BaseTime, [String]$ThisTime) {
    $GBChanged = 0
    try {
        # Get VM and view of the snapshot
        $VM = $vms | Where-Object { ($_.name -eq $snapshot.VM.Name) -and ($_.PersistentId -eq $snapshot.VM.PersistentId) }
        #$VM = $snapshot.VM
        $vmwiew = Get-View $vm
        $snapview = Get-View $snapshot

        # Sum up all changed Disk Areas
        [long]$Offset = 0
        do {
            $changes = $vmwiew.QueryChangedDiskAreas($snapview.MoRef, $snapdisk.key, $Offset, $ChangeId)
            if ($null -ne $changes) {
                $changedLength = 0
                foreach ($changedArea in $changes.ChangedArea) {
                    $changedLength += $changedArea.Length
                }
                $GBchanged += $changedLength / 1024 / 1024 / 1024
            }
            $LastChange = $changes.ChangedArea | Sort Start | select -last 1
            if ($null -ne $LastChange) {
                $Offset = $LastChange.start + $LastChange.Length
            }
        }
        until (($null -eq $LastChange) -or ($Offset -gt $snapdisk.CapacityInBytes) -or ($Changes.ChangedArea.Count -eq 0))
    } catch {
        $GBchanged = 'error'
    }

    # Output the result
    if (-not $OutputJSON) {
        Write-Host "$($VM.Name) (UUID: $($VM.PersistentId)) $($snapdisk.DeviceInfo.Label) $GBchanged GB changed since $($BaseTime)."
    }

    # Convert the Disk size (in kb) to an integer
    [String]$strDiskSummary = $snapdisk.DeviceInfo.Summary.Substring(0, $snapdisk.DeviceInfo.Summary.Length - 3).Replace(",", "")
    [int64]$intDiskSummary = [convert]::ToInt64($strDiskSummary, 10)

    # Generate the return object
    $objReturn = Generate-InfoObject -vm $vm -TimeStamp $ThisTime -AdditionalValues @{'DiskName'=$snapdisk.deviceinfo.label}, @{'DiskKey'=$snapdisk.key}, @{'DiskSummary GB'=$intDiskSummary / 1024 / 1024}, @{'BaseTime'=$BaseTime}, @{'Interval'=New-Timespan $BaseTime $ThisTime}, @{'GBChanged'=$GBChanged}

    return $objReturn
}

#####################
### FUNCTIONS END
#####################




# Misc. variables
[String]$DTformat = 'yyyy-MM-dd HH:mm:ss' # Chosen to import correctly into Excel

# Check, if VMware PowerCLI is installed
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Write-Host -ForegroundColor Red 'VMware PowerCLI not installed. Get it from https://www.vmware.com/support/developer/PowerCLI/'
    exit 1
}

# Creating subfolder for output
if (-not (Test-Path ($global:scriptPath + '\' + $vCenter) -PathType Container)) {
    $null = New-Item -ItemType Directory -Force -Path ($global:scriptPath + '\' + $vCenter)
}


# Cleaning error variable
$Error.Clear()


# Getting credentials for vCenter login
[PSCredential]$creds = $null
if ($PSCmdlet.ParameterSetName -eq "CredLogon") {
    try {
        $creds = Get-Credential (Import-Clixml $CredFile) -ErrorAction Stop
    } catch {
        $creds = Get-Credential  'domain\userid' -Message 'Provide userid\password with permissions on vCenter'
        if ($null -ne $creds) {
            $creds | Export-Clixml $CredFile -Force
        } else {
            if (-not $OutputJSON) {
                Throw ('No credentials for vCenter Login!')
            } else {
                (New-Object Management.Automation.ErrorRecord 'No credentials for vCenter Login!', 1, 'OperationStopped', 'No credentials for vCenter Login!' | ConvertTo-Json -Depth 1 -Compress).ToString()
            }
            exit 1
        }
    }
} elseif ($PSCmdlet.ParameterSetName -eq "UserLogon") {
    $creds = New-Object PSCredential $UserName, $(ConvertTo-SecureString $Password -AsPlainText -Force)
}


# Initialize PowerCLI and connect to vCenter
if (-not $OutputJSON) {
    Write-Host "Trying to connect to vCenter..."
}
$vCenterConnection = $null
try {
    # Suppress VMware Customer Experience Improvement Program message
    if ($null -eq (Get-PowerCLIConfiguration -Scope User).ParticipateInCEIP) {
        $null = Set-PowerCLIConfiguration -Scope User -ParticipateInCeip $false -Confirm:$false
    }

    # Ignore Invalid server certificate warning
    if ($null -eq (Get-PowerCLIConfiguration -Scope User).InvalidCertificateAction) {
        $null = Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false
    }

    # Logon to vCenter
    if ($null -eq $creds) {
        $vCenterConnection = Connect-VIServer $vCenter -NotDefault -ErrorAction Stop
    } else {
        $vCenterConnection = Connect-VIServer $vCenter -NotDefault -Credential $creds -ErrorAction Stop
    }
} catch {
    if (-not $OutputJSON) {
        Throw $Error[0]
    } else {
        ($Error[0] | ConvertTo-Json -Depth 1 -Compress).ToString()
    }
    exit 1
}

# Get list of all VMs
if (-not $OutputJSON) {
    Write-Host "Get list of all VMs..."
}
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VMs = Get-VM -Server $vCenter


# Exclude VMs that are sensitive to snapshots
#$FilterScript = '$_.Name -notmatch "dc01" -and $_.Name -notmatch "dc02" -and $_.Name -notlike "smtp-relay-*" -and $_.Name -notlike "vcenter*" -and $_.Name -notlike "BVQSRV*"'
#$FilterScript = '$_.Name -like "cv*"'
[scriptblock]$FilterBlock = [scriptblock]::Create( $FilterScript )
$VMs = $VMs | Where-Object -FilterScript $FilterBlock


# Sort list of all VMs
$VMs = $VMs | Sort-Object -Property Name, PersistentId
[int]$VMsCount = ($VMs | Measure-Object).Count


# Adds some information to each VM-Object: the own disks, summed capacity of those disks, datacenter, cluster
foreach ($VM in $VMs) {
    $VM | Add-Member -MemberType NoteProperty -Name 'Disks' -Value (Get-HardDisk -VM $VM)
    $CumulatedDiskCapacity = 0
    if ($null -ne $VM.Disks) {
        $CumulatedDiskCapacity = ($VM.Disks.CapacityGB | Measure-Object -Sum).sum
    }
    $VM | Add-Member -MemberType NoteProperty -Name 'CumulatedDiskCapacity' -Value $CumulatedDiskCapacity

    $VM | Add-Member -MemberType NoteProperty -Name 'Datacenter' -Value ($VM | Get-Datacenter).Name
    $VM | Add-Member -MemberType NoteProperty -Name 'Cluster' -Value ($VM | Get-Cluster).Name
}

# Filter by Datacenter and Cluster
if ($Datacenter -ne "") {
    $VMs = $VMs | Where-Object { $_.Cluster -ieq $Datacenter }
}
if ($Cluster -ne "") {
    $VMs = $VMs | Where-Object { $_.Cluster -ieq $Cluster }
}

# Get list of VMs with Change Block Tracking (CBT) enabled
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VMsToTrack = $VMs | Where-Object { (Get-View $_).Config.ChangeTrackingEnabled }

# Get list of VMs without Change Block Tracking (CBT)
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VMsWithoutCBT = $VMs | Where-Object  { $_.PersistentId -notin $VMsToTrack.PersistentId }


# Get the actual date and time
$TimeStamp = Get-Date -Format $DTformat

# Try to read existing file with VMs without CBT
[PSObject[]]$NoCbtVMs = @()
try {
    $NoCbtVMs = Import-CSV $NoCBTVMFile -Delimiter ";" -ErrorAction Stop
} catch {
    $Error.RemoveAt(0) # Remove last Error from $Error because we have already dealt with it
}

# Write all VMs with CBT disabled to the $NoCBTVMFile
foreach ($VMWithoutCBT in $VMsWithoutCBT) {
    # Check if VM is not already in the file
    $alreadyKnownVM = $NoCbtVMs | Where-Object { ($VMWithoutCBT.Name -eq $_.VMname) -and ($VMWithoutCBT.PersistentId -eq $_.UUID)}  | select -first 1

    if ($null -eq $alreadyKnownVM) {
        # Generate object for the CSV file
        $objTemp = Generate-InfoObject -vm $VMWithoutCBT -TimeStamp $TimeStamp -ErrorMessage 'Change block tracking disabled!'

        # Add object to the list
        $NoCbtVMs += ,$objTemp

        if ($OutputJSON) {
            # Only export new Information with JSON
            (@{'NoCbtVM' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
        }
    }
}
# Sort list and write it to disk
$NoCbtVMs = $NoCbtVMs | Sort-Object -Property VmName, UUID
$NoCbtVMs | Export-CSV -Delimiter ';' $NoCBTVMFile -NoTypeInformation -Force


# Build list of VMs that are not to be snapshotted at all.
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VMsNotToTrack = $VMs | Where-Object  { $_.PersistentId -notin $VMsToTrack.PersistentId }
# Count the members of the lists
[int]$VMsToTrackCount = ($VMsToTrack | Measure-Object).Count
[int]$VMsNotToTrackCount = ($VMsNotToTrack | Measure-Object).Count

# Is this the first run of the script? Automatically set to true if no baseline exists.
[boolean]$bFirstRun = $false


# Try to read existing baseline file
[PSObject[]]$Baselines = @()
try {
    $Baselines = Import-CSV $Basefile -Delimiter ";" -ErrorAction Stop
} catch {
    $Error.RemoveAt(0) # Remove last Error from $Error because we have already dealt with it
    $bFirstRun = $true
}

# Try to read existing file with independent disks
[PSObject[]]$IndependentDisks = @()
try {
    $IndependentDisks = Import-CSV $IndependentDiskFile -Delimiter ";" -ErrorAction Stop
} catch {
    $Error.RemoveAt(0) # Remove last Error from $Error because we have already dealt with it
}


# Retrieve or generate baseline change ids (one for each disks) for each VM in list to be measured
# Generating a new baseline requires creating a snapshot (which is removed immediately)
#
# Note that there may be more than one disk per VM.
# and in some cases only some disks have CBT enabled.
if (-not $OutputJSON) {
    Write-Host " "
    Write-Host "Creating baselines for max. $VMsToTrackCount VMs..."
    Write-Host " "
}

$export = $false
$i = 0
foreach ($vm in $VMsToTrack) {
    $i++
    $bCreateSnap = $false

    # Get the snappable and the non-snappable disks
    $snappableDisks = $null
    $nonsnappableDisks = $null
    if (($vm.Disks | Measure-Object).Count -gt 0) {
        $snappableDisks = $vm.Disks | Where-Object { $_.Persistence -notlike "Independent*" }
        $nonsnappableDisks = $vm.Disks | Where-Object { $_.Persistence -like "Independent*" }
    }
    
    # Check, if we don't already have a baseline for one or more of the disks. If true set $bCreateSnap=$true
    if ($null -ne $snappableDisks) {
        $knownDisks = $Baselines | Where-Object { $vm.Name -eq $_.VMname}
        if ($null -ne $knownDisks) {
            $additionalDisks = Compare-Object -ReferenceObject $snappableDisks.Name -DifferenceObject ($Baselines | Where-Object { $vm.Name -eq $_.VMname}).DiskName | Where-Object { $_.SideIndicator -eq '<=' }
            if ($null -ne $additionalDisks) {
                $bCreateSnap = $true
            }
        } else {
            $bCreateSnap = $true
        }
    }

    # Get the actual date and time
    $TimeStamp = Get-Date -Format $DTformat


    # Add the independent disks to the list ($IndependentDiskFile) if not already in that list
    forEach ($disk in $nonsnappableDisks) {
        $independentDisk = $IndependentDisks | Where-Object { ($vm.Name -eq $_.VmName) -and ($vm.PersistentId -eq $_.UUID) -and ($disk.FileName -eq $_.DiskFileName)}
        if ($null -eq $independentDisk) {
            $objTemp = Generate-InfoObject -vm $vm -TimeStamp $TimeStamp -AdditionalValues @{'DiskName'=$disk.Name}, @{'DiskFileName'=$disk.FileName}, @{'DiskCapacityGB'=$disk.CapacityGB}, @{'DiskPersistence'=$disk.Persistence}, @{'DiskType'=$disk.DiskType}
            $IndependentDisks += ,$objTemp

            if ($OutputJSON) {
                # Only export new Information with JSON
                (@{'IndependentDisk' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
            }
        }
    }


    # Create Snap if we don't already have a full baseline
    if ($bCreateSnap) {
        if (-not $OutputJSON) {
            Write-Host "Creating baseline for $($VM.Name) (UUID: $($VM.PersistentId)) ($i of $VMsToTrackCount)..."
        }
        $export = $true
        [VMware.VimAutomation.ViCore.Types.V1.VM.Snapshot]$snapshot = $null
        $snapdisks = $null
        $TimeStamp = Get-Date -Format $DTformat

        try {
            # Create Snapshot
            $snapshot = AsyncNew-Snapshot $vm
            if ($null -ne $snapshot) {
                $snapview  = Get-View $snapshot
                $snapdisks = $snapview.Config.Hardware.Device | Where-Object { ($_.GetType()).Name -eq 'VirtualDisk' }
            }
            
        } catch {
            # Something went wrong.
            $objTemp = Generate-InfoObject -vm $vm -TimeStamp $TimeStamp -ErrorMessage $Error[0].Exception.Message

            if ($OutputJSON) {
                # Export error with JSON
                (@{'SnapshotError' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
            }

            # Log Error in $SnapErrorFile
            if (-not $NoDataFiles) {
                $objTemp | Export-CSV -Delimiter ';' $SnapErrorFile -NoTypeInformation -Force -Append
            }
            
            $Error.RemoveAt(0) # Remove last Error from $Error because we have already dealt with it
        }

        # Add baseline information to list if we don't already have it in there
        foreach ($snapdisk in $snapdisks) {
            if ($null -ne $snapdisk.Backing.ChangeId) {
                if ($null -eq ($Baselines | Where-Object { $VM.Name -eq $_.VMname} | Where-Object { $_.DiskName -eq $snapdisk.deviceinfo.label})) {
                    # Convert the Disk size (in kb) to an integer
                    [String]$strDiskSummary = $snapdisk.DeviceInfo.Summary.Substring(0, $snapdisk.deviceinfo.summary.Length - 3).Replace(",", "")
                    [int64]$intDiskSummary = [convert]::ToInt64($strDiskSummary, 10)

                    # Generate the baseline object
                    $objTemp = Generate-InfoObject -vm $vm -TimeStamp $TimeStamp -AdditionalValues @{'DiskName'=$snapdisk.deviceinfo.label}, @{'DiskKey'=$snapdisk.key}, @{'DiskSummary GB'=$intDiskSummary / 1024 / 1024}, @{'ChangeId'=$snapdisk.Backing.ChangeId}, @{'DailyTimeStamp'=$TimeStamp}, @{'DailyChangeId'=$snapdisk.Backing.ChangeId}, @{'WeeklyTimeStamp'=$TimeStamp}, @{'WeeklyChangeId'=$snapdisk.Backing.ChangeId}

                    # Add object to list
                    $Baselines += ,$objTemp

                    if ($OutputJSON) {
                        # Only export new Information with JSON
                        (@{'Baseline' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
                    }
                }
            }

        }

        # Remove snapshot
        if ($null -ne $snapshot) {
            AsyncRemove-Snapshot $snapshot
        }
    }
}

# CSV export of independent disks
$IndependentDisks | Export-CSV -Delimiter ';' $IndependentDiskFile -NoTypeInformation -Force

 
# Additional Info
if (-not $OutputJSON) {
    Write-Host " "
    Write-Host "****************************************"
    Write-Host "   Total VMs: $VMscount"
    Write-Host "****************************************"
    Write-Host "   Total VMs with CBT enabled: $VMsToTrackCount"
    Write-Host "****************************************"
    Write-Host " "
}
    
# CSV export of baselines
$Baselines = $Baselines | Sort-Object -Property VmName, DiskName
$Baselines | Export-CSV -Delimiter ';' $Basefile -NoTypeInformation -Force



if (-not $bFirstRun) {
    # For each item in Baselines list, measure changes since baseline was set
    # A snapshot (which is removed immediately) is needed for each VM measured
    # Append results to existing file (if it exists)
    #
    # Note that there may be more than one disk per VM.
    # and in some cases only some disks have CBT enabled.

    if (-not $OutputJSON) {
        Write-Host " "
        Write-Host "Tracking changes of max. $(($Baselines | Where-Object {$_.VmName -in $VMsToTrack.Name}).Count) Disks..."
        Write-Host " "
    }
    
    # Resetting variables
    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$VM = $null
    $lastVMname = $null
    $lastVMUUID = $null
    $snapshot = $null
    $Data = @()
    $DailyData = @()
    $WeeklyData = @()


    ForEach ($b in $Baselines) {
        # Sort out the baselines of the VMs that we don't track (just by the name of the VM and not by the UUID)
        if ($b.VmName -in $VMsToTrack.Name){

            if (($b.VmName -ne $lastVMname) -or (($b.UUID -ne $lastVMUUID))) { # done with previous VM or first time in the loop

                # Get the actual date and time
                $TimeStamp = Get-Date -format $DTformat

                # delete snapshot created in previous step if it exists
                if ($null -ne $snapshot) {
                    AsyncRemove-Snapshot $snapshot
                }

                # Reset variable
                $snapshot = $null
            
                # next VM in baselines
                $vm = $VMsToTrack | Where-Object {($_.Name -ieq $b.VmName) -and ($_.PersistentId -eq $b.UUID)}

                # Create snapshot for this VM 
                if ($null -ne $vm) {
                    $vmview    = Get-View $vm
 
                    try {
                        $snapshot = AsyncNew-Snapshot $vm
                    } catch {
                        # Could not create Snapshot. Write error to $SnapErrorFile
                        $objTemp = Generate-InfoObject -vm $vm -TimeStamp $TimeStamp -ErrorMessage $Error[0].Exception.Message

                        if ($OutputJSON) {
                            # Export error with JSON
                            (@{'SnapshotError' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
                        }

                        # Log Error in $SnapErrorFile
                        if (-not $NoDataFiles) {
                            $objTemp | Export-CSV -Delimiter ';' $SnapErrorFile -NoTypeInformation -Force -Append
                        }

                        $Error.RemoveAt(0) # Remove last Error from $Error because we have already dealt with it
                    }
                } else {
                    # Could not find VM from baseline in the current VMs anymore... Ignore!
                    # Write-Host -f red "VM MISSING $($b.VMname)!"
                }

            }
        

            # Set information for the next loop
            $LastVmName = $b.VmName
            $lastVMUUID = $b.UUID

            # If we have a snapshot calculate changes since the last baseline
            if ($null -ne $snapshot) {
                # Get the corresponding virtual disk for the snap
                [VMware.Vim.VirtualDisk]$snapdisk = (Get-View $snapshot).Config.Hardware.Device | where {($_.GetType()).Name -eq "VirtualDisk"} | Where-Object {$_.key -eq $b.DiskKey}

                # Calculate changes and add them to the list
                $objTemp = Calculate-Changes -snapshot $snapshot -snapdisk $snapdisk -DiskKey $b.DiskKey -ChangeId $b.ChangeId -BaseTime $b.TimeStamp -ThisTime $TimeStamp
                $data += ,$objTemp

                if ($OutputJSON) {
                    # Only export new Information with JSON
                    (@{'Data' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
                }

                # Change 'ChangeId' and 'TimeStamp' in the baseline for the next run of the script.
                $b.ChangeId = $snapdisk.Backing.ChangeId
                $b.TimeStamp = $TimeStamp

                # If it is the first daily snapshot today, update the daily information, too.
                if ($b.DailyTimeStamp.Substring(0,10) -ne (Get-Date -Format $DTformat).Substring(0,10)) {
                    $objTemp = Calculate-Changes -VM $VM -snapshot $snapshot -snapdisk $snapdisk -DiskKey $b.DiskKey -ChangeId $b.DailyChangeId -BaseTime $b.DailyTimeStamp -ThisTime $TimeStamp
                    $DailyData += ,$objTemp

                    if ($OutputJSON) {
                        # Only export new Information with JSON
                        (@{'DailyData' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
                    }

                    $b.DailyChangeId = $snapdisk.Backing.ChangeId
                    $b.DailyTimeStamp = $TimeStamp
                }

                # If the weekday matches the chosen weekday and it is the first weekly snapshot today, update the weekly information, too.
                if (((Get-Date).DayOfWeek -eq [DayOfWeek] $weekDay) -and ($b.WeeklyTimeStamp.Substring(0,10) -ne (Get-Date -Format $DTformat).Substring(0,10))) {
                    $objTemp = Calculate-Changes -VM $VM -snapshot $snapshot -snapdisk $snapdisk -DiskKey $b.DiskKey -ChangeId $b.WeeklyChangeId -BaseTime $b.WeeklyTimeStamp -ThisTime $TimeStamp
                    $WeeklyData += ,$objTemp

                    if ($OutputJSON) {
                        # Only export new Information with JSON
                        (@{'WeeklyData' = $objTemp} | ConvertTo-Json -Depth 1 -Compress).ToString()
                    }

                    $b.WeeklyChangeId = $snapdisk.Backing.ChangeId
                    $b.WeeklyTimeStamp = $TimeStamp
                }
            }
        }
    }

    # Remove snap
    if ($null -ne $snapshot) {
        AsyncRemove-Snapshot $snapshot
    }

    if (-not $NoDataFiles) {
        # CSV export data
        $Data | Export-CSV -Delimiter ';' $Datafile -NoTypeInformation -Append
        if (($null -ne $DailyData) -and ($DailyData.Count -gt 0)){
            $DailyData | Export-CSV -Delimiter ';' $DailyDatafile -NoTypeInformation -Append
        }
        if (($null -ne $WeeklyData) -and ($WeeklyData.Count -gt 0)){
            $WeeklyData | Export-CSV -Delimiter ';' $WeeklyDatafile -NoTypeInformation -Append
        }
    }

    # Update the baseline file with the new ChangIds and TimeStamps
    $Baselines | Export-CSV -Delimiter ';' $Basefile -NoTypeInformation -Force
}

#Write-Host "Waiting for snapshot removal tasks to finish..."
#$null = $objRemoveTasks | Wait-Task

# Check for left-over CBT-related snapshots
if (-not $OutputJSON) {
    Write-Host " "
    Write-Host "Checking for leftover snapshots..."
}
$Snapshots = Get-VM -Server $vCenter | Get-Snapshot | ?{$_.name -match '\sCBT\s'}
If ($snapshots) {
    if (-not $OutputJSON) {
        Write-Host -f red (($Snapshots | Measure-Object).Count.toString() + " left-over CBT snapshot(s)! Going to remove...")
    }
    $Snapshots | Remove-Snapshot -Confirm:$false -ErrorAction SilentlyContinue
} else {
    if (-not $OutputJSON) {
        Write-Host "None found!"
    }
}

# Disconnect from vCenter
if (-not $OutputJSON) {
    Write-Host " "
    Write-Host "Disconnecting from vCenter..."
}
Disconnect-VIServer -Server $vCenterConnection -Force -Confirm:$false
if (-not $OutputJSON) {
    Write-Host "Done!"
}
