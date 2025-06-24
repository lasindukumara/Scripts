param (
    [string]$Path = ".",
    [switch]$Recurse
)

$copy1Dir = Join-Path $Path "Copy (1)"
$copy2Dir = Join-Path $Path "Copy (2)"
$copyExtraDir = Join-Path $Path "Copy Extra"

# Create target folders
$null = New-Item -ItemType Directory -Force -Path $copy1Dir
$null = New-Item -ItemType Directory -Force -Path $copy2Dir
$null = New-Item -ItemType Directory -Force -Path $copyExtraDir

# Dictionary: hash => list of full file paths
$hashTable = @{}

Write-Host "Scanning files in $Path..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $Path -File -Recurse:$Recurse

foreach ($file in $files) {
    try {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $hashValue = $hash.Hash

        if ($hashTable.ContainsKey($hashValue)) {
            $hashTable[$hashValue] += ,$file
        } else {
            $hashTable[$hashValue] = @($file)
        }
    } catch {
        Write-Warning "Failed to hash $($file.FullName): $_"
    }
}

function Remove-Suffix {
    param ([string]$filename)

    # Remove suffix like " (1)", " (2)", etc.
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
    if ($entry.Value.Count -gt 1) {
        for ($i = 0; $i -lt $entry.Value.Count; $i++) {
            $file = $entry.Value[$i]
            $originalName = Remove-Suffix -filename $file.Name

            switch ($i) {
                0 {
                    $targetDir = $copy1Dir
                }
                1 {
                    $targetDir = $copy2Dir
                }
                default {
                    $targetDir = $copyExtraDir
                }
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
