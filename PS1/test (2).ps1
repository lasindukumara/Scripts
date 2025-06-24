# Get the current directory
$directory = Get-Location

# Loop through each folder
Get-ChildItem -Path $directory -Directory | ForEach-Object {
    if ($_.Name -match '^\d{8}$') {
        $year = $_.Name.Substring(0,4)
        $month = $_.Name.Substring(4,2)
        $day = $_.Name.Substring(6,2)
        $newName = "WA ${year}_${month}_${day}"

        Rename-Item -Path $_.FullName -NewName $newName
    }
}