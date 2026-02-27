# Define script parameters
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the name of the commit")]
    [string]$CommitName
)

echo "Starting deployment process for commit: $CommitName";
echo "Pulling latest changes from the repository...";
git pull origin main;
echo "Commiting source code changes with commit message: $CommitName";
git add .;
git commit -m "$CommitName";
echo "Pushing changes to the repository...";
git push origin main;
echo "Building the project for web at base-href /screentimecheckup/";
cd screen_time_checkup;
flutter build web --base-href /screentimecheckup/;
echo "Build process completed successfully!";
cd build/web;
echo "Deploying to GitHub Pages with commit message: $CommitName";
git add .;
git commit -m "$CommitName";
echo "Pushing changes to the repository...";
git push origin main;
echo "Deployment process completed successfully!";
cd ../../../;