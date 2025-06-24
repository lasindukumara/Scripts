param (
    [string]$Path = ".",
    [switch]$Recurse
)

# Prepare base copy folders
$copyBaseDir = $Path
$copyExtraDir = Join-Path $Path "Copy Extra"
$null = New-Item -ItemType Directory -Force -Path $copyExtraDir

# Dictionary: hash => list of file paths
$hashTable = @{}

Write-Host "Scanning files in $Path..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $Path -File -Recurse:$Recurse
$totalFiles = $files.Count
$index = 0

foreach ($file in $files) {
    $percent = [math]::Round(($index / $totalFiles) * 100)
    Write-Progress -Activity "Hashing files..." -Status "Processing: $($file.Name)" -PercentComplete $percent
	Write-Host "Hashing files...$($file.Name)..$percent"
    $index++
    try {
        # Manual hash if Get-FileHash isn't available
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($file.FullName)
        $hashBytes = $sha256.ComputeHash($stream)
        $stream.Close()
        $hashValue = [BitConverter]::ToString($hashBytes) -replace '-', ''

        if ($hashTable.ContainsKey($hashValue)) {
            $hashTable[$hashValue] += ,$file
        } else {
            $hashTable[$hashValue] = @($file)
        }
    } catch {
        Write-Warning "Failed to hash $($file.FullName): $_"
    }
}
Write-Progress -Activity "Hashing files..." -Completed
function Remove-Suffix {
    param ([string]$filename)
    return $filename -replace '\s\(\d+\)', ''
}

function Get-UniqueName {
    param ($basePath, $filename)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    $ext = [System.IO.Path]::GetExtension($filename)
    $newName = $filename
    $counter = 1

    while (Test-Path (Join-Path $basePath $newName)) {
        $newName = "$name-$counter$ext"
        $counter++
    }

    return $newName
}

Write-Host "`nMoving duplicates..." -ForegroundColor Yellow

foreach ($entry in $hashTable.GetEnumerator()) {
    $files = $entry.Value
    if ($files.Count -gt 1) {
        for ($i = 0; $i -lt $files.Count; $i++) {
            $file = $files[$i]
            $originalName = Remove-Suffix -filename $file.Name

            if ($i -lt 99) {
                # Up to Copy (99)
                $targetDirName = "Copy ($($i + 1))"
                $targetDir = Join-Path $copyBaseDir $targetDirName
            } else {
                # Beyond 99 => Copy Extra
                $targetDir = $copyExtraDir
            }

            # Create folder if needed
            if (-not (Test-Path $targetDir)) {
                $null = New-Item -ItemType Directory -Force -Path $targetDir
            }

            $newName = Get-UniqueName -basePath $targetDir -filename $originalName
            $destination = Join-Path $targetDir $newName

            try {
                Move-Item -Path $file.FullName -Destination $destination -Force
                Write-Host "Moved '$($file.Name)' to '$destination'"
            } catch {
                Write-Warning "Failed to move '$($file.FullName)' to '$destination': $_"
            }
        }
    }
}

Write-Host "`nOperation complete." -ForegroundColor Green
