param(
  [Parameter(Mandatory = $true)]
  [string]$DeleteRepo,
  [Parameter(Mandatory = $true)]
  [string]$ArchiveRepo
)

# Create a new temporary directory and return its path
function New-TemporaryDirectory {
  $TmpDir = [System.IO.Path]::GetTempPath()
  $Name = (New-Guid).ToString("N") # ? HIghly unlikely change of collision
  $Path = Join-Path $TmpDir $Name
  New-Item -ItemType Directory -Path $Path | Out-Null
  return $Path
}

# Create a spinner which will spin until the ScriptBlock finishes executing
function Start-Spinner {
  param (
    [string]$Message,
    [scriptblock]$ScriptBlock
  )
    
  # Spinner animation
  $Spinner = @("◜", "◠", "◝", "◞", "◡", "◟")
  
  # Start the script block in the background
  $Job = Start-Job -ScriptBlock $ScriptBlock
  [Console]::CursorVisible = $false
  
  # Loop while the background task is running
  $SpinnerI = 0
  while ($Job.State -eq 'Running') {
    Write-Host -NoNewline "`r$($Spinner[$SpinnerI]) $Message..."
    $SpinnerI = ($SpinnerI + 1) % $Spinner.Length
    Start-Sleep -Milliseconds 150
  }

  # Clean up the line and restore cursor
  Write-Host -NoNewline ("`r" + (" " * ([Console]::WindowWidth - 1)) + "`r")
  [Console]::CursorVisible = $true
  
  # Retrieve output, and remove job
  $JobOutput = Receive-Job -Job $Job
  # `COMMAND_FAILED` can be printed to flag this
  $JobFailed = $Job.ChildJobs[0].Error -or $Job.State -eq 'Failed' -or $JobOutput -contains "COMMAND_FAILED"
  Remove-Job -Job $Job

  return -not $JobFailed
}


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
$TempDir = New-TemporaryDirectory

# Clone the mono-repo of deleted repositories
$MonoRepoDir = Join-Path $TempDir "mono"
git clone "$MonoRepo" "$MonoRepoDir"

# Clone the repository to be deleted
$DeleteRepoDir = Join-Path $TempDir "del"
git clone "$DeleteRepo" "$DeleteRepoDir"

# Create the folder name for the deleted repository in the mono-repo by time and original name
$DeleteRepoName = [System.IO.Path]::GetFileNameWithoutExtension($DeleteRepo)
$DateNow = Get-Date -Format "yyyy-MM-dd"
$PreservedName = "$DateNow-$DeleteRepoName"

# Modify Git history, so that all files are placed within a subfolder
python -m git_filter_repo --source "$DeleteRepoDir" --target "$DeleteRepoDir" --to-subdirectory-filter "$PreservedName"

# Merge the modified to-delete repo into the mono-repo
git -C "$MonoRepoDir" remote add del-repo "$DeleteRepoDir"
git -C "$MonoRepoDir" fetch del-repo
git -C "$MonoRepoDir" merge del-repo --allow-unrelated-histories -m "Archived ""$DeleteRepoName"" repository"
git -C "$MonoRepoDir" remote remove del-repo

# Allow the user to confirm changes before pushing
$Confirm = Read-Host "Are you sure you want to archive `"$DeleteRepoName`" into the mono-repo as `"$PreservedName`"? (Y/N)"
if ($Confirm -match "^[yY](es)?$") {
  # If the user approves, push the updated mono-repo with added archive
  git -C "$MonoRepoDir" push
  Write-Host "Archive added, you may now delete `"$DeleteRepoName`" ($DeleteRepo)"
}

# Cleanup by removing the temporary directory
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
