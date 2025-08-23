#!/usr/bin/env bash

declare -a URL_TITLES=()
declare -a URL_URLS=()
REPLACE_LINKS="false"
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
    if [[ "$REPLACE_LINKS" == "true" ]]; then
        content=$(md_process_content_with_links "$file" "$title")
    else
        content=$(md_process_content "$file" "$title")
    fi

    log_verbose "  Title: $title"
    log_verbose "  Content length: ${#content} characters"

    local result
    result=$(sync_document "$file" "$title" "$content")
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

    process_files

    url_init_mapping

    REPLACE_LINKS="true"
    process_files

    log_info "✨ All documents created and updated"
}

main "$@"
