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


4. Script akan menghasilkan file report:

   commits_[tanggal-awal]_to_[tanggal-akhir].txt

   Contoh: commits_2024-01-01_to_2024-01-31.txt


FITUR
-----

✓ Interaktif - tidak perlu input parameter di command line
✓ Multi-project - scan beberapa folder project sekaligus
✓ Multi-branch - check commits dari beberapa branch
✓ Validasi otomatis - validasi format tanggal dan git repository
✓ Report gabungan - satu file untuk semua project
✓ Summary lengkap - total commits per project dan grand total


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


PERSYARATAN
-----------

- Git terinstall di sistem
- Bash shell
- Git repository yang valid di folder-folder project
- Git user email dan name sudah dikonfigurasi


AUTHOR
------

Generated for: Moh Zulkifli Katili
Date: 2026-01-09


==================================================
              END OF README
==================================================
