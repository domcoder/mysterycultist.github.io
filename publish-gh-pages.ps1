$publicDir = "public"
$targetBranch = "gh-pages"
$tmpDir = Join-Path $env:TEMP ("gh-pages-" + [guid]::NewGuid().ToString())

New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    # Generate site
    hugo --cleanDestinationDir --destination $publicDir

    # Fetch remote branch if it exists
    git fetch origin $targetBranch 2>$null

    # Add worktree for the target branch
    git worktree add -B $targetBranch $tmpDir origin/$targetBranch

    # Remove all files except .git
    Get-ChildItem -Path $tmpDir -Force |
        Where-Object { $_.Name -ne ".git" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $sourcePath = Join-Path (Get-Location) $publicDir
    if (-Not (Test-Path $sourcePath)) {
        Write-Error "Public folder '$publicDir' does not exist."
        exit 1
    }

    # Copy site contents into worktree
    Get-ChildItem -Path $sourcePath -Recurse -Force |
        Copy-Item -Destination $tmpDir -Recurse -Force

    # Commit and push
    Push-Location $tmpDir

    git add .

    if ((git status --porcelain).Length -eq 0) {
        Write-Host "Nothing to commit, site is up to date."
    } else {
        git commit -m "Deploy public folder to gh-pages"

        # Avoid output buffering and use force-with-lease instead of --force
        git -c http.postBuffer=524288000 push -u origin $targetBranch --force-with-lease
    }

    Pop-Location

}
finally {
    # Clean up safely
    if ((Get-Location).Path -ne $tmpDir) {
        git worktree remove $tmpDir -f
    }
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
