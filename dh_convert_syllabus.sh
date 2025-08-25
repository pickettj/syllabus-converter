#!/bin/bash

# ===== DH COURSE WEBSITE SYLLABUS CONVERTER =====
# Specialized converter for dh.bactriana.org syllabi
# Converts markdown to XHTML with course navigation
# Author: James Pickett
# Version: 2.0 - Added PDF generation and JavaScript support

# Set script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"
THEME_FILE="$ASSETS_DIR/themes/dh.css"
JS_FILE="$ASSETS_DIR/syllabus-interactive.js"
OUTPUT_DIR="$SCRIPT_DIR/../dh_website"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
show_help() {
    echo "DH Course Website Syllabus Converter"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --file FILE     Specify markdown file directly (skips fuzzy search)"
    echo "  --no-toc           Skip table of contents generation"
    echo "  --no-pdf          Skip PDF generation"
    echo "  --open             Open output files after generation"
    echo
    echo "Interactive mode (default):"
    echo "  Uses fzf to select source markdown file"
    echo "  Outputs to ../dh_website/syllabus.xhtml"
    echo "  Uses dh.css theme automatically"
    echo "  Generates PDF version"
    echo "  Copies JavaScript for interactivity"
    echo
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 -f syllabus_fall2025.md          # Specify file directly"
    echo "  $0 --open --no-pdf                  # Open result, skip PDF"
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
        echo
        echo "To install:"
        echo "  pandoc: brew install pandoc"
        echo "  fzf: brew install fzf"
        exit 1
    fi
}

# Function to validate paths
validate_paths() {
    if [ ! -f "$THEME_FILE" ]; then
        echo -e "${RED}✗ Theme file not found: $THEME_FILE${NC}"
        echo "Please ensure dh.css exists in assets/themes/"
        exit 1
    fi

    if [ ! -f "$JS_FILE" ]; then
        echo -e "${RED}✗ JavaScript file not found: $JS_FILE${NC}"
        echo "Please ensure syllabus-interactive.js exists in assets/"
        exit 1
    fi

    if [ ! -d "$(dirname "$OUTPUT_DIR")" ]; then
        echo -e "${RED}✗ Parent directory not found: $(dirname "$OUTPUT_DIR")${NC}"
        echo "Please ensure ../dh_website exists"
        exit 1
    fi

    # Create output directory if it doesn't exist
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
        mkdir -p "$OUTPUT_DIR"
    fi

    # Create subdirectories in output if they don't exist
    for subdir in css javascript; do
        if [ ! -d "$OUTPUT_DIR/$subdir" ]; then
            mkdir -p "$OUTPUT_DIR/$subdir"
        fi
    done
}

# Function to select markdown file using fzf
select_markdown_file() {
    echo -e "${BLUE}Select the syllabus markdown file:${NC}" >&2

    local search_dirs=("$SCRIPT_DIR" "$SCRIPT_DIR/source" "$HOME/Documents" "$HOME/Desktop")
    local find_args=()

    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find_args+=("$dir")
        fi
    done

    if [ ${#find_args[@]} -eq 0 ]; then
        echo -e "${RED}✗ No valid search directories found${NC}" >&2
        exit 1
    fi

    local selected_file
    selected_file=$(find "${find_args[@]}" -name "*.md" -type f 2>/dev/null | \
        fzf --preview 'head -50 {}' \
            --preview-window=right:60% \
            --prompt="Select syllabus: " \
            --header="Choose your markdown syllabus file")

    if [ -z "$selected_file" ]; then
        echo -e "${RED}✗ No file selected${NC}" >&2
        exit 1
    fi

    echo "$selected_file"
}

# Function to create the DH navigation header
# Function to create the DH navigation header
create_nav_header() {
    cat << 'EOF'
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Course syllabus for Computational Methods in the Humanities - Digital Humanities at University of Pittsburgh" />
    <title>Syllabus - Digital Humanities</title>
    <link rel="stylesheet" type="text/css" href="css/style.css" />
    <link rel="stylesheet" type="text/css" href="css/syllabus.css" />
    <link href="https://fonts.googleapis.com/css?family=Assistant" rel="stylesheet" />
    <script src="javascript/syllabus-interactive.js" defer="defer"></script>
</head>
<body>
    <a href="#main-content" class="skip-link">Skip to main content</a>

    <header>
        <nav role="navigation" aria-label="Main navigation">
            <a href="index.xhtml">Home</a>
            <a href="syllabus.xhtml" aria-current="page">Syllabus</a>
            <a href="description.xhtml">Policies</a>
            <a href="projects.xhtml">Projects</a>
            <!-- <a href="assignments.xhtml">Assignments</a> -->
            <a href="http://dh.obdurodon.org/" target="_blank" rel="noopener">Resources</a>
            <a href="https://bactriana.org" target="_blank" rel="noopener">Bactriana</a>
        </nav>
    </header>

    <main id="main-content">
EOF
}


# Function to create the footer
create_footer() {
    cat << 'EOF'
    </main>
</body>
</html>
EOF
}

# Function to convert markdown to HTML body content
convert_markdown_to_body() {
    local source_file="$1"
    local include_toc="$2"

    local toc_option=""
    if [ "$include_toc" = true ]; then
        toc_option="--toc --toc-depth=3"
    fi

    # Convert markdown to HTML fragment (body content only)
    pandoc "$source_file" \
        -f markdown \
        -t html5 \
        $toc_option \
        --no-highlight \
        --section-divs
}

# Function to process the HTML to add syllabus-specific classes
process_html_content() {
    local html_content="$1"

    # Add classes to different sections based on headers
    # This is a simplified version - you might want to enhance this
    echo "$html_content" | sed \
        -e 's/<h4>Class:/<h4 class="class-section">Class:/g' \
        -e 's/<h4>Homework:/<h4 class="homework-section">Homework:/g' \
        -e 's/<h5>Associated Recitation/<h5 class="recitation-section">Associated Recitation/g' \
        -e 's/<h3>\(.*day, [A-Z].*\)/<h3 class="schedule-week">\1/g'
}

# Function to copy assets (CSS and JavaScript)
copy_assets() {
    echo -e "${BLUE}Copying assets...${NC}"

    # Copy the JavaScript file
    if cp "$JS_FILE" "$OUTPUT_DIR/javascript/syllabus-interactive.js"; then
        echo -e "${GREEN}✓ Copied: syllabus-interactive.js${NC}"
    else
        echo -e "${RED}✗ Failed to copy JavaScript file${NC}"
        return 1
    fi

    # Copy the CSS theme and rename it to syllabus.css
    if cp "$THEME_FILE" "$OUTPUT_DIR/css/syllabus.css"; then
        echo -e "${GREEN}✓ Copied: dh.css → syllabus.css${NC}"
    else
        echo -e "${RED}✗ Failed to copy CSS theme${NC}"
        return 1
    fi

    # Check if main style.css exists in output, if not, notify
    if [ ! -f "$OUTPUT_DIR/css/style.css" ]; then
        echo -e "${YELLOW}⚠ Note: css/style.css not found in output directory${NC}"
        echo -e "${YELLOW}  The syllabus will need the main site CSS to display properly${NC}"
    fi

    return 0
}

# Function to convert markdown to PDF (adapted from convert-syllabus.sh)
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

    echo -e "${YELLOW}⚠ PDF generation failed, but XHTML was created successfully${NC}"
    return 1
}

# Function to assemble the complete XHTML file
assemble_xhtml() {
    local source_file="$1"
    local output_file="$2"
    local include_toc="$3"

    echo -e "${BLUE}Converting markdown to XHTML...${NC}"

    # Create temporary file for processing
    local temp_file=$(mktemp)

    # Generate the navigation header
    create_nav_header > "$temp_file"

    # Convert and process the markdown content
    local body_content=$(convert_markdown_to_body "$source_file" "$include_toc")
    local processed_content=$(process_html_content "$body_content")

    # Add the processed content
    echo "$processed_content" >> "$temp_file"

    # Add the footer
    create_footer >> "$temp_file"

    # Move the temp file to the output location
    mv "$temp_file" "$output_file"

    echo -e "${GREEN}✓ Generated: $output_file${NC}"
    return 0
}

# Function to open the generated files
open_files() {
    local xhtml_file="$1"
    local pdf_file="$2"

    if [ "$OPEN_FILES" = true ]; then
        echo -e "${BLUE}Opening syllabus files...${NC}"

        if [ -f "$xhtml_file" ]; then
            if command -v open >/dev/null 2>&1; then
                open "$xhtml_file"
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$xhtml_file"
            fi
        fi

        if [ -f "$pdf_file" ]; then
            if command -v open >/dev/null 2>&1; then
                open "$pdf_file"
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$pdf_file"
            fi
        fi

        if ! command -v open >/dev/null 2>&1 && ! command -v xdg-open >/dev/null 2>&1; then
            echo -e "${YELLOW}Could not open files automatically${NC}"
        fi
    fi
}

# Parse command line arguments
SOURCE_FILE=""
INCLUDE_TOC=true
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
        --no-toc)
            INCLUDE_TOC=false
            shift
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
echo -e "${BLUE}=== DH Course Website Syllabus Converter ===${NC}"
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

echo -e "${GREEN}Source: $SOURCE_FILE${NC}"
echo -e "${GREEN}Output: $OUTPUT_DIR/syllabus.xhtml${NC}"
echo -e "${GREEN}Theme: dh.css${NC}"
echo

# Convert the syllabus
OUTPUT_FILE="$OUTPUT_DIR/syllabus.xhtml"
if ! assemble_xhtml "$SOURCE_FILE" "$OUTPUT_FILE" "$INCLUDE_TOC"; then
    echo -e "${RED}✗ Conversion failed${NC}"
    exit 1
fi

# Copy assets (CSS and JavaScript)
if ! copy_assets; then
    echo -e "${YELLOW}⚠ Asset copy had issues, but XHTML was created${NC}"
fi

# Generate PDF (unless skipped)
BASENAME=$(basename "$SOURCE_FILE" .md)
PDF_FILE="$OUTPUT_DIR/${BASENAME}.pdf"
if [ "$SKIP_PDF" = false ]; then
    convert_to_pdf "$SOURCE_FILE" "$OUTPUT_DIR"
fi

# Open files if requested
open_files "$OUTPUT_FILE" "$PDF_FILE"

echo
echo -e "${GREEN}=== Conversion Complete! ===${NC}"
echo -e "${GREEN}Syllabus created at: $OUTPUT_FILE${NC}"
if [ "$SKIP_PDF" = false ] && [ -f "$PDF_FILE" ]; then
    echo -e "${GREEN}PDF created at: $PDF_FILE${NC}"
fi
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated syllabus.xhtml and PDF"
echo "2. Ensure css/style.css exists in the output directory"
echo "3. Push changes to your GitHub repository"
echo "4. The syllabus will be live at: https://dh.bactriana.org/syllabus.xhtml"
