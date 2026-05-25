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
  Write-Error "❌ Git was not found, please install it first"
  exit 1
}

# Check that Python is installed and alliable on path, in order to use git-filter-repo
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
  Write-Error "❌ Python was not found, please install it first"
  exit 1
}

# Check that git-filter-repo is installed though python
python -m git_filter_repo --version *> $null
if (-not $?) {
  Write-Error "❌ git-filter-repo was not found, please install it first"
  Write-Host "run: " -NoNewline
  Write-Host "python -m pip install git-filter-repo" -ForegroundColor Cyan
  exit 1
}

# Create temporary directory to perform repository operations
$TempDir = New-TemporaryDirectory

try {
  # Clone the archive repo of deleted repositories
  $ArchiveRepoDir = Join-Path $TempDir "arh"
  $Success = Start-Spinner "Cloning Archive Repository" {
    git clone "$using:ArchiveRepo" "$using:ArchiveRepoDir" *> $null
    if (-not $?) { return "COMMAND_FAILED" }
  }
  if ($Success) {
    Write-Host "✅ Cloned Archive Repository"
  }
  else {
    Write-Error "❌ Failed to clone Archive Repository ($ArchiveRepo)"
    exit 1
  }

  # Clone the repository to be deleted
  $DeleteRepoDir = Join-Path $TempDir "del"
  $Success = Start-Spinner "Cloning To-Delete-Repository" {
    git clone "$using:DeleteRepo" "$using:DeleteRepoDir" *> $null
    if (-not $?) { return "COMMAND_FAILED" }
  }
  if ($Success) {
    Write-Host "✅ Cloned To-Delete Repository"
  }
  else {
    Write-Error "❌ Failed to clone To-Delete Repository ($DeleteRepo)"
    exit 1
  }

  # Create the folder name for the deleted repository in the archive repo by time and original name
  $DeleteRepoName = [System.IO.Path]::GetFileNameWithoutExtension($DeleteRepo)
  $DateNow = Get-Date -Format "yyyy-MM-dd"
  $PreservedName = "$DateNow-$DeleteRepoName"

  $Success = Start-Spinner "Merging history into Archive Repository" {
    # Modify Git history, so that all files are placed within a subfolder
    python -m git_filter_repo --source "$using:DeleteRepoDir" --target "$using:DeleteRepoDir" --to-subdirectory-filter "$using:PreservedName" *> $null
    if (-not $?) { return "COMMAND_FAILED" }

    # Merge the modified to-delete repo into the archive repo
    git -C "$using:ArchiveRepoDir" remote add del-repo "$using:DeleteRepoDir" *> $null
    git -C "$using:ArchiveRepoDir" fetch del-repo *> $null
    git -C "$using:ArchiveRepoDir" merge del-repo --allow-unrelated-histories -m "Archived ""$using:DeleteRepoName"" repository" *> $null
    if (-not $?) { return "COMMAND_FAILED" }
    git -C "$using:ArchiveRepoDir" remote remove del-repo *> $null
  }
  if ($Success) {
    Write-Host "✅ Merged To-Delete Repository history into the Archive Repository"
  }
  else {
    Write-Error "❌ Failed to merge To-Delete Repository history"
    exit 1
  }

  # Allow the user to confirm changes before pushing
  Write-Host "Are you sure you want to archive " -NoNewline
  Write-Host $DeleteRepoName -NoNewline  -ForegroundColor Cyan
  Write-Host " into the Archive Repository as " -NoNewline
  Write-Host $PreservedName -NoNewline -ForegroundColor Cyan
  Write-Host "? " -NoNewline
  Write-Host "(y/n): " -NoNewline -ForegroundColor DarkGray
  $Confirm = Read-Host
  if ($Confirm -match "^[yY](es)?$") {
    # If the user approves, push the updated archive repo with added archive
    $Success = Start-Spinner "Pushing the updated Archive Repository" {
      git -C "$using:ArchiveRepoDir" push *> $null
      if (-not $?) { return "COMMAND_FAILED" }
    }
    if ($Success) {
      Write-Host "✅ Pushed updates into the Archive Repository"
      Write-Host "Archive added, you may now delete " -NoNewline
      Write-Host $DeleteRepoName -NoNewline -ForegroundColor Cyan
      Write-Host "($DeleteRepo)" -NoNewline -ForegroundColor DarkGray
    }
    else {
      Write-Error "❌ Failed to push updates to the Archive Repository"
      exit 1
    }
  }
  else {
    Write-Host "🗑️ Cancelled Archive"
  }
}
finally {
  # This always runs, even if exit is triggered in the try

  # Cleanup by removing the temporary directory
  Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
