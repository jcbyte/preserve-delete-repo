param(
    $DeleteRepo,
    $MonoRepo
)

Import-Module (Join-Path $PSScriptRoot "Util")

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
  Write-Warning "Git was not found, please install it first"
  exit 1
}

if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
  Write-Warning "Python was not found, please install it first"
  exit 1
}

python -m git_ilter_repo --version | Out-Null
if (-not $?) {
  Write-Warning "git-filter-repo was not found, please install it first"
  Write-Host "run: " -NoNewline
  Write-Host "python -m pip install git-filter-repo" -ForegroundColor Cyan
  exit 1
}

# check that git and git filter tools is installed

# create temporary directory

# clone both repositories, don't actually need data...

# move deleting repository to a subfolder

# merge into monorepo

# probably user confirmation, then push monorepo and delete

