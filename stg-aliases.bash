#!/bin/bash

# Apply modifications to another patch and return to current patch 
function stg-apply-to {
	_current=$(stg series | grep '>' | awk '{print $NF}')
	git stash && stg goto "${1}" && git stash pop && stg refresh && stg goto "${_current}"
}

# Apply staged modifications to another patch and return to current patch 
function stg-apply-staged-to {
	_current=$(stg series | grep '>' | awk '{print $NF}')
	git stash --staged && stg goto "${1}" && git stash pop && stg refresh && stg goto "${_current}"
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
