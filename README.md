# Reusable Bash Command

Kumpulan script Bash yang dapat digunakan ulang untuk kebutuhan scripting dan otomasi proyek, seperti analisis struktur direktori, pengelolaan file, logging, dan lainnya.

Dibuat oleh [@kikiraihan](https://github.com/kikiraihan)

---

## generate_project_structure.sh

Script untuk menghasilkan:

- Struktur direktori proyek (mirip `tree`, tapi tanpa dependensi eksternal)
- Daftar semua file dalam format JSON
- Mendukung pengecualian folder yang tidak ingin disertakan

### Cara Pakai

```bash
./generate_project_structure.sh [folder_yang_ingin_diabaikan...]
````

Contoh:

```bash
./generate_project_structure.sh .git node_modules target build
```

### Output

* `struktur_folder_project.txt`
  Struktur direktori dengan indentasi seperti:

  ```
  ├── config/
      ├── SecurityConfig.java
  ├── controller/
      ├── ProductController.java
  ```

* `list_file_project.json`
  JSON array dari semua path file:

  ```json
  [
    "config/SecurityConfig.java",
    "controller/ProductController.java"
  ]
  ```

---

## Others

Script lain akan ditambahkan di sini bila tersedia.
