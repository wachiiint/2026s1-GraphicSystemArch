#!/usr/bin/env bash
# Export the LAB selected in .env to an orphan branch loadable by vga-playground.com.
# Layout: info.yaml, src/*.v (from compilePath), data/*.mem (from dataPath).
# Does not touch the current checkout, index, or remote.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"

set -a; source .env; set +a
: "${compilePath:?missing in .env}" "${dataPath:?missing in .env}" "${exportBranch:?missing in .env}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tree="$tmp/tree"
mkdir -p "$tree/src" "$tree/data"

sources=("$compilePath"/*.v)
[ ${#sources[@]} -gt 0 ] || { echo "no .v files in $compilePath" >&2; exit 1; }
cp "${sources[@]}" "$tree/src/"
mems=("$dataPath"/*.mem)
[ ${#mems[@]} -gt 0 ] && cp "${mems[@]}" "$tree/data/"

{
  echo "project:"
  echo "  title: \"${exportTitle:-}\""
  echo "  author: \"${exportAuthor:-}\""
  echo "  language: \"Verilog\""
  echo "  clock_hz: 25175000"
  echo "  source_files:"
  for f in "${sources[@]}"; do echo "    - \"$(basename "$f")\""; done
  echo "yaml_version: 6"
} > "$tree/info.yaml"

# Build the commit in a throwaway index; -f because .gitignore excludes *.mem
export GIT_INDEX_FILE="$tmp/index"
git --work-tree="$tree" add -A -f
commit=$(git commit-tree "$(git write-tree)" -m "export: $compilePath")
git update-ref "refs/heads/$exportBranch" "$commit"

repo=$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')
echo "Exported $compilePath + $dataPath -> branch $exportBranch"
echo "Push:  git push -f origin $exportBranch"
echo "Open:  https://vga-playground.com/?repo=$repo&ref=$exportBranch"
