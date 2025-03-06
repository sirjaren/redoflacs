<div>
  <img src="https://raw.githubusercontent.com/sirjaren/repository-images/master/redoflacs/redoflacs-0.30.png" alt="redoflacs 0.30"/>
</div>

# redoflacs

**redoflacs** is a parallel BASH command-line tool for managing a collection of FLAC audio files. It can re-compress FLACs to maximize compression, verify and repair their integrity, and organize or clean up metadata (tags and embedded artwork) in bulk. By utilizing multi-core processing, redoflacs can perform these operations quickly on large libraries of music.

## Features

- **Multi-core FLAC compression & verification** – Re-encode FLAC files to the highest compression level (default level 8) while verifying each file’s integrity. Ensures all files are compressed uniformly and correctly.
- **Error checking (testing)** – Scan FLAC files for any errors or corruption without altering them, logging any problematic files for review.
- **MD5 checksum validation** – Check the embedded MD5 signature of each FLAC file to identify files missing a checksum. This helps detect files that may need re-encoding to embed a proper MD5.
- **Metadata pruning** – Remove unnecessary metadata blocks from FLAC files (such as padding, seek tables, and embedded album art) to reduce file size. Only essential information (audio stream info and tags) is kept.
- **Retagging** – Clean up FLAC tags by removing all tags and reapplying only a defined set of essential tags. This ensures consistent, well-formed tags across your library (and trims any extraneous whitespace in tag values). Missing or empty required tags are reported for user review before any retagging occurs.
- **ReplayGain calculation** – Calculate and embed ReplayGain volume normalization tags (track and album gain/peak) for all files using `metaflac`. This allows consistent playback volume across tracks and albums. (Requires that each album’s tracks reside in separate directories for accurate album gain calculation.)
- **Authenticity analysis** – Use the **auCDtect** tool to analyze audio data and detect files that might not be true lossless sources (e.g. upconverted from MP3). Suspect files (those not 100% verified as CDDA) are logged for attention. An extended mode can also generate spectral spectrogram images (requires **SoX**) for each suspect file to assist in manual inspection.
- **Album art extraction** – Extract all embedded cover images from FLAC files to external image files. This is useful for backing up album art before using the metadata pruning operation (which by default removes embedded art). Extracted images are saved to a folder (configurable) alongside each FLAC file.

## Requirements

- **Operating System:** Unix-like environment (Linux; macOS should work with a newer Bash).
- **Bash 4.0** or higher.
- **FLAC:** The [FLAC tools](https://xiph.org/flac/) package (includes `flac` and `metaflac`).
- **Optional:**
  - **SoX** (with PNG support) – only needed for generating spectrogram images.
  - **auCDtect** – only needed for CDDA authenticity check operations.

Ensure the required programs are installed and in your PATH before using redoflacs. Optional tools can be installed to enable those specific features (redoflacs will notify you if an optional tool is required but not found).

## Installation

1. **Download the script:** You can get redoflacs by cloning the [GitHub repository](https://github.com/sirjaren/redoflacs) or downloading the latest release. The main script file is **`redoflacs`** (a single Bash script).
2. **Install the script:** Place the `redoflacs` script somewhere in your PATH (for example, `/usr/local/bin/`) and ensure it is executable. For example:
   ```bash
   $ cp redoflacs /usr/local/bin/redoflacs
   $ chmod +x /usr/local/bin/redoflacs
   ```
3. **Configuration (optional):** On first run, redoflacs will create a configuration file at `~/.config/redoflacs/config` with default settings. You can manually generate or reset this file by running `redoflacs -o`. Review this config file to adjust settings such as compression level, which tags to preserve during retagging, whether to remove album artwork during pruning, and where to save extracted artwork.
4. **Verify installation:** Run `redoflacs -h` to display the help text and verify that the script is working.

## Usage
```bash
redoflacs [operations] [options] [target]
```

### Common Operations

- **Compress & Verify**
  ```bash
  $ redoflacs -c ~/Music
  ```
  Re-encode every FLAC under `~/Music` to compression level defined, verifying each file’s integrity. Adds a `COMPRESSION` tag to each file on success.

- **Prune metadata from FLAC files**
  ```bash
  $ redoflacs -p ~/Music
  ```
  Removes all non-essential metadata (including album art) from the FLAC files.

- **Apply ReplayGain to an album**
  ```bash
  $ redoflacs -g ~/Music/Artist/Album
  ```
  Calculates track and album ReplayGain for all FLACs in an album directory and adds the appropriate tags.

- **Check FLAC authenticity and generate spectrograms**
  ```bash
  $ redoflacs -A ~/Music
  ```
  Analyzes all FLACs in a directory with auCDtect to detect upscaled or lossy-sourced files.

- **Combine multiple operations in one go**
  ```bash
  $ redoflacs -c -p ~/Music
  ```
  Compress and prune metadata in a single command.

- **Use compression jobs and threads**
  ```bash
  $ redoflacs -J8 -T2 -C ~/Music
  ```
  Forcefully compress using 2 threads per job and 8 jobs.

## Project Status and Contribution

redoflacs is an open-source project released under the MIT License. Contributions such as bug fixes or improvements are welcome – feel free to fork the repository and open a pull request on GitHub.

If you encounter any issues or have questions, please refer to the built-in help (`redoflacs -h`) or the provided man page distributed with this program.
