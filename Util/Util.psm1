# Create a new temporary directory and return its path
function New-TemporaryDirectory {
  $TmpDir = [System.IO.Path]::GetTempPath()
  $Name = (New-Guid).ToString("N") # ? HIghly unlikely change of collision
  $Path = Join-Path $TmpDir $Name
  New-Item -ItemType Directory -Path $Path | Out-Null
  return $Path
}
Export-ModuleMember -Function New-TemporaryDirectory