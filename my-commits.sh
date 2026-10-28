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
#   -m, --model X       Model AI (default: qwen/qwen3.8-27b untuk groq,
#                       gemini-2.0-flash untuk gemini)
#   -h, --help          Tampilkan bantuan ini
#
# Kalau tidak ada option mode, script akan menanyakan mau diapakan report-nya
# setelah commit selesai dikumpulkan.
#
# Khusus mode AI (--daily / --weekly) butuh: python3, curl, dan API key.
# API key bisa diisi langsung di variable MY_GROQ_API_KEY / MY_GEMINI_API_KEY
# di bawah, atau lewat environment GROQ_API_KEY / GEMINI_API_KEY (spt gfbpr).

# --------------------------------------------------
# AI API KEY (isi di sini)
# --------------------------------------------------
# Groq   → daftar gratis di https://console.groq.com      (format: gsk_xxxxxx)
# Gemini → daftar gratis di https://aistudio.google.com/apikey (format: AIza_xxxxxx)
#
# ⚠️  JANGAN commit key asli kalau repo ini public.
#    Isi key-nya di copy lokal saja, atau kosongkan di sini dan tetap pakai
#    "export GROQ_API_KEY=..." dari ~/.zshrc / git-featuring-branch.
MY_GROQ_API_KEY=""
MY_GEMINI_API_KEY=""

# Key yang diisi di atas menang. Kalau dikosongkan, pakai yang sudah di-export
# di environment (mis. dari file git-featuring-branch).
[ -n "$MY_GROQ_API_KEY" ]   && GROQ_API_KEY="$MY_GROQ_API_KEY"
[ -n "$MY_GEMINI_API_KEY" ] && GEMINI_API_KEY="$MY_GEMINI_API_KEY"

OUTPUT_MODE=""          # show | file | daily | weekly (kosong = tanya interaktif)
AI_PROVIDER="groq"      # groq (default) / gemini
AI_MODEL=""             # kosong = pakai default per provider

# --- UI helpers -------------------------------------------------------------
# Gaya sama dengan perintah gfb* (git-featuring-branch):
#   ◆ judul   › langkah   ✔ sukses   ▲ peringatan   ✖ error   ℹ info   ? pertanyaan
#   Simbol di kolom 2, isi/detail di kolom 4, label key-value redup & rata kiri.
# Warna otomatis mati kalau output bukan terminal atau NO_COLOR di-set.
if [ -z "$NO_COLOR" ] && [ -t 1 ]; then
    B=$'\e[1m' D=$'\e[2m' N=$'\e[0m' G=$'\e[32m' R=$'\e[31m' Y=$'\e[33m' C=$'\e[36m' M=$'\e[35m'
    GH=$'\e[90m'    # abu-abu untuk ghost suggestion
else
    B='' D='' N='' G='' R='' Y='' C='' M='' GH=''
fi

# UI_AFTER_HEAD: section tepat setelah judul tidak perlu baris kosong lagi
ui_head()   { echo; printf '  %s◆%s %s%s%s%s\n' "$C" "$N" "$B" "$1" "$N" "${2:+  $D$2$N}"; echo; UI_AFTER_HEAD=1; }
ui_sec()    { [ -z "$UI_AFTER_HEAD" ] && echo; UI_AFTER_HEAD=''; printf '  %s%s%s%s\n' "$B" "$1" "$N" "${2:+  $D$2$N}"; }
ui_kv()     { UI_AFTER_HEAD=''; printf "    ${D}%-9s${N} %s\n" "$1" "$2"; }
ui_step()   { UI_AFTER_HEAD=''; printf '  %s›%s %s\n' "$C" "$N" "$*"; }
ui_ok()     { UI_AFTER_HEAD=''; printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
ui_warn()   { UI_AFTER_HEAD=''; printf '  %s▲%s %s\n' "$Y" "$N" "$*"; }
ui_err()    { UI_AFTER_HEAD=''; printf '  %s✖%s %s\n' "$R" "$N" "$*" >&2; }
ui_info()   { UI_AFTER_HEAD=''; printf '  %sℹ%s %s\n' "$C" "$N" "$*"; }
ui_note()   { UI_AFTER_HEAD=''; printf '    %s%s%s\n' "$D" "$*" "$N"; }
ui_item()   { UI_AFTER_HEAD=''; printf "    ${D}%3s${N}  %s\n" "$1" "$2"; }
ui_rule()   { UI_AFTER_HEAD=''; printf '  %s────────────────────────────────────────────────────────%s\n' "$D" "$N"; }
ui_use()    { UI_AFTER_HEAD=''; printf '    %s%s%s\n' "$B" "$*" "$N"; }
ui_opt()    { UI_AFTER_HEAD=''; printf "    ${C}%-20s${N} %s\n" "$1" "$2"; }
ui_ex()     { UI_AFTER_HEAD=''; printf "    %-40s ${D}%s${N}\n" "$1" "$2"; }

# Hapus 1 baris terakhir (untuk menghapus baris "› Generating…")
ui_unwait() { [ -t 1 ] && printf '\e[1A\e[2K'; }

# Cetak blok teks menjorok 4 spasi di antara dua garis
ui_block() {
    ui_rule
    printf '%s\n' "$1" | sed 's/^/    /'
    ui_rule
}

show_help() {
    ui_head "my-commits.sh" "laporan commit kamu dari banyak project"
    ui_sec "Pemakaian"
    ui_use "./my-commits.sh [--show|--file|--daily|--weekly] [-p provider] [-m model]"
    ui_note "jalankan dari folder yang berisi project-project git"
    ui_sec "Mode output"
    ui_opt "--show" "tampilkan raw commit report (default)"
    ui_opt "--file" "simpan ke commits_<from>_to_<to>.txt"
    ui_opt "--daily" "Daily Standup Report via AI"
    ui_opt "--weekly" "Weekly Progress Report via AI (2 tahap)"
    ui_note "tanpa flag mode → ditanya setelah commit terkumpul"
    ui_sec "Opsi AI"
    ui_opt "-p, --provider" "groq (default) atau gemini"
    ui_opt "-m, --model" "default: qwen/qwen3.8-27b · gemini-2.0-flash"
    ui_opt "-h, --help" "bantuan ini"
    ui_sec "Contoh"
    ui_ex "./my-commits.sh" "interaktif"
    ui_ex "./my-commits.sh --daily" "langsung daily standup"
    ui_ex "./my-commits.sh --weekly -p gemini" "weekly pakai Gemini"
    ui_sec "Setup AI"
    ui_ex 'export GROQ_API_KEY="gsk_xxxxxx"' "console.groq.com"
    ui_ex 'export GEMINI_API_KEY="AIza_xxxxxx"' "aistudio.google.com/apikey"
    ui_note "atau isi MY_GROQ_API_KEY / MY_GEMINI_API_KEY di atas script"
    echo
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
            ui_err "Option tidak dikenal: $1"
            ui_note "Lihat bantuan: $0 -h" >&2
            exit 1
            ;;
    esac
    shift
done

ui_head "my-commits" "laporan commit dari banyak project"

# Function to validate date format
validate_date() {
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# --- Last input memory ------------------------------------------------------

# Input terakhir tiap prompt disimpan di file ini (format key=value).
# Saat input kosong, input terakhir tampil sebagai teks abu-abu (ghost).
# Tab / → untuk memakainya, atau langsung ketik untuk mengabaikannya.
LAST_INPUT_FILE="$HOME/.my_commits_last_input"

get_last_input() {
    [ -f "$LAST_INPUT_FILE" ] || return 0
    grep -m1 "^$1=" "$LAST_INPUT_FILE" | cut -d= -f2-
}

save_last_input() {
    local key="$1" value="$2" tmp
    [ -z "$value" ] && return 0
    tmp="$(mktemp "${TMPDIR:-/tmp}/my_commits_last_XXXXXX")"
    [ -f "$LAST_INPUT_FILE" ] && grep -v "^$key=" "$LAST_INPUT_FILE" > "$tmp"
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
    mv "$tmp" "$LAST_INPUT_FILE"
}

# read_with_last VAR KEY PERTANYAAN [PETUNJUK]
# Prompt gaya gfb ("? pertanyaan petunjuk"). Line editor kecil ala fish autosuggestion:
# - input kosong  → input terakhir tampil abu-abu di belakang kursor
# - Tab / →       → terima suggestion, lalu masih bisa diedit
# - ketik apa saja → suggestion diabaikan; hapus sampai kosong → muncul lagi
# Key lain: ← → Home End Backspace Delete, Ctrl-A/E/U/W.
read_with_last() {
    local var="$1" key="$2" last buf="" pos=0 k c seq prompt
    prompt="  ${M}?${N} ${B}$3${N}${4:+ ${D}$4${N}} "
    last="$(get_last_input "$key")"

    # Bukan terminal (pipe/redirect): baca biasa
    if [ ! -t 0 ]; then
        IFS= read -r buf
        printf -v "$var" '%s' "$buf"
        return
    fi

    while true; do
        printf '\r\033[K%s%s' "$prompt" "$buf"
        if [ -z "$buf" ] && [ -n "$last" ]; then
            # Simpan posisi kursor, tulis ghost, balikkan kursor
            printf '\0337%s%s  %s⇥ Tab%s\0338' "$GH" "$last" "$D" "$N"
        elif (( pos < ${#buf} )); then
            printf '\033[%dD' $(( ${#buf} - pos ))
        fi

        IFS= read -rsn1 k || break
        case "$k" in
            '')                         # Enter
                break ;;
            $'\t')
                if [ -z "$buf" ] && [ -n "$last" ]; then buf="$last"; pos=${#buf}; fi ;;
            $'\x7f'|$'\b')              # Backspace
                if (( pos > 0 )); then buf="${buf:0:pos-1}${buf:pos}"; pos=$((pos - 1)); fi ;;
            $'\x01') pos=0 ;;           # Ctrl-A
            $'\x05') pos=${#buf} ;;     # Ctrl-E
            $'\x15') buf="${buf:pos}"; pos=0 ;;  # Ctrl-U
            $'\x17')                    # Ctrl-W: hapus kata sebelum kursor
                c="${buf:0:pos}"
                c="${c%"${c##*[! ]}"}"
                c="${c%"${c##*[ ]}"}"
                buf="$c${buf:pos}"; pos=${#c} ;;
            $'\e')                      # Escape sequence (arrow, home, end, del)
                seq=""
                IFS= read -rsn1 -t 1 c
                if [[ "$c" == "[" || "$c" == "O" ]]; then
                    while IFS= read -rsn1 -t 1 c; do
                        seq="$seq$c"
                        [[ "$c" =~ [A-Za-z~] ]] && break
                    done
                fi
                case "$seq" in
                    C)                  # →
                        if [ -z "$buf" ] && [ -n "$last" ]; then buf="$last"; pos=${#buf}
                        elif (( pos < ${#buf} )); then pos=$((pos + 1)); fi ;;
                    D) (( pos > 0 )) && pos=$((pos - 1)) ;;  # ←
                    H|1~|7~) pos=0 ;;
                    F|4~|8~) pos=${#buf} ;;
                    3~) buf="${buf:0:pos}${buf:pos+1}" ;;     # Delete
                esac ;;
            *)
                if [[ "$k" != [[:cntrl:]] ]]; then
                    buf="${buf:0:pos}$k${buf:pos}"; pos=$((pos + 1))
                fi ;;
        esac
    done

    # Gambar ulang tanpa ghost, lalu pindah baris
    printf '\r\033[K%s%s\n' "$prompt" "$buf"
    printf -v "$var" '%s' "$buf"
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
    echo
    read_with_last copy_ans copy "Copy ke clipboard?" "[y/N]"
    save_last_input copy "$copy_ans"
    if [[ "$copy_ans" == "y" || "$copy_ans" == "Y" ]]; then
        if copy_to_clipboard "$content"; then
            ui_ok "Sudah di-copy ke clipboard."
        else
            ui_warn "Tidak ada tool clipboard (pbcopy/wl-copy/xclip/xsel/clip.exe)."
        fi
    fi
}

# Validasi provider, model default, API key, dan dependency untuk mode AI
prepare_ai() {
    case "$AI_PROVIDER" in
        groq)   [ -z "$AI_MODEL" ] && AI_MODEL="qwen/qwen3.8-27b" ;;
        gemini) [ -z "$AI_MODEL" ] && AI_MODEL="gemini-2.0-flash" ;;
        *)
            ui_err "Provider tidak dikenal: '$AI_PROVIDER'. Pilih: groq / gemini"
            return 1
            ;;
    esac

    if [ "$AI_PROVIDER" = "groq" ] && [ -z "$GROQ_API_KEY" ]; then
        ui_err "GROQ_API_KEY belum di-set."
        ui_note "Daftar gratis di https://console.groq.com, lalu isi salah satu:" >&2
        ui_note "variable MY_GROQ_API_KEY di bagian atas $0" >&2
        ui_note "export GROQ_API_KEY=\"gsk_xxxxxx\"" >&2
        return 1
    fi
    if [ "$AI_PROVIDER" = "gemini" ] && [ -z "$GEMINI_API_KEY" ]; then
        ui_err "GEMINI_API_KEY belum di-set."
        ui_note "Daftar gratis di https://aistudio.google.com/apikey, lalu isi salah satu:" >&2
        ui_note "variable MY_GEMINI_API_KEY di bagian atas $0" >&2
        ui_note "export GEMINI_API_KEY=\"AIza_xxxxxx\"" >&2
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        ui_err "python3 tidak ditemukan (dipakai untuk build & parse JSON)."
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        ui_err "curl tidak ditemukan."
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
        ui_err "API error: ${result#__ERR__}"
        return 1
    fi
    if [ -z "$result" ]; then
        ui_err "AI tidak mengembalikan hasil apapun."
        return 1
    fi

    printf '%s\n' "$result"
}

# Baca input multi-baris sampai baris kosong
read_multiline() {
    local line acc=""
    while IFS= read -r -p "    ${D}›${N} " line; do
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

    ui_sec "Daily Standup Report" "$AI_PROVIDER · $AI_MODEL"
    ui_step "Generating…"
    result="$(call_ai "$prompt")" || return 1
    ui_unwait

    ui_block "$result"
    ask_copy "$result"
}

# Weekly Progress Report — 2 tahap: konfirmasi analisa dulu, baru full report
generate_weekly_report() {
    local report="$1"
    local next_tasks feedback prompt1 prompt2 analysis result

    ui_sec "Weekly Progress Report" "$AI_PROVIDER · $AI_MODEL"
    echo
    printf '  %s?%s %sRencana minggu depan%s %s(opsional)%s\n' "$M" "$N" "$B" "$N" "$D" "$N"
    ui_note "satu task per baris, Enter di baris kosong untuk selesai"
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

    echo
    ui_step "Menganalisa commit… (tahap 1/2)"
    analysis="$(call_ai "$prompt1")" || return 1
    ui_unwait

    ui_block "$analysis"
    echo
    printf '  %s?%s %sKoreksi / tambahan%s %s(persentase, issues, notes)%s\n' "$M" "$N" "$B" "$N" "$D" "$N"
    ui_note "satu per baris, langsung Enter kosong kalau sudah setuju semua"
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

    echo
    ui_step "Generating report… (tahap 2/2)"
    result="$(call_ai "$prompt2")" || return 1
    ui_unwait

    ui_block "$result"
    ask_copy "$result"
}

# Get date range from user
CURRENT_DATE=$(date +%Y-%m-%d)

ui_sec "Rentang tanggal"
while true; do
    read_with_last FROM_DATE from_date "Tanggal mulai" "YYYY-MM-DD, kosong = $CURRENT_DATE"
    FROM_DATE=${FROM_DATE:-$CURRENT_DATE}
    if validate_date "$FROM_DATE"; then
        save_last_input from_date "$FROM_DATE"
        break
    else
        ui_warn "Format tanggal salah, pakai YYYY-MM-DD"
    fi
done

while true; do
    read_with_last TO_DATE to_date "Tanggal akhir" "YYYY-MM-DD, kosong = $CURRENT_DATE"
    TO_DATE=${TO_DATE:-$CURRENT_DATE}
    if validate_date "$TO_DATE"; then
        save_last_input to_date "$TO_DATE"
        break
    else
        ui_warn "Format tanggal salah, pakai YYYY-MM-DD"
    fi
done

# Get current directory
CURRENT_DIR=$(pwd)

# Scan for folders (excluding hidden folders and common non-project folders)
FOLDERS=()
while IFS= read -r folder; do
    FOLDERS+=("$folder")
done < <(ls -d */ 2>/dev/null | sed 's|/$||' | grep -v -E "^(node_modules|vendor|dist|build|\\.)" || true)

if [ ${#FOLDERS[@]} -eq 0 ]; then
    ui_err "Tidak ada folder di direktori ini."
    exit 1
fi

# Display available folders
ui_sec "Project" "${#FOLDERS[@]} folder"
for i in "${!FOLDERS[@]}"; do
    folder="${FOLDERS[$i]}"
    # Check if it's a git repository
    if [ -d "$folder/.git" ]; then
        ui_item "$((i+1))" "$folder"
    else
        ui_item "$((i+1))" "$D$folder  (bukan git)$N"
    fi
done

echo
read_with_last SELECTION folder_selection "Pilih project" "nomor dipisah koma, atau all"
save_last_input folder_selection "$SELECTION"

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
                ui_warn "Nomor '$sel' tidak ada, dilewati."
            fi
        else
            ui_warn "Input '$sel' tidak valid, dilewati."
        fi
    done
fi

if [ ${#SELECTED_FOLDERS[@]} -eq 0 ]; then
    ui_err "Tidak ada project yang dipilih."
    exit 1
fi

ui_ok "${#SELECTED_FOLDERS[@]} project: ${SELECTED_FOLDERS[*]}"

# --- Branch Selection Logic ---
ui_sec "Branch"
ui_step "Scan branch…"

# Arrays to store options
# OPTION_PAIRS stores "PROJECT_NAME:BRANCH_NAME"
OPTION_PAIRS=()

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
ui_unwait

# Sort and deduplicate the list
if [ -s "$TEMP_FILE" ]; then
    sort -u "$TEMP_FILE" > "${TEMP_FILE}.sorted"
    mv "${TEMP_FILE}.sorted" "$TEMP_FILE"

    while IFS= read -r line; do
        OPTION_PAIRS+=("$line")
    done < "$TEMP_FILE"
fi
rm -f "$TEMP_FILE"

SELECTED_PAIRS=() # Stores specific "PROJECT:BRANCH"
GLOBAL_BRANCHES=() # Stores "branchname" (for manual input applied to all)

if [ ${#OPTION_PAIRS[@]} -eq 0 ]; then
    ui_warn "Tidak ada branch ditemukan, pakai default 'kikidev'."
    GLOBAL_BRANCHES=("kikidev")
else
    # Tampilkan per project, nomor tetap berurutan global
    last_project=""
    for i in "${!OPTION_PAIRS[@]}"; do
        p_name="${OPTION_PAIRS[$i]%%:*}"
        b_name="${OPTION_PAIRS[$i]##*:}"
        if [ "$p_name" != "$last_project" ]; then
            [ -n "$last_project" ] && echo
            printf '    %s%s%s\n' "$C" "$p_name" "$N"
            last_project="$p_name"
        fi
        ui_item "$((i+1))" "$b_name"
    done

    echo
    ui_note "nomor dipisah koma, 'all', atau nama branch manual"
    ui_note "wildcard: *kiki* (mengandung) · kiki* (diawali) · *kiki (diakhiri)"
    ui_note "bisa digabung: *kiki*, master, main, develop, staging"
    read_with_last BRANCH_SELECTION branch_selection "Pilih branch"
    save_last_input branch_selection "$BRANCH_SELECTION"

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
                    ui_warn "Nomor '$sel' tidak ada, dilewati."
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
                    ui_warn "Tidak ada branch yang cocok dengan '$branch'"
                else
                    ui_ok "$match_count branch cocok dengan '$branch'"
                fi
            else
                GLOBAL_BRANCHES+=("$branch")
            fi
        done
    fi
fi

# Fallback
if [ ${#SELECTED_PAIRS[@]} -eq 0 ] && [ ${#GLOBAL_BRANCHES[@]} -eq 0 ]; then
    ui_warn "Tidak ada branch valid, pakai default 'kikidev' untuk semua project."
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
    ui_err "Git user email belum dikonfigurasi."
    ui_note "git config --global user.email \"kamu@contoh.com\"" >&2
    exit 1
fi

SCRIPT_DIR="$CURRENT_DIR"
OUTPUT_FILE="commits_${FROM_DATE}_to_${TO_DATE}.txt"
FINAL_OUTPUT_PATH="$SCRIPT_DIR/$OUTPUT_FILE"

# Report selalu ditulis ke file sementara dulu. Baru di bagian OUTPUT HANDLING
# (paling bawah) diputuskan mau ditampilkan / disimpan jadi file / dikirim ke AI.
OUTPUT_PATH="$(mktemp "${TMPDIR:-/tmp}/my_commits_XXXXXX")"
trap 'rm -f "$OUTPUT_PATH"' EXIT

echo
ui_step "Mengumpulkan commit…"

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

ui_unwait
ui_ok "Commit report selesai."
ui_kv "author" "$CURRENT_NAME <$CURRENT_USER>"
ui_kv "tanggal" "$FROM_DATE → $TO_DATE"
ui_kv "branch" "${ALL_BRANCH_NAMES[*]}"
ui_kv "project" "$PROJECTS_PROCESSED"
ui_kv "commit" "$TOTAL_COMMITS"

# Kalau mode belum ditentukan lewat option, tanya sekarang
if [ -z "$OUTPUT_MODE" ]; then
    ui_sec "Output"
    ui_item 1 "Tampilkan raw commit report $D(default)$N"
    ui_item 2 "Daily Standup Report $D(AI)$N"
    ui_item 3 "Weekly Progress Report $D(AI)$N"
    ui_item 4 "Simpan ke file"
    echo
    read_with_last MODE_SELECTION mode_selection "Mau diapakan report ini?" "[1]"
    save_last_input mode_selection "${MODE_SELECTION:-1}"
    case "${MODE_SELECTION:-1}" in
        1) OUTPUT_MODE="show" ;;
        2) OUTPUT_MODE="daily" ;;
        3) OUTPUT_MODE="weekly" ;;
        4) OUTPUT_MODE="file" ;;
        *)
            ui_warn "Pilihan '$MODE_SELECTION' tidak dikenal, tampilkan raw report."
            OUTPUT_MODE="show"
            ;;
    esac
fi

case "$OUTPUT_MODE" in
    file)
        mv "$OUTPUT_PATH" "$FINAL_OUTPUT_PATH"
        echo
        ui_ok "Report disimpan."
        ui_kv "file" "$FINAL_OUTPUT_PATH"
        echo
        ;;

    show)
        ui_sec "Raw commit report"
        ui_block "$REPORT_CONTENT"
        ask_copy "$REPORT_CONTENT"
        echo
        ;;

    daily|weekly)
        if ! prepare_ai; then
            ui_info "Report tetap bisa dilihat/disimpan manual: jalankan ulang dengan --show atau --file."
            exit 1
        fi
        if [ "$TOTAL_COMMITS" -eq 0 ]; then
            echo
            ui_warn "Tidak ada commit di rentang tanggal ini, tidak ada yang bisa dilaporkan."
            echo
            exit 0
        fi
        if [ "$OUTPUT_MODE" = "daily" ]; then
            generate_daily_report "$REPORT_CONTENT" || exit 1
        else
            generate_weekly_report "$REPORT_CONTENT" || exit 1
        fi
        echo
        ;;
esac
