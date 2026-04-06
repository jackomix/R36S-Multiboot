# Update R36S-Multiboot for Andr36oid and dArkOSRE R36

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update Andr36oid to the latest version and add dArkOSRE R36 with dynamic download logic for a genuine Panel 4 device.

**Architecture:** Each OS has its own directory with scripts to download (`get-image.sh`) and install (`install-os.sh`, `post-install.sh`) the OS into the multiboot image. Automation uses GitHub API to find the latest assets.

**Tech Stack:** Bash, curl, jq, wget, unzip, 7z.

---

### Task 1: Update Andr36oid to latest version

**Files:**
- Modify: `andr36oid/get-image.sh`

- [ ] **Step 1: Update andr36oid/get-image.sh**
Update the script to fetch the latest image from the `andr36oid/release_uploads` repository instead of the `andr36oid/releases` assets, as the developer moved the assets.

```bash
#!/bin/bash

# Fetch the latest lineage-*-r36s-android.img.zip from the root of andr36oid/release_uploads
asset_url=$(curl -s "https://api.github.com/repos/andr36oid/release_uploads/contents/" \
  | jq -r '[.[]] | select(.name | test("r36s-android.img.zip$")) | sort_by(.name) | reverse | .[0].download_url' \
  | head -n 1)

if [[ ! -f "${ThisImgName}" ]]
then
    if [[ -z "$asset_url" ]] || [[ "$asset_url" == "null" ]]; then
        echo "Error: Could not find latest Andr36oid image."
        exit 1
    fi
    echo "Downloading Andr36oid: ${asset_url}"
    wget "$asset_url" -O"${ThisImgName}.zip"
    unzip "${ThisImgName}.zip"
    rm -f "${ThisImgName}.zip"
    dlf=$(find -name "lineage-*-r36s-android.img")
    mv $dlf "${ThisImgName}"
    sync
fi
```

- [ ] **Step 2: Commit changes**
```bash
git add andr36oid/get-image.sh
git commit -m "feat(andr36oid): update get-image.sh to fetch from release_uploads"
```

### Task 2: Create dArkOSRE R36 directory and metadata

**Files:**
- Create: `darkosre/bootbutton`
- Create: `darkosre/bootsizereq`
- Create: `darkosre/sizereq`

- [ ] **Step 1: Create darkosre/bootbutton**
Use button B (south) which is `b5`.
```bash
echo b5 > darkosre/bootbutton
```

- [ ] **Step 2: Create darkosre/bootsizereq**
Set to 128MiB.
```bash
echo 128 > darkosre/bootsizereq
```

- [ ] **Step 3: Create darkosre/sizereq**
Set to 8192MiB.
```bash
echo 8192 > darkosre/sizereq
```

### Task 3: Implement dArkOSRE download logic

**Files:**
- Create: `darkosre/get-image.sh`

- [ ] **Step 1: Create darkosre/get-image.sh**
Implement dynamic download logic using GitHub API to find the latest Torrent link.

```bash
#!/bin/bash

repo="southoz/dArkOSRE-R36"
release_body=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.body')
torrent_url=$(echo "$release_body" | grep -oP '(?<=\[Torrent\]\().*?(?=\))' | head -n 1)
mega_url=$(echo "$release_body" | grep -oP '(?<=\[Mega\]\().*?(?=\))' | head -n 1)

if [[ ! -f "${ThisImgName}" ]]
then
    echo "To download dArkOSRE R36:"
    echo "Latest release: https://github.com/${repo}/releases/latest"
    echo "Torrent: ${torrent_url}"
    echo "Mega: ${mega_url}"
    
    if command -v aria2c >/dev/null 2>&1; then
        echo "Attempting to download via aria2c..."
        wget "$torrent_url" -O darkosre.torrent
        aria2c darkosre.torrent
        # Note: Extraction might require 7z and renaming the .img file.
        # This part depends on the torrent contents.
        archive=$(find . -name "*.7z")
        7z x "$archive"
        img=$(find . -name "*.img")
        mv "$img" "${ThisImgName}"
        rm darkosre.torrent "$archive"
    else
        echo "Please download the image manually and place it in this directory as ${ThisImgName}"
        exit 1
    fi
fi
```

### Task 4: Implement dArkOSRE installation scripts

**Files:**
- Create: `darkosre/install-os.sh`
- Create: `darkosre/post-install.sh`
- Create: `darkosre/boot.darkosre.ini`
- Create: `darkosre/darkosre.fstab`
- Create: `darkosre/darkosre-firstrun.sh`
- Create: `darkosre/ez.service`
- Create: `darkosre/ez.sh`
- Create: `darkosre/firstboot.sh`

- [ ] **Step 1: Create darkosre/install-os.sh**
Copy from `ark/install-os.sh` and update labels.

- [ ] **Step 2: Create darkosre/post-install.sh**
Copy from `ark/post-install.sh` and update paths.

- [ ] **Step 3: Create darkosre/boot.darkosre.ini**
Use `LABEL=darkosre`.

- [ ] **Step 4: Create other supporting files**
Copy from `ark/` and modify `ark` to `darkosre`.

### Task 5: Update documentation and button list

**Files:**
- Modify: `r36s u-Boot buttons gpio.txt`
- Modify: `README.md`

- [ ] **Step 1: Update button list**
Add `b5   B (south)  =   dArkOSRE R36`.

- [ ] **Step 2: Update README.md**
Add dArkOSRE R36 to the supported OS list.

---
