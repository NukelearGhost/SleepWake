# Script Parameters
param(
    [switch] $install,
    [switch] $uninstall,
    [switch] $hib,
    [switch] $wake,
    [switch] $updt,
    [switch] $testInstall,
    [switch] $testHib,
    [switch] $testUpdt
)
# Check for admin and alert underprivileged users
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
 {    
    try{
        Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Error -EventId 9 -Message "Run Failed. Script must be run as admin."
        Read-Host "Must run as admin. Press any key to exit..."
        Break
    }
    catch{
        Read-Host "Must run as admin. Press any key to exit..."
        Break
    }
 }
# Configuration
    # Set the user to run the task (Default: Local SYSTEM).
    $runAs = "SYSTEM"
    # Hib/Wake Times
        # Weekday
        $wkdyHibTime = '12am'
        $wkdyWakeTime = '8am'
        # Weekend
        $wkndHibTime = '4am'
        $wkndWakeTime = '12pm'
    # Hib/Wake and Update Days (the days to sleep/wake according to $wkdayHibTime and #wkndHibTime)
        # Weekdays and Weekends (Note: 0000/12:00AM is the start of the new day)
        $weekdays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
        $weekends = @('Saturday', 'Sunday') 
        # Update Day
        $updtDay = 'Wednesday'
        $updtTime = '11pm' # Note: Depending on the day, make sure this runs long enough before the hib time otherwise the hib could run prior to updates completing.
# Sleep/Wake/Update Functions
    # Hibernate Function
    function Hibernate ([switch] $test) {
        Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Information -EventId 1 -Message "Good Night!";
        # Enter Hibernation
        if (!($test)){
            [System.Windows.Forms.Application]::SetSuspendState(1,0,0) | Out-Null
        }
    }
    # Wake Function
    function Wake {
        # Wake Computer with Arbitrary Event Log
        Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Information -EventId 2 -Message "Good Morning!";
    }
    # Update Function
    function Update ([switch] $test) {
        # If missing PSWindowsUpdate powershell module, install it, run updates, and uninstall when finished; otherwise just run updates.
            if ((((Get-Module -ListAvailable -Name PSWindowsUpdate).ExportedCommands | Measure-Object).count) -gt 0){
                Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Information -EventId 3 -Message "Starting Updates!"
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll
                Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Information -EventId 4 -Message "Updates Complete, Rebooting!"
                if (!($test)){shutdown -r -t 0}
            } else {
                Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Error -EventId 5 -Message "Unable to update, PSWindowsUpdate module not found. Install from Admin Powershell Terminal using Install-Module PSWindowsUpdate"
            }
    }
    # Install Function
    function Install ([switch] $test) {
        # If event log source does not exist, create it.
        if (![system.diagnostics.eventlog]::SourceExists("sleep_wake")){
            New-EventLog -LogName Application -Source "sleep_wake"
        }
        # Install and Configure PSWindowsUpdate for Updating Windows
        if (!($test)){
            try{
                Set-PSRepository PSGallery -InstallationPolicy Trusted # Sets PSGallery (https://www.powershellgallery.com/) as a trusted package repo.
                Install-Module PSWindowsUpdate -Force | Out-Null
                Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false | Out-Null
            }
            catch{
                $e = $_.Exception.Message
                Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Error -EventId 6 -Message "Unable to install PSWindowsUpdate.`nError Message: $e"
                exit(1)
            }
        }   
        # Create Folder in Task Scheduler for Tasks
        try{
            $scheduleObject = New-Object -ComObject schedule.service
            $scheduleObject.connect()
            $rootFolder = $scheduleObject.GetFolder("\")
            $rootFolder.CreateFolder("Sleep_Wake") | Out-Null
        }
        catch{
            $e = $_.Exception.Message
            Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Error -EventId 7 -Message "Unable to create Sleep_Wake folder in Task Scheduler.`nError Message: $e"
            if($test){
                Write-Host "[TEST FAILED]`n$e"
            }
            exit(1) 
        }
        # Create Triggers for Scheduled Tasks
            # Weekday Triggers
            $wkdyHibTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekdays -At $wkdyHibTime
            $wkdyWakeTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekdays -At $wkdyWakeTime
            # Weekend Triggers
            $wkndHibTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekends -At $wkndHibTime
            $wkndWakeTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekends -At $wkndWakeTime
            # Update Trigger
            $updtTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $updtDay -At $updtTime
        # Create Actions for Scheduled Task
            $workingDir = (Get-Location).path
            $hibAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $workingDir"\SleepWake.ps1 -hib"
            $wakeAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $workingDir"\SleepWake.ps1 -wake"
            $updtAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $workingDir"\SleepWake.ps1 -updt"
        # Create Settings for Scheduled Task
            $settings = New-ScheduledTaskSettingsSet -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        # Create Scheduled Tasks
            # Weekday Tasks
                # Weekday Wake Timer
                if(!(Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkdyWakeTimer" -ErrorAction SilentlyContinue)){
                    Register-ScheduledTask -TaskName "WkdyWakeTimer" -Trigger $wkdyWakeTrigger -Action $wakeAction -User $runAs -TaskPath "Sleep_Wake" -Settings $settings -ErrorAction SilentlyContinue | Out-Null
                }
                # Weekday Hib Timer
                if(!(Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkdyHibernateTimer" -ErrorAction SilentlyContinue)){
                    Register-ScheduledTask -TaskName "WkdyHibernateTimer" -Trigger $wkdyHibTrigger -Action $hibAction -User $runAs -TaskPath "Sleep_Wake" -Settings $settings -ErrorAction SilentlyContinue | Out-Null
                }
            # Weekend Tasks
                # Weekend Wake Timer
                if(!(Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkndWakeTimer" -ErrorAction SilentlyContinue)){
                    Register-ScheduledTask -TaskName "WkndWakeTimer" -Trigger $wkndWakeTrigger -Action $wakeAction -User $runAs -TaskPath "Sleep_Wake" -Settings $settings -ErrorAction SilentlyContinue | Out-Null
                }
                # Weekend Hib Timer
                if(!(Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkndHibernateTimer" -ErrorAction SilentlyContinue)){
                    Register-ScheduledTask -TaskName "WkndHibernateTimer" -Trigger $wkndHibTrigger -Action $hibAction -User $runAs -TaskPath "Sleep_Wake" -Settings $settings -ErrorAction SilentlyContinue | Out-Null
                }
            # Update Task
                if(!(Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "winUpdate" -ErrorAction SilentlyContinue)){
                    Register-ScheduledTask -TaskName "winUpdate" -Trigger $updtTrigger -Action $updtAction -User $runAs -TaskPath "Sleep_Wake" -Settings $settings -ErrorAction SilentlyContinue | Out-Null
                }
    }
    # Uninstall Function
    function Uninstall () {
        # Remove Scheduled Tasks

            # Weekday Tasks

                # Weekday Wake Timer
                if((Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkdyWakeTimer" -ErrorAction SilentlyContinue)){
                    Unregister-ScheduledTask -TaskName "WkdyWakeTimer" -Confirm:$false
                }
                # Weekday Hib Timer
                if((Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkdyHibernateTimer" -ErrorAction SilentlyContinue)){
                    Unregister-ScheduledTask -TaskName "WkdyHibernateTimer" -Confirm:$false
                }
            # Weekend Tasks
                # Weekend Wake Timer
                if((Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkndWakeTimer" -ErrorAction SilentlyContinue)){
                    Unregister-ScheduledTask -TaskName "WkndWakeTimer" -Confirm:$false
                }
                # Weekend Hib Timer
                if((Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "WkndHibernateTimer" -ErrorAction SilentlyContinue)){
                    Unregister-ScheduledTask -TaskName "WkndHibernateTimer" -Confirm:$false
                }
            # Update Task
                if((Get-ScheduledTask -TaskPath \Sleep_Wake\ -TaskName "winUpdate" -ErrorAction SilentlyContinue)){
                    Unregister-ScheduledTask -TaskName "winUpdate" -Confirm:$false
                }
        
        # Remove Sleep_Wake folder from task scheduler
            try{
                $scheduleObject = New-Object -ComObject schedule.service
                $scheduleObject.connect()
                $rootFolder = $scheduleObject.GetFolder("\")
                $rootFolder.DeleteFolder("Sleep_Wake", $null) | Out-Null
            }
            catch {
                $e = $_.Exception.Message
                Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Error -EventId 8 -Message "Unable to delete Sleep_Wake folder in Task Scheduler. You may need to go remove this folder manually`nError Message: $e"
                Write-Host "Error on Uninstall, check Windows Application Log for more information."
            }
        }
    # Installation Test Function
    function TestInstall {
        try{
            Install -test
            Uninstall
            Write-Host "Test Installation Successful!"
        }
        catch{
            Uninstall
            $e = $_.Exception.Message
            Write-EventLog -LogName Application -Source "sleep_wake" -EntryType Error -EventId 11 -Message "Test Installation Failed`nError Message: $e"
            Write-Host "[TEST FAILED]`n$e"
        }

    }
# Take actions based on supplied parameters
if ($install){
    Install
    exit(0)
}
if ($uninstall){
    Uninstall
    exit(0)
}
if ($hib){
    Hibernate
    exit(0)
}
if ($wake){
    Wake
    exit(0)
}
if ($updt){
    Update
    exit(0)
}
if ($testInstall){
    TestInstall
    exit(0)
}
if ($testHib){
    Hibernate -test
    exit(0)
}
if ($testUpdt){
    Update -test
    exit(0)
}
