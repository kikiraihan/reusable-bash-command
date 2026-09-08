==================================================
  GIT MULTI-PROJECT COMMIT REPORTER - README
==================================================

DESKRIPSI
---------
Script ini digunakan untuk menghasilkan laporan commit git dari multiple project
sekaligus dalam satu periode waktu tertentu. Script bekerja secara interaktif
sehingga mudah digunakan.


LOKASI FILE
-----------
/Users/mohzulkiflikatili/1SiteKiki/singa/my-commits.sh


CARA MENGGUNAKAN
----------------

1. Buka terminal dan masuk ke folder /singa:

   cd /Users/mohzulkiflikatili/1SiteKiki/singa


2. Jalankan script:

   ./my-commits.sh


3. Ikuti petunjuk interaktif:

   a) Input tanggal mulai (format: YYYY-MM-DD)
      Contoh: 2024-01-01

   b) Input tanggal akhir (format: YYYY-MM-DD)
      Contoh: 2024-01-31

   c) Pilih folder project yang ingin di-scan
      - Script akan menampilkan list folder yang tersedia
      - Folder yang merupakan git repository ditandai dengan [GIT]
      - Pilih dengan mengetik nomor (contoh: 1,3,5)
      - Atau ketik "all" untuk memilih semua folder

   d) Input nama branch yang ingin di-check
      - Pisahkan dengan koma untuk multiple branches
      - Contoh: kikidev,master,develop
      - Atau tekan Enter untuk default branch (kikidev)


4. Pilih mau diapakan report-nya:

   [1] Tampilkan raw commit report (default)
       -> report langsung tampil di terminal, TIDAK bikin file,
          lalu ditanya mau di-copy ke clipboard atau tidak

   [2] Generate Daily Standup Report (AI)
       -> AI langsung merangkum commit jadi daily standup (paragraf natural)

   [3] Generate Weekly Progress Report (AI)
       -> AI merangkum commit jadi weekly report, lewat 2 tahap
          (konfirmasi analisa dulu, baru full report)

   [4] Simpan ke file

       commits_[tanggal-awal]_to_[tanggal-akhir].txt

       Contoh: commits_2024-01-01_to_2024-01-31.txt


MODE LANGSUNG (TANPA DITANYA)
-----------------------------

Mode bisa juga dipilih dari awal lewat option:

   ./my-commits.sh --show      # tampilkan raw report di terminal (default)
   ./my-commits.sh --file      # simpan ke file commits_*.txt
   ./my-commits.sh --daily     # langsung generate Daily Standup Report (AI)
   ./my-commits.sh --weekly    # langsung generate Weekly Progress Report (AI)
   ./my-commits.sh --help      # bantuan

Option AI:

   -p, --provider   groq (default) / gemini
   -m, --model      model manual, contoh:
                    ./my-commits.sh --weekly -m openai/gpt-oss-120b
                    ./my-commits.sh --daily -p gemini

   Default model: qwen/qwen3-32b (groq), gemini-2.0-flash (gemini)


FITUR AI REPORT
---------------

Butuh API key yang sama dengan gfbpr di file git-featuring-branch:

   export GROQ_API_KEY="gsk_xxxxxx"      -> https://console.groq.com
   export GEMINI_API_KEY="AIza_xxxxxx"   -> https://aistudio.google.com/apikey

Butuh juga python3 dan curl.

DAILY (--daily / pilihan [2]):
- Commit dikelompokkan Yesterday vs Today
- Output paragraf natural Bahasa Inggris (bukan bullet)
- Nama project selalu disebut
- Commit WIP/temp/draft disebut sebagai WIP
- Diakhiri "That's all from my side."

WEEKLY (--weekly / pilihan [3]):
- Tahap 0: script menanyakan rencana minggu depan (opsional, satu task per
  baris, akhiri dengan baris kosong) -> jadi bagian "Next Week"
- Tahap 1: AI menampilkan analisa (WIP + estimasi %, issues, notes) untuk
  dikonfirmasi. Ketik koreksi (satu per baris, akhiri baris kosong), atau
  langsung Enter kosong kalau sudah setuju
- Tahap 2: AI generate full report dengan seksi
  Done / In Progress / Next Week / Issues / Notes
- Setiap bullet menyebut nama project dalam kurung

Hasil AI langsung tampil di terminal dan ditanya mau di-copy ke clipboard.
Copy otomatis pakai pbcopy / wl-copy / xclip / xsel / clip.exe (mana yang ada).


FITUR
-----

✓ Interaktif - tidak perlu input parameter di command line
✓ Multi-project - scan beberapa folder project sekaligus
✓ Multi-branch - check commits dari beberapa branch
✓ Validasi otomatis - validasi format tanggal dan git repository
✓ Report gabungan - satu file untuk semua project
✓ Summary lengkap - total commits per project dan grand total
✓ Tampil langsung di terminal (default) - tidak wajib bikin file
✓ Copy ke clipboard - ditanya setelah report/hasil AI tampil
✓ AI report - daily standup & weekly progress report via Groq/Gemini


FORMAT OUTPUT
-------------

File report akan berisi:

1. Header dengan informasi:
   - Nama author (dari git config)
   - Periode tanggal
   - List branches yang di-check
   - List projects yang di-scan
   - Waktu generate report

2. Detail commits per project:
   - Dikelompokkan per project
   - Dikelompokkan per branch
   - Format: [commit-hash] - [tanggal-waktu] - [commit-message]

3. Summary:
   - Jumlah project yang diproses
   - Total commits dari semua project


CONTOH PENGGUNAAN
-----------------

Scenario 1: Scan semua project untuk branch kikidev
----------------------------------------------------
$ ./my-commits.sh
Enter start date (YYYY-MM-DD): 2024-01-01
Enter end date (YYYY-MM-DD): 2024-01-31

Available project folders:
  [1] project-a [GIT]
  [2] project-b [GIT]
  [3] project-c [GIT]

Selection: all
Branches: [tekan Enter untuk default]


Scenario 2: Scan beberapa project untuk multiple branches
----------------------------------------------------------
$ ./my-commits.sh
Enter start date (YYYY-MM-DD): 2024-01-01
Enter end date (YYYY-MM-DD): 2024-01-31

Available project folders:
  [1] project-a [GIT]
  [2] project-b [GIT]
  [3] project-c [GIT]

Selection: 1,2
Branches: kikidev,master,develop


CATATAN
-------

- Script akan menggunakan email dan nama dari git config untuk filter commits
- Pastikan git config sudah di-set dengan benar
- Hanya folder dengan repository git yang akan diproses
- Jika branch tidak ditemukan, akan ditampilkan warning di report
- Report akan di-generate di folder yang sama dengan lokasi script


TROUBLESHOOTING
---------------

Problem: "Git user email not configured"
Solusi: Set git config dengan command:
        git config --global user.email "email@example.com"
        git config --global user.name "Your Name"

Problem: "No folders found in current directory"
Solusi: Pastikan menjalankan script dari folder /singa yang berisi
        subfolder-subfolder project

Problem: Branch tidak ditemukan
Solusi: Check nama branch dengan 'git branch -a' di masing-masing project

Problem: "GROQ_API_KEY belum di-set"
Solusi: export GROQ_API_KEY="gsk_xxxxxx" (daftar gratis di console.groq.com)
        atau pakai Gemini: ./my-commits.sh --daily -p gemini

Problem: "API error: model ... does not exist"
Solusi: Model default bisa berubah/di-deprecate oleh provider. Pilih model lain:
        ./my-commits.sh --daily -m openai/gpt-oss-120b

Problem: "Tidak ada tool clipboard"
Solusi: Install salah satu: pbcopy (macOS bawaan), xclip/xsel (X11),
        wl-copy (Wayland). Atau copy manual dari terminal.


PERSYARATAN
-----------

- Git terinstall di sistem
- Bash shell
- Git repository yang valid di folder-folder project
- Git user email dan name sudah dikonfigurasi
- Khusus mode AI: python3, curl, dan GROQ_API_KEY / GEMINI_API_KEY


AUTHOR
------

Generated for: Moh Zulkifli Katili
Date: 2026-01-09


==================================================
              END OF README
==================================================
