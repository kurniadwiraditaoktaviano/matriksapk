$flutterBin = "C:\Users\lenovo\flutter\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)

if ($currentPath -like "*$flutterBin*") {
    Write-Host "Flutter is already in your PATH." -ForegroundColor Green
} else {
    $newPath = "$currentPath;$flutterBin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::User)
    Write-Host "Success! Added Flutter to User PATH." -ForegroundColor Green
    Write-Host "Please restart your terminal (VS Code) for changes to take effect." -ForegroundColor Yellow
}

Write-Host "You can now run 'flutter run' in a new terminal."
Read-Host -Prompt "Press Enter to exit"
