param(
    [string]$DeleteRepo,
    [string]$MonoRepo
)

Import-Module (Join-Path $PSScriptRoot "Util")

# Check that Git is installed and alliable on path
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
  Write-Warning "Git was not found, please install it first"
  exit 1
}

# Check that Python is installed and alliable on path, in order to use git-filter-repo
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
  Write-Warning "Python was not found, please install it first"
  exit 1
}

# Check that git-filter-repo is installed though python
python -m git_filter_repo --version | Out-Null
if (-not $?) {
  Write-Warning "git-filter-repo was not found, please install it first"
  Write-Host "run: " -NoNewline
  Write-Host "python -m pip install git-filter-repo" -ForegroundColor Cyan
  exit 1
}

# Create temporary directory to perform repository operations
# $TempDir = New-TemporaryDirectory
$TempDir = "C:\Users\joelc\Desktop\preserve-delete-repo\tempdir"

# Clone the mono-repo of deleted repositories
$MonoRepoDir = Join-Path $TempDir "mono"
git clone --bare $MonoRepo $MonoRepoDir

# Clone the repository to be deleted
$DeleteRepoDir = Join-Path $TempDir "del"
git clone --bare $DeleteRepo $DeleteRepoDir




# move deleting repository to a subfolder

# merge into monorepo

# probably user confirmation, then push monorepo and delete

