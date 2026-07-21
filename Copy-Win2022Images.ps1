$Source = "D:\Lab_Images\MOC\WinServer2022 Images"

# Build computer list
$Computers = @()

#Foreach room ...

1..24 | ForEach-Object {
    $Computers += "A133-{0:D2}-SVR" -f $_
}

1..20 | ForEach-Object {
    $Computers += "A143-{0:D2}-SVR" -f $_
}

# Create log folder
$LogFolder = "D:\CopyLogs"
New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null

$Jobs = foreach ($Computer in $Computers) {

    Start-Job -ArgumentList $Computer,$Source,$LogFolder -ScriptBlock {

        param($Computer,$Source,$LogFolder)

        $Destination = "\\$Computer\D$\LabImages"

        if (-not (Test-Connection $Computer -Count 1 -Quiet)) {
            return "$Computer : OFFLINE"
        }

        try {

            robocopy `
                $Source `
                $Destination `
                /E `
                /Z `
                /XO `
                /MT:32 `
                /R:1 `
                /W:1 `
                /LOG:"$LogFolder\$Computer.log"

            return "$Computer : COMPLETE"
        }
        catch {
            return "$Computer : FAILED - $($_.Exception.Message)"
        }

    }
}

$Jobs