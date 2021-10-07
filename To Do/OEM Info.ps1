
Function timeStamp {
  Return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
} # End timeStamp Function
<# =================================================================================================================================
Function to add OEM info if it does not exist     #>
Function AddOEMInfo {
  $regStrings = @{
    'Logo' = 'C:\Windows\System32\oemlogo.bmp'
    'Manufacturer' = 'Omnis Computers'
    'SupportPhone' = '(518)372-7829'
    'SupportURL' = 'https://www.omniscomputers.com'
  }
  
  $regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
  $regKeyAdd = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
  
  $value = (Get-ItemProperty $regKey)
  If ( $value.Logo -is [string] ) { 
    Write-Host "[$(timeStamp)] The Logo value exists already [$($value.Logo)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray
  } Else { 
    Write-Host "[$(timeStamp)] The Logo value is missing. Adding the following value [$($regStrings.Logo)]." -ForegroundColor Gray
    reg add $regKeyAdd /v 'Logo' /t REG_SZ /d $regStrings.Logo /f 
  }    
  If ( $value.Manufacturer -is [string] ) { 
    Write-Host "[$(timeStamp)] The Manufacturer value exists already [$($value.Manufacturer)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray
  } Else { 
    Write-Host "[$(timeStamp)] The Manufacturer value is missing. Adding the following value [$($regStrings.Manufacturer)]." -ForegroundColor Gray
    reg add $regKeyAdd /v 'Manufacturer' /t REG_SZ /d $regStrings.Manufacturer /f 
  }    
  If ( $value.SupportPhone -is [string] ) { 
    Write-Host "[$(timeStamp)] The Support Phone value exists already [$($value.SupportPhone)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray 
  } Else { 
    Write-Host "[$(timeStamp)] The Support Phone value is missing. Adding the following value [$($regStrings.SupportPhone)]." -ForegroundColor Gray 
    reg add $regKeyAdd /v 'SupportPhone' /t REG_SZ /d $regStrings.SupportPhone /f 
  }    
  If ( $value.SupportURL -is [string] ) { 
    Write-Host "[$(timeStamp)] The Support URL value exists already [$($value.SupportURL)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray 
  } Else { 
    Write-Host "[$(timeStamp)] The Support URL value is missing. Adding the following value [$($regStrings.SupportURL)]." -ForegroundColor Gray 
    reg add $regKeyAdd /v 'SupportURL' /t REG_SZ /d $regStrings.SupportURL /f 
  }

    Write-Host "[$(timeStamp)] Any OEM Information that was missing has now been replaced with suggested values" -ForegroundColor DarkGray
  } # End AddOEMInfo Function

  AddOEMInfo
