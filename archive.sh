#!/bin/bash

# === CONFIGURATION ===
GITHUB_TOK="<token>"

# === Authenticate using the token ===
echo ${GITHUB_TOK} | gh auth login --with-token >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ Authentication failed. Exiting."
  exit 1
fi

# === Prompt for date (default: today) ===
default_date=$(date +%F)
read -p "Enter date (YYYY-MM-DD) [default: $default_date]: " target_date
target_date=${target_date:-$default_date}

# === Get authenticated username ===
user=$(gh api user --jq '.login')

# === Get repos created on the specified date ===
raw_repos=$(gh repo list "$user" --limit 1000 --json name,createdAt,isArchived)
repos=$(echo "$raw_repos" | jq -r --arg date "$target_date" '.[] | select( (type == "object") and (.createdAt | startswith($date)) and (.isArchived == false)) | .name')

if [ -z "$repos" ]; then
  echo "ℹ️ No repositories found for $target_date."
  exit 0
fi

echo "📦 Repositories created on $target_date:"
echo "$repos"
echo

archive_all_remaining=false

for repo in $repos; do
  if [ "$archive_all_remaining" = false ]; then
    read -p "Archive '$repo'? ([y]es / [n]o / [a]ll): " answer
    case "$answer" in
      [Yy]* )
        ;;
      [Aa]* )
        archive_all_remaining=true
        ;;
      * )
        echo "➡️ Skipping $repo."
        continue
        ;;
    esac
  fi

  echo "📁 Archiving $repo..."
  gh api -X PATCH "repos/$user/$repo" -f archived=true
done

echo "✅ Operation complete."

