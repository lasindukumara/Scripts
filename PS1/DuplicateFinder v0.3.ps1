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
    Write-Host "$percent% - Hashing files...$($file.Name)..$percent%"
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

function Get-FilePriority {
    param ([System.IO.FileInfo]$file)
    
    $filename = $file.Name.ToUpper()
    
    # Check if it has "Copy" patterns first (these get lower priority)
    $hasCopyPattern = $filename -match 'COPY\s*\(\d+\)' -or $filename -match '-\s*COPY' -or $filename -match 'COPY\s*-'
    
    # Priority 1: Files starting with proper names (IMG, VID, etc.) WITHOUT copy patterns
    $properPrefixes = @('IMG', 'VID', 'DSC', 'PHOTO', 'VIDEO', 'PIC', 'IMAGE')
    foreach ($prefix in $properPrefixes) {
        if ($filename.StartsWith($prefix)) {
            if (-not $hasCopyPattern) {
                return 1  # Clean proper name - HIGHEST PRIORITY
            } else {
                # Has proper prefix but also copy pattern - lower priority
                if ($filename -match 'COPY\s*\(\d+\)') {
                    return 5  # IMG with Copy (n)
                } else {
                    return 4  # IMG with - Copy
                }
            }
        }
    }
    
    # Priority 2: Files with actual dates in name (YYYY-MM-DD or YYYYMMDD format) 
    if ($filename -match '\d{4}[-_]\d{2}[-_]\d{2}' -or ($filename -match '\d{8}' -and $filename -match '20\d{6}')) {
        return 2
    }
    
    # Priority 3: Clean filenames without any copy patterns
    if (-not $hasCopyPattern) {
        return 3
    }
    
    # Priority 4: Files with "- Copy" patterns
    if ($filename -match '-\s*COPY' -or $filename -match 'COPY\s*-') {
        return 4
    }
    
    # Priority 5: Files with "Copy (n)" pattern
    if ($filename -match 'COPY\s*\(\d+\)') {
        return 5
    }
    
    # Priority 6: Everything else
    return 6
}

Write-Host "`nSorting and moving duplicates..." -ForegroundColor Yellow

foreach ($entry in $hashTable.GetEnumerator()) {
    $files = $entry.Value
    
    if ($files.Count -gt 1) {
        Write-Host "`nFound $($files.Count) duplicates with hash: $($entry.Key.Substring(0,8))..." -ForegroundColor Magenta
        
        # Sort files by priority (best names first)
        $sortedFiles = $files | Sort-Object { Get-FilePriority $_ }, Name
        
        # Display the sorting order
        Write-Host "Priority order:" -ForegroundColor Gray
        for ($i = 0; $i -lt $sortedFiles.Count; $i++) {
            $priority = Get-FilePriority $sortedFiles[$i]
            $priorityText = switch ($priority) {
                1 { "Clean proper name" }
                2 { "Date in name" }
                3 { "Clean filename" }
                4 { "Proper name + Copy" }
                5 { "Proper name + Copy (n)" }
                6 { "Generic/Other" }
            }
            Write-Host "  $($i + 1). $($sortedFiles[$i].Name) [$priorityText]" -ForegroundColor Gray
        }
        
        # Move files to appropriate folders
        for ($i = 0; $i -lt $sortedFiles.Count; $i++) {
            $file = $sortedFiles[$i]
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
                Write-Host "Moved '$($file.Name)' to '$targetDirName\$newName'" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to move '$($file.FullName)' to '$destination': $_"
            }
        }
    }
}

Write-Host "`nOperation complete!" -ForegroundColor Green
Write-Host "Files with proper names (IMG, VID, etc.) have been prioritized for Copy (1) folders." -ForegroundColor Cyan
Write-Host "Press any key to continue..." -ForegroundColor Yellow
[void][System.Console]::ReadKey($true)
