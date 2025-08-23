# Quick Start Guide

## Quick Navigation

| Need | Link |
|------|----------|
| Errors | [Troubleshooting](troubleshooting.md) |
| Examples | [Examples](examples.md) |## Overview
The `docs-sync.sh` script automatically synchronizes Markdown documentation from your local project to Outline Wiki, ensuring that internal links work correctly.

## Features

- **Memory-only operation**: Stores all data in memory, no temporary files created
- **Automatic synchronization**: Creates/updates documents and fixes internal links
- **Proper link formatting**: Converts relative links to full Outline Wiki URLs
- **Dry-run mode**: Test changes without making actual updates
- **Minimal output**: Clean, focused logging with verbose mode available
- **Folder structure support**: Maintains directory hierarchy in Outline Wiki

## Prerequisites
- **Bash shell** (Linux, macOS, or WSL on Windows)
- **curl** and **jq** installed
- **Outline Wiki API token** (get from https://wiki.gluzdov.com/settings/tokens)
- **Parent document ID** in Outline Wiki

## Quick Setup

### 1. Get Your API Token
1. Go to [Outline Wiki Settings](https://wiki.gluzdov.com/settings/tokens)
2. Create a new API token
3. Copy the token value

### 2. Set Environment Variables
```bash
export OUTLINE_TOKEN="your_api_token_here"
export OUTLINE_PARENT_DOCUMENT_ID="your_parent_doc_id"
```

### 3. Make Script Executable
```bash
chmod +x scripts/docs-sync.sh
```

### 4. Run the Script
```bash
# Basic usage (minimal output)
./scripts/docs-sync.sh

# With verbose output
./scripts/docs-sync.sh --verbose

# Dry run (test without changes)
./scripts/docs-sync.sh --dry-run --verbose

# Custom source directory
./scripts/docs-sync.sh --source-dir ./documentation
```

## Command Line Options

- `--dry-run`: Test changes without making actual updates
- `--verbose`: Enable detailed logging
- `--source-dir DIR`: Source directory for markdown files (default: ./docs)
- `--outline-url URL`: Outline Wiki base URL (overrides OUTLINE_URL env var)
- `--outline-token TOKEN`: Outline Wiki API token (overrides OUTLINE_TOKEN env var)
- `--outline-parent-document-id ID`: Parent document ID (overrides OUTLINE_PARENT_DOCUMENT_ID env var)
- `--help`: Show help message

## Environment Variables

- `OUTLINE_URL`: Outline Wiki base URL (default: https://wiki.gluzdov.com/)
- `OUTLINE_TOKEN`: Outline Wiki API token (required)
- `OUTLINE_PARENT_DOCUMENT_ID`: Parent document ID (required)
- `SOURCE_DIR`: Source directory for markdown files (default: ./docs)
- `DRY_RUN`: Enable dry-run mode
- `VERBOSE`: Enable verbose logging

## What It Does

### Document Creation
1. **Scans** your source directory for `.md` files
2. **Extracts** titles from Markdown headers
3. **Creates** documents in Outline Wiki with same titles
4. **Maintains** folder structure as document hierarchy
5. **Updates** existing documents if they already exist

### Link Processing
5. **Builds URL mapping** from all documents in Outline Wiki
6. **Replaces local markdown links** with clickable Outline Wiki URLs
7. **Updates** all documents with corrected cross-references

## Examples

```bash
# Dry run with verbose output
./scripts/docs-sync.sh --dry-run --verbose --outline-parent-document-id "sync-docs-87nhl4t2uD" ./docs/sync-script

# Real synchronization (minimal output)
./scripts/docs-sync.sh --outline-parent-document-id "sync-docs-87nhl4t2uD" ./docs/sync-script

# Use environment variables (recommended for GitHub Actions)
./scripts/docs-sync.sh --verbose

# Override with command-line arguments
./scripts/docs-sync.sh --outline-url "https://wiki.example.com" --outline-token "token123" --outline-parent-document-id "doc456"

# Dry run with custom source directory
./scripts/docs-sync.sh --dry-run --source-dir ./documentation --verbose
```

## Common Use Cases
- **Initial sync**: First time uploading documentation
- **Regular updates**: Keep wiki in sync with code changes
- **Testing**: Use `--dry-run` to see what would happen
- **CI/CD integration**: Automated documentation updates

## Troubleshooting

### Getting Help
- **Script help**: `./scripts/docs-sync.sh --help`
- **Error messages**: Check troubleshooting section below
- **Verbose mode**: Use `--verbose` for detailed output

### Common Issues

#### Links not working
- Ensure you're using the latest version of the script
- Check that documents exist in Outline Wiki
- Verify API token has proper permissions

#### Empty documents
- Check source markdown files for content
- Verify API connection and authentication
- Use verbose mode for detailed error messages

#### API connection issues
- Verify OUTLINE_URL is correct (should be: https://wiki.gluzdov.com)
- Check OUTLINE_TOKEN is valid and not expired
- Ensure OUTLINE_PARENT_DOCUMENT_ID exists

### Security Notes

- API tokens are masked in logs for security (shows only first 8 characters)
- Use environment variables for sensitive data
- HTTPS is required for production use
- No credentials are stored in script files
- No temporary files are created (memory-only operation)

## Contributing

If you find issues or have suggestions:

1. Test with `--dry-run` mode first
2. Enable verbose logging with `--verbose`
3. Report issues with detailed error messages
4. Check that all prerequisites are met

---

**Last updated**: December 2024  
**Script version**: 4.0 (Minimal & Clean)  
**Compatible with**: Outline Wiki API v1
