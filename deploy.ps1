param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the name of the commit")]
    [string]$CommitName,
    [switch]$run
)

# We remove the global 'Stop' preference to prevent Git status from killing the script
$ErrorActionPreference = "Continue"

function Write-Header {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Black -BackgroundColor Cyan
}

function Test-NoSecrets {
    param([string]$SearchPath = ".")
    $patterns = @('.env', '.env.*', '*.pem', '*.key', '*.p12', '*.pfx',
                  'serviceAccountKey.json', 'google-services.json', 'GoogleService-Info.plist')
    foreach ($pattern in $patterns) {
        $found = Get-ChildItem -Path $SearchPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue |
                 Where-Object { !$_.PSIsContainer -and $_.FullName -notmatch '\\build\\' }
        if ($found) {
            Write-Host "[!] POTENTIAL SECRET FILE: $($found.FullName)" -ForegroundColor Red
            Write-Host "[!] Aborting -- remove or .gitignore it before committing." -ForegroundColor Red
            exit 1
        }
    }
}

function Invoke-SafeCommand {
    param([scriptblock]$Command)
    
    # Run the command. We use Write-Host with Gray to make it look different.
    # We don't pipe 2>&1 here to avoid the "RemoteException" crash.
    Write-Host "Running command..." -ForegroundColor DarkGray
    & $Command
    
    # This is the only truth: Did the program actually fail?
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Write-Host "`n[!] REAL ERROR: Command failed with exit code $LASTEXITCODE." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Header "STARTING DEPLOYMENT: $CommitName"

# 1. Update Source Repo
Write-Header "STEP 1: UPDATING SOURCE REPOSITORY"
Invoke-SafeCommand { git pull origin main }
Test-NoSecrets -SearchPath "."
Invoke-SafeCommand { git add . }

# Note: Git commit returns exit code 1 if there is nothing to commit.
# We wrap this in a try/catch or check to prevent the script from stopping if no changes exist.
$status = git status --porcelain
if ($status) {
    Invoke-SafeCommand { git commit -m "$CommitName" }
    Invoke-SafeCommand { git push origin main }
} else {
    Write-Host "No changes to commit in source." -ForegroundColor Yellow
}

# 2. Build Flutter Web
if (Test-Path "screen_time_checkup") {
    pushd screen_time_checkup
    Write-Header "STEP 2: BUILDING FLUTTER WEB"
    Invoke-SafeCommand { flutter build web --base-href /screentimecheckup/ }
    
    # 3. Deploy to GitHub Pages
    Write-Header "STEP 3: DEPLOYING TO GITHUB PAGES"
    if (Test-Path "build/web") {
        pushd build/web
        Test-NoSecrets -SearchPath "."
        Invoke-SafeCommand { git add . }
        
        $buildStatus = git status --porcelain
        if ($buildStatus) {
            Invoke-SafeCommand { git commit -m "$CommitName" }
            Invoke-SafeCommand { git push origin main }
        } else {
            Write-Host "No changes in build output." -ForegroundColor Yellow
        }
        popd 
    }
    popd 
} else {
    Write-Host "[!] Project folder 'screen_time_checkup' not found!" -ForegroundColor Red
    exit 1
}

Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY!" -BackgroundColor Green

if ($run) {
    Write-Header "Opening localhost:8080 in browser for testing..."
    pushd screen_time_checkup
    Invoke-SafeCommand {flutter run -d edge --web-port=8080}
    popd 
}