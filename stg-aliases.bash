#!/bin/bash

# Apply modifications to another patch and return to current patch 
function stg-apply-to {
	_current=$(stg series | grep '>' | awk '{print $NF}')
	git stash && stg goto "${1}" && git stash pop && stg refresh && stg goto "${_current}"
}

# Delete patch but keep local changes
function stg-unstage {
	_current=$(stg series | grep '>' | awk '{print $NF}')
  _current_msg="$(stg show ${_current} | tail -n +5)"
  stg delete --spill "${_current}" && stg new "${_current}" -m "${_current_msg}"
}

# Add and refesh all conflicts
function stg-resolve {
	git status --short | grep '^UU' | awk '{print $2}' | xargs git add
	stg refresh
}

