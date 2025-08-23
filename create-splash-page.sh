#!/bin/bash

# ===== SPLASH PAGE GENERATOR =====
# Creates the main landing page for courses.bactriana.org
# Automatically detects syllabus directories and generates course links

# Set directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../courses-bactriana"
CSS_SOURCE="$OUTPUT_DIR/splash.css"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate paths
validate_paths() {
    if [ ! -d "$(dirname "$OUTPUT_DIR")" ]; then
        echo -e "${RED}✗ Parent directory not found: $(dirname "$OUTPUT_DIR")${NC}"
        echo "Make sure ../courses-bactriana exists"
        exit 1
    fi
    
    if [ ! -f "$CSS_SOURCE" ]; then
        echo -e "${RED}✗ CSS file not found: $CSS_SOURCE${NC}"
        exit 1
    fi
}

# Function to check CSS file
check_css() {
    echo -e "${BLUE}Checking CSS file...${NC}"
    
    if [ -f "$CSS_SOURCE" ]; then
        echo -e "${GREEN}  ✓ CSS file exists: $CSS_SOURCE${NC}"
        return 0
    else
        echo -e "${RED}  ✗ CSS file not found: $CSS_SOURCE${NC}"
        echo -e "${YELLOW}  Create splash.css in the courses-bactriana directory first${NC}"
        return 1
    fi
}

# Function to extract title from HTML file (much simpler approach)
extract_title() {
    local html_file="$1"
    local title=""
    
    # First try to find the multi-line h1 by looking for the specific pattern in your pahlavi file
    title=$(tr '\n' ' ' < "$html_file" | \
            grep -o '<h1[^>]*id="zoroastrianism[^"]*"[^>]*>[^<]*</h1>' | \
            sed 's/<[^>]*>//g' | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
            head -1)
    
    # If that didn't work, try a more general approach
    if [ -z "$title" ]; then
        title=$(tr '\n' ' ' < "$html_file" | \
                grep -o '<h1[^>]*>[^<]*</h1>' | \
                sed 's/<[^>]*>//g' | \
                sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
                grep -v '^Syllabus$' | \
                head -1)
    fi
    
    # If still nothing, use directory name
    if [ -z "$title" ]; then
        local dirname=$(basename "$(dirname "$html_file")")
        title=$(echo "$dirname" | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
    fi
    
    echo "$title"
}

# Function to detect syllabus directories
detect_syllabus_directories() {
    echo -e "${BLUE}Detecting course syllabi...${NC}"
    
    local syllabus_info=""
    
    # Look for directories that contain index.html files
    for dir in "$OUTPUT_DIR"/*/; do
        if [ -d "$dir" ]; then
            local dirname=$(basename "$dir")
            
            # Skip known system/policy directories
            if [[ "$dirname" == "policies" || "$dirname" == ".git" || "$dirname" == "assets" ]]; then
                continue
            fi
            
            # Check if directory contains an index.html file
            if [ -f "$dir/index.html" ]; then
                local title=$(extract_title "$dir/index.html")
                local subtitle=$(grep -o '<div class="subtitle">[^<]*</div>' "$dir/index.html" | sed 's/<[^>]*>//g' | head -1)
                
                syllabus_info="${syllabus_info}${dirname}|${title}|${subtitle}\n"
                echo -e "${GREEN}  ✓ Found: $dirname ($title)${NC}"
            fi
        fi
    done
    
    echo -e "$syllabus_info"
}

# Function to create the splash page
create_splash_page() {
    local splash_file="$OUTPUT_DIR/index.html"
    local syllabus_info="$1"
    
    echo -e "${BLUE}Creating splash page...${NC}"
    
    local current_date=$(date +'%B %d, %Y')
    
    # Create the HTML file
    cat > "$splash_file" << 'EOF'
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="generator" content="splash-generator" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
  <title>Eurasian History at Pitt</title>
  <link rel="stylesheet" href="splash.css" />
</head>
<body>
<header id="title-block-header">
<h1 class="title">Eurasian History at Pitt</h1>
<p class="subtitle">Dashboard for classes taught by James Pickett</p>
</header>

<main class="content">
  <section class="info-section">
    <h2>Instructor Information</h2>
    <div class="link-grid">
      <a href="https://jamespickett.info/" class="info-link">
        <h3>James Pickett Personal Website</h3>
        <p>Academic portfolio and research</p>
      </a>
      <a href="https://www.history.pitt.edu/people/james-pickett" class="info-link">
        <h3>University Faculty Page</h3>
        <p>Official Pitt History Department profile</p>
      </a>
      <a href="https://www.history.pitt.edu/" class="info-link">
        <h3>Pitt History Department</h3>
        <p>Department homepage and resources</p>
      </a>
    </div>
  </section>

  <section class="courses-section">
    <h2>Course Websites</h2>
    <div class="course-grid">
      <a href="https://courses.bactriana.org/policies/" class="course-link general-policies">
        <h3>General Course Policies</h3>
        <p>Standard policies and guidelines for all courses</p>
      </a>
      <a href="https://dh.bactriana.org/" class="course-link digital-methods">
        <h3>Digital Methods</h3>
        <p>Tools and techniques for digital humanities research</p>
      </a>
EOF

    # Add syllabus links
    if [ -n "$syllabus_info" ]; then
        echo "$syllabus_info" | while IFS='|' read -r dirname title subtitle; do
            if [ -n "$dirname" ] && [ -n "$title" ]; then
                echo "      <a href=\"https://courses.bactriana.org/$dirname/\" class=\"course-link syllabus-link\">" >> "$splash_file"
                echo "        <h3>$title</h3>" >> "$splash_file"
                if [ -n "$subtitle" ]; then
                    echo "        <p>$subtitle</p>" >> "$splash_file"
                else
                    echo "        <p>Course syllabus and materials</p>" >> "$splash_file"
                fi
                echo "      </a>" >> "$splash_file"
            fi
        done
    fi

    # Close the HTML
    cat >> "$splash_file" << EOF
    </div>
  </section>
</main>

<footer>
  <div class="date-stamp">Last updated on $current_date</div>
</footer>
</body>
</html>
EOF

    echo -e "${GREEN}✓ Created splash page${NC}"
    echo -e "${BLUE}Splash page: $splash_file${NC}"
    return 0
}

# Function to deploy to GitHub
deploy_to_github() {
    echo -e "${BLUE}Deploying to GitHub...${NC}"
    
    cd "$OUTPUT_DIR" || {
        echo -e "${RED}  ✗ Failed to change to repository directory${NC}"
        return 1
    }
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}  ✗ Not in a git repository: $OUTPUT_DIR${NC}"
        return 1
    fi
    
    git add index.html splash.css
    
    if git diff --cached --quiet 2>/dev/null || git diff --quiet --cached 2>/dev/null; then
        echo -e "${YELLOW}  No changes to commit${NC}"
        return 0
    fi
    
    local commit_message="Splash page updated on $(date +'%B %d, %Y at %I:%M %p')"
    if git commit -m "$commit_message"; then
        echo -e "${GREEN}  ✓ Committed: $commit_message${NC}"
    else
        echo -e "${RED}  ✗ Failed to commit changes${NC}"
        return 1
    fi
    
    if git push origin main; then
        echo -e "${GREEN}  ✓ Pushed to GitHub${NC}"
        echo -e "${GREEN}  🌐 Site will be available at: https://courses.bactriana.org/${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to push to GitHub${NC}"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}=== Splash Page Generator ===${NC}"
echo

validate_paths
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}Output directory: $OUTPUT_DIR${NC}"

check_css
echo

syllabus_info=$(detect_syllabus_directories)

echo
create_splash_page "$syllabus_info"

echo
echo -e "${GREEN}✓ Splash page generation complete${NC}"
echo -e "${BLUE}Files saved to: $OUTPUT_DIR${NC}"

echo
deploy_to_github