#!/bin/bash

# ===== SYLLABUS CONVERTER =====
# Converts markdown syllabi to interactive HTML and PDF
# Uses existing fzf functions for file/directory selection
#
# Directory structure expected:
# syllabus-converter/
# ├── convert-syllabus.sh (this script)
# ├── templates/
# │   └── pandoc-syllabus-template.html
# ├── assets/
# │   ├── syllabus-interactive.js
# │   └── themes/
# │       ├── blue-grey.css
# │       ├── earth-tones.css
# │       └── ...
# └── source/
#     ├── imperial-russia.md
#     └── ...

# Set script directory and related paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/templates/pandoc-syllabus-template.html"
ASSETS_DIR="$SCRIPT_DIR/assets"
THEMES_DIR="$SCRIPT_DIR/assets/themes"
JS_FILE="$ASSETS_DIR/syllabus-interactive.js"

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
    echo "Syllabus Converter - Transform markdown syllabi into interactive websites"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --file FILE     Specify markdown file directly (skips fuzzy search)"
    echo "  -o, --output DIR    Specify output directory directly (skips fuzzy search)"
    echo "  -t, --theme THEME   Specify theme directly (skips fuzzy search)"
    echo "  --no-pdf           Skip PDF generation"
    echo "  --open             Open output files after generation"
    echo
    echo "Interactive mode (default):"
    echo "  - Uses fzf to select source file"
    echo "  - Uses fzf to select output directory"
    echo "  - Uses fzf to select theme"
    echo
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 -f source/russia.md -t blue-grey  # Specify file and theme"
    echo "  $0 --no-pdf --open                   # No PDF, open results"
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

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}✗ Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Function to validate file paths
validate_paths() {
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
}

# Function to select markdown file using fzf (like fow but more targeted)
select_markdown_file() {
    echo -e "${BLUE}Searching for markdown files...${NC}" >&2  # <-- ADD >&2 HERE

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
            --header="Select your syllabus markdown file")

    if [ -z "$selected_file" ]; then
        echo -e "${RED}✗ No file selected${NC}" >&2  # <-- ADD >&2 HERE TOO
        exit 1
    fi

    echo "$selected_file"
}

# Function to select output directory using fzf (like fdw but more targeted)
select_output_directory() {
    echo -e "${BLUE}Searching for output directories...${NC}" >&2

    # Search in common output locations
    local search_dirs=(
        "$HOME/Sites"
        "$HOME/Dropbox/Active_Directories"
        "$HOME/Desktop"
        "$HOME/Documents"
        "$SCRIPT_DIR/.."  # Parent directory for course repos
    )

    # Build find command for existing directories
    local find_args=()
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find_args+=("$dir")
        fi
    done

    if [ ${#find_args[@]} -eq 0 ]; then
            echo -e "${YELLOW}No standard directories found, using current directory...${NC}" >&2  # Add >&2 here
            find_args=(".")
        fi

    local selected_dir
    selected_dir=$(find "${find_args[@]}" -type d 2>/dev/null | \
        fzf --preview 'ls -la {}' \
            --preview-window=right:60% \
            --prompt="Select output directory: " \
            --header="Select where to save the generated files")

    if [ -z "$selected_dir" ]; then
        echo -e "${RED}✗ No directory selected${NC}" >&2
        exit 1
    fi

    echo "$selected_dir"
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
            --header="Select a color theme for your syllabus")

    if [ -z "$selected_theme" ]; then
        echo -e "${RED}✗ No theme selected${NC}" >&2
        exit 1
    fi

    echo "$selected_theme"
}

# Function to convert markdown to HTML
convert_to_html() {
    local source_file="$1"
    local output_dir="$2"
    local output_file="$output_dir/index.html"

    echo -e "${BLUE}Converting markdown to HTML...${NC}"


    # Run pandoc with our custom template
    if pandoc "$source_file" \
        -o "$output_file" \
        --template="$TEMPLATE_FILE" \
        --standalone \
        --toc \
        --toc-depth=3 \
        --metadata-file=<(echo "date: $(date +'%B %Y')"); then

        echo -e "${GREEN}✓ HTML generated: $output_file${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to generate HTML${NC}"
        return 1
    fi
}

# Function to convert markdown to PDF (using existing script logic)
convert_to_pdf() {
    local source_file="$1"
    local output_dir="$2"
    local basename=$(basename "$source_file" .md)
    local pdf_file="$output_dir/${basename}.pdf"

    echo -e "${BLUE}Converting markdown to PDF...${NC}"

    # Check if BasicTeX is available
    if command -v pdflatex >/dev/null 2>&1; then
        # Use LaTeX engine
        if pandoc "$source_file" \
            -o "$pdf_file" \
            --pdf-engine=xelatex \
            --variable=geometry:margin=1in \
            --metadata-file=<(echo "date: $(date +'%B %Y')") \
            2>/dev/null; then

            echo -e "${GREEN}✓ PDF generated: $pdf_file${NC}"
            return 0
        fi
    fi

    # Fallback: Generate HTML first, then convert to PDF
    echo -e "${YELLOW}Falling back to HTML→PDF conversion...${NC}"
    local temp_html="$output_dir/temp_syllabus.html"

    if pandoc "$source_file" \
        -o "$temp_html" \
        --standalone \
        --css="$HOME/.pandoc/default.css" \
        --metadata-file=<(echo "date: $(date +'%B %Y')") \
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
                return 0
            fi
        fi
    fi

    echo -e "${YELLOW}⚠ PDF generation failed, but HTML was created successfully${NC}"
    return 1
}

# Function to copy assets
copy_assets() {
    local output_dir="$1"
    local theme="$2"
    local theme_file="$THEMES_DIR/${theme}.css"

    echo -e "${BLUE}Copying assets...${NC}"

    # Copy JavaScript
    if cp "$JS_FILE" "$output_dir/"; then
        echo -e "${GREEN}✓ Copied: syllabus-interactive.js${NC}"
    else
        echo -e "${RED}✗ Failed to copy JavaScript file${NC}"
        return 1
    fi

    # Copy and rename theme CSS
    if cp "$theme_file" "$output_dir/syllabus-styles.css"; then
        echo -e "${GREEN}✓ Copied theme: $theme${NC}"
    else
        echo -e "${RED}✗ Failed to copy theme file${NC}"
        return 1
    fi

    return 0
}

# Function to open generated files
open_files() {
    local output_dir="$1"
    local basename="$2"

    if [ "$OPEN_FILES" = true ]; then
        if [ -f "$output_dir/index.html" ]; then
            echo -e "${BLUE}Opening HTML file...${NC}"
            open "$output_dir/index.html" 2>/dev/null || xdg-open "$output_dir/index.html" 2>/dev/null
        fi

        if [ -f "$output_dir/${basename}.pdf" ]; then
            echo -e "${BLUE}Opening PDF file...${NC}"
            open "$output_dir/${basename}.pdf" 2>/dev/null || xdg-open "$output_dir/${basename}.pdf" 2>/dev/null
        fi
    fi
}

# Parse command line arguments
SOURCE_FILE=""
OUTPUT_DIR=""
THEME=""
SKIP_PDF=false
OPEN_FILES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -f|--file)
            SOURCE_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
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
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Main execution
echo -e "${BLUE}=== Syllabus Converter ===${NC}"
echo

# Check dependencies and validate paths
check_dependencies
validate_paths

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

# Get output directory (interactive or from command line)
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(select_output_directory)
else
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
        mkdir -p "$OUTPUT_DIR"
    fi
fi

echo -e "${GREEN}Output directory: $OUTPUT_DIR${NC}"

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
echo

# Perform conversions
BASENAME=$(basename "$SOURCE_FILE" .md)

# Convert to HTML
if ! convert_to_html "$SOURCE_FILE" "$OUTPUT_DIR"; then
    echo -e "${RED}✗ HTML conversion failed${NC}"
    exit 1
fi

# Convert to PDF (unless skipped)
if [ "$SKIP_PDF" = false ]; then
    convert_to_pdf "$SOURCE_FILE" "$OUTPUT_DIR"
fi

# Copy assets
if ! copy_assets "$OUTPUT_DIR" "$THEME"; then
    echo -e "${RED}✗ Asset copying failed${NC}"
    exit 1
fi

# Open files if requested
open_files "$OUTPUT_DIR" "$BASENAME"

echo
echo -e "${GREEN}=== Conversion Complete! ===${NC}"
echo -e "${GREEN}Files generated in: $OUTPUT_DIR${NC}"
echo -e "${BLUE}HTML: $OUTPUT_DIR/index.html${NC}"
if [ "$SKIP_PDF" = false ] && [ -f "$OUTPUT_DIR/${BASENAME}.pdf" ]; then
    echo -e "${BLUE}PDF: $OUTPUT_DIR/${BASENAME}.pdf${NC}"
fi
echo -e "${BLUE}Assets: syllabus-styles.css, syllabus-interactive.js${NC}"
