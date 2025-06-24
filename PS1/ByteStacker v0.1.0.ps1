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
$form.Size = New-Object System.Drawing.Size(420,170)
$form.StartPosition = "CenterScreen"
#$form.Icon = New-Object System.Drawing.Icon("$PSScriptRoot\9079582.ico")
$form.Icon = New-Object System.Drawing.Icon("C:\Scripts\9079582.ico")

$browseButton = New-Object Windows.Forms.Button
    $browseButton.Text = "Browse..."
    $browseButton.Location = '315,43'
    $browseButton.Add_Click({
        $folderBrowser = New-Object Windows.Forms.FolderBrowserDialog
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $textBox.Text = $folderBrowser.SelectedPath
        }
    })
    $form.Controls.Add($browseButton)



$label = New-Object System.Windows.Forms.Label
$label.Text = "Max Folder Size (e.g. 500MB, 2GB):"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(230, 17)
$textBox.Size = New-Object System.Drawing.Size(150,20)
$form.Controls.Add($textBox)

$button = New-Object System.Windows.Forms.Button
$button.Text = "Organize Files"
$button.Location = New-Object System.Drawing.Point(150,60)
$button.AutoSize = $true

$button.Add_Click({
    try {
        $maxSizeInput = $textBox.Text
        $maxSizeBytes = Convert-ToBytes $maxSizeInput

        $sourcePath = $textBox.Text
        $targetRoot = Join-Path $sourcePath "Organized"
        $folderIndex = 1
        $currentFolderSize = 0

        $videos = Get-ChildItem -Path $sourcePath -File | Sort-Object Length
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

            $destination = Join-Path $subFolderPath $video.Name
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($video.Name)
$extension = $video.Extension
$destination = Join-Path $subFolderPath $video.Name
$counter = 1

while (Test-Path $destination) {
    $newName = "$baseName ($counter)$extension"
    $destination = Join-Path $subFolderPath $newName
    $counter++
}

Move-Item -Path $video.FullName -Destination $destination


            $currentFolderSize += $fileSize
        }

        [System.Windows.Forms.MessageBox]::Show("✅ All files organized successfully!")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("❌ Error: $_")
    }
})

$form.Controls.Add($button)
$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()