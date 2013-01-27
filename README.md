## [redoflacs](/sirjaren/redoflacs)
`redoflacs`: Parallel BASH commandline FLAC compressor, verifier, organizer, analyzer, and retagger

<p align="center">
	UNIX/Linux/BSD Version
</p>

<p align="center">
	<img src="https://raw.github.com/sirjaren/repository-images/master/redoflacs/redoflacs_0.20_all.png" alt="redoflacs 0.20: all options"/>
</p>

##Dependencies
##### Required Dependencies
     - BASH 4 (or greater)  
     - Coreutils  
     - FLAC  
        ↳ Metaflac (included with FLAC)

##### Optional Dependencies
     - SoX (Built with `libpng`)
     - auCDtect

## Usage
    redoflacs [operations] [options] [target] ...
    Operations:
      -c, --compress
      -C, --compress-notest
      -t, --test
      -m, --md5check
      -a, --aucdtect
      -A, --aucdtect-spectrogram
      -p, --prune
      -g, --replaygain
      -G, --replaygain-noforce
      -r, --redo
      -l, --all
      -L, --reallyall
    Options:
      -j[N], --jobs[=N]
      -n, --no-color
      -o, --new-config
      -v, --version
      -h, --help

## Program Information
`redoflacs` is a multi-process/multi-job BASH script for managing your FLAC library

##### Preamble
One of the best features of this program is the idea that it can use more than one job to process your FLAC files. By default, this program will try and determine how many CPUs/cores you have (via `/proc/cpuinfo`) and use that many jobs during the specified operation. This essentially means this program will utilize all your CPUs/cores to quickly and efficiently complete your specified operation. The number of jobs to use can be specified with the `-j, --jobs` option.

The most common operations are detailed below. If you have any more questions you can invoke `redoflacs -h` to get more information on the various operations and options available to you. When describing an invocation of this program, I'll use the short style options (`-c`, `-m`, `-p`, etc), but know you can use the long style options (`--compress`, `--md5check`, `--prune`, etc) as well as mix the short and long style (`--compress`, `-mp`).

##### Compressing & Verifying
The most common operation is compressing your FLAC library (level 8 compression, by default). This can be invoked with `redoflacs -c /path/to/flac/directory`. This operation will check your FLAC files for any errors (verifying it's integrity) as well as re-encode your FLAC files using the highest compression possible (which is level 8). The level of compression used can be changed quite easily under the user's configuration file (normally `~/.config/redoflacs/config`) with the **compression\_level** option.

Upon successful verification and re-encoding of each FLAC file, a tag will be added to that FLAC file with the level it was compressed at. The tag added is: COMRPESSION. For example, if you decided to compress all your FLAC files with level 8 compression (default), each FLAC file that successfully complete would have COMPRESSION=8 added to it. This is useful for the user to know with certainty that his/her FLAC files are compressed to the level he/she wanted.

If any FLAC file has an error with the operation, that FLAC file will be logged to a log file in your the directory specified in the user's configuration file (the HOME directory by default). A COMPRESSION tag will **\_NOT\_** be added to a FLAC file which has failed.

##### Testing
If you don't want to compress and verify your FLAC files, you can opt to just test them for any errors. This operation does just that and can be invoked with `redoflacs -t /path/to/flac/directory`.

This operation will test all your FLAC files, and report any issues/errors to a log file to your log directory.

##### MD5 Verification
This operation can check the MD5 signature of each FLAC file and report any errors to a log file, and it's invoked via `redoflacs -m /path/to/flac/directory` What this means is it will check to make sure the MD5 signature is not unset (meaning it's not a string of zeros). A FLAC file with an unset MD5 signature is not necessarily corrupt, it just means that it hasn't been encoded with a signature (maybe it was encoded by a third-party tool that isn't quite up to par with the official tools?).

A re-encoding of the file will force an MD5 signature to be set, but you should steer clear and try and verify the FLAC file before doing this, as it **\_may\_** indicate a faulty FLAC file. This option would normally be used by itself first (before compressing & verifying/testing) to see which files have an unset MD5 signature.

##### Pruning/Removing Excess Metadata
If you want to remove some of the excess blocks inside your FLAC files, this is the operation to run. The operation is invoked with `redoflacs -p /path/to/flac/directory`. This operation will remove all the METADATA blocks inside each FLAC file (except for the STREAMINFO block and the VORBIS\_COMMENT block). The STREAMINFO block cannot be removed, by design of the FLAC tools, and the VORBIS\_COMMENT block houses all the tags of your FLAC files (so it won't be removed). By default, the operation **\_will\_** remove any embedded pictures and cover art stored inside your FLAC files. This can be changed by setting the **remove\_artwork** to *false* in the user's configuration file.

Keep in mind, this operation will remove the SEEKTABLE block from your FLAC files. This block is not needed for modern music players, and is used only to help older music players allow users to seek within a song as it's playing.

This operation will also remove any excess padding (the PADDING block) inside each FLAC file. Padding is caused when editing the FLAC files (tagging, for example). This padding is created to make tagging a much faster process. If you do not have any padding in you FLAC files, and you want to add some tags to the them, the process will take **\_A LOT\_** more time as the FLAC file will have to expand to accommodate the new tags. Generally, you want to prune your FLAC files when you have tagged them the way you want, otherwise tagging your FLAC files is a battle with patience.

##### Retagging
The retagging operation is a bit more complicated than other operations. First of all, it can be invoked with `redoflacs -r /path/to/flac/directory`. What this operation does is analyze your FLAC files' tags, checking for any tags that are unset and/or missing. The tags that are checked are defined in the user's configuration file, which can be changed to what you want to keep. If any of your FLAC files have unset and/or missing tags, those FLAC files are logged to a log file with the name of the FLAC and all tags that are unset and/or missing. If there is a log file, the operation will quit after analyzing the tags (so there won't be any retagging -- useful to check for missing tags).

If the operation analyzed all the FLAC files and did **\_NOT\_** find any unset/missing tags, retagging will occur. What does this mean? First, all the tags that are to be kept are extracted and saved in memory for each FLAC file. Next, each FLAC file has all of it's tags removed. Finally, the saved tags are applied back to each FLAC file. This operation makes it possible to clear your FLAC files of superfluous tags, leaving you with clean tags.

A benefit of this operation is it's ability to remove any extra spacing before and after tag values. For example, let's say you have a FLAC file with a TITLE tag of:

    '    The Great Escape    '

After retagging, the TITLE tag would look like:

    'The Great Escape'

#####  Applying ReplayGain
ReplayGain is applied using `metaflac` which is a part of the flac package. This operation is invoked with `redoflacs -g /path/to/flac/directory`. There are two types of ReplayGain values that can be added to your FLAC files: **Track Values** and **Album Values**. In order for the album ReplayGain values to be applied to your FLAC files (correctly), each album will need to be in a **\_separate\_** directory. Otherwise, the album ReplayGain values will end up the same as the track ReplayGain values.

The first part of the operations analyzes your FLAC files's in each directory for different sample rates. If a directory of FLAC files have different sample rates, an error will be issued to a log file indicating FLAC files with multiple sample rates are not supported, with the directory logged as well. This is because the ReplayGain values will not be generated correctly.

After testing, ReplayGain values will be generated and applied via FLAC tags. The tags applied are as follows:

    REPLAYGAIN_REFERENCE_LOUDNESS
    REPLAYGAIN_TRACK_GAIN
    REPLAYGAIN_TRACK_PEAK
    REPLAYGAIN_ALBUM_GAIN
    REPLAYGAIN_ALBUM_PEAK

##### Validating FLAC Authenticity Using auCDtect
This operation uses the `auCDtect` developed by *Oleg Berngardt* and *Alexander Djourik* to help detect whether your FLAC files originated from CD's and/or are mastered lossy. If you decide to run this operation, make sure you have `auCDtect` installed, otherwise this program will let you know it cannot find the program and quit. This operation is invoked with `redoflacs -a /path/to/flac/directory`.

What this operation essentially does is scan your FLAC files and report any files that may be suspicious to a log file. Suspicious in this case, means any file that doesn't pass auCDtect's test with 100% certainty of being from a CD (eg. CDDA).

If you invoke `redoflacs -A /path/to/flac/directory` instead, any file that doesn't pass auCDtect with 100% certainty has a spectrogram created with `SoX`. The spectrogram is created in the same directory as the FLAC file being tested with the same name as the FLAC file (with the PNG extension). If `SoX` is **\_NOT\_** installed, the program will let you know it cannot find the program and quit.

##### Options
This program has two options to change how the program looks and operates. You can turn off all the ANSI colors that are shown via the `-n`, `--no-color` option. You can also specify the number of jobs to run (mentioned above) before the operation starts via the `-j`, `--jobs` option.

## Examples
##### Compress All FLAC Files & Verify FLAC Integrity
    redoflacs -c /path/to/flac/directory
           or
    redoflacs --compress /path/to/flac/directory

##### Check FLAC Validity Using auCDtect & Create A Spectrogram For Problematic Files
    redoflacs -A /path/to/flac/directory
            or
    redoflacs --aucdtect-spectrogram /path/to/flac/directory

##### Prune FLAC Files Of All METADATA Blocks Except STREAMINFO, VORBIS_COMMENT, and possibly the PICTURE Block
    redoflacs -p /path/to/flac/directory
            or
    redoflacs --prune /path/to/flac/directory

##### Check The MD5 Signature of Each FLAC File, Running With 10 Jobs
    redoflacs -mj10 /path/to/flac/directory
            or
    redoflacs --md5check --jobs=10 /path/to/flac/directory

##### Run The Entire Gamut Of Tests
    redoflacs -L /path/to/flac/directory
            or
    redoflacs -cmpgrA /path/to/flac/directory
            or
    redoflacs --compress --md5check --prune --replaygain --redo --aucdtect-spectrogram /path/to/flac/directory

##### Donations
Consider [supporting](https://www.gittip.com/sirjaren "Gittip") me if you appreciate my work!
