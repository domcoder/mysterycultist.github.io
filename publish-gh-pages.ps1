$publicDir = "public"
$targetBranch = "gh-pages"
$tmpDir = Join-Path $env:TEMP ("gh-pages-" + [guid]::NewGuid().ToString())

New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    hugo --cleanDestinationDir

    git worktree add -B $targetBranch $tmpDir

    # Remove everything *except* .git
    Get-ChildItem -Path $tmpDir -Force |
        Where-Object { $_.Name -ne ".git" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $sourcePath = Join-Path (Get-Location) $publicDir
    if (-Not (Test-Path $sourcePath)) {
        Write-Error "Public folder '$publicDir' does not exist."
        exit 1
    }

    Copy-Item -Path "$sourcePath\*" -Destination $tmpDir -Recurse -Force

    Push-Location $tmpDir
    git add .
    git commit -m "Deploy public folder to gh-pages" 2>$null
    git push origin $targetBranch --force
    Pop-Location
}
finally {
    git worktree remove $tmpDir -f
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}