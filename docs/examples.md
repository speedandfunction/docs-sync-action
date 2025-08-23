# Usage Examples

## Quick Navigation

| Need | Link |
|------|----------|
| Quick Start Guide | [Quick Start Guide](quick-start.md) |
| Fixing errors | [Troubleshooting Guide](troubleshooting.md) |

## Basic Examples

### Example 1: First-Time Setup
```bash
# Set up environment variables
export OUTLINE_TOKEN="sk_1234567890abcdef"
export OUTLINE_PARENT_DOCUMENT_ID="doc_abc123"

# Test the setup
./scripts/docs-sync.sh --dry-run --verbose

# Run actual sync
# Minimal output (default)
./scripts/docs-sync.sh./scripts/docs-sync.sh --verbose
```

### Example 2: Sync Specific Directory
```bash
# Sync documentation from custom directory
./scripts/docs-sync.sh --source-dir ./documentation --verbose

# Or use positional argument
./scripts/docs-sync.sh --verbose ./documentation
```

### Example 3: Override Configuration
```bash
# Override all settings via command line
./scripts/docs-sync.sh \
  --outline-url "https://wiki.example.com" \
  --outline-token "sk_override_token" \
  --outline-parent-document-id "doc_override" \
  --source-dir ./custom-docs \
  --verbose
```

## Advanced Examples

### Example 4: GitHub Actions Integration
```yaml
# .github/workflows/docs-sync.yml
name: Sync Documentation
on:
  push:
    branches: [main]
    paths: ['docs/**']

jobs:
  sync-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Sync to Outline Wiki
        env:
          OUTLINE_TOKEN: ${{ secrets.OUTLINE_TOKEN }}
          OUTLINE_PARENT_DOCUMENT_ID: ${{ secrets.OUTLINE_PARENT_DOC_ID }}
        run: |
          chmod +x scripts/docs-sync.sh
          ./scripts/docs-sync.sh --verbose
```

### Example 5: CI/CD Pipeline Integration
```bash
#!/bin/bash
# ci/sync-docs.sh

set -e

# Load environment from CI variables
export OUTLINE_TOKEN="$CI_OUTLINE_TOKEN"
export OUTLINE_PARENT_DOCUMENT_ID="$CI_OUTLINE_PARENT_ID"

# Validate before sync
echo "Validating configuration..."
./scripts/docs-sync.sh --dry-run --verbose

# Perform sync
echo "Syncing documentation..."
./scripts/docs-sync.sh --verbose

echo "Documentation sync completed!"
```

### Example 6: Local Development Workflow
```bash
#!/bin/bash
# scripts/dev-sync.sh

# Development sync script
echo "🔄 Syncing documentation for development..."

# Use development parent document
export OUTLINE_PARENT_DOCUMENT_ID="dev_doc_123"

# Always dry-run first
echo "📋 Testing sync..."
./scripts/docs-sync.sh --dry-run --verbose

# Ask for confirmation
read -p "Proceed with actual sync? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Performing sync..."
    ./scripts/docs-sync.sh --verbose
    echo "✅ Sync completed!"
else
    echo "❌ Sync cancelled."
fi
```

## File Structure Examples

### Example 7: Simple Documentation Structure
```
docs/
├── README.md
├── installation.md
├── configuration.md
└── troubleshooting.md
```

**Result in Outline Wiki:**
- README
- Installation
- Configuration
- Troubleshooting

### Example 8: Hierarchical Documentation Structure
```
docs/
├── getting-started/
│   ├── installation.md
│   ├── configuration.md
│   └── first-steps.md
├── user-guide/
│   ├── basic-usage.md
│   ├── advanced-features.md
│   └── examples.md
└── reference/
    ├── api.md
    ├── cli.md
    └── config.md
```

**Result in Outline Wiki:**
- getting-started/
  - Installation
  - Configuration
  - First Steps
- user-guide/
  - Basic Usage
  - Advanced Features
  - Examples
- reference/
  - API
  - CLI
  - Config

## Markdown File Examples

### Example 9: Proper Markdown Structure
```markdown
# Installation Guide

This guide covers the installation process.

## Prerequisites

- Node.js 16+
- Git

## Steps

1. Clone the repository
2. Install dependencies
3. Configure settings
```

### Example 10: YAML Front Matter (Will be Removed)
```markdown
---
title: "Custom Title"
date: 2024-01-01
author: "Team"
---

# Installation Guide

Content here...
```

**Note:** YAML front matter is automatically removed during sync.

## Error Handling Examples

### Example 11: Graceful Error Handling
```bash
#!/bin/bash
# scripts/safe-sync.sh

set -e

echo "Starting documentation sync..."

# Test connection first
if ! ./scripts/docs-sync.sh --dry-run --verbose; then
    echo "❌ Configuration test failed"
    exit 1
fi

# Perform sync with error handling
if ./scripts/docs-sync.sh --verbose; then
    echo "✅ Sync completed successfully"
else
    echo "❌ Sync failed"
    exit 1
fi
```

### Example 12: Backup Before Sync
```bash
#!/bin/bash
# scripts/backup-sync.sh

# Create backup timestamp
BACKUP_DIR="backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup current docs
echo "📦 Creating backup..."
cp -r docs/ "$BACKUP_DIR/"

# Perform sync
echo "🔄 Syncing documentation..."
./scripts/docs-sync.sh --verbose

echo "✅ Sync completed. Backup saved to $BACKUP_DIR"
```

## Monitoring and Logging

### Example 13: Log File Output
```bash
# Redirect output to log file
./scripts/docs-sync.sh --verbose 2>&1 | tee sync.log

# Check for errors
if grep -q "❌" sync.log; then
    echo "Errors found in sync log"
    exit 1
fi
```

### Example 14: Email Notification
```bash
#!/bin/bash
# scripts/sync-with-notification.sh

# Perform sync
./scripts/docs-sync.sh --verbose > sync.log 2>&1

# Check result and notify
if [ $? -eq 0 ]; then
    echo "Documentation sync completed successfully" | mail -s "Docs Sync Success" team@company.com
else
    echo "Documentation sync failed. Check logs." | mail -s "Docs Sync Failed" team@company.com
fi
```
