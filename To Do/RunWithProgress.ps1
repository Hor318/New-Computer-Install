
# https://github.com/pratyakshm/WinRice/blob/main/WinRice.ps1
# GNU GENERAL PUBLIC LICENSE
# https://github.com/pratyakshm/WinRice/blob/main/LICENSE

function RunWithProgress {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Text,
        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $Task,
		[Parameter(Mandatory = $false)]
        [Boolean]
		$Exit = $false
    )
    $spinner = '\', '|', '/', '-', '\', '|', '/', '-'
	$endtext = $text
    # Run given scriptblock in bg
    $job = Start-Job -ScriptBlock $Task
    # Spin while job is running
    do {
        foreach ($s in $spinner) {
            Write-Host -NoNewline "`r  [$s] $text"
            Start-Sleep -Milliseconds 150
        }
    }
    while($job.State -eq "Running")
    # Get output
    $result = Receive-Job -Job $job
    # Filter result
    if ($result -eq $false -or $null -eq $result) {
        # Failure indicator
        $ind = '-'
        $color = "DarkRed"
		$fail = $true
    }
    else {
        # Success indicator
        $ind = '+'
        $color = "DarkGreen"
    }
    Write-Host -NoNewline -ForegroundColor $color "`r  [$ind] "; Write-Host "$endtext"
	# Exit on failure
	if ($Exit -and $fail) { "Now Exiting" ; Start-Sleep -Seconds 2 ; Exit }
    return $result
}

$test1 = { 
    Start-Sleep -s 4
    return $true 
}

$test2 = { 
    $test = Test-NetConnection 1.1.1.1
      if ($test.PingSucceeded -eq $true) { 
          return $true
        } elseif ($test.PingSucceeded -eq $false) {
          return $false
        }
    }

$test3 = { 
    #Get-Process 
    start-sleep -s 1 
    return $false 
}

$oscheck = {
	$CurrentBuild = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild
	if ($CurrentBuild -lt 19043) {
		return $false
	}
	elseif ($CurrentBuild -ge 19043) {
		return $true
	}
}


""
RunWithProgress -Text "Supported Windows version" -Task $oscheck -Exit $true | Out-Null
RunWithProgress -Text "Encrypting computer using inpenetrable algorithm" -Task $test1 -Exit $false | Out-Null
RunWithProgress -Text "Testing ability to penetrate" -Task $test2 -Exit $false | Out-Null
RunWithProgress -Text "Ending example" -Task $test3 -Exit $false | Out-Null
Pause

<#
Example
# Check if supported OS build.
$oscheck = {
	$CurrentBuild = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild
	if ($CurrentBuild -lt 19043) {
		return $false
	}
	elseif ($CurrentBuild -ge 19043) {
		return $true
	}
}

RunWithProgress -Text "Supported Windows version" -Task $oscheck -Exit $true | Out-Null

# This will output the text parameter and run the task parameter as a background job, while displaying a spinner progress bar
#>