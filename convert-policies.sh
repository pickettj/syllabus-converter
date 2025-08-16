#!/bin/bash

# ===== SIMPLE POLICY CONVERTER =====
# Converts markdown policy files to HTML using pandoc defaults
# Saves to ../courses-bactriana/policies directory

# Set directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/boilerplate_policies"
OUTPUT_DIR="$SCRIPT_DIR/../courses-bactriana/policies"
CSS_SOURCE="$SCRIPT_DIR/assets/themes/policies.css"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check dependencies
check_dependencies() {
    if ! command -v pandoc >/dev/null 2>&1; then
        echo -e "${RED}✗ pandoc not found. Please install pandoc and try again.${NC}"
        exit 1
    fi
}

# Function to validate paths
validate_paths() {
    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${RED}✗ Source directory not found: $SOURCE_DIR${NC}"
        exit 1
    fi

    if [ ! -f "$CSS_SOURCE" ]; then
        echo -e "${RED}✗ CSS file not found: $CSS_SOURCE${NC}"
        exit 1
    fi

    if [ ! -d "$(dirname "$OUTPUT_DIR")" ]; then
        echo -e "${RED}✗ Parent directory not found: $(dirname "$OUTPUT_DIR")${NC}"
        echo "Make sure ../courses-bactriana exists"
        exit 1
    fi
}

# Function to copy CSS file
copy_css() {
    local css_output="$OUTPUT_DIR/policies.css"
    
    echo -e "${BLUE}Copying CSS file...${NC}"
    
    if cp "$CSS_SOURCE" "$css_output"; then
        echo -e "${GREEN}  ✓ Copied: $css_output${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to copy CSS file${NC}"
        return 1
    fi
}

# Function to add date stamp and back link to HTML files
add_date_stamp_and_nav() {
    local html_file="$1"
    local date_text="Updated on $(date +'%B %d, %Y')"
    
    # Try to add back link to h1.title first (pandoc's header structure)
    if grep -q '<h1 class="title">' "$html_file"; then
        sed -i.bak 's|<h1 class="title">\(.*\)</h1>|<h1 class="title">\1 <a href="index.html" class="back-link">← Back to Index</a></h1>|' "$html_file" && rm "${html_file}.bak"
    else
        # Fallback: add to any h1 tag
        sed -i.bak 's|<h1[^>]*>\(.*\)</h1>|<h1>\1 <a href="index.html" class="back-link">← Back to Index</a></h1>|' "$html_file" && rm "${html_file}.bak"
    fi
    
    # Add date stamp div before closing body tag
    sed -i.bak "s|</body>|<div class=\"date-stamp\">$date_text</div>\n</body>|" "$html_file" && rm "${html_file}.bak"
}

# Function to convert a single markdown file
convert_file() {
    local source_file="$1"
    local filename=$(basename "$source_file" .md)
    local output_file="$OUTPUT_DIR/${filename}.html"
    
    echo -e "${BLUE}Converting: $filename${NC}"
    
    # Run pandoc with default settings + CSS (let pandoc extract title from first heading)
    if pandoc "$source_file" \
        -o "$output_file" \
        --standalone \
        --css="policies.css"; then
        
        # Add date stamp and navigation to the HTML file
        add_date_stamp_and_nav "$output_file"
        
        echo -e "${GREEN}  ✓ Created: $output_file${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to convert: $filename${NC}"
        return 1
    fi
}

# Function to deploy to GitHub
deploy_to_github() {
    echo -e "${BLUE}Deploying to GitHub...${NC}"
    
    # Change to the output repository directory
    cd "$(dirname "$OUTPUT_DIR")" || {
        echo -e "${RED}  ✗ Failed to change to repository directory${NC}"
        return 1
    }
    
    # Add all changes in the policies directory
    git add policies/
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        echo -e "${YELLOW}  No changes to commit${NC}"
        return 0
    fi
    
    # Commit changes with timestamp
    local commit_message="Policies updated on $(date +'%B %d, %Y at %I:%M %p')"
    if git commit -m "$commit_message"; then
        echo -e "${GREEN}  ✓ Committed: $commit_message${NC}"
    else
        echo -e "${RED}  ✗ Failed to commit changes${NC}"
        return 1
    fi
    
    # Push to GitHub
    if git push origin main; then
        echo -e "${GREEN}  ✓ Pushed to GitHub${NC}"
        echo -e "${GREEN}  🌐 Site will be available at: https://courses.bactriana.org/policies/${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to push to GitHub${NC}"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}=== Simple Policy Converter ===${NC}"
echo

# Check dependencies and validate paths
check_dependencies
validate_paths

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}Output directory: $OUTPUT_DIR${NC}"

# Copy CSS file
copy_css
echo

# Convert all markdown files
echo -e "${BLUE}Converting policy files...${NC}"
conversion_count=0
failed_count=0

for policy_file in "$SOURCE_DIR"/*.md; do
    if [ -f "$policy_file" ]; then
        if convert_file "$policy_file"; then
            ((conversion_count++))
        else
            ((failed_count++))
        fi
    fi
done

# Summary
echo
if [ $failed_count -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully converted $conversion_count policy files${NC}"
else
    echo -e "${YELLOW}⚠ Converted $conversion_count files, $failed_count failed${NC}"
fi

echo -e "${BLUE}Files saved to: $OUTPUT_DIR${NC}"

# Deploy to GitHub
echo
deploy_to_github

# Create index page (this will also deploy itself)
echo
echo -e "${BLUE}Creating policy index page...${NC}"
if [ -f "$SCRIPT_DIR/create-policy-index.sh" ]; then
    chmod +x "$SCRIPT_DIR/create-policy-index.sh"
    "$SCRIPT_DIR/create-policy-index.sh"
else
    echo -e "${YELLOW}⚠ Index script not found: $SCRIPT_DIR/create-policy-index.sh${NC}"
fi