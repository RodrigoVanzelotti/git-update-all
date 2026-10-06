[CmdletBinding()]
param(
	[Parameter(Position = 0)]
	[string]$BranchName = "main"
)

$SpecificBranchRequested = $BranchName -ne "main"

# Validate branch name before touching any repository
git check-ref-format --branch "$BranchName" *> $null

if ($LASTEXITCODE -ne 0) {
	Write-Host "Invalid Git branch name: '$BranchName'"
	exit 1
}

Get-ChildItem -Directory | ForEach-Object {
	$repoName = $_.Name
	$repoPath = $_.FullName

	Push-Location $repoPath

	try {
		#
		# Check if this is a Git repository
		#

		git rev-parse --is-inside-work-tree *> $null

		if ($LASTEXITCODE -ne 0) {
			return
		}

		Write-Host ""
		Write-Host "========================================"
		Write-Host "Repository: $repoName"
		Write-Host "========================================"

		#
		# DEFAULT BEHAVIOR
		#
		# git update-all
		#
		# Require clean tree -> checkout main -> pull latest main
		#

		if (-not $SpecificBranchRequested) {
			$status = git status --porcelain

			if ($status) {
				Write-Host "Skipping ${repoName}: working tree is dirty"
				return
			}

			git show-ref --verify --quiet "refs/heads/main"

			if ($LASTEXITCODE -ne 0) {
				Write-Host "Local main branch not found. Checking origin..."

				git ls-remote --exit-code --heads origin "refs/heads/main" *> $null
				$remoteMainExitCode = $LASTEXITCODE

				if ($remoteMainExitCode -eq 0) {
					Write-Host "Fetching origin/main..."

					git fetch origin "refs/heads/main:refs/remotes/origin/main"

					if ($LASTEXITCODE -ne 0) {
						Write-Host "Skipping ${repoName}: failed to fetch origin/main"
						return
					}

					git checkout -b main --track origin/main

					if ($LASTEXITCODE -ne 0) {
						Write-Host "Skipping ${repoName}: failed to create local main"
						return
					}
				}
				else {
					Write-Host "Skipping ${repoName}: main branch does not exist locally or on origin"
					return
				}
			}
			else {
				Write-Host "Checking out main..."

				git checkout main

				if ($LASTEXITCODE -ne 0) {
					Write-Host "Skipping ${repoName}: could not checkout main"
					return
				}
			}

			Write-Host "Pulling latest main..."

			git pull --ff-only

			if ($LASTEXITCODE -ne 0) {
				Write-Host "${repoName}: pull failed on main"
				return
			}

			Write-Host "${repoName}: main is up to date"
			return
		}

		#
		# SPECIFIC BRANCH BEHAVIOR
		#
		# git update-all feature/my-feature
		#

		#
		# STEP 1:
		# Does the branch already exist locally?
		#

		git show-ref --verify --quiet "refs/heads/$BranchName"
		$localBranchExists = $LASTEXITCODE -eq 0

		if ($localBranchExists) {
			#
			# Existing branch:
			# require a clean working tree before switching
			#

			$status = git status --porcelain

			if ($status) {
				Write-Host "Skipping ${repoName}: branch '$BranchName' exists, but working tree is dirty"
				return
			}

			Write-Host "Checking out $BranchName..."

			git checkout "$BranchName"

			if ($LASTEXITCODE -ne 0) {
				Write-Host "${repoName}: could not checkout $BranchName"
				return
			}

			#
			# First try pulling using the branch's configured upstream
			#

			$upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null

			if ($LASTEXITCODE -eq 0 -and $upstream) {
				Write-Host "Pulling latest $BranchName from $upstream..."

				git pull --ff-only

				if ($LASTEXITCODE -ne 0) {
					Write-Host "${repoName}: pull failed on $BranchName"
					return
				}

				Write-Host "${repoName}: $BranchName is up to date"
				return
			}

			#
			# Branch has no upstream.
			# Check whether the same branch exists on origin.
			#

			Write-Host "$BranchName has no configured upstream. Checking origin..."

			git ls-remote --exit-code --heads origin "refs/heads/$BranchName" *> $null
			$remoteBranchExitCode = $LASTEXITCODE

			if ($remoteBranchExitCode -eq 0) {
				Write-Host "Found origin/$BranchName. Fetching..."

				git fetch origin "refs/heads/${BranchName}:refs/remotes/origin/${BranchName}"

				if ($LASTEXITCODE -ne 0) {
					Write-Host "${repoName}: failed to fetch origin/$BranchName"
					return
				}

				Write-Host "Setting upstream to origin/$BranchName..."

				git branch --set-upstream-to="origin/$BranchName" "$BranchName"

				if ($LASTEXITCODE -ne 0) {
					Write-Host "${repoName}: could not configure upstream"
					return
				}

				Write-Host "Pulling latest $BranchName..."

				git pull --ff-only

				if ($LASTEXITCODE -ne 0) {
					Write-Host "${repoName}: pull failed on $BranchName"
					return
				}

				Write-Host "${repoName}: $BranchName is up to date"
				return
			}

			if ($remoteBranchExitCode -eq 2) {
				Write-Host "${repoName}: $BranchName exists locally but does not exist on origin"
				Write-Host "${repoName}: checked out local $BranchName without pulling"
				return
			}

			Write-Host "${repoName}: could not verify $BranchName on origin"
			return
		}

		#
		# STEP 2:
		# Branch does not exist locally.
		#
		# Check whether it exists remotely.
		#
		# This does NOT modify the working tree, so it is safe even
		# when there are staged or unstaged changes.
		#

		Write-Host "Local branch '$BranchName' not found. Checking origin..."

		git ls-remote --exit-code --heads origin "refs/heads/$BranchName" *> $null
		$remoteBranchExitCode = $LASTEXITCODE

		if ($remoteBranchExitCode -eq 0) {
			#
			# Branch exists remotely.
			#
			# Because we are switching to an existing branch,
			# require a clean working tree.
			#

			$status = git status --porcelain

			if ($status) {
				Write-Host "Skipping ${repoName}: origin/$BranchName exists, but working tree is dirty"
				return
			}

			Write-Host "Found origin/$BranchName. Fetching..."

			git fetch origin "refs/heads/${BranchName}:refs/remotes/origin/${BranchName}"

			if ($LASTEXITCODE -ne 0) {
				Write-Host "${repoName}: failed to fetch origin/$BranchName"
				return
			}

			Write-Host "Creating local tracking branch $BranchName..."

			git checkout -b "$BranchName" --track "origin/$BranchName"

			if ($LASTEXITCODE -ne 0) {
				Write-Host "${repoName}: could not checkout origin/$BranchName"
				return
			}

			Write-Host "Pulling latest $BranchName..."

			git pull --ff-only

			if ($LASTEXITCODE -ne 0) {
				Write-Host "${repoName}: pull failed on $BranchName"
				return
			}

			Write-Host "${repoName}: $BranchName is up to date"
			return
		}

		#
		# ls-remote exit code 2 means the remote was reachable,
		# but the requested branch does not exist.
		#
		# Any other error may indicate network/authentication problems,
		# so we must NOT assume the branch doesn't exist.
		#

		if ($remoteBranchExitCode -ne 2) {
			Write-Host "${repoName}: could not verify whether '$BranchName' exists on origin"
			Write-Host "${repoName}: branch will not be created"
			return
		}

		#
		# STEP 3:
		# Branch does not exist locally OR remotely.
		#
		# This is the special case where a dirty working tree is allowed.
		#
		# Creating a new branch from the current HEAD preserves staged
		# and unstaged changes.
		#

		$currentBranch = git branch --show-current

		if (-not $currentBranch) {
			$currentBranch = "(detached HEAD)"
		}

		$status = git status --porcelain

		Write-Host ""
		Write-Host "Branch '$BranchName' does not exist locally or on origin."
		Write-Host "Current branch: $currentBranch"

		if ($status) {
			Write-Host "Working tree contains uncommitted changes."
			Write-Host "Those changes will be preserved on the new branch."
		}
		else {
			Write-Host "Working tree is clean."
		}

		$answer = Read-Host "Create '$BranchName' from the current HEAD? [y/N]"

		if ($answer -match '^(y|yes)$') {
			Write-Host "Creating $BranchName..."

			git checkout -b "$BranchName"

			if ($LASTEXITCODE -ne 0) {
				Write-Host "${repoName}: failed to create $BranchName"
				return
			}

			Write-Host "${repoName}: created and switched to $BranchName"

			if ($status) {
				Write-Host "${repoName}: existing working tree changes were preserved"
			}
		}
		else {
			Write-Host "${repoName}: branch creation skipped"
		}
	}
	finally {
		Pop-Location
	}
}