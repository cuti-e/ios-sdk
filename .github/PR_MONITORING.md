# PR Monitoring and Copilot Review Workflow

This guide explains how to monitor PRs and handle Copilot code review comments.

## Automatic Copilot Reviews

GitHub Copilot automatically reviews all PRs with:
- **Review on push**: Every new commit triggers a review
- **Review drafts**: Even draft PRs get reviewed early

## PR Monitoring Workflow

After creating a PR, follow this workflow:

### 1. Wait for CI Checks (30-60 seconds)
```bash
gh pr checks <pr-number>
```

### 2. Wait for Copilot Review (1-2 minutes)
Copilot typically reviews within 1-2 minutes. Check the PR page or:
```bash
gh pr view <pr-number> --json reviews --jq '.reviews[] | select(.author.login == "copilot") | {state, body}'
```

### 3. Check for Unresolved Conversations
```bash
./scripts/resolve-pr-conversations.sh <pr-number>
```

This script will:
- Show all unresolved review conversations
- Display the file, line, and comment
- Offer options to resolve or view in browser

### 4. Address or Resolve Comments

**Option A: Fix the issue**
- Make the suggested change
- Push a new commit
- Copilot will re-review

**Option B: Acknowledge and resolve**
- If the suggestion doesn't apply, resolve the conversation
- Use option 1 in the script to resolve all at once

### 5. Verify Auto-merge

Once all checks pass and conversations are resolved:
```bash
gh pr view <pr-number> --json state,mergedAt
```

## Quick Commands

```bash
# Check PR status
gh pr checks <number>

# View PR details
gh pr view <number>

# Resolve conversations
./scripts/resolve-pr-conversations.sh <number>

# Monitor until merged
watch -n 30 'gh pr view <number> --json state,mergedAt'
```

## Troubleshooting

### PR Not Merging
1. Check all CI checks passed: `gh pr checks <number>`
2. Check for unresolved conversations: `./scripts/resolve-pr-conversations.sh <number>`
3. Check branch protection: ensure auto-merge is enabled

### Copilot Not Reviewing
- PRs with < 10 lines changed may not trigger review
- Fork PRs don't get Copilot reviews
- Wait up to 5 minutes for large PRs

### Script Errors
Ensure you have:
- `gh` CLI installed and authenticated
- `jq` installed for JSON parsing
