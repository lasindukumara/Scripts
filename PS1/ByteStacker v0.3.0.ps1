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
$form.Size = New-Object System.Drawing.Size(440,230)
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

# Max size label and textbox
$labelSize = New-Object System.Windows.Forms.Label
$labelSize.Text = "Max Folder Size (e.g. 500MB):"
$labelSize.AutoSize = $true
$labelSize.Location = '10,50'
$form.Controls.Add($labelSize)

$textBoxSize = New-Object System.Windows.Forms.TextBox
$textBoxSize.Location = '230,47'
$textBoxSize.Size = '130,20'
$form.Controls.Add($textBoxSize)

# Recurse checkbox
$checkBox = New-Object Windows.Forms.CheckBox
$checkBox.Text = "Include subfolders"
$checkBox.Location = '10,75'
$checkBox.Width = 150
$form.Controls.Add($checkBox)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = '20,145'
$progressBar.Size = '380,20'
$progressBar.Style = 'Continuous'
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.Location = '20,170'
$statusLabel.Size = '380,20'
$form.Controls.Add($statusLabel)

# Tooltips
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.SetToolTip($textBoxPath, "Select the folder containing video files.")
$toolTip.SetToolTip($textBoxSize, "Enter maximum folder size (e.g., 700MB or 1GB).")
$toolTip.SetToolTip($checkBox, "Include files in all subfolders.")
$toolTip.SetToolTip($browseButton, "Click to browse for a folder.")
$toolTip.SetToolTip($progressBar, "Shows progress during organization.")

# Organize button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Organize Files"
$button.Location = '150,105'
$button.AutoSize = $true

$button.Add_Click({
    try {
        $button.Enabled = $false
        $form.UseWaitCursor = $true

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

        $videos = Get-ChildItem -Path $sourcePath -File -Recurse:$recurse | Sort-Object Length
        if ($videos.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No video files found in $sourcePath.")
            return
        }

        $progressBar.Value = 0
        $i = 0
        $subFolderPath = Join-Path $targetRoot "SubFolder$folderIndex"
        New-Item -Path $subFolderPath -ItemType Directory -Force | Out-Null

        foreach ($video in $videos) {
            $i++
            $progress = [math]::Round(($i / $videos.Count) * 100)
            $progressBar.Value = $progress
            $statusLabel.Text = "Processing $i of $($videos.Count): $($video.Name)"
            $form.Refresh()

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

        $statusLabel.Text = "✅ Completed organizing files."
        [System.Windows.Forms.MessageBox]::Show("✅ All files organized successfully!")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("❌ Error: $_")
    } finally {
        $progressBar.Value = 0
        $button.Enabled = $true
        $form.UseWaitCursor = $false
    }
})

$aboutButton = New-Object System.Windows.Forms.Button
$aboutButton.Text = "About"
$aboutButton.Location = '330,105'
$aboutButton.Size = '75,23'

$aboutButton.Add_Click({
    $aboutText = @"
🧰 PURPOSE:
This PowerShell-based tool organizes video files into subfolders by size. Great for exports, downloads, or phone dumps. It handles duplication and removes empty folders after cleanup.

🖥️ UI COMPONENTS:
- Browse: Select source folder
- Max Folder Size: Specify max size (e.g., 500MB)
- Include Subfolders: Recursively process files
- Progress bar and status display
- Organize button to start
- Tooltips for guidance

🔄 HOW IT WORKS:
Files are sorted by size and grouped into subfolders under 'Organized'. When a folder exceeds the size limit, a new one is created. Duplicate filenames are renamed automatically. Empty folders are deleted at the end.

✅ FEATURES:
- Simple GUI, no scripting knowledge needed
- Auto-renames duplicate filenames
- Cleans unused folders
- Fast for local video collections


"@

    [System.Windows.Forms.MessageBox]::Show($aboutText, "About Video Organizer")
})
$form.Controls.Add($aboutButton)

$form.Controls.Add($button)
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()