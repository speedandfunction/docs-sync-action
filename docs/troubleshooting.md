# Troubleshooting Guide

## Quick Navigation

| Need | Link |
|------|----------|
| Quick Start | [Quick Start](quick-start.md) |
| Examples | [Examples](examples.md) |## Common Issues and Solutions

### 1. Authentication Errors

#### Problem: "OUTLINE_TOKEN not set"
```
❌ OUTLINE_TOKEN not set. Please provide it via environment variable OUTLINE_TOKEN or parameter --outline-token
```

**Solution:**
```bash
# Set environment variable
export OUTLINE_TOKEN="your_token_here"

# Or use command line argument
./scripts/docs-sync.sh --outline-token "your_token_here"
```

#### Problem: "Connection test failed"
```
❌ Connection test failed - check OUTLINE_URL and OUTLINE_TOKEN
```

**Solutions:**
1. Verify token is valid at https://wiki.gluzdov.com/settings/tokens
2. Check token hasn't expired
3. Ensure correct OUTLINE_URL format

### 2. Configuration Errors

#### Problem: "OUTLINE_PARENT_DOCUMENT_ID not set"
```
❌ OUTLINE_PARENT_DOCUMENT_ID not set
```

**Solution:**
```bash
# Get document ID from Outline Wiki URL
# URL format: https://wiki.gluzdov.com/doc/document-name-XXXXXX
# The XXXXXX part is your document ID

export OUTLINE_PARENT_DOCUMENT_ID="your_doc_id_here"
```

#### Problem: "Source directory not found"
```
❌ Source directory not found: ./docs
```

**Solutions:**
1. Create the docs directory: `mkdir -p docs`
2. Use different source: `./scripts/docs-sync.sh --source-dir ./documentation`

### 3. API Errors

#### Problem: "Invalid JSON response from API"
```
❌ Invalid JSON response from API: <!DOCTYPE html>...
```

**Causes:**
- Incorrect OUTLINE_URL
- Invalid API token
- Network connectivity issues

**Solutions:**
1. Verify OUTLINE_URL format: `https://wiki.gluzdov.com/`
2. Test API manually:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        "https://wiki.gluzdov.com/api/documents.list"
   ```

#### Problem: "Could not find parent document"
```
❌ Could not find parent document with URL ID: XXXXXX
```

**Solutions:**
1. Verify document ID exists in Outline Wiki
2. Check document permissions
3. Use UUID instead of URL ID

### 4. File Processing Errors

#### Problem: "Permission denied"
```
❌ Permission denied: ./docs/file.md
```

**Solutions:**
1. Check file permissions: `ls -la docs/`
2. Fix permissions: `chmod 644 docs/*.md`
3. Run with appropriate user permissions

#### Problem: Empty or corrupted files
```
✅ Created: (empty title)
```

**Solutions:**
1. Check file content: `cat docs/file.md`
2. Ensure files have proper Markdown headers
3. Verify file encoding (UTF-8)

### 5. Network Issues

#### Problem: "Connection timeout"
```
❌ curl: (7) Failed to connect to wiki.gluzdov.com
```

**Solutions:**
1. Check internet connectivity
2. Verify firewall settings
3. Try with verbose mode: `--verbose`

## Debug Mode

### Enable Verbose Logging
```bash
./scripts/docs-sync.sh --verbose
```

### Dry Run Testing
```bash
./scripts/docs-sync.sh --dry-run --verbose
```

### Manual API Testing
```bash
# Test connection
curl -H "Authorization: Bearer YOUR_TOKEN" \
     "https://wiki.gluzdov.com/api/documents.list"

# Test specific document
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"id":"DOCUMENT_ID"}' \
     "https://wiki.gluzdov.com/api/documents.info"
```

## Getting Help

### Check Script Help
```bash
./scripts/docs-sync.sh --help
```

### Verify Dependencies
```bash
# Check if required tools are installed
which curl
which jq
bash --version
```

### Log Analysis
Look for these patterns in output:
- `ℹ️` - Information messages
- `✅` - Success messages
- `❌` - Error messages
- `🔍` - Verbose debug messages (only with --verbose flag)
- `⚠️` - Warning messages

## Prevention Tips

1. **Always test with `--dry-run` first**
2. **Use environment variables for sensitive data**
3. **Keep API tokens secure and rotate regularly**
4. **Verify file structure before running**
5. **Check Outline Wiki permissions**
