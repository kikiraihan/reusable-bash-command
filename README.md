
# 🔁 reusable-bash-command

📦 Kumpulan script Bash yang dapat digunakan ulang (reusable) untuk berbagai kebutuhan scripting dan otomasi proyek, seperti analisis struktur direktori, pengelolaan file, logging, dan lainnya.

> Dibuat oleh [@kikiraihan](https://github.com/kikiraihan) — silakan fork, modifikasi, dan gunakan!

---

## 📁 Daftar Script

Berikut beberapa script reusable yang tersedia di repo ini:

### 1. `generate_structure_no_tree.sh`

Script ini digunakan untuk:

- Menampilkan struktur direktori proyek seperti output `tree`, **tanpa perlu menginstal `tree`**.
- Menghasilkan daftar file dalam format **JSON array**.
- Mendukung pengecualian folder tertentu agar tidak disertakan dalam hasil.

#### 🔧 Cara Menggunakan

```bash
./generate_structure_no_tree.sh [folder_yang_ingin_diabaikan...]
````

Contoh:

```bash
./generate_structure_no_tree.sh .git node_modules target build
```

#### 📂 Output yang Dihasilkan

1. **`struktur_folder_project.txt`**
   Berisi struktur direktori dengan indentasi dan garis seperti `tree`.

   Contoh:

   ```
   ├── AplikasiMinibankApplication.java
   ├── config/
       ├── SecurityConfig.java
   ├── controller/
       ├── ProductController.java
       └── rest/
           ├── AccountRestController.java
           └── UserRestController.java
   ```

2. **`list_file_project.json`**
   Berisi array JSON semua path file relatif dari root folder.

   Contoh:

   ```json
   [
     "AplikasiMinibankApplication.java",
     "config/SecurityConfig.java",
     "controller/ProductController.java"
   ]
   ```

#### 📝 Catatan

* Tidak menggunakan `tree` → jadi lebih portable.
* Direkomendasikan untuk digunakan sebagai bagian dari CI, dokumentasi proyek, atau build pipeline.

---

## 🛠️ Kontribusi

Sumbangan script Bash lainnya sangat dipersilakan!
Pastikan script yang kamu tambahkan:

* Reusable untuk konteks umum
* Tidak tergantung library luar jika memungkinkan
* Dilengkapi komentar dan dokumentasi singkat

---

## 🧾 Lisensi

MIT License © [kikiraihan](https://github.com/kikiraihan)

```

---
