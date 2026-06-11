#!/bin/bash

# Apply modifications to another patch and return to current patch 
function stg-apply-to {
	_current=$(stg series | grep '>' | awk '{print $NF}')
	git stash && stg goto "${1}" && git stash pop && stg refresh && stg goto "${_current}"
}

# Apply staged modifications to another patch and return to current patch 
function stg-apply-staged-to {
	_current=$(stg series | grep '>' | awk '{print $NF}')
	echo "Stashing changes at $(pwd)"
	if ! git stash --staged; then
		echo "Failed to stash staged changes"
		return 1
	fi
	if ! git stash; then
		echo "Failed to stash unstaged changes"
		return 1
	fi
	if ! stg goto "${1}"; then
		echo "Failed to goto patch ${1}"
		return 1
	fi
	if ! git stash apply stash@{1}; then
		echo "Failed to apply staged changes"
		return 1
	fi
	if ! git stash drop stash@{1}; then
		echo "Failed to drop staged stash"
		return 1
	fi
	if ! stg refresh; then
		echo "Failed to refresh patch"
		return 1
	fi
	if ! stg goto "${_current}"; then
		echo "Failed to return to patch ${_current}"
		return 1
	fi
	if ! git stash pop; then
		echo "Failed to pop stashed changes"
		return 1
	fi
}

# Empty patch but keep local changes
function stg-spill {
	_current=$(stg series | grep '>' | awk '{print $NF}')
  _current_msg="$(stg show ${_current} | tail -n +5)"
  stg delete --spill "${_current}" && stg new "${_current}" -m "${_current_msg}"
}

# Add and refesh all conflicts
function stg-resolve {
	git status --short | grep -E '^(UU|AA|AU|UA)' | awk '{print $2}' | xargs git add
	stg refresh
}

# Quick new patch with default message
function stg-new {
  stg new "${1}" -m "${1}"
}

# Create new patch with staged changes after specified patch (or current) and return
# Usage: stg-staged-new-after <new_patch_name> [<after_patch_name>]
function stg-staged-new-after {
	local new_patch="${1}"
	local after_patch="${2}"
	local _current=$(stg series | grep '>' | awk '{print $NF}')

	# Default to current patch if not specified
	if [[ -z "${after_patch}" ]]; then
		after_patch="${_current}"
	fi

	echo "Creating new patch '${new_patch}' with staged changes after '${after_patch}'"

	if ! git stash --staged; then
		echo "Failed to stash staged changes"
		return 1
	fi
	if ! git stash; then
		echo "Failed to stash unstaged changes"
		git stash pop stash@{1} 2>/dev/null || true
		return 1
	fi
	if ! stg goto "${after_patch}"; then
		echo "Failed to goto patch ${after_patch}"
		git stash pop stash@{0} 2>/dev/null || true
		git stash drop stash@{1} 2>/dev/null || true
		return 1
	fi
	if ! stg new "${new_patch}" -m "${new_patch}"; then
		echo "Failed to create new patch ${new_patch}"
		git stash pop stash@{0} 2>/dev/null || true
		git stash drop stash@{1} 2>/dev/null || true
		return 1
	fi
	if ! git stash apply stash@{1}; then
		echo "Failed to apply staged changes to new patch"
		stg delete --spill "${new_patch}" 2>/dev/null || true
		git stash pop stash@{0} 2>/dev/null || true
		git stash drop stash@{1} 2>/dev/null || true
		return 1
	fi
	if ! git stash drop stash@{1}; then
		echo "Failed to drop staged stash"
		return 1
	fi
	if ! stg refresh; then
		echo "Failed to refresh new patch with staged changes"
		return 1
	fi
	if ! stg goto "${_current}"; then
		echo "Failed to return to patch ${_current}"
		return 1
	fi
	if ! git stash pop; then
		echo "Failed to restore unstaged changes"
		return 1
	fi
	echo "Successfully created new patch '${new_patch}' with staged changes after '${after_patch}'"
}
