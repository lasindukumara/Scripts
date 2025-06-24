param (
    [switch]$Recurse
)

$baseFolder = (Get-Location).Path

if ($Recurse) {
    $allFiles = Get-ChildItem -Path $baseFolder -File -Recurse
} else {
    $allFiles = Get-ChildItem -Path $baseFolder -File
}

# Step 1: Gather all files recursively
#$allFiles = Get-ChildItem -Path $baseFolder -File -Recurse
$totalFiles = $allFiles.Count
$current = 0

Write-Host "Processing $totalFiles file(s)...`n"

foreach ($file in $allFiles) {
    $current++
    $extension = $file.Extension.TrimStart('.').ToUpper()
    if (-not $extension) { $extension = "NO_EXTENSION" }

    $destinationFolder = Join-Path $baseFolder $extension
    if (-not (Test-Path $destinationFolder)) {
        New-Item -Path $destinationFolder -ItemType Directory | Out-Null
    }

    $baseName = $file.BaseName
    $fileExt = $file.Extension
    $destPath = Join-Path $destinationFolder ($baseName + $fileExt)
    $counter = 2

    while (Test-Path $destPath) {
        $newName = "$baseName ($counter)$fileExt"
        $destPath = Join-Path $destinationFolder $newName
        $counter++
    }

    Move-Item -Path $file.FullName -Destination $destPath -Force

    Write-Progress -Activity "Organizing files..." -Status "$current of $totalFiles" -PercentComplete (($current / $totalFiles) * 100)
}

Write-Progress -Activity "Organizing files..." -Completed

# Step 2: Remove empty folders (bottom-up)
$allDirs = Get-ChildItem -Path $baseFolder -Directory -Recurse |
           Sort-Object FullName -Descending
$deleted = 0

foreach ($dir in $allDirs) {
    if (-not (Get-ChildItem -Path $dir.FullName -Recurse -File)) {
        Remove-Item -Path $dir.FullName -Force -Recurse
        Write-Host "Removed empty folder: $($dir.FullName)"
        $deleted++
    }
}

Write-Host "`nDone. Moved $totalFiles file(s) and removed $deleted empty folder(s) from $baseFolder"