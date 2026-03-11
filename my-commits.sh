#!/bin/bash

# Interactive script to list commits by current git user from multiple projects
# Usage: ./my-commits.sh

echo "=================================================="
echo "       Git Multi-Project Commit Reporter"
echo "=================================================="
echo ""

# Function to validate date format
validate_date() {
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get date range from user
CURRENT_DATE=$(date +%Y-%m-%d)

while true; do
    read -p "Enter start date (YYYY-MM-DD) [$CURRENT_DATE]: " FROM_DATE
    FROM_DATE=${FROM_DATE:-$CURRENT_DATE}
    if validate_date "$FROM_DATE"; then
        break
    else
        echo "Invalid date format. Please use YYYY-MM-DD"
    fi
done

while true; do
    read -p "Enter end date (YYYY-MM-DD) [$CURRENT_DATE]: " TO_DATE
    TO_DATE=${TO_DATE:-$CURRENT_DATE}
    if validate_date "$TO_DATE"; then
        break
    else
        echo "Invalid date format. Please use YYYY-MM-DD"
    fi
done

echo ""
echo "Scanning for project folders..."
echo ""

# Get current directory
CURRENT_DIR=$(pwd)

# Scan for folders (excluding hidden folders and common non-project folders)
FOLDERS=()
while IFS= read -r folder; do
    FOLDERS+=("$folder")
done < <(ls -d */ 2>/dev/null | sed 's/\\\///' | grep -v -E "^(node_modules|vendor|dist|build|\\.)" || true)

if [ ${#FOLDERS[@]} -eq 0 ]; then
    echo "No folders found in current directory!"
    exit 1
fi

# Display available folders
echo "Available project folders:"
echo ""
for i in "${!FOLDERS[@]}"; do
    folder="${FOLDERS[$i]}"
    # Check if it's a git repository
    if [ -d "$folder/.git" ]; then
        echo "  [$((i+1))] $folder [GIT]"
    else
        echo "  [$((i+1))] $folder"
    fi
done

echo ""
echo "Select folders (comma-separated numbers, or 'all' for all folders):"
read -p "Selection: " SELECTION

# Parse selection
SELECTED_FOLDERS=()

if [ "$SELECTION" = "all" ]; then
    SELECTED_FOLDERS=("${FOLDERS[@]}")
else
    IFS=',' read -ra SELECTIONS <<< "$SELECTION"
    for sel in "${SELECTIONS[@]}"; do
        # Trim whitespace
        sel=$(echo "$sel" | xargs)
        # Validate number
        if [[ "$sel" =~ ^[0-9]+$ ]]; then
            index=$((sel - 1))
            if [ $index -ge 0 ] && [ $index -lt ${#FOLDERS[@]} ]; then
                SELECTED_FOLDERS+=("${FOLDERS[$index]}")
            else
                echo "Warning: Invalid selection '$sel' - skipping"
            fi
        else
            echo "Warning: Invalid input '$sel' - skipping"
        fi
    done
fi

if [ ${#SELECTED_FOLDERS[@]} -eq 0 ]; then
    echo "No folders selected!"
    exit 1
fi

echo ""
echo "Selected folders: ${SELECTED_FOLDERS[*]}"
echo ""

# --- Branch Selection Logic ---
echo "Scanning branches in selected projects..."

# Arrays to store options
# OPTION_PAIRS stores "PROJECT_NAME:BRANCH_NAME"
OPTION_PAIRS=()
# OPTION_DISPLAY stores "[PROJECT_NAME][BRANCH_NAME]"
OPTION_DISPLAY=()

TEMP_FILE="$CURRENT_DIR/.my_commits_tmp_branches"
> "$TEMP_FILE"

for FOLDER in "${SELECTED_FOLDERS[@]}"; do
    PROJECT_PATH="$CURRENT_DIR/$FOLDER"
    if [ -d "$PROJECT_PATH/.git" ]; then
        cd "$PROJECT_PATH" || continue
        # Get all branches, clean them, and append to temp file
        git branch -a --format='%(refname:short)' | grep -v 'origin/HEAD' | while read -r branch; do
            clean_branch=${branch#origin/}
            echo "$FOLDER:$clean_branch" >> "$TEMP_FILE"
        done
        cd "$CURRENT_DIR"
    fi
done

# Sort and deduplicate the list
if [ -s "$TEMP_FILE" ]; then
    sort -u "$TEMP_FILE" > "${TEMP_FILE}.sorted"
    mv "${TEMP_FILE}.sorted" "$TEMP_FILE"
    
    while IFS= read -r line; do
        OPTION_PAIRS+=("$line")
        p_name="${line%%:*}"
        b_name="${line##*:}"
        OPTION_DISPLAY+=("[$p_name][$b_name]")
    done < "$TEMP_FILE"
    rm "$TEMP_FILE"
fi

SELECTED_PAIRS=() # Stores specific "PROJECT:BRANCH"
GLOBAL_BRANCHES=() # Stores "branchname" (for manual input applied to all)

if [ ${#OPTION_PAIRS[@]} -eq 0 ]; then
    echo "No branches found! Defaulting to 'kikidev'."
    GLOBAL_BRANCHES=("kikidev")
else
    echo ""
    echo "Available branches:"
    echo ""
    for i in "${!OPTION_DISPLAY[@]}"; do
        echo "  [$((i+1))] ${OPTION_DISPLAY[$i]}"
    done

    echo ""
    echo "Select branches (comma-separated numbers, 'all', or type a name manually):"
    echo "  Wildcards supported: *kiki* (contains), kiki* (starts with), *kiki (ends with)"
    read -p "Selection: " BRANCH_SELECTION

    if [ "$BRANCH_SELECTION" = "all" ]; then
        SELECTED_PAIRS=("${OPTION_PAIRS[@]}")
    elif [[ "$BRANCH_SELECTION" =~ ^[0-9,[:space:]]+$ ]]; then
        # Numeric selection
        IFS=',' read -ra B_SELECTIONS <<< "$BRANCH_SELECTION"
        for sel in "${B_SELECTIONS[@]}"; do
            sel=$(echo "$sel" | xargs)
            if [[ "$sel" =~ ^[0-9]+$ ]]; then
                index=$((sel - 1))
                if [ $index -ge 0 ] && [ $index -lt ${#OPTION_PAIRS[@]} ]; then
                    SELECTED_PAIRS+=("${OPTION_PAIRS[$index]}")
                else
                    echo "Warning: Invalid selection '$sel' - skipping"
                fi
            fi
        done
    else
        IFS=',' read -ra MANUAL_BRANCHES <<< "$BRANCH_SELECTION"
        for branch in "${MANUAL_BRANCHES[@]}"; do
            branch="$(echo "$branch" | xargs)"
            if [[ "$branch" == *"*"* ]]; then
                # Wildcard pattern — match against available branches
                match_count=0
                for pair in "${OPTION_PAIRS[@]}"; do
                    b_name="${pair##*:}"
                    if [[ "$b_name" == $branch ]]; then
                        SELECTED_PAIRS+=("$pair")
                        match_count=$((match_count + 1))
                    fi
                done
                if [ $match_count -eq 0 ]; then
                    echo "Warning: No branches matching pattern '$branch'"
                else
                    echo "Matched $match_count branch(es) for pattern '$branch'"
                fi
            else
                GLOBAL_BRANCHES+=("$branch")
            fi
        done
    fi
fi

# Fallback
if [ ${#SELECTED_PAIRS[@]} -eq 0 ] && [ ${#GLOBAL_BRANCHES[@]} -eq 0 ]; then
    echo "No valid branches selected. Defaulting to 'kikidev' for all projects."
    GLOBAL_BRANCHES=("kikidev")
fi

# Get current git user info
CURRENT_USER=$(git config user.email 2>/dev/null || git config --global user.email)
CURRENT_NAME=$(git config user.name 2>/dev/null || git config --global user.name)

if [ -z "$CURRENT_USER" ]; then
    echo "Error: Git user email not configured"
    exit 1
fi

SCRIPT_DIR="$CURRENT_DIR"
OUTPUT_FILE="commits_${FROM_DATE}_to_${TO_DATE}.txt"
OUTPUT_PATH="$SCRIPT_DIR/$OUTPUT_FILE"

# Create output file
> "$OUTPUT_PATH"

# Header
echo "==================================================" >> "$OUTPUT_PATH"
echo "       Multi-Project Git Commit Report" >> "$OUTPUT_PATH"
echo "==================================================" >> "$OUTPUT_PATH"
echo "" >> "$OUTPUT_PATH"
echo "Author: $CURRENT_NAME <$CURRENT_USER>" >> "$OUTPUT_PATH"
echo "Date Range: $FROM_DATE to $TO_DATE" >> "$OUTPUT_PATH"
echo "Projects: ${SELECTED_FOLDERS[*]}" >> "$OUTPUT_PATH"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_PATH"
echo "" >> "$OUTPUT_PATH"
echo "==================================================" >> "$OUTPUT_PATH"
echo "" >> "$OUTPUT_PATH"

TOTAL_COMMITS=0
PROJECTS_PROCESSED=0

for FOLDER in "${SELECTED_FOLDERS[@]}"; do
    PROJECT_PATH="$CURRENT_DIR/$FOLDER"

    if [ ! -d "$PROJECT_PATH" ] || [ ! -d "$PROJECT_PATH/.git" ]; then
        continue
    fi

    echo "" >> "$OUTPUT_PATH"
    echo "########## PROJECT: $FOLDER ##########" >> "$OUTPUT_PATH"
    echo "" >> "$OUTPUT_PATH"

    cd "$PROJECT_PATH" || continue

    # Determine branches to check for THIS project
    TARGET_BRANCHES=()
    
    # 1. Add manual global branches
    for b in "${GLOBAL_BRANCHES[@]}"; do
        TARGET_BRANCHES+=("$b")
    done

    # 2. Add specific selected branches for this project
    for pair in "${SELECTED_PAIRS[@]}"; do
        p_name="${pair%%:*}"
        b_name="${pair##*:}"
        if [ "$p_name" == "$FOLDER" ]; then
            # Avoid duplicates if already in global
            duplicate=false
            for eb in "${TARGET_BRANCHES[@]}"; do
                if [ "$eb" == "$b_name" ]; then
                    duplicate=true
                    break
                fi
            done
            if [ "$duplicate" = false ]; then
                TARGET_BRANCHES+=("$b_name")
            fi
        fi
    done

    # Remove duplicates from TARGET_BRANCHES (simple sort unique)
    IFS=$'\n' sorted_targets=($(sort -u <<<"${TARGET_BRANCHES[*]}"))
    unset IFS
    TARGET_BRANCHES=("${sorted_targets[@]}")

    if [ ${#TARGET_BRANCHES[@]} -eq 0 ]; then
        echo "  [No branches selected for this project]" >> "$OUTPUT_PATH"
        cd "$CURRENT_DIR"
        continue
    fi

    PROJECT_COMMITS=0

    for BRANCH in "${TARGET_BRANCHES[@]}"; do
        if [ -z "$BRANCH" ]; then continue; fi
        
        echo "" >> "$OUTPUT_PATH"
        echo "  ### Branch: $BRANCH ###" >> "$OUTPUT_PATH"
        echo "" >> "$OUTPUT_PATH"

        # Check if branch exists (Local or Remote)
        TARGET_REF=""
        if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
            TARGET_REF="$BRANCH"
        elif git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
            TARGET_REF="origin/$BRANCH"
        else
            echo "    [Warning: Branch '$BRANCH' not found]" >> "$OUTPUT_PATH"
            echo "" >> "$OUTPUT_PATH"
            continue
        fi

        # Get commits
        COMMITS=$(git log $TARGET_REF \
            --author="$CURRENT_USER" \
            --since="$FROM_DATE 00:00:00" \
            --until="$TO_DATE 23:59:59" \
            --pretty=format:"%h - %ad - %s" \
            --date=format:"%Y-%m-%d %H:%M:%S" 2>/dev/null)

        if [ -z "$COMMITS" ]; then
            echo "    No commits found" >> "$OUTPUT_PATH"
        else
            echo "$COMMITS" | sed 's/^/    /' >> "$OUTPUT_PATH"
            BRANCH_COUNT=$(echo "$COMMITS" | wc -l | xargs)
            PROJECT_COMMITS=$((PROJECT_COMMITS + BRANCH_COUNT))
            echo "" >> "$OUTPUT_PATH"
            echo "    Branch commits: $BRANCH_COUNT" >> "$OUTPUT_PATH"
        fi
        echo "" >> "$OUTPUT_PATH"
    done

    echo "  --------------------------------------------------" >> "$OUTPUT_PATH"
    echo "  Project total: $PROJECT_COMMITS commits" >> "$OUTPUT_PATH"
    echo "" >> "$OUTPUT_PATH"

    TOTAL_COMMITS=$((TOTAL_COMMITS + PROJECT_COMMITS))
    PROJECTS_PROCESSED=$((PROJECTS_PROCESSED + 1))

    cd "$CURRENT_DIR"
done

# Footer
echo "" >> "$OUTPUT_PATH"
echo "==================================================" >> "$OUTPUT_PATH"
echo "SUMMARY" >> "$OUTPUT_PATH"
echo "==================================================" >> "$OUTPUT_PATH"
echo "Projects processed: $PROJECTS_PROCESSED" >> "$OUTPUT_PATH"
echo "Total commits: $TOTAL_COMMITS" >> "$OUTPUT_PATH"
echo "==================================================" >> "$OUTPUT_PATH"

echo ""
echo "✓ Commit report generated successfully!"
echo "  File: $OUTPUT_PATH"
echo "  Date range: $FROM_DATE to $TO_DATE"
echo "  Total commits: $TOTAL_COMMITS"
echo ""