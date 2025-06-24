Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-AboutPage {
    $aboutForm = New-Object Windows.Forms.Form
    $aboutForm.Text = "About AutoCategorizer"
    $aboutForm.Size = '500,400'
    $aboutForm.StartPosition = "CenterParent"

    $textBox = New-Object Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Dock = "Fill"
    $textBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $textBox.Text = @"
AutoCategorizer v0.1.0
© 2025 A.H.K Lasindu Kumara. All rights reserved.

AutoCategorizer is a personal utility that organizes files into folders by extension.
This tool is for personal, non-commercial use only.

LICENSE:
You are free to use and copy this software for private use.
Redistribution, modification, or commercial use is not allowed without permission.

Author: A.H.K Lasindu Kumara
Contact: you@example.com
"@

    $aboutForm.Controls.Add($textBox)
    [void]$aboutForm.ShowDialog()
}


















function Show-OrganizerForm {
    $form = New-Object Windows.Forms.Form
    $form.Text = "File Organizer"
    $form.Size = '420,240'
    $form.StartPosition = "CenterScreen"

    $label = New-Object Windows.Forms.Label
    $label.Text = "Select the base folder:"
    $label.Location = '10,20'
    $label.Size = '380,20'
    $form.Controls.Add($label)

    $textBox = New-Object Windows.Forms.TextBox
    $textBox.Location = '10,45'
    $textBox.Size = '300,20'
    $form.Controls.Add($textBox)

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

$checkBox = New-Object Windows.Forms.CheckBox
$checkBox.Text = "Include subfolders"
$checkBox.Location = '10,75'
$checkBox.Width = 150  # Adjust this value as needed
$form.Controls.Add($checkBox)

    $statusLabel = New-Object Windows.Forms.Label
    $statusLabel.Location = '10,150'
    $statusLabel.Size = '380,40'
    $statusLabel.Text = ""
    $form.Controls.Add($statusLabel)

$aboutButton = New-Object Windows.Forms.Button
$aboutButton.Text = "About"
$aboutButton.Location = '10,110'
$aboutButton.Size = '80,25'
$aboutButton.Add_Click({ Show-AboutPage })
$form.Controls.Add($aboutButton)

    $startButton = New-Object Windows.Forms.Button
    $startButton.Text = "Organize"
    $startButton.Location = '160,110'
    $startButton.Add_Click({
        $basePath = $textBox.Text
        $recurse = $checkBox.Checked
        if (-not (Test-Path $basePath)) {
            [System.Windows.Forms.MessageBox]::Show("Invalid folder path.","Error","OK","Error")
            return
        }

              
if ($Recurse) {
    $allFiles = Get-ChildItem -Path $basePath -File -Recurse
} else {
    $allFiles = Get-ChildItem -Path $basePath -File
}

        $total = $allFiles.Count
        $moved = 0

        foreach ($file in $allFiles) {
            $ext = if ($file.Extension) { $file.Extension.TrimStart('.').ToUpper() } else { "NO_EXTENSION" }
            $destFolder = Join-Path $basePath $ext
            if (-not (Test-Path $destFolder)) {
                New-Item -ItemType Directory -Path $destFolder | Out-Null
            }

            $base = $file.BaseName
            $extn = $file.Extension
            $target = Join-Path $destFolder ($base + $extn)
            $i = 2
            while (Test-Path $target) {
                $target = Join-Path $destFolder "$base ($i)$extn"
                $i++
            }
            Move-Item $file.FullName $target
            $moved++
        }

        $allDirs = Get-ChildItem -Path $basePath -Directory -Recurse | Sort-Object FullName -Descending
        $deleted = 0
        foreach ($dir in $allDirs) {
            if (-not (Get-ChildItem -Path $dir.FullName -Recurse -File)) {
                Remove-Item -Path $dir.FullName -Recurse -Force
                $deleted++
            }
        }

        $statusLabel.Text = "Moved $moved file(s), deleted $deleted empty folder(s)."
    })
    $form.Controls.Add($startButton)

    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}



Show-OrganizerForm