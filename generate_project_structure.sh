#!/bin/bash

# Nama file output
STRUCTURE_FILE="struktur_folder_project.txt"
JSON_FILE="list_file_project.json"

# Folder yang ingin diabaikan (dipisahkan dengan spasi saat menjalankan)
IGNORE_DIRS=("$@")

# Convert folder yang diabaikan menjadi pola grep
IGNORE_PATTERN=""
for dir in "${IGNORE_DIRS[@]}"; do
  if [[ -n "$IGNORE_PATTERN" ]]; then
    IGNORE_PATTERN="$IGNORE_PATTERN|^$dir/"
  else
    IGNORE_PATTERN="^$dir/"
  fi
done

# Fungsi untuk menampilkan struktur folder (tanpa tree)
generate_structure() {
  find . -print | sed 's|^\./||' | sort | grep -Ev "$IGNORE_PATTERN" | awk '
  BEGIN {
    indent = "    ";
  }
  {
    n = split($0, path, "/");
    depth = n - 1;

    line = "";
    for (i = 1; i < depth; i++) {
      line = line indent "│";
    }

    fname = path[n];
    if (system("[ -d \"" $0 "\" ]") == 0) {
      print line indent "├── " fname "/";
    } else {
      print line indent "├── " fname;
    }
  }' > "$STRUCTURE_FILE"
}

# Fungsi untuk membuat JSON list file
generate_json_file_list() {
  echo "[" > "$JSON_FILE"
  find . -type f | sed 's|^\./||' | grep -Ev "$IGNORE_PATTERN" | awk '{print "  \"" $0 "\","}' >> "$JSON_FILE"
  sed -i '$ s/,$//' "$JSON_FILE"
  echo "]" >> "$JSON_FILE"
}

# Jalankan
generate_structure
generate_json_file_list

echo "✅ Struktur folder disimpan di: $STRUCTURE_FILE"
echo "✅ Daftar file JSON disimpan di: $JSON_FILE"
