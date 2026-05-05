$Rooms = "A135","A133","A118", "A116", "A112", "A143","A141","A137", "A106", "A105", "A104", "A103", "A114"
$cred = Get-Credential tdm\buttsm.admin
foreach ($Room in $Rooms){
    for($i=1; $i -lt 10; $i++){
        #$computer = "$Room-0$i-svr"
        #$s = New-CimSession -ComputerName $computer -Credential $cred
        #$ip = Get-NetIPAddress -CimSession $s
        if (Test-Connection "$Room-0$i-svr" -Count 1 -Quiet){        
            Write-Host "$Room-0$i-svr Up ... Shutting Down" -ForegroundColor Green
            Invoke-Command -ComputerName "$Room-0$i-svr" -ScriptBlock {Stop-Computer -Force} -Credential $cred -AsJob
        }
        else {
            Write-Verbose "$Room-0$i-svr Down"
        }
        if (Test-Connection "$Room-0$i" -Count 1 -Quiet){        
            Write-Host "$Room-0$i Up ... Shutting Down" -ForegroundColor Green
            Invoke-Command -ComputerName "$Room-0$i-svr" -ScriptBlock {Stop-Computer -Force} -Credential $cred -AsJob
        }
        else {
            Write-Verbose "$Room-0$i Down"
        }
    }

    for($i=10; $i -lt 26; $i++){
        if (Test-Connection "$Room-$i-svr" -Count 1 -Quiet){        
            Write-Host "$Room-$i-svr Up ... Shutting Down" -ForegroundColor Green  
            Invoke-Command -ComputerName "$Room-$i-svr" -ScriptBlock {Stop-Computer -Force} -Credential $cred -AsJob
        }
        else {
            Write-Verbose "$Room-$i-svr Down"
        }
        if (Test-Connection "$Room-$i" -Count 1 -Quiet){        
            Write-Host "$Room-$i Up ... Shutting Down" -ForegroundColor Green
            Invoke-Command -ComputerName "$Room-$i-svr" -ScriptBlock {Stop-Computer -Force} -Credential $cred -AsJob
        }
        else {
            Write-Verbose "$Room-$i Down"
        }
    }
}


# SIG # Begin signature block
# MIINnQYJKoZIhvcNAQcCoIINjjCCDYoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwb3l/pN+ytXnYk7z9sKTF++i
# uXugggsIMIIEtjCCA56gAwIBAgITGgAAACmLJIuPnyys1gAAAAAAKTANBgkqhkiG
# 9w0BAQsFADBSMRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxGDAWBgoJkiaJk/IsZAEZ
# Fgh0ZG1hZG1pbjEfMB0GA1UEAxMWdGRtYWRtaW4tQURNSU4tQURDUy1DQTAeFw0y
# MjAyMDQwOTI0MzNaFw0yNDAyMDQwOTM0MzNaMEcxFTATBgoJkiaJk/IsZAEZFgVs
# b2NhbDETMBEGCgmSJomT8ixkARkWA3RkbTEZMBcGA1UEAxMQdGRtLUdBTEFEUklF
# TC1DQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANTRjpfS4WTk0d3l
# toxAjmYIy1IopyD400deuILabRlckxND2YQW5QzvPh4Jk3kvjxHrWPFaG8nu4/zL
# 2Z8uw9denbQjwostRrf5fILsAv4ePhPAyDYDZDyWy/QqMAp3nNtR/kK19IREETcS
# PojgITQ4ie8NbwArlD5xN+q3sqKGJevPvciL6igCy5nLtxd1NOea8pO3hMPcBkQa
# ek3KtfqbiTJrW/nA3HY9eur1rDBVfLiKOGhI5KAAOzrIUQzQcjIcp+Jz4hlqiKMa
# r1jaGbDTmywYY6Lc1nsWN4MUZInwDjKEcK8dIhECnq5v28ouli+imGMLJWiniOLX
# 79SCjo0CAwEAAaOCAY4wggGKMBAGCSsGAQQBgjcVAQQDAgEBMCMGCSsGAQQBgjcV
# AgQWBBTGrBz3hlo19vs3YUWDjoxZH022VDAdBgNVHQ4EFgQU3NXWji443E3Lj1ES
# Gxqi5enBVJEwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDgYDVR0PAQH/BAQD
# AgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUehX2O6HCXfiT9By9LoJ8
# 2eMPiWswVwYDVR0fBFAwTjBMoEqgSIZGaHR0cDovL0FkbWluLUFEQ1MudGRtYWRt
# aW4ubG9jYWwvQ2VydEVucm9sbC90ZG1hZG1pbi1BRE1JTi1BRENTLUNBLmNybDB8
# BggrBgEFBQcBAQRwMG4wbAYIKwYBBQUHMAKGYGh0dHA6Ly9BZG1pbi1BRENTLnRk
# bWFkbWluLmxvY2FsL0NlcnRFbnJvbGwvQWRtaW4tQURDUy50ZG1hZG1pbi5sb2Nh
# bF90ZG1hZG1pbi1BRE1JTi1BRENTLUNBLmNydDANBgkqhkiG9w0BAQsFAAOCAQEA
# nS4iOVgX1I0xu3jEF+/0i0PqNjEE0lAfA4xNBgf9qJuuolYCljB0aIZcIxbjR6ee
# RFCxGlZso2auQzUWI/uStePKfKp7My9IDs5ATZeu0xk4tbCE9eGEJ8dgqdHgPcd/
# iVBnQxhbfLJ09H8ykD6d7aKgBuWEBghq5Okb7Z5JWLIFaqEy4RhwyHCjNwGi7aRt
# 2B8EJ3IqqljQl+4rzFaI5Zh4Q9NVU4PnI11IRf/ZXPm1NX/Hco2dCva/fYQcH5Bq
# KM8yOBKT4g/Ns49d0T5DkZ54za/egUQtKZCxlhePaBouWrIYHuxuPoDF3e0nLYtc
# 98dFpmfewdqB0uVSRsw3ZzCCBkowggUyoAMCAQICEzoAABQD5adYnELYOW0AAQAA
# FAMwDQYJKoZIhvcNAQELBQAwRzEVMBMGCgmSJomT8ixkARkWBWxvY2FsMRMwEQYK
# CZImiZPyLGQBGRYDdGRtMRkwFwYDVQQDExB0ZG0tR0FMQURSSUVMLUNBMB4XDTIy
# MDIwNDE3MDIzMFoXDTIzMDIwNDE3MDIzMFowTDEVMBMGCgmSJomT8ixkARkWBWxv
# Y2FsMRMwEQYKCZImiZPyLGQBGRYDdGRtMQ8wDQYDVQQLEwZBZG1pbnMxDTALBgNV
# BAMTBE1hcmswggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDMUEKR0JYc
# Pduz5KdKZc1VvXucmGjLupLDx+KhbLL6PG5dZcjrWUeDysq0rlCIrwxoVEcTpUdU
# n1eJXRT4UuiuUkIE4RoS2DJpfFg4dKmZNU5pAZ4p7sTGhe6YlegQg2oOZYGaGmQq
# rNKCcKB014ctx18nVTJtUa/NlV+EE9dU8+bTXvJ28xo8Zz0PCDvk56eVDuasLFUt
# E522GVB+FCj5EST2ULCQR+aMW+L/LHTq9ZofHgafn0IAuVAymMsHJCXjOi0P9tc0
# QZpbfxnD11XGl/JDXBzCUji76E/K67EdRc12x8FPbFC2JKPdk+/0LIDiDOLLR3aD
# rpgCniRIGWqFAgMBAAGjggMoMIIDJDA7BgkrBgEEAYI3FQcELjAsBiQrBgEEAYI3
# FQiIw3PZnWiCnZEshKLoZIfK6mkQgovuGYT1tQ0CAWUCAQMwPwYDVR0lBDgwNgYK
# KwYBBAGCNwoDDAYIKwYBBQUHAwMGCCsGAQUFBwMCBggrBgEFBQcDBAYKKwYBBAGC
# NwoDBDAOBgNVHQ8BAf8EBAMCBeAwTwYJKwYBBAGCNxUKBEIwQDAMBgorBgEEAYI3
# CgMMMAoGCCsGAQUFBwMDMAoGCCsGAQUFBwMCMAoGCCsGAQUFBwMEMAwGCisGAQQB
# gjcKAwQwRAYJKoZIhvcNAQkPBDcwNTAOBggqhkiG9w0DAgICAIAwDgYIKoZIhvcN
# AwQCAgCAMAcGBSsOAwIHMAoGCCqGSIb3DQMHMB0GA1UdDgQWBBTP9/EpOevy/1I7
# KGcJjvZfeeuf6jAfBgNVHSMEGDAWgBTc1daOLjjcTcuPURIbGqLl6cFUkTCBzgYD
# VR0fBIHGMIHDMIHAoIG9oIG6hoG3bGRhcDovLy9DTj10ZG0tR0FMQURSSUVMLUNB
# LENOPWdhbGFkcmllbCxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMs
# Q049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz10ZG0sREM9bG9jYWw/Y2Vy
# dGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3Ry
# aWJ1dGlvblBvaW50MIHABggrBgEFBQcBAQSBszCBsDCBrQYIKwYBBQUHMAKGgaBs
# ZGFwOi8vL0NOPXRkbS1HQUxBRFJJRUwtQ0EsQ049QUlBLENOPVB1YmxpYyUyMEtl
# eSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9dGRt
# LERDPWxvY2FsP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZp
# Y2F0aW9uQXV0aG9yaXR5MCkGA1UdEQQiMCCgHgYKKwYBBAGCNxQCA6AQDA5tYXJr
# QHRkbS5sb2NhbDANBgkqhkiG9w0BAQsFAAOCAQEAJYGxKar22dCYZMmK8AXla8Gf
# wvBMot1sH5mfQ82w0n/PW/nkc/HSLVRqHwtkjC9zZaFCH+Ew/AEhPoHJy36d7r59
# eMvUk3TqEhnaluLQzqb3uC1mTKllzLokROfy7C742JOo2KmoIuKgiqIGYeTqsQ8v
# tQAJDiLW2tWkqjs+2zqiKYK2SKYjS1vezJjEDevc5P9I8VkFqBfePH/NVo9ueKHM
# c/Vkebf7qwPnZjY9Dg9XG+ktgWm3othHwQPCuQnzvpTnTmn7GFe2tgSM4a4ovQ82
# Lv86B2LU+oaheYWRhPeAVZNanBR1ii07XQSv1rDpXqpwx9Tb3DIEFAG0sfH6GjGC
# Af8wggH7AgEBMF4wRzEVMBMGCgmSJomT8ixkARkWBWxvY2FsMRMwEQYKCZImiZPy
# LGQBGRYDdGRtMRkwFwYDVQQDExB0ZG0tR0FMQURSSUVMLUNBAhM6AAAUA+WnWJxC
# 2DltAAEAABQDMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBS5OWht/lUmn5FiUTQifMV/Ax108DAN
# BgkqhkiG9w0BAQEFAASCAQBbwxrdIs9RsCYfl+Nu8XbcHfcCnH39kzygzpCt4za3
# ONokiigHxtAtKWWS9CGQa3QFPX2DKpHYg8mHYBmatistq+qDtiwZO1FWv1GBHbp9
# 4cE2LMM8aq0oE0ggXUEOCxIfAwmRxYzL5WJ16PUBaDfddCX+3HrjoJhhvvmqFBMB
# ReGCCFH2khkI5eiRESy3qgfUAVD4ZlxGuXnLS/Gz6cEM1jFvxy5iXU8UJMjVW250
# f44VGZl2VySPBMH3m1aoYA1FS0K9d2Q7EbK4h9c1PkBJoGO6e3N13rm1iN7nj3aW
# k3ZI8+XmZ7IGevfiII5HCuwZ62R5WkdJeCfyrR9TD7Bn
# SIG # End signature block
