#!/bin/bash
# check-spec-patches.sh
#	usage:
#		check-spec-patches.sh <specfile>
#	specfile: valid specfile.
#
# Description:
#    This script checks that:
#      a) Specfile applies patches that were specified by `PatchN:`
#         i.e. for every PatchN there is %patchN
#      b) Each patch exists in the current directory
#         i.e. For every PatchN: <file.patch> there is <file.patch> in the current directory.
#      c) Each Patch in directory is tracked in git
#         i.e. Every <file.patch> is commited in git
#    If any of the rules is broken then the script throws an error.
#
# Dependencies: Ruby interpreter, bash

function die {
	for var in "$@"
	do
		echo -e "$var" 1>&2
	done
	exit 1
}

# Accepts single argument with the header content.
function format_header {
	printf "==== %s ====" "${1}"
}

file="$1"

if [ -z "$file" ]; then
	die "No specfile supplied"
fi

sources=""
applied=""
existing=""

# Get patches that are packaged
sources=$(grep -e "^Patch[0-9]*:" $file | sort -n)
# Get patches that are applied
applied=$(sed -nr 's/%patch([0-9]+|[[:space:]]+[0-9]+[[:space:]]|[[:space:]]+-P [0-9]+[[:space:]]).*/\1/p' $file | tr -d -c "0-9\n" | sort -n)
# Get patches in current dir
if [ -z "$(ls $file)" ]; then
	die "No specfile found... are we in the correct directory?"
else
	existing=$(find "$PWD" -name "*.patch" -exec basename {} \; | sort)
fi

if [[ $(echo "$applied" | sort -n) == $(echo "$sources" | cut -d':' -f 1 | sed -nr 's/Patch([0-9]*)/\1/p'| sort -n)  ]]; then
	echo "Specfile applies all patches match ✓"
else
	die "Mismatch of patches in specfile" "$(format_header "Defined in specfile")" "$sources" "$(format_header "Applied in package")" "$applied"
fi

read -r -d '' RSCA << EOR
  existing = "$existing".split("\n").sort
  sources = "$sources".split("\n").map { |e| e.split(':') }.flatten.reject { |e| e =~ /^Patch/ }.sort.map(&:strip).sort
  puts (existing == sources)
EOR

if [[ $(ruby -e "$RSCA") == "true" ]]; then
	echo "Patches sources match ✓"
else
	die "Mismatch of sources" "$(format_header "Present in directory")" "$existing" "$(format_header "Defined in specfile")" "$(echo "$sources" | cut -d' ' -f 2 | sort -n)"
fi

git_patches=$(git ls-files | grep ".patch")

read -r -d '' RSCB << EOR
  sources = "$git_patches".split("\n").sort
  existing = "$sources"
    .split("\n")
    .map { |e| e.split(':') }
    .flatten
    .reject { |e| e =~ /^Patch/ }
    .map(&:strip)
    .sort
  puts (existing == sources)
EOR

if [[ $(ruby -e "$RSCB") == "true" ]]; then
	echo "All present patches commited in git are used ✓"
else
	# present_f="$(mktemp)"
	# git_f="$(mktemp)"
	# echo "$existing" | sort > "$present_f"
	# echo "$sources" | cut -d' ' -f 2 | sort > "$git_f"
	# diff -au "$present_f" "$git_f"
	die "Unused patches present in git" "$(format_header "Present in current directory")" "$(echo "$existing" | sort)" "$(format_header "Checked into git")" "$(echo "$sources" | cut -d' ' -f 2 | sort)"
fi
