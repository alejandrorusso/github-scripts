#!/bin/bash

# === CONFIGURATION ===
BITBUCKET_USER="<bitbucker user>"
BITBUCKET_TOKEN="<token>"
BITBUCKET_WORKSPACE="russo"     # e.g. "myteam"
UNTITLED_PROJECT_KEY="PROJ" 
MIGRATED_PROJECT_KEY="MIG"
GITHUB_ORG="<github user>"           # GitHub org or user account
GITHUB_TOK="<token>"

# Ensure dependencies are available
command -v jq >/dev/null 2>&1 || { echo >&2 "❌ 'jq' is required but not installed. Aborting."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo >&2 "❌ 'gh' (GitHub CLI) is required but not installed. Aborting."; exit 1; }

# === Fetch Repositories from Bitbucket ===
echo "🔍 Fetching repositories from Bitbucket project '$UNTITLED_PROJECT_KEY'..."

REPOS=$(curl -s -u $BITBUCKET_USER:$BITBUCKET_TOKEN \
  "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE?q=project.key=\"${UNTITLED_PROJECT_KEY}\"" \
  | jq -r '.values[].slug')

if [ -z "$REPOS" ]; then
  echo "⚠️  No repositories found in project '$UNTITLED_PROJECT_KEY'. Exiting."
  exit 0
fi

AUTO_CONFIRM=false

for repo in $REPOS; do
  echo "------------------------------------------"
  echo "📦 Repository: $repo"
  echo "🔗 Bitbucket: https://bitbucket.org/$BITBUCKET_WORKSPACE/$repo.git"
  echo "🔗 GitHub:    https://github.com/$GITHUB_ORG/$repo.git"
  echo "------------------------------------------"

  if [ "$AUTO_CONFIRM" = false ]; then
    echo "Options:"
    echo "  [y] - migrate this repo"
    echo "  [n] - skip this repo"
    echo "  [a] - migrate this and all remaining repos"
    read -p "What do you want to do? [y/n/a]: " confirm

    case "$confirm" in
      y|Y)
        echo "✅ Proceeding with $repo..."
        ;;
      a|A)
        echo "🔁 Auto-confirm enabled. Proceeding with $repo and all remaining..."
        AUTO_CONFIRM=true
        ;;
      *)
        echo "⏭️  Skipping $repo."
        continue
        ;;
    esac
  else
    echo "⚙️  Auto-confirm: migrating $repo..."
  fi

  # === Clone from Bitbucket ===
  echo "📥 Cloning $repo from Bitbucket..."
  git clone --mirror "https://$BITBUCKET_USER:$BITBUCKET_TOKEN@bitbucket.org/$BITBUCKET_WORKSPACE/$repo.git"
  cd "$repo.git" || { echo "❌ Failed to enter $repo.git directory"; exit 1; }

  # === Authenticate with GitHub ===
  echo "🔑 Authenticating with GitHub..."
  echo $GITHUB_TOK | gh auth login --with-token 

  # === Create GitHub Repo ===
  echo "📂 Creating GitHub repository..."
  gh repo create "git@github.com:$GITHUB_ORG/$repo.git" --private 

  # === Push all refs ===
  echo "🚀 Pushing all branches and tags to GitHub..."
  git push --mirror "git@github.com:$GITHUB_ORG/$repo.git"

  cd ..
  rm -rf "$repo.git"

  # === Move Bitbucket repo to MigratedGitHub ===
  echo "📦 Moving Bitbucket repo to project '$MIGRATED_PROJECT_KEY'..."
  curl -s -X PUT -u $BITBUCKET_USER:$BITBUCKET_TOKEN \
    -H "Content-Type: application/json" \
    -d "{\"project\": {\"key\": \"$MIGRATED_PROJECT_KEY\"}}" \
    "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$repo" \
    > /dev/null

  echo "✅ Migration of $repo completed."
done

echo "🎉 All selected repositories have been processed."

