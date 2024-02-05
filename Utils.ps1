$pathToFile = "deployment_info.json"

function Generate-RandomString {
    $length = 12
    $randomString = -join ((48..57) + (97..122) + (65..90) | Get-Random -Count 12 | % {[char]$_})
    return $randomString
}

function Get-RandomIdentifier () {
    # Check if the file exists
    $randomIdentifier = ""
    if (Test-Path $pathToFile) {
        $jsonContent = Get-Content -Path $pathToFile -Raw | ConvertFrom-Json

        # Check if the randomIdentifier property exists or is null
        if ($jsonContent -eq $null -or -not $jsonContent.PSObject.Properties['randomIdentifier']) {
            # If not present, assign a random value
            $randomIdentifier = Generate-RandomString

            # Create or update the randomIdentifier property
            if ($jsonContent -eq $null) {
                $jsonContent = [PSCustomObject]@{}
            }
            $jsonContent | Add-Member -MemberType NoteProperty -Name 'randomIdentifier' -Value $randomIdentifier -Force

            # Manually create a new object with required properties
            $newObject = [PSCustomObject]@{
                randomIdentifier = $randomIdentifier
            }

            # Save the updated JSON back to the file
            $newObject | ConvertTo-Json -Depth 20 | Set-Content -Path $pathToFile -NoNewLine -Encoding UTF8
            Write-Host "Added random identifier: $randomIdentifier"
        } else {
            $randomIdentifier = $jsonContent.randomIdentifier
            Write-Host "Random identifier exists: $($jsonContent.randomIdentifier)"
        }
    } else {
        # Create a new object if the file is empty
        $randomIdentifier = Generate-RandomString
        $newObject = [PSCustomObject]@{
            randomIdentifier = $randomIdentifier
        }

        # Save the new object as JSON to the file
        $newObject | ConvertTo-Json -Depth 20 | Set-Content -Path $pathToFile -NoNewLine -Encoding UTF8
        Write-Host "Added random identifier: $randomIdentifier"
    }
    Write-Host "returning random identifier: $randomIdentifier"
    return $randomIdentifier
}