#!/bin/bash

# ===== DH SYLLABUS CONVERTER =====
# Converts markdown syllabi to XHTML for dh.bactriana.org
# Always outputs to ../dh_website with specific structure
#
# Directory structure expected:
# syllabus-converter/
# ├── dh-convert-syllabus.sh (this script)
# ├── templates/
# │   └── pandoc-dh-template.html
# ├── assets/
# │   ├── syllabus-interactive.js
# │   └── themes/
# │       ├── blue-grey.css
# │       ├── earth-tones.css
# │       └── ...
# └── source/
#     ├── imperial-russia.md
#     └── ...
#
# Output structure:
# ../dh_website/
# ├── syllabus.xhtml
# ├── css/
# │   ├── style.css (from main site)
# │   └── syllabus-styles.css (from theme)
# └── javascript/
#     └── syllabus-interactive.js

# Set script directory and related paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/templates/pandoc-dh-template.html"
ASSETS_DIR="$SCRIPT_DIR/assets"
THEMES_DIR="$SCRIPT_DIR/assets/themes"
JS_FILE="$ASSETS_DIR/syllabus-interactive.js"

# Fixed output directory for DH website
OUTPUT_DIR="$SCRIPT_DIR/../dh_website"

# Path to main site's style.css (assuming it's in the dh_website css directory)
MAIN_STYLE_CSS="$OUTPUT_DIR/css/style.css"

# Import user's fzf functions if available
if [ -f "$HOME/.fzf_functions" ]; then
    source "$HOME/.fzf_functions"
elif [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
show_help() {
    echo "DH Syllabus Converter - Transform markdown syllabi for dh.bactriana.org"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --file FILE     Specify markdown file directly (skips fuzzy search)"
    echo "  -t, --theme THEME   Specify theme directly (skips fuzzy search)"
    echo "  --no-pdf           Skip PDF generation"
    echo "  --open             Open output files after generation"
    echo "  --git              Add, commit, and push changes to git from output directory"
    echo
    echo "Output:"
    echo "  Always outputs to: ../dh_website/"
    echo "  XHTML file: ../dh_website/syllabus.xhtml"
    echo "  Main CSS: ../dh_website/css/style.css"
    echo "  Syllabus CSS: ../dh_website/css/syllabus-styles.css"
    echo "  JS: ../dh_website/javascript/syllabus-interactive.js"
    echo
    echo "Interactive mode (default):"
    echo "  - Uses fzf to select source file"
    echo "  - Uses fzf to select theme"
    echo
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 -f source/dh-syllabus.md -t dh    # Specify file and theme"
    echo "  $0 --no-pdf --open                   # No PDF, open results"
    echo "  $0 --git                              # Include git operations"
    exit 0
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v pandoc >/dev/null 2>&1; then
        missing_deps+=("pandoc")
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        missing_deps+=("fzf")
    fi

    if [ "$USE_GIT" = true ] && ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}✗ Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Function to validate file paths and create output structure
validate_and_setup_paths() {
    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo -e "${RED}✗ Template file not found: $TEMPLATE_FILE${NC}"
        exit 1
    fi

    if [ ! -f "$JS_FILE" ]; then
        echo -e "${RED}✗ JavaScript file not found: $JS_FILE${NC}"
        exit 1
    fi

    if [ ! -d "$THEMES_DIR" ]; then
        echo -e "${RED}✗ Themes directory not found: $THEMES_DIR${NC}"
        exit 1
    fi

    # Create output directory structure
    echo -e "${BLUE}Setting up output directory structure...${NC}"

    if [ ! -d "$OUTPUT_DIR" ]; then
        echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
        mkdir -p "$OUTPUT_DIR"
    fi

    # Create subdirectories
    for subdir in css javascript; do
        if [ ! -d "$OUTPUT_DIR/$subdir" ]; then
            echo -e "${YELLOW}Creating subdirectory: $OUTPUT_DIR/$subdir${NC}"
            mkdir -p "$OUTPUT_DIR/$subdir"
        fi
    done

    echo -e "${GREEN}✓ Output directory structure ready${NC}"
}

# Function to select markdown file using fzf (like fow but more targeted)
select_markdown_file() {
    echo -e "${BLUE}Searching for markdown files...${NC}" >&2

    # Search in common directories, prioritizing syllabus-related locations
    local search_dirs=(
        "$SCRIPT_DIR/source"
        "$HOME/Dropbox/Active_Directories/Teaching"
        "$HOME/Dropbox/Active_Directories"
        "$HOME/Documents"
        "$HOME/Desktop"
    )

    # Build find command for existing directories
    local find_args=()
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find_args+=("$dir")
        fi
    done

    if [ ${#find_args[@]} -eq 0 ]; then
        echo -e "${YELLOW}No standard directories found, searching current directory...${NC}" >&2
        find_args=(".")
    fi

    local selected_file
    selected_file=$(find "${find_args[@]}" -type f -name "*.md" 2>/dev/null | \
        fzf --preview 'head -20 {}' \
            --preview-window=right:60% \
            --prompt="Select markdown file: " \
            --header="Select your DH syllabus markdown file")

    if [ -z "$selected_file" ]; then
        echo -e "${RED}✗ No file selected${NC}" >&2
        exit 1
    fi

    echo "$selected_file"
}

# Function to select theme
select_theme() {
    echo -e "${BLUE}Available themes:${NC}" >&2

    local selected_theme
    selected_theme=$(find "$THEMES_DIR" -name "*.css" 2>/dev/null | \
        sed 's|.*/||' | sed 's|\.css$||' | \
        fzf --preview "head -20 $THEMES_DIR/{}.css" \
            --preview-window=right:60% \
            --prompt="Select theme: " \
            --header="Select a color theme for your DH syllabus")

    if [ -z "$selected_theme" ]; then
        echo -e "${RED}✗ No theme selected${NC}" >&2
        exit 1
    fi

    echo "$selected_theme"
}

# Function to preprocess markdown for better list handling
preprocess_markdown() {
    local source_file="$1"
    local temp_file="$2"
    
    # Use awk to insert blank lines before bullet points that directly follow non-blank lines
    awk '
    NR > 1 {
        # Check if current line is a bullet point and previous line was non-blank and non-bullet
        if ($0 ~ /^[[:space:]]*[-*+] / && prev_line != "" && prev_line !~ /^[[:space:]]*[-*+] /) {
            print prev_line  # Print the previous line
            print ""         # Then insert a blank line before the bullet
        } else {
            print prev_line  # Just print previous line normally
        }
    }
    { prev_line = $0 }  # Store current line as previous for next iteration
    END { if (NR > 0) print prev_line }  # Print the last line
    ' "$source_file" > "$temp_file"
}

# Function to convert markdown to XHTML
convert_to_xhtml() {
    local source_file="$1"
    local output_file="$OUTPUT_DIR/syllabus.xhtml"

    echo -e "${BLUE}Converting markdown to XHTML...${NC}"

    # Generate PDF filename for the download link
    local basename=$(basename "$source_file" .md)
    local pdf_filename="${basename}.pdf"
    
    # Create temporary file for preprocessed markdown
    local temp_md=$(mktemp)
    trap "rm -f $temp_md" EXIT
    
    # Preprocess the markdown to fix bullet point spacing
    preprocess_markdown "$source_file" "$temp_md"

    # Run pandoc with our custom template, outputting XHTML
    pandoc "$temp_md" \
        -o "$output_file" \
        --template="$TEMPLATE_FILE" \
        --standalone \
        --toc \
        --toc-depth=3 \
        -t html \
        --variable="pdf-filename:$pdf_filename" \
        --variable="date:$(date +'%B %d, %Y')"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ XHTML generated: $output_file${NC}"
        rm -f "$temp_md"
        return 0
    else
        echo -e "${RED}✗ Failed to generate XHTML${NC}"
        rm -f "$temp_md"
        return 1
    fi
}

# Function to convert markdown to PDF
convert_to_pdf() {
    local source_file="$1"
    local basename=$(basename "$source_file" .md)
    local pdf_file="$OUTPUT_DIR/${basename}.pdf"

    echo -e "${BLUE}Converting markdown to PDF...${NC}"
    
    # Create temporary file for preprocessed markdown
    local temp_md=$(mktemp)
    trap "rm -f $temp_md" EXIT
    
    # Preprocess the markdown to fix bullet point spacing
    preprocess_markdown "$source_file" "$temp_md"

    # Check if BasicTeX is available
    if command -v pdflatex >/dev/null 2>&1; then
        # Use LaTeX engine with preprocessed file
        if pandoc "$temp_md" \
            -o "$pdf_file" \
            --pdf-engine=xelatex \
            --variable=geometry:margin=1in \
            --variable="date:$(date +'%B %Y')" \
            2>/dev/null; then

            echo -e "${GREEN}✓ PDF generated: $pdf_file${NC}"
            rm -f "$temp_md"
            return 0
        fi
    fi

    # Fallback: Generate HTML first, then convert to PDF
    echo -e "${YELLOW}Falling back to HTML→PDF conversion...${NC}"
    local temp_html="$OUTPUT_DIR/temp_syllabus.html"

    if pandoc "$temp_md" \
        -o "$temp_html" \
        --standalone \
        --css="$HOME/.pandoc/default.css" \
        --variable="date:$(date +'%B %Y')" \
        2>/dev/null; then

        # Try to convert HTML to PDF using Chrome/Chromium
        local chrome_path=""
        if [ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
            chrome_path="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        elif command -v google-chrome &>/dev/null; then
            chrome_path="google-chrome"
        fi

        if [ -n "$chrome_path" ]; then
            "$chrome_path" --headless --disable-gpu --print-to-pdf="$pdf_file" "file://$temp_html" 2>/dev/null
            rm "$temp_html"

            if [ -f "$pdf_file" ] && [ -s "$pdf_file" ]; then
                echo -e "${GREEN}✓ PDF generated: $pdf_file${NC}"
                rm -f "$temp_md"
                return 0
            fi
        fi
    fi

    echo -e "${YELLOW}⚠ PDF generation failed, but XHTML was created successfully${NC}"
    rm -f "$temp_md"
    return 1
}

# Function to copy assets to proper subdirectories
copy_assets() {
    local theme="$1"
    local theme_file="$THEMES_DIR/${theme}.css"

    echo -e "${BLUE}Copying assets to subdirectories...${NC}"

    # Copy JavaScript to javascript subdirectory
    local js_target="$OUTPUT_DIR/javascript/syllabus-interactive.js"
    if cp "$JS_FILE" "$js_target"; then
        echo -e "${GREEN}✓ Copied: javascript/syllabus-interactive.js${NC}"
    else
        echo -e "${RED}✗ Failed to copy JavaScript file${NC}"
        return 1
    fi

    # Check if main site's style.css exists, if not create a warning but continue
    if [ ! -f "$MAIN_STYLE_CSS" ]; then
        echo -e "${YELLOW}⚠ Main site style.css not found at: $MAIN_STYLE_CSS${NC}"
        echo -e "${YELLOW}  The syllabus will use only the theme CSS${NC}"
        echo -e "${YELLOW}  To fix: ensure the main website's style.css is in ../dh_website/css/${NC}"
    else
        echo -e "${GREEN}✓ Main site style.css found${NC}"
    fi

    # Copy and rename theme CSS to css subdirectory as syllabus-styles.css
    local css_target="$OUTPUT_DIR/css/syllabus-styles.css"
    if cp "$theme_file" "$css_target"; then
        echo -e "${GREEN}✓ Copied theme to: css/syllabus-styles.css${NC}"
    else
        echo -e "${RED}✗ Failed to copy theme file${NC}"
        return 1
    fi

    return 0
}

# Function to handle git operations
git_commit_and_push() {
    local current_dir=$(pwd)

    echo -e "${BLUE}Performing git operations...${NC}"

    # Change to output directory
    cd "$OUTPUT_DIR" || {
        echo -e "${RED}✗ Failed to change to output directory: $OUTPUT_DIR${NC}"
        return 1
    }

    # Check if this is a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Output directory is not a git repository${NC}"
        echo -e "${YELLOW}  Skipping git operations${NC}"
        cd "$current_dir"
        return 0
    fi

    # Generate timestamp for commit message
    local timestamp=$(date +'%B %d, %Y at %I:%M %p')
    local commit_message="DH Syllabus updated on $timestamp"

    # Add all changes
    echo -e "${BLUE}Adding files to git...${NC}"
    if git add .; then
        echo -e "${GREEN}✓ Files added to git${NC}"
    else
        echo -e "${RED}✗ Failed to add files to git${NC}"
        cd "$current_dir"
        return 1
    fi

    # Check if there are changes to commit
    if git diff --staged --quiet; then
        echo -e "${YELLOW}⚠ No changes to commit${NC}"
        cd "$current_dir"
        return 0
    fi

    # Commit changes
    echo -e "${BLUE}Committing changes...${NC}"
    if git commit -m "$commit_message"; then
        echo -e "${GREEN}✓ Changes committed: $commit_message${NC}"
    else
        echo -e "${RED}✗ Failed to commit changes${NC}"
        cd "$current_dir"
        return 1
    fi

    # Push to remote
    echo -e "${BLUE}Pushing to remote repository...${NC}"
    if git push; then
        echo -e "${GREEN}✓ Changes pushed to remote repository${NC}"
    else
        echo -e "${RED}✗ Failed to push to remote repository${NC}"
        echo -e "${YELLOW}  Changes were committed locally but not pushed${NC}"
        cd "$current_dir"
        return 1
    fi

    # Return to original directory
    cd "$current_dir"
    return 0
}

# Function to open generated files
open_files() {
    local basename="$1"

    if [ "$OPEN_FILES" = true ]; then
        if [ -f "$OUTPUT_DIR/syllabus.xhtml" ]; then
            echo -e "${BLUE}Opening XHTML file...${NC}"
            open "$OUTPUT_DIR/syllabus.xhtml" 2>/dev/null || xdg-open "$OUTPUT_DIR/syllabus.xhtml" 2>/dev/null
        fi

        if [ -f "$OUTPUT_DIR/${basename}.pdf" ]; then
            echo -e "${BLUE}Opening PDF file...${NC}"
            open "$OUTPUT_DIR/${basename}.pdf" 2>/dev/null || xdg-open "$OUTPUT_DIR/${basename}.pdf" 2>/dev/null
        fi
    fi
}

# Parse command line arguments
SOURCE_FILE=""
THEME=""
SKIP_PDF=false
OPEN_FILES=false
USE_GIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -f|--file)
            SOURCE_FILE="$2"
            shift 2
            ;;
        -t|--theme)
            THEME="$2"
            shift 2
            ;;
        --no-pdf)
            SKIP_PDF=true
            shift
            ;;
        --open)
            OPEN_FILES=true
            shift
            ;;
        --git)
            USE_GIT=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Main execution
echo -e "${BLUE}=== DH Syllabus Converter ===${NC}"
echo -e "${BLUE}Output destination: $OUTPUT_DIR${NC}"
echo

# Check dependencies and validate paths
check_dependencies
validate_and_setup_paths

# Get source file (interactive or from command line)
if [ -z "$SOURCE_FILE" ]; then
    SOURCE_FILE=$(select_markdown_file)
else
    if [ ! -f "$SOURCE_FILE" ]; then
        echo -e "${RED}✗ Source file not found: $SOURCE_FILE${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Source file: $SOURCE_FILE${NC}"

# Get theme (interactive or from command line)
if [ -z "$THEME" ]; then
    THEME=$(select_theme)
else
    if [ ! -f "$THEMES_DIR/${THEME}.css" ]; then
        echo -e "${RED}✗ Theme not found: $THEMES_DIR/${THEME}.css${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Theme: $THEME${NC}"
if [ "$USE_GIT" = true ]; then
    echo -e "${GREEN}Git operations: enabled${NC}"
fi
echo

# Perform conversions
BASENAME=$(basename "$SOURCE_FILE" .md)

# Convert to XHTML
if ! convert_to_xhtml "$SOURCE_FILE"; then
    echo -e "${RED}✗ XHTML conversion failed${NC}"
    exit 1
fi

# Convert to PDF (unless skipped)
if [ "$SKIP_PDF" = false ]; then
    convert_to_pdf "$SOURCE_FILE"
fi

# Copy assets to subdirectories
if ! copy_assets "$THEME"; then
    echo -e "${RED}✗ Asset copying failed${NC}"
    exit 1
fi

# Perform git operations if requested
if [ "$USE_GIT" = true ]; then
    git_commit_and_push
fi

# Open files if requested
open_files "$BASENAME"

echo
echo -e "${GREEN}=== DH Conversion Complete! ===${NC}"
echo -e "${GREEN}Files generated in: $OUTPUT_DIR${NC}"
echo -e "${BLUE}XHTML: $OUTPUT_DIR/syllabus.xhtml${NC}"
echo -e "${BLUE}Main CSS: $OUTPUT_DIR/css/style.css${NC}"
echo -e "${BLUE}Syllabus CSS: $OUTPUT_DIR/css/syllabus-styles.css${NC}"
echo -e "${BLUE}JS: $OUTPUT_DIR/javascript/syllabus-interactive.js${NC}"
if [ "$SKIP_PDF" = false ] && [ -f "$OUTPUT_DIR/${BASENAME}.pdf" ]; then
    echo -e "${BLUE}PDF: $OUTPUT_DIR/${BASENAME}.pdf${NC}"
fi
if [ "$USE_GIT" = true ]; then
    echo -e "${BLUE}Git: Changes committed and pushed${NC}"
fi