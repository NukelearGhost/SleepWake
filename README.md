# SleepWake
## Description
 PowerShell script that will put your computer into hibernation and wake it from hibernation at specified times via Scheduled Tasks. _Requires Administrator privileges to local machine to install_.

 Script also runs Microsoft Updates and reboots at specified times.

## How it Works
SleepWake is designed to be run as a standalone script.

Heavy use of the event log, if you're stumped check the _sleep_wake_ source in Windows Event Viewer.

The default schedule hibernates at Midnight and wakes at 8am Mon - Fri; and hibernates at 4am and wakes at 12pm on Sat & Sun.

### Installation
1. Place the file _SleepWake.ps1_ in a location accessible by the _SYSTEM_ user. This will be the location the scheduled tasks execute the script from so _do not move the file after you install_ (more below).
2. [Optional] Open _SleepWake.ps1_ in your text editor of choice and update the configuration as needed (see _Config_ below)
3. Open the location from step one in an _elevated PowerShell prompt_.
4. [Optional, recommended if using custom config] Test your config by running the following in your PowerShell window  
```powershell
PS> .\SleepWake.ps1 -testConfig
```
5. Install SleepWake using current configuration by running the following in our PowerShell window
```powershell
PS> .\Sleepwake.ps1 -install
```
**Note:** You can test that everything worked correctly by checking Task Scheduler/Sleep_Wake/ for the created tasks (more below).

*From here on you can monitor the tasks by creating a custom filter in event viewer based on the* *_sleep_wake_* *log source*

### Config
_For the sake of clarity, this guide follows top to bottom starting in the "Configuration" section of the script file._

```powershell

$runAs | the user that runs the scheduled task. Default: SYSTEM

$wkdyHibTime | DateTime representing the time to hibernate the computer each week day. Default: 12am
$wkdyWakeTime | DateTime representing the time to wake the computer each week day. Default: 8am

$wkdyHibTime | DateTime representing the time to hibernate the computer each weekend day. Default: 4am
$wkdyWakeTime | DateTime representing the time to wake the computer each weekend day. Default: 12pm

$weekdays | Array containing strings representing the weekdays (must be spelled out). Default: Monday - Friday
$weekends | Array containing strings representing the weekend days (must be spelled out). Default: Saturday & Sunday

$updtDay | String representing the day of the week to run updates (must be spelled out). Default: Wednesday
$updtTime | String representing the time of day to run updates on $updtDay. Default: 11pm
```
#### Config Notes
* It is recommended that you run updates at LEAST one hour prior to your hibernate time for that particular day. This behavior is untested, however the likely outcome is undesirable.
* It can be important to keep in mind while editing the configuration that 12:00:00 AM is the first second of the new day.

### Other Commands
Most of the core functionality can be triggered using switches, along with other testing functionality built in to ease the development process.

_From the location where SleepWake.ps1 is stored_
```powershell
PS> Sleepwake.ps1 -install | Installs sleep wake in the current directory.

PS> Sleepwake.ps1 -uninstall | Uninstalls sleep wake from any directory (does not affect the script file).

PS> Sleepwake.ps1 -hib | Put computer into hibernation

PS> Sleepwake.ps1 -wake | Wakes computer from hibernation (primarily used for testing)

PS> Sleepwake.ps1 -updt | Runs Microsoft Updates and reboots computer.

PS> Sleepwake.ps1 -testInstall | Tests the installation of the current configuration.

PS> Sleepwake.ps1 -testHib | Test the hibernate function without hibernating.

PS> Sleepwake.ps1 -testUpdt | Runs Microsoft Updates without rebooting.
```
