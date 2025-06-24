Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Convert-ToBytes {
    param ($size)
    switch -Regex ($size) {
        "KB$" { return [int64]($size -replace "KB","") * 1KB }
        "MB$" { return [int64]($size -replace "MB","") * 1MB }
        "GB$" { return [int64]($size -replace "GB","") * 1GB }
        "TB$" { return [int64]($size -replace "TB","") * 1TB }
        default { throw "Invalid size format. Use formats like 500MB, 12GB, etc." }
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Video Organizer"
$form.Size = New-Object System.Drawing.Size(420,180)
$form.StartPosition = "CenterScreen"
$form.Icon = New-Object System.Drawing.Icon("C:\Scripts\9079582.ico")

# Folder path label and textbox
$labelPath = New-Object System.Windows.Forms.Label
$labelPath.Text = "Source Folder:"
$labelPath.AutoSize = $true
$labelPath.Location = '10,20'
$form.Controls.Add($labelPath)

$textBoxPath = New-Object System.Windows.Forms.TextBox
$textBoxPath.Location = '110,17'
$textBoxPath.Size = '200,20'
$form.Controls.Add($textBoxPath)

$browseButton = New-Object Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = '315,15'
$browseButton.Add_Click({
    $folderBrowser = New-Object Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxPath.Text = $folderBrowser.SelectedPath
    }
})
$form.Controls.Add($browseButton)


# Size label and textbox
$labelSize = New-Object System.Windows.Forms.Label
$labelSize.Text = "Max Folder Size (e.g. 500MB):"
$labelSize.AutoSize = $true
$labelSize.Location = '10,50'
$form.Controls.Add($labelSize)

$textBoxSize = New-Object System.Windows.Forms.TextBox
$textBoxSize.Location = '230,47'
$textBoxSize.Size = '130,20'
$form.Controls.Add($textBoxSize)


$checkBox = New-Object Windows.Forms.CheckBox
$checkBox.Text = "Include subfolders"
$checkBox.Location = '10,75'
$checkBox.Width = 150  # Adjust this value as needed
$form.Controls.Add($checkBox)


# Organize button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Organize Files"
$button.Location = '150,80'
$button.AutoSize = $true

$button.Add_Click({
    try {
                 $recurse = $checkBox.Checked

        $maxSizeBytes = Convert-ToBytes $textBoxSize.Text
        $sourcePath = $textBoxPath.Text

        if (-not (Test-Path $sourcePath)) {
            [System.Windows.Forms.MessageBox]::Show("Invalid folder path.")
            return
        }

        $targetRoot = Join-Path $sourcePath "Organized"
        $folderIndex = 1
        $currentFolderSize = 0


if ($Recurse) {
    $videos = Get-ChildItem -Path $sourcePath -File -Recurse  | Sort-Object Length
} else {
$videos = Get-ChildItem -Path $sourcePath -File  | Sort-Object Length
}

       # $videos = Get-ChildItem -Path $sourcePath -File  | Sort-Object Length
        if ($videos.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No video files found in $sourcePath.")
            return
        }

        $subFolderPath = Join-Path $targetRoot "SubFolder$folderIndex"
        New-Item -Path $subFolderPath -ItemType Directory -Force | Out-Null

        foreach ($video in $videos) {
            $fileSize = $video.Length
            if (($currentFolderSize + $fileSize) -gt $maxSizeBytes) {
                $folderIndex++
                $currentFolderSize = 0
                $subFolderPath = Join-Path $targetRoot "SubFolder$folderIndex"
                New-Item -Path $subFolderPath -ItemType Directory -Force | Out-Null
            }

            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($video.Name)
            $extension = $video.Extension
            $destination = Join-Path $subFolderPath $video.Name
            $counter = 1

            while (Test-Path $destination) {
                $destination = Join-Path $subFolderPath "$baseName ($counter)$extension"
                $counter++
            }

            Move-Item -Path $video.FullName -Destination $destination
            $currentFolderSize += $fileSize
        }
# Clean up empty folders
Get-ChildItem -Path $targetRoot -Recurse -Directory | Where-Object {
    @(Get-ChildItem -Path $_.FullName -Force -Recurse -ErrorAction SilentlyContinue).Count -eq 0
} | Remove-Item -Force -Recurse

        [System.Windows.Forms.MessageBox]::Show("✅ All files organized successfully!")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("❌ Error: $_")
    }
})
$form.Controls.Add($button)

$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()