#!/bin/bash

# GitOps-Homelab - SAFE FILE EXPORTER
# Usage: ./script.sh > context.txt

# --- CONFIGURATION ---
OUTPUT_FILENAME="context.txt"
MAX_FILE_SIZE_KB=500
EXCLUDE_DIRS="\.git\|\.terraform\|node_modules\|venv\|\.venv\|dist\|build\|\.cache"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- COLOR LOGIC ---
# Only use colors if outputting to a terminal (not a file)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' WHITE='' NC=''
fi

echo -e "${WHITE}================================================================================${NC}"
echo -e "${WHITE}                    GitOps-Homelab Project Context                           ${NC}"
echo -e "${WHITE}================================================================================${NC}"
echo -e "Generated on: $(date)"
echo -e "Project Root: $PROJECT_ROOT"
echo ""

echo -e "${WHITE}🌳 DIRECTORY TREE STRUCTURE${NC}"
if command -v tree >/dev/null 2>&1; then
    tree -I '.git|.terraform|node_modules|venv|.venv|dist|build|.cache' "$PROJECT_ROOT"
else
    find . -maxdepth 2 -not -path '*/.*'
fi

echo -e "\n${WHITE}================================================================================${NC}"
echo -e "${WHITE}                    FILE CONTENTS                                              ${NC}"
echo -e "${WHITE}================================================================================${NC}"

# Find files but EXPLICITLY ignore the output file itself to prevent crashes
while IFS= read -r file; do
    # 1. Skip if it's the output file we are currently writing to
    if [[ "$file" == *"$OUTPUT_FILENAME"* ]]; then continue; fi
    
    # 2. Check file size
    filesize=$(du -k "$file" | cut -f1)
    if [ "$filesize" -gt "$MAX_FILE_SIZE_KB" ]; then
        echo -e "${RED} [!] Skipping $file (Too Large: ${filesize}KB)${NC}"
        continue
    fi

    relative_path="${file#$PROJECT_ROOT/}"
    
    echo -e "\n${WHITE}--- FILE: $relative_path ---${NC}"
    
    # Use cat for file output (cleaner than bat for text files)
    if [ -t 1 ] && command -v bat >/dev/null 2>&1; then
        bat --style=plain --color=always "$file"
    else
        cat "$file"
    fi
    echo ""

done < <(find "$PROJECT_ROOT" -type f \
    \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" -o -name "*.mermaid" -o -name "*.ini" -o -name "*.hcl" -o -name "*.json" -o -name "*.txt" -o -name "*.conf" -o -name "*.config" \) \
    -not -path "*/.*" | grep -v -E "$EXCLUDE_DIRS")

echo -e "\n${GREEN}✅ Done.${NC}"