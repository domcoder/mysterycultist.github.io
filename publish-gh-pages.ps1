$publicDir = "public"
$targetBranch = "gh-pages"
$repoRoot = git rev-parse --show-toplevel
$tmpDir = Join-Path $env:TEMP ("gh-pages-" + [guid]::NewGuid().ToString())

# Ensure we're starting in repo root
Set-Location $repoRoot

# Check for existing worktree
$existingWorktrees = git worktree list | Select-String $targetBranch
if ($existingWorktrees) {
    Write-Host "Removing existing worktree for $targetBranch"
    $existingPath = ($existingWorktrees -split ' ')[0]
    git worktree remove $existingPath -f
}

New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    # Generate site
    hugo --cleanDestinationDir --destination $publicDir

    # Fetch remote branch if it exists
    git fetch origin $targetBranch 2>$null

    # Add worktree
    git worktree add -B $targetBranch $tmpDir origin/$targetBranch

    # Clear tmpDir (except .git)
    Get-ChildItem -Path $tmpDir -Force |
        Where-Object { $_.Name -ne ".git" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Copy site contents
    Copy-Item -Path (Join-Path $repoRoot $publicDir "*") -Destination $tmpDir -Recurse -Force

    Push-Location $tmpDir
    git add .

    if ((git status --porcelain).Length -eq 0) {
        Write-Host "Nothing to commit, site is up to date."
    } else {
        git commit -m "Deploy public folder to gh-pages"
        git push -u origin $targetBranch --force-with-lease
    }
    Pop-Location
}
finally {
    # Always return to repo root before cleanup
    Set-Location $repoRoot
    if (Test-Path $tmpDir) {
        git worktree remove $tmpDir -f
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}