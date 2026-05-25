# preserve-delete-repo

A PowerShell script to archives a repository's history into an monolithic archive repository before deletion, preserving all commits and code history.

This script automates the process of archiving a repository you want to delete. Instead of losing all the code and commit history, it merges the repository into a dedicated archive repository, organising it by date and repository name.

## Prerequisites

- **Git** - Version control system
- **Python** - For running `git-filter-repo`
- **git-filter-repo** - Python package for rewriting Git history
- Read access to the to-delete repository
- Push access to the archive repository

Install `git-filter-repo` if not already installed:

```powershell
python -m pip install git-filter-repo
```

## Usage

```powershell
./Archive-Repo.ps1 -DeleteRepo <repository-url> -ArchiveRepo <archive-repository-url>
```

- **`-DeleteRepo`** (required): The URL of the repository to archive
- **`-ArchiveRepo`** (required): The URL of the archive repository where the history will be merged

## Notes

- The original repository URL is not affected by this process, you can safely delete the original repository after successful archival.
- All commit history is preserved in the archive repository, GitHub contributions (green boxes) will not be lost.
