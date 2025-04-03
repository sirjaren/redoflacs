% REDOFLACS(1) | redoflacs User Manual
% redoflacs Project Authors
% Version 1.1.0

# NAME

**redoflacs** - Parallel BASH commandline FLAC compressor, verifier, organizer,
analyzer, and retagger

# SYNOPSIS

**redoflacs** [*operations*] [*options*] *target*

# DESCRIPTION

**redoflacs** is a parallel BASH FLAC management tool that performs various
audio preservation tasks including compression, verification, authentication,
metadata pruning, *ReplayGain* application, and retagging while maintaining
detailed logs.

Features include:
- Multi-threaded processing with configurable job/thread counts
- *auCDtect* validation with spectrogram generation
- Lossless Audio Checker (*LAC*) validation with spectrogram generation
- Intelligent FLAC compression, with skipping based on metadata tags
- *ReplayGain* calculation with album/track preservation
- Configurable metadata retention policies
- Embedded artwork extraction and management
- Detailed error logging and progress reporting

# OPERATIONS

**-c**
: Compress FLAC files using configured level (default: *8*). Skips files with
matching *COMPRESSION* tag unless forced.

**-C**
: Force compression regardless of existing *COMPRESSION* tags.

**-t**
: Verify FLAC integrity without compression.

**-m**
: Check for valid *MD5 signature* in *STREAMINFO* blocks.

**-a**
: Authenticate with *auCDtect* (skipping files tagged *MASTERING=Lossy*).

**-A**
: Authenticate with *auCDtect* and generate spectrograms for questionable
files.

**-l**
: Authenticate with Lossless Audio Checker (*LAC*) (skipping files tagged
*MASTERING=Lossy*).

**-L**
: Authenticate with Lossless Audio Checker (*LAC*) and generate spectrograms
for questionable files.

**-e**
: Extract all embedded artwork to organized directories.

**-p**
: Prune metadata blocks (keeps *STREAMINFO*, *VORBIS_COMMENT*, and optionally
*PICTURE*).

**-g**
: Apply *ReplayGain* (skipping files with existing *ReplayGain* tags).

**-G**
: Force *ReplayGain* application regardless of existing tags.

**-r**
: Retag files, removing all tags except those specified within the
**~/.config/redoflacs/config** configuration file, and optionally normalizing
track numbers.

# OPTIONS

**-j**[*N*]
: Allow N jobs at once (default: *all cores*, or *2* if unknown)

**-J**[*N*]
: Allow N jobs for compression >= FLAC 1.5.0 (default: *cores*/*threads*)

**-T**[*N*]
: Allow N threads for compression >= FLAC 1.5.0 (default: *2*)

**-n**
: Disable colored output

**-x**
: Do not apply *COMPRESSION* tag when compressing FLAC files

**-o**
: Generate a new configuration file (non-destructively) and exit

**-v**
: Print the version number of redoflacs and exit

**-h**
: Show help information and exit

# FILES

**~/.config/redoflacs/config**

A user configuration file is generated if one is not present.

# CONFIGURATION

The configuration file supports these options:

**preserve_modtime**:
: Maintain file timestamps (*true*/*false*)

**prepend_zero**:
: Zero-pad track numbers (*true*/*false*)

**compression_level**:
: 1-8 (default: *8* [best])

**remove_artwork**:
: Remove *PICTURE* blocks (*true*/*false*)

**skip_lossy**:
: Skip *auCDtect* or Lossless Audio Checker (*LAC*) on *MASTERING=Lossy* files
(*true*/*false*)

**error_log**:
: Directory for log files (default: *$HOME*)

**temporary_wav_location**:
: Directory for temporary WAV file generation; used during *auCDtect* and
Lossless Audio Checker (*LAC*) operations (default: *same location as FLAC
file*)

**spectrogram_location**:
: Spectrogram output directory (default: *same location as FLAC file*)

**artwork_location**:
: Artwork extraction directory (default: *same location as FLAC file*)

# EXAMPLES

Compress and verify all FLAC files:

    redoflacs -c ~/Music

CDDA authenticity (*auCDtect*) checking with spectrograms with 8 parallel jobs:

    redoflacs -j8 -A ~/Music

Force *ReplayGain* application, retag and prune files:

    redoflacs -Gpr ~/Music

Check MD5 checksum and test integrity with 8 jobs:

    redoflacs -j8 -mt ~/Music

Force re-compression with 4 threads/jobs:

    redoflacs -J4 -T4 -C ~/Music

LAC checking without color using 12 jobs:

    redoflacs -n -j8 -l ~/Music

Parallel compression/retagging with different job counts:

    redoflacs -j12 -J3 -T4 -C ~/Music

# NOTES

- Requires **flac** and **metaflac**
- Optionally uses **sox** (*spectrograms*), **auCDtect** and **LAC**
- Multithreaded compression requires **flac** >=1.5.0
- Artwork/spectrogram directories use incremental numbering to prevent
overwrites
- Spectrograms generate *1800x513* PNGs with FLAC file information

# BUGS

Report issues at:

https://github.com/sirjaren/redoflacs/issues

# SEE ALSO

**flac**(1), **metaflac**(1), **sox**(1)
