#!/bin/bash

# Interactive script to list commits by current git user from multiple projects
# Usage: ./my-commits.sh [OPTIONS]
#
# Options:
#   --show              Tampilkan raw commit report langsung di terminal (default)
#   --file              Simpan raw commit report ke file commits_<from>_to_<to>.txt
#   --daily             Langsung generate Daily Standup Report pakai AI
#   --weekly            Langsung generate Weekly Progress Report pakai AI (2 tahap)
#   -p, --provider X    AI provider: groq (default) / gemini
#   -m, --model X       Model AI (default: qwen/qwen3-32b untuk groq,
#                       gemini-2.0-flash untuk gemini)
#   -h, --help          Tampilkan bantuan ini
#
# Kalau tidak ada option mode, script akan menanyakan mau diapakan report-nya
# setelah commit selesai dikumpulkan.
#
# Khusus mode AI (--daily / --weekly) butuh: python3, curl, dan
# GROQ_API_KEY atau GEMINI_API_KEY di environment (sama seperti gfbpr).

OUTPUT_MODE=""          # show | file | daily | weekly (kosong = tanya interaktif)
AI_PROVIDER="groq"      # groq (default) / gemini
AI_MODEL=""             # kosong = pakai default per provider

show_help() {
    sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
}

# Parsing argumen
while [[ $# -gt 0 ]]; do
    case "$1" in
        --show)   OUTPUT_MODE="show" ;;
        --file)   OUTPUT_MODE="file" ;;
        --daily)  OUTPUT_MODE="daily" ;;
        --weekly) OUTPUT_MODE="weekly" ;;
        -p|--provider) AI_PROVIDER="$2"; shift ;;
        -m|--model)    AI_MODEL="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *)
            echo "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
    shift
done

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

# --- Clipboard & AI helpers -------------------------------------------------

# Copy ke clipboard, portable (macOS / Wayland / X11 / WSL)
copy_to_clipboard() {
    local content="$1"
    if command -v pbcopy >/dev/null 2>&1; then
        printf '%s\n' "$content" | pbcopy
    elif command -v wl-copy >/dev/null 2>&1; then
        printf '%s\n' "$content" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s\n' "$content" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf '%s\n' "$content" | xsel --clipboard --input
    elif command -v clip.exe >/dev/null 2>&1; then
        printf '%s\n' "$content" | clip.exe
    else
        return 1
    fi
}

# Tanya user apakah hasilnya mau di-copy ke clipboard
ask_copy() {
    local content="$1"
    local copy_ans
    read -p "📋 Copy result ke clipboard? (y/N): " copy_ans
    if [[ "$copy_ans" == "y" || "$copy_ans" == "Y" ]]; then
        if copy_to_clipboard "$content"; then
            echo "✅ Sudah di-copy ke clipboard!"
        else
            echo "⚠️  Tidak ada tool clipboard (pbcopy/wl-copy/xclip/xsel/clip.exe)."
        fi
    fi
}

# Validasi provider, model default, API key, dan dependency untuk mode AI
prepare_ai() {
    case "$AI_PROVIDER" in
        groq)   [ -z "$AI_MODEL" ] && AI_MODEL="qwen/qwen3-32b" ;;
        gemini) [ -z "$AI_MODEL" ] && AI_MODEL="gemini-2.0-flash" ;;
        *)
            echo "❌ Provider tidak dikenal: '$AI_PROVIDER'. Pilih: groq / gemini"
            return 1
            ;;
    esac

    if [ "$AI_PROVIDER" = "groq" ] && [ -z "$GROQ_API_KEY" ]; then
        echo "❌ GROQ_API_KEY belum di-set."
        echo "Daftar gratis di https://console.groq.com lalu:"
        echo "  export GROQ_API_KEY=\"gsk_xxxxxx\""
        return 1
    fi
    if [ "$AI_PROVIDER" = "gemini" ] && [ -z "$GEMINI_API_KEY" ]; then
        echo "❌ GEMINI_API_KEY belum di-set."
        echo "Daftar gratis di https://aistudio.google.com/apikey lalu:"
        echo "  export GEMINI_API_KEY=\"AIza_xxxxxx\""
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ python3 tidak ditemukan (dipakai untuk build & parse JSON)."
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl tidak ditemukan."
        return 1
    fi

    return 0
}

# Kirim prompt ke AI, hasilnya di-echo ke stdout (error ke stderr)
# Pola sama seperti gfbpr di git-featuring-branch:
# python3 build JSON payload, curl yang kirim (urllib diblokir Cloudflare 403)
call_ai() {
    local prompt="$1"
    local json_payload response result

    if [ "$AI_PROVIDER" = "groq" ]; then
        json_payload=$(python3 -c "
import sys, json
print(json.dumps({
    'model': sys.argv[2],
    'messages': [{'role': 'user', 'content': sys.argv[1]}],
    'temperature': 0.3
}))
" "$prompt" "$AI_MODEL" 2>/dev/null)

        response=$(curl -s https://api.groq.com/openai/v1/chat/completions \
            -H "Authorization: Bearer $GROQ_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$json_payload")
    else
        json_payload=$(python3 -c "
import sys, json
print(json.dumps({
    'contents': [{'parts': [{'text': sys.argv[1]}]}],
    'generationConfig': {'temperature': 0.3}
}))
" "$prompt" 2>/dev/null)

        response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL}:generateContent?key=$GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$json_payload")
    fi

    result=$(python3 -c "
import sys, json, re
try:
    d = json.loads(sys.argv[1])
except Exception as e:
    print('__ERR__Response bukan JSON: %s' % e); sys.exit()
err = d.get('error') if isinstance(d, dict) else None
if err:
    print('__ERR__%s' % (err.get('message') if isinstance(err, dict) else err)); sys.exit()
try:
    if sys.argv[2] == 'groq':
        txt = d['choices'][0]['message']['content']
    else:
        txt = d['candidates'][0]['content']['parts'][0]['text']
except Exception as e:
    print('__ERR__Parse error: %s' % e); sys.exit()
# Buang blok reasoning <think>...</think> (muncul di model reasoning spt qwen)
txt = re.sub(r'<think>.*?</think>', '', txt, flags=re.S).strip()
print(txt)
" "$response" "$AI_PROVIDER" 2>/dev/null)

    if [[ "$result" == __ERR__* ]]; then
        echo "❌ API error: ${result#__ERR__}" >&2
        return 1
    fi
    if [ -z "$result" ]; then
        echo "❌ AI tidak mengembalikan hasil apapun." >&2
        return 1
    fi

    printf '%s\n' "$result"
}

# Baca input multi-baris sampai baris kosong
read_multiline() {
    local line acc=""
    while IFS= read -r line; do
        [ -z "$line" ] && break
        acc="${acc}${line}"$'\n'
    done
    printf '%s' "$acc"
}

# --- AI report generators ---------------------------------------------------

# Daily Standup Report
generate_daily_report() {
    local report="$1"
    local prompt result

    prompt="$(cat <<'PROMPT_EOF'
You are an assistant that generates a DAILY STANDUP REPORT from a multi-project git commit report.

Rules:
1. Group the commits per date: Yesterday vs Today (the latest date in the report = Today, the earlier date = Yesterday).
2. The output must be natural paragraphs in English, NOT bullet points.
3. ALWAYS mention the project name, in a natural style.
4. Commits containing WIP/temp/draft must be mentioned as WIP.
5. "fix" -> fixing/fixed, "add"/"create" -> implemented/added.
6. Combine similar commits into one sentence.
7. End with "That's all from my side."
8. If there is only one day of commits, start with "I didn't push any code yesterday."

Return ONLY the report text: no preamble, no explanation, no markdown code fence.

Here is the commit report:
PROMPT_EOF
)"
    prompt="$prompt
$report"

    echo "⏳ Generating Daily Report ($AI_PROVIDER / $AI_MODEL)..."
    echo ""
    result="$(call_ai "$prompt")" || return 1

    echo "=================================================="
    echo "              DAILY STANDUP REPORT"
    echo "=================================================="
    echo ""
    printf '%s\n' "$result"
    echo ""
    ask_copy "$result"
}

# Weekly Progress Report — 2 tahap: konfirmasi analisa dulu, baru full report
generate_weekly_report() {
    local report="$1"
    local next_tasks feedback prompt1 prompt2 analysis result

    echo ""
    echo "📅 Rencana minggu depan (opsional). Satu task per baris, akhiri dengan baris kosong:"
    next_tasks="$(read_multiline)"
    [ -z "$next_tasks" ] && next_tasks="(none provided)"

    prompt1="$(cat <<'PROMPT_EOF'
You are an assistant that generates a WEEKLY/MONTHLY PROGRESS REPORT from a multi-project git commit report.

This is STAGE 1 of 2: analysis & confirmation. DO NOT generate the full report yet.

Analyze the commits, then return EXACTLY this block (in English) and nothing else:

Before I generate the report, let me confirm a few things:

🔄 In Progress (WIP detected):
- [task description] (project-name) → estimated [X]%

⚠️ Issues / Blockers / Risks (inferred):
- [issue description]

📊 Notes (inferred):
- Bugs fixed: [list if any]
- [other notes if any]

Does this look correct? Feel free to adjust the percentages, add/remove issues or notes, then I'll generate the full report.

Rules for the % estimation:
- WIP/temp/draft/init commits -> 20-40%
- Several commits but no "complete/done/finish" commit -> 50-70%
- Many commits + small fixes but still not done -> 80-90%

Return only the confirmation block: no preamble, no markdown code fence.

Here is the commit report:
PROMPT_EOF
)"
    prompt1="$prompt1
$report"

    echo ""
    echo "⏳ Analyzing commits ($AI_PROVIDER / $AI_MODEL)..."
    echo ""
    analysis="$(call_ai "$prompt1")" || return 1

    printf '%s\n' "$analysis"
    echo ""
    echo "✏️  Koreksi/tambahan (persentase, issues, notes). Satu per baris,"
    echo "    langsung Enter kosong kalau sudah setuju semua:"
    feedback="$(read_multiline)"
    [ -z "$feedback" ] && feedback="(the user agreed with the analysis above, no changes)"

    prompt2="$(cat <<'PROMPT_EOF'
This is STAGE 2: generate the full weekly report.

Use exactly this structure:

[Author First Name]'s Weekly Report on [End Date, e.g. 10 Apr]

✅ Done
- [Task description] ([project-name])

🔄 In Progress
- [Task description] ([project-name]) (XX%)

📅 Next Week
- [Task description] ([project-name])

⚠️ Issues / Blockers / Risks
- [Issue description]

📊 Notes
- Bugs fixed: [list or "-"]
- Incidents: [list or "-"]
- [Other thoughts if any]

Rules:
1. Combine similar commits into ONE task per bullet.
2. EVERY bullet MUST mention the project name in parentheses: (project-name)
3. WIP commits go to In Progress with the % estimation, and ALSO to Next Week.
4. Tasks from the "next:" input go to Next Week.
5. If there are no Issues, write "- -"
6. If there are no Notes, omit the Notes section.
7. Take the author first name and the end date from the report header.

Return only the report: no preamble, no markdown code fence.
PROMPT_EOF
)"
    prompt2="$prompt2

Stage 1 analysis:
$analysis

User corrections for that analysis (these override the analysis):
$feedback

next:
$next_tasks

Here is the commit report:
$report"

    echo ""
    echo "⏳ Generating Weekly Report ($AI_PROVIDER / $AI_MODEL)..."
    echo ""
    result="$(call_ai "$prompt2")" || return 1

    echo "=================================================="
    echo "              WEEKLY PROGRESS REPORT"
    echo "=================================================="
    echo ""
    printf '%s\n' "$result"
    echo ""
    ask_copy "$result"
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
done < <(ls -d */ 2>/dev/null | sed 's|/$||' | grep -v -E "^(node_modules|vendor|dist|build|\\.)" || true)

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
    echo "  You can also include general branches: e.g. *kiki*, master, main, develop, staging"
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

# Kumpulkan nama branch yang dipilih (dipakai di header report)
ALL_BRANCH_NAMES=()
for b in "${GLOBAL_BRANCHES[@]}"; do
    ALL_BRANCH_NAMES+=("$b")
done
for pair in "${SELECTED_PAIRS[@]}"; do
    ALL_BRANCH_NAMES+=("${pair##*:}")
done
if [ ${#ALL_BRANCH_NAMES[@]} -gt 0 ]; then
    IFS=$'\n' sorted_branch_names=($(printf '%s\n' "${ALL_BRANCH_NAMES[@]}" | sort -u))
    unset IFS
    ALL_BRANCH_NAMES=("${sorted_branch_names[@]}")
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
FINAL_OUTPUT_PATH="$SCRIPT_DIR/$OUTPUT_FILE"

# Report selalu ditulis ke file sementara dulu. Baru di bagian OUTPUT HANDLING
# (paling bawah) diputuskan mau ditampilkan / disimpan jadi file / dikirim ke AI.
OUTPUT_PATH="$(mktemp "${TMPDIR:-/tmp}/my_commits_XXXXXX")"
trap 'rm -f "$OUTPUT_PATH"' EXIT

# Create output file
> "$OUTPUT_PATH"

# Header
echo "==================================================" >> "$OUTPUT_PATH"
echo "       Multi-Project Git Commit Report" >> "$OUTPUT_PATH"
echo "==================================================" >> "$OUTPUT_PATH"
echo "" >> "$OUTPUT_PATH"
echo "Author: $CURRENT_NAME <$CURRENT_USER>" >> "$OUTPUT_PATH"
echo "Date Range: $FROM_DATE to $TO_DATE" >> "$OUTPUT_PATH"
echo "Branches: ${ALL_BRANCH_NAMES[*]}" >> "$OUTPUT_PATH"
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

# ==================================================
# OUTPUT HANDLING
# ==================================================

REPORT_CONTENT="$(cat "$OUTPUT_PATH")"

echo ""
echo "✓ Commit report generated successfully!"
echo "  Date range: $FROM_DATE to $TO_DATE"
echo "  Total commits: $TOTAL_COMMITS"
echo ""

# Kalau mode belum ditentukan lewat option, tanya sekarang
if [ -z "$OUTPUT_MODE" ]; then
    echo "Mau diapakan report ini?"
    echo ""
    echo "  [1] Tampilkan raw commit report (default)"
    echo "  [2] Generate Daily Standup Report (AI)"
    echo "  [3] Generate Weekly Progress Report (AI)"
    echo "  [4] Simpan ke file"
    echo ""
    read -p "Selection [1]: " MODE_SELECTION
    case "${MODE_SELECTION:-1}" in
        1) OUTPUT_MODE="show" ;;
        2) OUTPUT_MODE="daily" ;;
        3) OUTPUT_MODE="weekly" ;;
        4) OUTPUT_MODE="file" ;;
        *)
            echo "Warning: Pilihan '$MODE_SELECTION' tidak dikenal - tampilkan raw report"
            OUTPUT_MODE="show"
            ;;
    esac
    echo ""
fi

case "$OUTPUT_MODE" in
    file)
        mv "$OUTPUT_PATH" "$FINAL_OUTPUT_PATH"
        echo "  File: $FINAL_OUTPUT_PATH"
        echo ""
        ;;

    show)
        echo "$REPORT_CONTENT"
        echo ""
        ask_copy "$REPORT_CONTENT"
        echo ""
        ;;

    daily|weekly)
        if ! prepare_ai; then
            echo ""
            echo "ℹ️  Report tetap bisa dilihat/disimpan manual, jalankan ulang dengan --show atau --file."
            exit 1
        fi
        if [ "$TOTAL_COMMITS" -eq 0 ]; then
            echo "⚠️  Tidak ada commit di rentang tanggal ini, tidak ada yang bisa dilaporkan."
            exit 0
        fi
        if [ "$OUTPUT_MODE" = "daily" ]; then
            generate_daily_report "$REPORT_CONTENT" || exit 1
        else
            generate_weekly_report "$REPORT_CONTENT" || exit 1
        fi
        echo ""
        ;;
esac
