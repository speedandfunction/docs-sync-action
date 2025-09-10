#!/usr/bin/env bash

declare -a URL_TITLES=()
declare -a URL_URLS=()
declare -a ATTACHMENT_CACHE_KEYS=()
declare -a ATTACHMENT_CACHE_VALUES=()

url_build_mapping_from_files() {
    log_verbose "Building URL mapping from file names..."

    URL_TITLES=()
    URL_URLS=()

    local parent_id="$OUTLINE_PARENT_DOCUMENT_ID"
    if [[ ! "$OUTLINE_PARENT_DOCUMENT_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        parent_id=$(api_get_uuid_from_url_id "$OUTLINE_PARENT_DOCUMENT_ID")
        if [[ -z "$parent_id" ]]; then
            log_error "Could not find parent document with URL ID: $OUTLINE_PARENT_DOCUMENT_ID"
            return 1
        fi
    fi

    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$SOURCE_DIR" -name "*.md" -type f -print0)

    log_verbose "Found ${#files[@]} markdown files to check"

    for file in "${files[@]}"; do
        local title
        title=$(md_extract_title "$file")

        if [[ -n "$title" ]]; then
            log_verbose "Looking for document with title: '$title'"

            local doc_url
            doc_url=$(api_find_document_url_by_title "$title")

            if [[ -n "$doc_url" ]]; then
                URL_TITLES+=("$title")
                URL_URLS+=("$doc_url")
                log_verbose "Added mapping from file: '$title' -> '$doc_url'"
            else
                log_verbose "No document found for title: '$title'"
            fi
        fi
    done
}

api_find_document_url_by_title() {
    local title="$1"

    local parent_uuid="$OUTLINE_PARENT_DOCUMENT_ID"
    if [[ ! "$OUTLINE_PARENT_DOCUMENT_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        parent_uuid=$(api_get_uuid_from_url_id "$OUTLINE_PARENT_DOCUMENT_ID")
        if [[ -z "$parent_uuid" ]]; then
            log_error "Could not find parent document with URL ID: $OUTLINE_PARENT_DOCUMENT_ID"
            echo ""
            return
        fi
    fi

    local response
    response=$(curl -sS "${OUTLINE_URL%/}/api/documents.list"  \
        -H "Authorization: Bearer $OUTLINE_TOKEN"  \
        -H "Accept: application/json"  \
        -d "parentDocumentId=$parent_uuid")

    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API: $response"
        echo ""
        return
    fi

    local doc_url
    doc_url=$(echo "$response" | jq -r --arg title "$title" '.data[]? | select(.title == $title) | .url // empty' 2>/dev/null)

    if [[ -n "$doc_url" ]]; then
        if [[ "$doc_url" != http* ]]; then
            doc_url="${OUTLINE_URL%/}$doc_url"
        fi
        echo "$doc_url"
    else
        echo ""
    fi
}

url_build_mapping() {
    log_verbose "Building URL mapping from existing documents..."

    URL_TITLES=()
    URL_URLS=()

    url_build_mapping_from_files
}

url_get_document_url() {
    local title="$1"

    for i in "${!URL_TITLES[@]}"; do
        if [[ "${URL_TITLES[$i]}" == "$title" ]]; then
            echo "${URL_URLS[$i]}"
            return 0
        fi
    done

    local lower_title
    lower_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')

    for i in "${!URL_TITLES[@]}"; do
        local lower_mapped
        lower_mapped=$(echo "${URL_TITLES[$i]}" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower_mapped" == "$lower_title" ]]; then
            echo "${URL_URLS[$i]}"
            return 0
        fi
    done

    for i in "${!URL_TITLES[@]}"; do
        local mapped_title="${URL_TITLES[$i]}"
        if [[ "$mapped_title" == *"$title"* ]] || [[ "$title" == *"$mapped_title"* ]]; then
            echo "${URL_URLS[$i]}"
            log_verbose "Found partial match for '$title': '$mapped_title'"
            return 0
        fi
    done

    log_verbose "No URL mapping found for title: '$title'"
    return 1
}

url_add_to_mapping() {
    local title="$1"
    local url="$2"

    if [[ -n "$title" && -n "$url" ]]; then
        URL_TITLES+=("$title")
        URL_URLS+=("$url")
        log_verbose "Added new mapping: '$title' -> '$url'"
    fi
}

url_replace_links() {
    local content="$1"
    local result=""

    while IFS= read -r line; do
        local processed_line="$line"

        if echo "$processed_line" | grep -q '\[.*\](.*\.md)'; then
            local temp_line="$processed_line"
            while echo "$temp_line" | grep -q '\[[^]]*\]([^)]*\.md)'; do
                local link_text
                local file_path
                link_text=$(echo "$temp_line" | sed -n 's/.*\[\([^]]*\)\]([^)]*\.md).*/\1/p')
                file_path=$(echo "$temp_line" | sed -n 's/.*\[[^]]*\](\([^)]*\.md\)).*/\1/p')

                if [[ -n "$link_text" && -n "$file_path" ]]; then
                    local file_title
                    file_title=$(basename "$file_path" .md)

                    local mapped_url
                    if mapped_url=$(url_get_document_url "$file_title") || mapped_url=$(url_get_document_url "$link_text"); then
                        processed_line=$(echo "$processed_line" | sed "s|\[$link_text\]($file_path)|[$link_text]($mapped_url)|g")
                        log_verbose "Replaced link: [$link_text]($file_path) -> [$link_text]($mapped_url)"
                    else
                        log_verbose "No mapping found for link: [$link_text]($file_path)"
                    fi
                fi

                temp_line=$(echo "$temp_line" | sed 's/\[[^]]*\]([^)]*\.md)//')
            done
        fi

        result+="$processed_line"$'\n'
    done <<< "$content"

    echo -n "${result%$'\n'}"
}

url_init_mapping() {
    url_build_mapping
}

cfg_load() {
    OUTLINE_URL="${OUTLINE_URL:-https://wiki.gluzdov.com/}"
    OUTLINE_TOKEN="${OUTLINE_TOKEN:-}"
    OUTLINE_PARENT_DOCUMENT_ID="${OUTLINE_PARENT_DOCUMENT_ID:-}"
    SOURCE_DIR="${SOURCE_DIR:-./docs}"
    DRY_RUN="${DRY_RUN:-false}"
    VERBOSE="${VERBOSE:-false}"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --source-dir)
                SOURCE_DIR="$2"
                shift 2
                ;;
            --outline-url)
                OUTLINE_URL="$2"
                shift 2
                ;;
            --outline-token)
                OUTLINE_TOKEN="$2"
                shift 2
                ;;
            --outline-parent-document-id)
                OUTLINE_PARENT_DOCUMENT_ID="$2"
                shift 2
                ;;
            --help)
                cfg_show_help
                exit 0
                ;;
            -*)
                error_die "Unknown option: $1"
                ;;
            *)
                SOURCE_DIR="$1"
                shift
                ;;
        esac
    done
}

cfg_validate() {
    log_verbose "Validating configuration..."

    [[ -n "$OUTLINE_URL" ]] || error_die "OUTLINE_URL not set"

    if [[ -z "$OUTLINE_TOKEN" ]]; then
        error_die "OUTLINE_TOKEN not set. Please provide it via environment variable OUTLINE_TOKEN or parameter --outline-token
Get your token at: https://wiki.gluzdov.com/settings/tokens"
    fi

    if [[ -z "$OUTLINE_PARENT_DOCUMENT_ID" ]]; then
        error_die "OUTLINE_PARENT_DOCUMENT_ID not set. Please provide it via environment variable OUTLINE_PARENT_DOCUMENT_ID or parameter --outline-parent-document-id"
    fi

    [[ -d "$SOURCE_DIR" ]] || error_die "Source directory not found: $SOURCE_DIR"

    log_verbose "Configuration validation passed"
    log_verbose "Using Outline URL: $OUTLINE_URL"
    log_verbose "Using Outline Token: ${OUTLINE_TOKEN:0:8}..."
    log_verbose "Using Parent Document ID: $OUTLINE_PARENT_DOCUMENT_ID"
}

cfg_show_help() {
    cat << 'HELP_EOF'
GitHub Actions Documentation Sync Script (Memory-Only Version)

Usage: ./docs-sync-memory-only.sh [OPTIONS] [SOURCE_DIR]

This version stores all data in memory and does not create any temporary files.

Options:
    --dry-run          Run in dry-run mode (no actual changes)
    --verbose          Enable verbose logging
    --source-dir DIR   Source directory for markdown files (default: ./docs)
    --outline-url URL  Outline Wiki base URL (overrides OUTLINE_URL env var)
    --outline-token TOKEN Outline Wiki API token (overrides OUTLINE_TOKEN env var)
    --outline-parent-document-id ID Outline Wiki parent document ID (overrides OUTLINE_PARENT_DOCUMENT_ID env var)
    --help             Show this help message

SOURCE_DIR:
    Source directory for markdown files (can be specified as last argument)

Environment Variables (used by default):
    OUTLINE_URL        Outline Wiki base URL (default: https://wiki.gluzdov.com/)
    OUTLINE_TOKEN      Outline Wiki API token
    OUTLINE_PARENT_DOCUMENT_ID      Outline Wiki parent document ID
    SOURCE_DIR         Source directory for markdown files (default: ./docs)
    DRY_RUN            Enable dry-run mode
    VERBOSE            Enable verbose logging

Examples:
    ./docs-sync-memory-only.sh --verbose

    ./docs-sync-memory-only.sh --outline-url "https://wiki.example.com" --outline-token "token123" --outline-parent-document-id "doc456"

    ./docs-sync-memory-only.sh --dry-run --source-dir ./documentation --verbose
HELP_EOF
}

api_create_document_in_parent() {
    local title="$1"
    local content="$2"
    local parent_id="$3"

    log_verbose "Creating document: $title"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create document: $title in parent: $parent_id"
        return 0
    fi

    local response
    response=$(curl -sS "${OUTLINE_URL%/}/api/documents.create" \
        -X POST \
        -H "Authorization: Bearer $OUTLINE_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d @- << EOF_INNER
{
    "title": $(jq -Rn --arg t "$title" '$t'),
    "text": $(jq -Rn --arg x "$content" '$x'),
    "parentDocumentId": "$parent_id",
    "publish": true
}
EOF_INNER
    )

    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API: $response"
        error_die "Failed to create document: $title - Invalid JSON response"
    fi

    local doc_id
    doc_id=$(echo "$response" | jq -r '.data.id // empty' 2>/dev/null)

    if [[ -n "$doc_id" ]]; then
        log_verbose "Created document: $title (ID: $doc_id)"

        local doc_url
        doc_url=$(echo "$response" | jq -r '.data.url // empty' 2>/dev/null)

        if [[ -n "$doc_url" ]]; then
            url_add_to_mapping "$title" "$doc_url"
        fi

        echo "$doc_id"
    else
        log_error "API Response: $response"
        error_die "Failed to create document: $title"
    fi
}

api_update_document() {
    local id="$1"
    local content="$2"

    log_verbose "Updating document ID: $id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update document ID: $id"
        return 0
    fi

    local response
    response=$(curl -sS "${OUTLINE_URL%/}/api/documents.update" \
        -X POST \
        -H "Authorization: Bearer $OUTLINE_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d @- << EOF_INNER
{
    "id": "$id",
    "text": $(jq -Rn --arg x "$content" '$x'),
    "publish": true
}
EOF_INNER
    )

    local success
    success=$(echo "$response" | jq -r '.ok // false')

    if [[ "$success" == "true" ]]; then
        log_verbose "Updated document ID: $id"
    else
        error_die "Failed to update document ID: $id"
    fi
}

api_find_document_by_title_in_parent() {
    local title="$1"
    local parent_id="$2"

    local response
    response=$(curl -sS "${OUTLINE_URL%/}/api/documents.list" \
        -H "Authorization: Bearer $OUTLINE_TOKEN" \
        -H "Accept: application/json" \
        -d "parentDocumentId=$parent_id")

    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API: $response"
        echo ""
        return
    fi

    local doc_id
    doc_id=$(echo "$response" | jq -r --arg title "$title" '.data[]? | select(.title == $title) | .id // empty' 2>/dev/null)

    echo "$doc_id"
}

api_get_uuid_from_url_id() {
    local url_id="$1"

    local response
    response=$(curl -sS "${OUTLINE_URL%/}/api/documents.info" \
        -X POST \
        -H "Authorization: Bearer $OUTLINE_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"id\": \"$url_id\"}" \
        2>/dev/null)

    local uuid
    uuid=$(echo "$response" | jq -r '.data.id // empty' 2>/dev/null)

    if [[ -n "$uuid" ]]; then
        echo "$uuid"
    else
        echo ""
    fi
}

api_create_folder_document() {
    local folder_name="$1"
    local parent_id="$2"

    log_verbose "Creating folder: $folder_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create folder: $folder_name"
        return 0
    fi

    local response
    response=$(curl -sS "${OUTLINE_URL%/}/api/documents.create" \
        -X POST \
        -H "Authorization: Bearer $OUTLINE_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d @- << EOF_INNER
{
    "title": $(jq -Rn --arg t "$folder_name" '$t'),
    "text": "📁 $folder_name",
    "parentDocumentId": "$parent_id",
    "publish": true
}
EOF_INNER
    )

    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API: $response"
        return 1
    fi

    local folder_id
    folder_id=$(echo "$response" | jq -r '.data.id // empty' 2>/dev/null)

    if [[ -n "$folder_id" ]]; then
        log_info "Created folder: $folder_name (ID: $folder_id)"
        echo "$folder_id"
    else
        log_error "API Response: $response"
        error_die "Failed to create folder: $folder_name"
    fi
}

api_test_connection() {
    log_verbose "Testing connection to Outline Wiki..."

    if [[ ! "$OUTLINE_URL" =~ ^https?:// ]]; then
        error_die "Invalid OUTLINE_URL format: $OUTLINE_URL (should start with http:// or https://)"
    fi

    local is_uuid=false
    if [[ "$OUTLINE_PARENT_DOCUMENT_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        is_uuid=true
    fi

    local test_id="$OUTLINE_PARENT_DOCUMENT_ID"
    if [[ "$is_uuid" == "false" ]]; then
        log_verbose "Converting URL ID to UUID: $OUTLINE_PARENT_DOCUMENT_ID"
        test_id=$(api_get_uuid_from_url_id "$OUTLINE_PARENT_DOCUMENT_ID")
        if [[ -z "$test_id" ]]; then
            error_die "Could not find document with URL ID: $OUTLINE_PARENT_DOCUMENT_ID"
        fi
        log_verbose "Found UUID: $test_id"
    fi

    local api_url="${OUTLINE_URL%/}/api/documents.info"
    log_verbose "Testing API endpoint: $api_url"

    local response
    response=$(curl -sS "$api_url" \
        -X POST \
        -H "Authorization: Bearer $OUTLINE_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"id\": \"$test_id\"}" \
        -w "\nHTTP_STATUS: %{http_code}\n")

    local http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d' ' -f2)
    local response_body=$(echo "$response" | sed '/HTTP_STATUS:/d')

    log_verbose "HTTP Status: $http_status"
    log_verbose "API Response (first 200 chars): ${response_body:0:200}"

    if [[ "$response_body" =~ ^[[:space:]]*"<!DOCTYPE"[[:space:]]"html" ]]; then
        log_error "Received HTML response instead of JSON - this indicates an error"
        log_error "Possible issues:"
        log_error "  1. OUTLINE_URL is incorrect (should be: https://wiki.gluzdov.com)"
        log_error "  2. OUTLINE_TOKEN is invalid or expired"
        log_error "  3. API endpoint is not accessible"
        log_error "Full response: $response_body"
        error_die "API connection failed - received HTML error page"
    fi

    local success
    success=$(echo "$response_body" | jq -r '.ok // false' 2>/dev/null)

    if [[ "$success" == "true" ]] || [[ "$http_status" == "200" ]]; then
        log_verbose "Connection test successful"
        return 0
    else
        log_error "Connection test failed"
        log_error "Response: $response_body"
        error_die "Connection test failed - check OUTLINE_URL and OUTLINE_TOKEN"
    fi
}

normalize_path() {
    local path="$1"
    path="${path#./}"
    path="${path%/}"
    echo "$path"
}

get_relative_path() {
    local file="$1"
    local normalized_file
    local normalized_source

    normalized_file=$(normalize_path "$file")
    normalized_source=$(normalize_path "$SOURCE_DIR")

    if [[ "$normalized_file" == "$normalized_source"/* ]]; then
        echo "${normalized_file#$normalized_source/}"
    elif [[ "$normalized_file" == "$normalized_source" ]]; then
        echo ""
    else
        echo "$normalized_file"
    fi
}

process_folder_structure() {
    local file="$1"

    local current_parent_id="$OUTLINE_PARENT_DOCUMENT_ID"
    if [[ ! "$OUTLINE_PARENT_DOCUMENT_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        current_parent_id=$(api_get_uuid_from_url_id "$OUTLINE_PARENT_DOCUMENT_ID")
        if [[ -z "$current_parent_id" ]]; then
            error_die "Could not find root parent document with URL ID: $OUTLINE_PARENT_DOCUMENT_ID"
        fi
    fi

    local relative_path
    relative_path=$(get_relative_path "$file")

    if [[ -z "$relative_path" ]]; then
        echo "$current_parent_id"
        return
    fi

    local dir_path
    dir_path=$(dirname "$relative_path")
    [[ "$dir_path" == "." ]] && dir_path=""

    if [[ -z "$dir_path" ]]; then
        echo "$current_parent_id"
        return
    fi

    IFS="/" read -ra path_components <<< "$dir_path"

    for folder in "${path_components[@]}"; do
        if [[ -n "$folder" ]]; then
            log_verbose "Processing folder: $folder"

            local folder_id
            folder_id=$(api_find_document_by_title_in_parent "$folder" "$current_parent_id")

            if [[ -n "$folder_id" ]]; then
                log_verbose "Found existing folder: $folder"
                current_parent_id="$folder_id"
            else
                log_verbose "Creating folder: $folder"
                folder_id=$(api_create_folder_document "$folder" "$current_parent_id")
                current_parent_id="$folder_id"
            fi
        fi
    done

    echo "$current_parent_id"
}

md_extract_title() {
    local file="$1"

    local title
    title=$(grep -m1 -E '^#\s+' "$file" | sed -E 's/^#+\s*//' | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -z "$title" ]]; then
        title=$(basename "$file" .md)
    fi

    echo "$title"
}

md_clean_content() {
    local content="$1"
    local title="$2"

    content=$(echo "$content" | sed '/^---$/,/^---$/d')
    content=$(echo "$content" | awk '/^#+[[:space:]]/ { if (!found) { found=1; next } } { print }')

    echo "$content"
}

md_replace_mermaid() {
    local content="$1"
    
    # Replace ```mermaid with ```mermaidjs for Outline compatibility
    # Use a more precise pattern to avoid double replacement
    content=$(echo "$content" | sed 's/```mermaid$/```mermaidjs/g')
    content=$(echo "$content" | sed 's/```mermaid\([[:space:]]\)/```mermaidjs\1/g')
    
    echo "$content"
}

md_process_content() {
    local file="$1"
    local title="$2"

    local content
    content=$(cat "$file")

    content=$(md_clean_content "$content" "$title")
    content=$(md_replace_mermaid "$content")

    echo "$content"
}

md_process_content_with_links() {
    local file="$1"
    local title="$2"

    local content
    content=$(cat "$file")

    content=$(md_clean_content "$content" "$title")
    content=$(md_replace_mermaid "$content")
    content=$(url_replace_links "$content")
    
    content=$(att_process_attachments_in_content "$content" "$(dirname "$file")")
    
    echo "$content"
}
log_info() {
    echo "ℹ️  $1"
}

log_error() {
    echo "❌ $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 $1" >&2
    fi
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

error_die() {
    log_error "$1"
    exit 1
}

process_single_file() {
    local file="$1"
    local title
    local content

    log_verbose "Processing file: $file"

    title=$(md_extract_title "$file")
    content=$(md_process_content_with_links "$file" "$title")

    log_verbose "  Title: $title"
    log_verbose "  Content length: ${#content} characters"

    local result
    result=$(sync_document "$file" "$title" "$content")
    
    # Add delay between files to avoid rate limiting
    log_verbose "  Adding 2 second delay between files to respect rate limits..."
    sleep 2
}

sync_document() {
    local file="$1"
    local title="$2"
    local content="$3"

    log_verbose "  Checking if document exists: $title"

    local parent_uuid
    parent_uuid=$(process_folder_structure "$file")

    log_verbose "Searching for title: '$title' in parent: $parent_uuid"

    local doc_id
    doc_id=$(api_find_document_by_title_in_parent "$title" "$parent_uuid")

    # Validate that all local attachment links have been replaced
    if ! att_validate_content_replacement "ose" "$(dirname "$file")"; then
        log_error "Attachment replacement validation failed for document: $title"
        log_error "Document will not be saved due to validation failure"
        return 1
    fi

    if [[ -n "$doc_id" ]]; then
        log_verbose "  Document exists (ID: $doc_id), updating..."
        api_update_document "$doc_id" "$content"
    else
        log_verbose "  Document not found, creating new in parent: $parent_uuid..."
        api_create_document_in_parent "$title" "$content" "$parent_uuid"
    fi
}

process_files() {
    local file_count=0
    local processed_count=0

    log_verbose "Scanning for markdown files..."
    while IFS= read -r -d '' file; do
        ((file_count++))
        log_verbose "Found: $file"
    done < <(find "$SOURCE_DIR" -name "*.md" -print0)

    log_verbose "Found $file_count markdown files"

    if [[ "$file_count" -gt 0 ]]; then

    while IFS= read -r -d '' file; do
    if process_single_file "$file"; then
            ((processed_count++))
        fi
    done < <(find "$SOURCE_DIR" -name "*.md" -print0)

        fi

    log_verbose "Processed $processed_count of $file_count files"
}


# =============================================================================
# Check if file is already in cache
att_cache_check() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    local file_hash
    file_hash=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)
    
    for i in "${!ATTACHMENT_CACHE_KEYS[@]}"; do
        if [[ "${ATTACHMENT_CACHE_KEYS[$i]}" == "$file_hash" ]]; then
            echo "${ATTACHMENT_CACHE_VALUES[$i]}"
            return 0
        fi
    done
    
    return 1
}

# Add file to cache
att_cache_add() {
    local file_path="$1"
    local remote_url="$2"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Cannot add non-existent file to cache: $file_path"
        return 1
    fi
    
    local file_hash
    file_hash=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)
    
    if [[ -n "$file_hash" && -n "$remote_url" ]]; then
        ATTACHMENT_CACHE_KEYS+=("$file_hash")
        ATTACHMENT_CACHE_VALUES+=("$remote_url")
        log_verbose "Added to attachment cache: $file_hash -> $remote_url"
    else
        log_error "Failed to add to attachment cache: invalid hash or URL"
        return 1
    fi
}

# Find all attachment references in markdown content
att_find_attachments_in_content() {
    local content="$1"
    
    # Extract all image links that reference attachments directory
    # Handle both simple links and links with title attributes
    echo "$content" | grep -o '!\[.*\](.*attachments/.*)' 2>/dev/null || true
}

# Extract file path from markdown image link
att_extract_file_path() {
    local image_link="$1"
    echo "$image_link" | sed -E 's/.*]\(([^)]*)\).*/\1/' | sed -E 's/\s*"[^"]*"$//' | sed 's/[[:space:]]*$//'
}

# Resolve relative attachment path to absolute path
att_resolve_attachment_path() {
    local relative_path="$1"
    local source_dir="$2"
    
    # Remove any quotes or size specifications
    relative_path=$(echo "$relative_path" | sed -E 's/^["'\'']|["'\'']$//g' | sed -E 's/\s*=.*$//')
    
    if [[ "$relative_path" = /* ]]; then
        # Already absolute path
        echo "$relative_path"
    else
        # Make relative to source directory
        echo "$source_dir/$relative_path"
    fi
}

# Validate attachment file exists and is readable
att_validate_attachment_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        log_warning "Attachment file not found: $file_path"
        return 1
    fi
    
    if [[ ! -r "$file_path" ]]; then
        log_error "Attachment file not readable: $file_path"
        return 1
    fi
    
    # Check file size (Outline has limits)
    local file_size
    file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
    
    if [[ "$file_size" -gt 26214400 ]]; then  # 25MB limit
        log_error "Attachment file too large (>25MB): $file_path"
        return 1
    fi
    
    log_verbose "Attachment file validated: $file_path ($file_size bytes)"
    return 0
}

# Create attachment via Outline API
# Create attachment via Outline API with exponential backoff
api_create_attachment() {
    local file_path="$1"
    local filename="$2"
    
    log_verbose "Creating attachment via API: $filename"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create attachment: $filename"
        echo "https://example.com/attachments/dry-run-$filename"
        return 0
    fi
    
    local file_size
    file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
    contentType="$(file -b --mime-type "$file_path" 2>/dev/null || echo "application/octet-stream")"
    
    # Exponential backoff for rate limit handling
    local retry_count=0
    local max_retries=3
    local base_delay=30  # 30 seconds base delay for 30, 60, 120 second intervals
    
    while [[ $retry_count -le $max_retries ]]; do
        local response
        response=$(curl -sS "${OUTLINE_URL%/}/api/attachments.create" --request POST --header "Content-Type: application/json" --header "Authorization: Bearer ${OUTLINE_TOKEN}" --data "{\"name\": \"${filename}\", \"contentType\": \"${contentType}\", \"size\": ${file_size}}")

        if ! echo "$response" | jq empty 2>/dev/null; then
            log_error "Invalid JSON response from attachment API: $response" 
            return 1
        fi
        
        # Check for rate limit error
        local status
        local error
        status=$(echo "$response" | jq -r ".status // empty" 2>/dev/null)
        error=$(echo "$response" | jq -r ".error // empty" 2>/dev/null)
        
        if [[ "$status" == "429" && "$error" == "rate_limit_exceeded" ]]; then
            if [[ $retry_count -lt $max_retries ]]; then
                local delay=$((base_delay * (2 ** retry_count)))
                log_verbose "Rate limit exceeded, waiting ${delay} seconds before retry $((retry_count + 1))/$max_retries..."
                sleep $delay
                ((retry_count++))
                continue
            else
                log_error "Max retries exceeded for rate limit"
                log_error "API Response: $response"
                return 1
            fi
        fi
        
        # If not rate limit error, process the response
        local upload_url
        local attachment_url
        local form_data
        upload_url=$(echo "$response" | jq -r ".data.uploadUrl // empty" 2>/dev/null)
        attachment_url=$(echo "$response" | jq -r ".data.attachment.url // empty" 2>/dev/null)
        form_data=$(echo "$response" | jq -c ".data.form // empty" 2>/dev/null)
        
        if [[ -n "$upload_url" && -n "$attachment_url" && -n "$form_data" ]]; then
            sleep 1
            echo "${upload_url}|${attachment_url}|${form_data}"
            return 0
        else
            log_error "API Response: $response"
            return 1
        fi
    done
}

api_upload_attachment_file() {
    local file_path="$1"
    local upload_url="$2"
    local form_data="$3"

    log_verbose "Upload URL: ${upload_url}"
    log_verbose "File Path: ${file_path}"
    
    log_verbose "Uploading file to signed URL: ${file_path}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would upload file: $file_path"
        return 0
    fi

    # Try POST approach with correct presigned POST URL usage
    log_verbose "Using POST approach with correct presigned POST URL usage"
    
    # Extract individual fields from form_data
    local key_value=$(echo "$form_data" | jq -r '.key // empty' 2>/dev/null)
    local policy_value=$(echo "$form_data" | jq -r '.Policy // empty' 2>/dev/null)
    local x_amz_algorithm=$(echo "$form_data" | jq -r '."X-Amz-Algorithm" // empty' 2>/dev/null)
    local x_amz_credential=$(echo "$form_data" | jq -r '."X-Amz-Credential" // empty' 2>/dev/null)
    local x_amz_date=$(echo "$form_data" | jq -r '."X-Amz-Date" // empty' 2>/dev/null)
    local x_amz_signature=$(echo "$form_data" | jq -r '."X-Amz-Signature" // empty' 2>/dev/null)
    local x_amz_security_token=$(echo "$form_data" | jq -r '."X-Amz-Security-Token" // empty' 2>/dev/null)
    local cache_control=$(echo "$form_data" | jq -r '."Cache-Control" // empty' 2>/dev/null)
    local content_type=$(echo "$form_data" | jq -r '."Content-Type" // empty' 2>/dev/null)
    local content_disposition=$(echo "$form_data" | jq -r '."Content-Disposition" // empty' 2>/dev/null)
    local acl=$(echo "$form_data" | jq -r '.acl // empty' 2>/dev/null)
    local bucket=$(echo "$form_data" | jq -r '.bucket // empty' 2>/dev/null)
    
    # Build curl command with correct presigned POST approach
    local response
    response=$(curl -sS -X POST "${upload_url}" \
        --form-string "key=${key_value}" \
        --form-string "Policy=${policy_value}" \
        --form-string "X-Amz-Algorithm=${x_amz_algorithm}" \
        --form-string "X-Amz-Credential=${x_amz_credential}" \
        --form-string "X-Amz-Date=${x_amz_date}" \
        --form-string "X-Amz-Signature=${x_amz_signature}" \
        --form-string "X-Amz-Security-Token=${x_amz_security_token}" \
        --form-string "Cache-Control=${cache_control}" \
        --form-string "Content-Type=${content_type}" \
        --form-string "Content-Disposition=${content_disposition}" \
        --form-string "acl=${acl}" \
        --form-string "bucket=${bucket}" \
        --form "file=@${file_path}")
    
    log_verbose "Response: $response"
    
    if [[ $? -eq 0 ]]; then
        log_verbose "File uploaded successfully: $file_path"
        return 0
    else
        log_error "Failed to upload file: $file_path"
        log_error "Response: $response"
        return 1
    fi
}

# Get final attachment URL from Outline
att_get_attachment_url() {
    local filename="$1"
    
    log_verbose "Getting final attachment URL for: $filename"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "https://example.com/attachments/dry-run-$filename"
        return 0
    fi
    
    # For now, we'll construct the URL based on the filename
    # In a real implementation, you might need to query the API for the final URL
    echo "${OUTLINE_URL%/}/api/attachments/$filename"
}

# Process all attachments in content
att_process_attachments_in_content() {
    local content="$1"
    local source_dir="$2"
    local processed_content="$content"
    
    log_verbose "Processing attachments in content"
    
    # Find all attachment references
    local attachments
    attachments=$(att_find_attachments_in_content "$content")
    
    if [[ -z "$attachments" ]]; then
        log_verbose "No attachments found in content"
        echo "$processed_content"
        return 0
    fi
    
    # Process each attachment
    while IFS= read -r image_link; do
        if [[ -n "$image_link" ]]; then
            log_verbose "Processing attachment: $image_link"
            
            # Extract file path
            local relative_path
            relative_path=$(att_extract_file_path "$image_link")
            
            if [[ -z "$relative_path" ]]; then
                log_warning "Could not extract path from image link: $image_link"
                continue
            fi
            
            # Resolve to absolute path
            local absolute_path
            absolute_path=$(att_resolve_attachment_path "$relative_path" "$source_dir")
            
            # Check cache first
            local cached_url
            cached_url=$(att_cache_check "$absolute_path")
            
            if [[ -n "$cached_url" ]]; then
                log_verbose "Using cached attachment: $absolute_path -> $cached_url"
                local alt_text
                alt_text=$(echo "$image_link" | sed -n 's/.*!\[\([^]]*\)\].*/\1/p')
                if [[ -n "$alt_text" ]]; then
                    processed_content="${processed_content//$image_link/![$alt_text]($cached_url)}"
                else
                    processed_content="${processed_content//$image_link/![Image]($cached_url)}"
                fi
                continue
            fi
            
            # Validate file
            if ! att_validate_attachment_file "$absolute_path"; then
                log_warning "Skipping invalid attachment: $absolute_path"
                continue
            fi
            
            # Get filename
            local filename
            filename=$(basename "$absolute_path")
            
            # Create attachment via API
            local api_result
            api_result=$(api_create_attachment "$absolute_path" "$filename")
            
            if [[ -z "$api_result" ]]; then
                log_error "Failed to create attachment: $filename"
                continue
            fi
            
            # Split the result into upload_url, attachment_url, and form_data
            local upload_url
            local attachment_url
            local form_data
            upload_url=$(echo "$api_result" | cut -d'|' -f1)
            attachment_url=$(echo "$api_result" | cut -d'|' -f2)
            form_data=$(echo "$api_result" | cut -d'|' -f3)
            
            # Upload file
            if ! api_upload_attachment_file "$absolute_path" "$upload_url" "$form_data"; then
                log_error "Failed to upload attachment: $filename"
                continue
            fi
            
            # Use the attachment URL from API response
            local final_url
            final_url="${OUTLINE_URL%/}${attachment_url}"
            
            if [[ -n "$final_url" ]]; then
                # Add to cache
                att_cache_add "$absolute_path" "$final_url"
                
                # Replace in content - preserve original alt text and title
                local alt_text
                alt_text=$(echo "$image_link" | sed -n 's/.*!\[\([^]]*\)\].*/\1/p')

                # Debug output to understand why replacement is not working
                # Use Python3 for robust string replacement that handles special characters
                if command -v python3 >/dev/null 2>&1; then
                    if [[ -n "$alt_text" ]]; then
                        processed_content=$(python3 -c "import sys; content=sys.stdin.read(); old=r'$image_link'; new=r'![$alt_text]($final_url)'; print(content.replace(old, new), end='')" <<< "$processed_content")
                    else
                        processed_content=$(python3 -c "import sys; content=sys.stdin.read(); old=r'$image_link'; new=r'![Image]($final_url)'; print(content.replace(old, new), end='')" <<< "$processed_content")
                    fi
                else
                    # Fall back to bash (may not work with special chars)
                    if [[ -n "$alt_text" ]]; then
                        processed_content="${processed_content//$image_link/![$alt_text]($final_url)}"
                    else
                        processed_content="${processed_content//$image_link/![Image]($final_url)}"
                    fi
                fi                
                log_verbose "Replaced attachment: $image_link -> $final_url"
            else
                log_error "Failed to get final URL for attachment: $filename"
            fi
        fi
    done <<< "$attachments"
    
    echo "$processed_content"
}

# Validate that all local attachment links have been replaced with external URLs
att_validate_content_replacement() {
    local content="$1"
    local source_dir="$2"
    
    log_verbose "Validating attachment link replacement..."
    
    # Find all attachment references in the content
    local attachments
    attachments=$(att_find_attachments_in_content "$content")
    
    if [[ -z "$attachments" ]]; then
        log_verbose "No attachments found in content - validation passed"
        return 0
    fi
    
    # Check each attachment to see if it's still a local path
    while IFS= read -r image_link; do
        if [[ -n "$image_link" ]]; then
            # Extract file path from the image link
            local relative_path
            relative_path=$(att_extract_file_path "$image_link")
            
            if [[ -n "$relative_path" ]]; then
                # Check if this is still a local path (not an external URL)
                if [[ "$relative_path" == attachments/* ]]; then
                    log_error "Validation failed: Local attachment link still present: $image_link"
                    log_error "Expected: External URL, Found: Local path"
                    return 1
                fi
            fi
        fi
    done <<< "$attachments"
    
    log_verbose "All attachment links successfully replaced with external URLs"
    return 0
}

# ATTACHMENT PROCESSING FUNCTIONS (Memory-based)
# =============================================================================
main() {
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            cfg_show_help
            exit 0
        fi
    done

    log_info "🚀 Starting Outline Wiki synchronization..."

    cfg_load "$@"
    cfg_validate

    api_test_connection

    url_init_mapping

    process_files

    log_info "✨ All documents created and updated"
}

main "$@"
