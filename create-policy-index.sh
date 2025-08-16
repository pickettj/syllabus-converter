#!/bin/bash

# ===== POLICY INDEX CREATOR =====
# Creates an index page for the policies directory with card layout
# Extracts H1 titles from existing HTML files and creates navigation

# Set directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="$SCRIPT_DIR/../courses-bactriana/policies"
CSS_SOURCE="$SCRIPT_DIR/assets/themes/policy-index.css"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate paths
validate_paths() {
    if [ ! -d "$POLICIES_DIR" ]; then
        # Function to deploy to GitHub
deploy_to_github() {
    echo -e "${BLUE}Deploying index to GitHub...${NC}"
    
    # Change to the output repository directory
    cd "$(dirname "$POLICIES_DIR")" || {
        echo -e "${RED}  ✗ Failed to change to repository directory${NC}"
        return 1
    }
    
    # Add all changes in the policies directory (including index.html and CSS)
    git add policies/
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        echo -e "${YELLOW}  No changes to commit${NC}"
        return 0
    fi
    
    # Commit changes with timestamp
    local commit_message="Policy index updated on $(date +'%B %d, %Y at %I:%M %p')"
    if git commit -m "$commit_message"; then
        echo -e "${GREEN}  ✓ Committed: $commit_message${NC}"
    else
        echo -e "${RED}  ✗ Failed to commit changes${NC}"
        return 1
    fi
    
    # Push to GitHub
    if git push origin main; then
        echo -e "${GREEN}  ✓ Pushed to GitHub${NC}"
        echo -e "${GREEN}  🌐 Index will be available at: https://courses.bactriana.org/policies/${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to push to GitHub${NC}"
        return 1
    fi
}

echo -e "${RED}✗ Policies directory not found: $POLICIES_DIR${NC}"
        exit 1
    fi

    if [ ! -f "$CSS_SOURCE" ]; then
        echo -e "${RED}✗ CSS file not found: $CSS_SOURCE${NC}"
        echo -e "${YELLOW}Will create a basic stylesheet${NC}"
        create_css=true
    fi
}

# Function to extract title from HTML file
extract_title_from_html() {
    local html_file="$1"
    
    # Extract the title from the h1.title element, but remove any back link
    local title=$(grep '<h1 class="title">' "$html_file" | sed 's/.*<h1[^>]*>\(.*\)<\/h1>.*/\1/' | sed 's/ <a href="index.html"[^>]*>.*<\/a>//' | head -1)
    
    if [ -n "$title" ]; then
        echo "$title"
    else
        # Try alternative patterns that pandoc might generate, also removing back links
        title=$(grep -o '<h1[^>]*>.*</h1>' "$html_file" | sed 's/<[^>]*>//g' | sed 's/ ← Back to Index//' | head -1)
        if [ -n "$title" ]; then
            echo "$title"
        else
            # Fallback to filename if no title found
            local filename=$(basename "$html_file" .html)
            echo "$filename" | sed 's/-/ /g' | sed 's/\b\w/\U&/g'
        fi
    fi
}

# Function to copy CSS file
copy_css() {
    local css_output="$POLICIES_DIR/policy-index.css"
    
    echo -e "${BLUE}Copying index CSS file...${NC}"
    
    if [ "$create_css" = true ]; then
        echo -e "${YELLOW}Creating basic CSS file first...${NC}"
        create_basic_css
    fi
    
    if cp "$CSS_SOURCE" "$css_output"; then
        echo -e "${GREEN}  ✓ Copied: $css_output${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to copy CSS file${NC}"
        return 1
    fi
}

# Function to create basic CSS if needed
create_basic_css() {
    mkdir -p "$(dirname "$CSS_SOURCE")"
    cat > "$CSS_SOURCE" << 'EOF'
/* Basic policy index styles - replace with custom design */
body { font-family: Georgia, serif; max-width: 900px; margin: 0 auto; }
.policy-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; }
.policy-card { border: 1px solid #ddd; padding: 1rem; border-radius: 8px; }
.policy-card a { text-decoration: none; color: #333; }
.policy-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
EOF
    echo -e "${GREEN}✓ Created basic CSS: $CSS_SOURCE${NC}"
}

# Function to create the index page
create_index_page() {
    local index_file="$POLICIES_DIR/index.html"
    
    echo -e "${BLUE}Creating policies index page...${NC}"
    
    # Start building the HTML
    cat > "$index_file" << 'EOF'
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="generator" content="pandoc" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
  <title>Course Policies</title>
  <link rel="stylesheet" href="policy-index.css" />
</head>
<body>
<header id="title-block-header">
<h1 class="title">Course Policies</h1>
</header>

<p class="intro">Standard policies and information <a href="https://jamespickett.info/">James Pickett's courses</a>:</p>

<div class="policy-grid">
EOF

    # Count policy files for progress
    local policy_count=0
    
    # Add cards for all policy HTML files (excluding index.html)
    for html_file in "$POLICIES_DIR"/*.html; do
        if [ -f "$html_file" ] && [ "$(basename "$html_file")" != "index.html" ]; then
            local filename=$(basename "$html_file" .html)
            local title=$(extract_title_from_html "$html_file")
            
            cat >> "$index_file" << EOF
    <div class="policy-card">
        <a href="$filename.html">
            <h3>$title</h3>
        </a>
    </div>
EOF
            ((policy_count++))
            echo -e "${GREEN}  ✓ Added: $title${NC}"
        fi
    done

    # Close the HTML
    cat >> "$index_file" << EOF
</div>

<div class="date-stamp">Updated on $(date +'%B %d, %Y')</div>
</body>
</html>
EOF

    if [ $policy_count -gt 0 ]; then
        echo -e "${GREEN}✓ Created index page with $policy_count policy links${NC}"
        echo -e "${BLUE}Index page: $index_file${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ No policy files found to index${NC}"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}=== Policy Index Creator ===${NC}"
echo

# Validate paths
validate_paths

# Copy CSS file
copy_css

# Create the index page
echo
create_index_page

echo
echo -e "${GREEN}=== Index Creation Complete! ===${NC}"

# Deploy to GitHub
echo
deploy_to_github