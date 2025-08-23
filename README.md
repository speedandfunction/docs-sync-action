# Docs Sync Action

A GitHub Action that automatically synchronizes markdown documentation with [Outline Wiki](https://www.getoutline.com/), enabling seamless documentation management between your repository and wiki system.

## 🚀 Features

- **Automatic Synchronization**: Sync markdown files from your repository to Outline Wiki
- **Smart Document Matching**: Matches files by title to existing wiki documents
- **Hierarchical Structure**: Maintains folder structure in your wiki
- **Dry Run Mode**: Test synchronization without making changes
- **Verbose Logging**: Detailed logging for debugging and monitoring
- **Link Replacement**: Automatically updates internal links between documents
- **Error Handling**: Robust error handling with graceful degradation

## 📋 Prerequisites

- GitHub repository with markdown documentation
- Outline Wiki instance with API access
- Outline Wiki API token
- Parent document ID in your wiki

## 🔧 Installation

### 1. Add the Action to Your Workflow

Create or update your `.github/workflows/docs-sync.yml`:

```yaml
name: Sync Documentation

on:
  push:
    branches: [ main ]
    paths: [ 'docs/**' ]
  workflow_dispatch:

jobs:
  sync-docs:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Sync docs to Outline Wiki
        uses: ./
        with:
          outline_url: 'https://your-wiki.getoutline.com/'
          outline_token: ${{ secrets.OUTLINE_TOKEN }}
          outline_parent_document_id: 'your-parent-document-id'
          source_dir: './docs'
          dry_run: 'false'
          verbose: 'true'
```

### 2. Configure Secrets

Add your Outline Wiki API token to your repository secrets:

1. Go to your repository Settings → Secrets and variables → Actions
2. Create a new secret named `OUTLINE_TOKEN`
3. Add your Outline Wiki API token as the value

## ⚙️ Configuration

### Input Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `outline_url` | Outline Wiki base URL | Yes | `https://wiki.gluzdov.com/` |
| `outline_token` | Outline Wiki API token | Yes | - |
| `outline_parent_document_id` | Parent document ID in wiki | Yes | - |
| `source_dir` | Source directory for markdown files | No | `./docs` |
| `dry_run` | Run in dry-run mode (no changes made) | No | `false` |
| `verbose` | Enable verbose logging | No | `false` |

### Environment Variables

The action uses these environment variables internally:

- `OUTLINE_URL`: Your Outline Wiki base URL
- `OUTLINE_TOKEN`: Your API token
- `OUTLINE_PARENT_DOCUMENT_ID`: Parent document ID
- `SOURCE_DIR`: Source directory path
- `DRY_RUN`: Dry run mode flag
- `VERBOSE`: Verbose logging flag

## 📁 File Structure

Your markdown files should be organized in the source directory:

```
docs/
├── getting-started.md
├── api-reference.md
├── deployment/
│   ├── installation.md
│   └── configuration.md
└── troubleshooting/
    └── common-issues.md
```

## 🔍 How It Works

### 1. File Discovery
The action scans your source directory for all `.md` files.

### 2. Title Extraction
For each markdown file, it extracts the title from the first `#` heading.

### 3. Document Matching
It searches your Outline Wiki for existing documents with matching titles.

### 4. Folder Structure
The action maintains your folder structure by creating parent documents for each directory.

### 5. Synchronization
- **Existing Documents**: Updates content if document exists
- **New Documents**: Creates new documents in the appropriate location
- **Link Processing**: Updates internal links between documents

### 6. Link Replacement
In the second pass, it processes and updates internal links between documents.

## 📝 Markdown Requirements

### Title Extraction
Your markdown files must have a title as the first heading:

```markdown
# Document Title

Your content here...
```

### Internal Links
The action supports internal links between documents:

```markdown
[Link to another document](another-document.md)
[Link with custom text](deployment/installation.md)
```

## 🛠️ Usage Examples

### Basic Usage

```yaml
- name: Sync documentation
  uses: ./
  with:
    outline_url: 'https://wiki.company.com/'
    outline_token: ${{ secrets.OUTLINE_TOKEN }}
    outline_parent_document_id: 'docs-folder-id'
```

### With Custom Source Directory

```yaml
- name: Sync documentation
  uses: ./
  with:
    outline_url: 'https://wiki.company.com/'
    outline_token: ${{ secrets.OUTLINE_TOKEN }}
    outline_parent_document_id: 'docs-folder-id'
    source_dir: './documentation'
```

### Dry Run Mode

```yaml
- name: Test sync (dry run)
  uses: ./
  with:
    outline_url: 'https://wiki.company.com/'
    outline_token: ${{ secrets.OUTLINE_TOKEN }}
    outline_parent_document_id: 'docs-folder-id'
    dry_run: 'true'
    verbose: 'true'
```

### Alternative Usage with Direct Script Execution

You can also run the synchronization script directly without GitHub Actions using curl:

```bash
# Download and execute the script directly
curl -sSL https://raw.githubusercontent.com/speedandfunction/docs-sync-action/main/docs-sync.sh | bash

# Or with environment variables
OUTLINE_URL="https://wiki.company.com/" \
OUTLINE_TOKEN="your-api-token" \
OUTLINE_PARENT_DOCUMENT_ID="docs-folder-id" \
SOURCE_DIR="./docs" \
curl -sSL https://raw.githubusercontent.com/speedandfunction/docs-sync-action/main/docs-sync.sh | bash

# With additional options
OUTLINE_URL="https://wiki.company.com/" \
OUTLINE_TOKEN="your-api-token" \
OUTLINE_PARENT_DOCUMENT_ID="docs-folder-id" \
SOURCE_DIR="./docs" \
DRY_RUN="true" \
VERBOSE="true" \
curl -sSL https://raw.githubusercontent.com/speedandfunction/docs-sync-action/main/docs-sync.sh | bash
```

**Note**: Replace `your-username` with your actual GitHub username or organization name.

## 🔍 Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify your API token is correct
   - Ensure the token has appropriate permissions

2. **Document Not Found**
   - Check that the parent document ID exists
   - Verify the document ID format (UUID or URL ID)

3. **File Processing Errors**
   - Ensure markdown files have proper titles
   - Check file permissions and encoding

4. **API Rate Limits**
   - The action includes built-in rate limiting
   - Consider running during off-peak hours

### Debug Mode

Enable verbose logging to see detailed information:

```yaml
verbose: 'true'
```

This will show:
- File discovery process
- Title extraction results
- API calls and responses
- Document creation/update operations

## 🔒 Security

- **API Tokens**: Store tokens as GitHub secrets
- **Permissions**: Use tokens with minimal required permissions
- **Dry Run**: Test changes with dry run mode before production
- **Audit**: Review logs to verify synchronization results


---

**Note**: This action is designed to work with Outline Wiki. Make sure you have the necessary permissions and API access to your wiki instance.
