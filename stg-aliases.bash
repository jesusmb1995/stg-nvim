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
	git status --short | grep '^UU' | awk '{print $2}' | xargs git add
	stg refresh
}

# Quick new patch with default message
function stg-new {
  stg new "${1}" -m "${1}"
}
