# GetChangedBlocksV2

.SYNOPSIS

    This scripts measures the amount of disk changes on VMware VMs each time it is run.

.DESCRIPTION

    This scripts measures the amount of disk changes on VMware VMs each time it is run.
    The main/original purpose is to get real data of the daily and weekly incremental changes of your VMs in order to size your data protection / backup solution properly.
    It measures all VM virtual disks for which Change Block Tracking (CBT) has been enabled.
    The first time it is run, it creates a file containing baseline data (CBT change IDs and times).
    Each subsequent run measures changes since the last run.
    Additionally once a day/week (first run) it measures changes since the last day/week.
    Note that every run creates a short-lived snapshot on every VM that has CBT enabed.

.NOTES

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

.Parameter SingleSignOn

    Set to $True if you want to use single sign on with your windows account to the vCenter.
    Alias: sso
    Optional
    Default: $False

.Parameter weekDay

    Weekday for getting weekly changes. English weekdays.
    Optional
    Default: Saturday

.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local
    Running the script against 'vcenter.mycompany.local' without single sign on.
    At first run you are getting asked for credentials which get saved in a credential file for later runs.

.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -SingleSignOn $true
    Running the script against 'vcenter.mycompany.local' with single sign on.

.EXAMPLE

    GetChangedBlocksV2.ps1 -vCenter vcenter.mycompany.local -SingleSignOn $true -weekDay Friday
    Running the script against 'vcenter.mycompany.local' with single sign on.
    Using Friday as the day to check for the weekly changes.
