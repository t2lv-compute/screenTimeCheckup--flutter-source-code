param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the name of the commit")]
    [string]$CommitName
)
$ErrorActionPreference = "Stop";
# Function for consistent status styling
function Write-Status {
    param([string]$Message)
    Write-Host "`n>> $Message" -ForegroundColor Cyan -BackgroundColor Black
}

Write-Status "Starting deployment process for commit: $CommitName"

Write-Status "Pulling latest changes from the repository..."
git pull origin main

Write-Status "Committing source code changes: $CommitName"
git add .
git commit -m "$CommitName"

Write-Status "Pushing source changes..."
git push origin main

Write-Status "Building Flutter web project..."
cd screen_time_checkup
flutter build web --base-href /screentimecheckup/

Write-Status "Building process complete. Preparing deployment..."
cd build/web

# Note: If this is a separate repo for GH Pages, ensure git is initialized here
Write-Status "Deploying to GitHub Pages..."
git add .
git commit -m "$CommitName"
git push origin main

Write-Status "DEPLOYMENT SUCCESSFUL!"
cd ../../../