# Reusable Bash Command

Kumpulan script Bash yang dapat digunakan ulang untuk kebutuhan scripting dan otomasi proyek, seperti analisis struktur direktori, pengelolaan file, logging, dan lainnya.

Dibuat oleh [@kikiraihan](https://github.com/kikiraihan)

---

## generate_project_structure.sh

Script untuk menghasilkan:

- Struktur direktori proyek (mirip `tree`, tapi tanpa dependensi eksternal)
- Berguna untuk memberikan konteks kepada AI LLM ketika ingin memberi perintah
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

## my-commits.sh

Laporan commit milik sendiri dari banyak project sekaligus: pilih rentang tanggal, project, dan branch
(bisa wildcard seperti `*kiki*`). Report bisa tampil di terminal, disimpan ke file, atau dirangkum AI
jadi daily standup / weekly report. Detail lengkap ada di [`my-commit-readme.txt`](my-commit-readme.txt).

```bash
./my-commits.sh --show
```

![Contoh my-commits.sh --show](screenshots/my-commits.png)

---

## git-featuring-branch (gfb)

Kumpulan fungsi zsh untuk alur kerja feature branch. Pasang dengan `source` dari `~/.zshrc`:

```bash
source /path/to/reusable-bash-command/git-featuring-branch
```

Ketik `gfbmain` untuk daftar semua perintah, atau `gfbmain help <cmd>` / `<cmd> -h` untuk bantuan detail.

### Contoh penggunaan

**`gfbmain`** — ringkasan semua perintah

![gfbmain](screenshots/gfbmain.png)

**`gfbstatus`** — git status versi lengkap: upstream, posisi terhadap base, staged/changes/untracked, commit belum di-push, dan langkah berikut

![gfbstatus](screenshots/gfbstatus.png)

**`gfbls`** — daftar branch, urut terakhir dipakai, dengan status sinkron ke origin

![gfbls](screenshots/gfbls.png)

**`gfblog main`** — commit di branch aktif yang belum ada di base

![gfblog](screenshots/gfblog.png)

**`gfbcompare main feature/payment-webhook`** — bandingkan dua branch: common ancestor, commit yang hanya ada di masing-masing, dan file yang berbeda

![gfbcompare](screenshots/gfbcompare.png)

**`gfbrenew`** — perbarui branch aktif dengan master terbaru, tanpa risiko kehilangan kerjaan

```bash
gfbrenew              # split-payment → backup split-payment-old-20261111, buat ulang dari origin/master, merge backup
gfbrenew -b develop   # pakai develop sebagai base
gfbrenew -dp          # hapus backup di akhir tanpa tanya + push (fast-forward, tanpa force)
gfbrenew -k           # simpan backup tanpa tanya
gfbrenew -n           # dry-run, lihat rencana saja
```

- Nama backup `<branch>-old-YYYYMMDD`; kalau tanggal sama sudah ada → `-2`, `-3`, dst. Backup hanya lokal.
- Backup dihapus paling akhir: tanpa `-d`/`-k` ditanya dulu (default: tidak dihapus).
- Base diambil dari `origin/<base>` tanpa checkout, jadi aman dipakai di worktree. Upstream branch dipertahankan.
- Kalau conflict: proses berhenti, backup tetap aman, dan ditampilkan perintah untuk batal & kembali seperti semula.

**`gfbwt`** — kelola git worktree: 1 branch = 1 folder, kerjakan beberapa branch sekaligus tanpa stash/checkout

```bash
gfbwt                                 # daftar worktree: status file, sinkron origin, commit terakhir
gfbwt add kiki/feat/SP-900 develop    # worktree branch baru dari origin/develop, lalu cd ke sana
gfbwt add kiki/feat/SP-829            # branch yang sudah ada (lokal/origin)
gfbwt go 829                          # cd ke worktree yang cocok
gfbwt main                            # kembali ke repo utama
gfbwt rm -b @                         # hapus worktree ini + branch-nya (lokal + origin)
gfbwt clean develop -b                # prune worktree hilang + hapus yang sudah merged
gfb -pw develop kiki/feat/SP-901      # gfb versi worktree: repo utama tidak di-checkout
```

- Lokasi: `../<repo>.wt/<branch-slug>` (ubah dengan `GFB_WT_DIR`).
  Kalau folder induk repo punya `.gfbwt-ws`, lokasinya jadi `<induk>/.wt/<branch-slug>/<repo>` (lihat workspace multi-repo di bawah).
- Setelah `add`: `.env*` yang di-gitignore di-copy dari repo utama, `vendor/` & `node_modules/`
  di-clone dengan APFS copy-on-write (`-i` untuk `composer install`/`npm ci`, `-x` tanpa deps),
  lalu `.gfbwt-setup` dijalankan kalau ada.
- `vendor/` sengaja tidak di-symlink: `__DIR__` PHP mengikuti symlink, sehingga autoload Composer
  akan memuat kode dari repo utama, bukan dari worktree.
- Terintegrasi: `gfbls` menandai branch di worktree lain dengan `⎇`, `gfbdel`/`gfbclean` tidak
  mencoba menghapus branch yang masih terbuka di worktree.

**`gfbwt ws`** — workspace multi-repo: 1 branch = 1 folder berisi beberapa repo yang sejajar.
Cocok kalau satu fitur menyentuh beberapa repo (mis. backend + admin panel) dalam satu folder induk.

```
projects/                     ← folder induk, berisi .gfbwt-ws
├── api-gateway/              ← repo utama (tetap)
├── web-dashboard/            ← repo utama (tetap)
└── .wt/
    └── kiki-feat-SP-900/     ← 1 workspace = 1 branch
        ├── api-gateway/      ← worktree
        └── web-dashboard/    ← worktree, branch sama, sejajar
```

```bash
# projects/.gfbwt-ws — per baris: <alias> <folder-repo> [base-default]
api   api-gateway     develop
web   web-dashboard   develop
```

```bash
gfbwt ws                                   # daftar workspace + status tiap repo + worktree di lokasi lama
gfbwt ws add kiki/feat/SP-900 api web      # worktree kedua repo sekaligus (semua dicek dulu)
gfbwt ws add @ web                         # lagi kerja di api, tambah web di sebelahnya (branch sama)
gfbwt ws add kiki/feat/SP-900 web:master   # base khusus untuk repo itu
gfbwt ws go web                            # dari dalam workspace → pindah ke repo web
gfbwt ws rm -b @                           # hapus workspace ini + branch-nya di semua repo
gfbwt ws migrate                           # pindahkan worktree lama <repo>.wt/... ke .wt/<branch>/<repo>
```

- Dengan `.gfbwt-ws`, `gfbwt add` / `gfb -w` biasa juga menaruh worktree di `.wt/<branch>/<repo>`,
  jadi hanya ada satu aturan lokasi dan repo lain dengan branch yang sama selalu ada di folder sebelah.
- Tanpa symlink: `../web-dashboard` dari dalam worktree tetap mengarah ke pasangannya, grep/IDE aman.
- Branch yang sudah punya worktree di lokasi lama → `ws add` menawarkan pindah (`git worktree move`,
  perubahan yang belum di-commit ikut pindah).

> Screenshot diambil dari repo demo (`api-gateway`, `web-dashboard`, `mobile-app`) dengan data commit contoh.

---

## Others

Script lain akan ditambahkan di sini bila tersedia.
