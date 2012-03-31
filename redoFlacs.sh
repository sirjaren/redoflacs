#!/bin/bash

#------------------------------------------------------------
# Re-compress, Verify, Test, Re-tag, and Clean Up FLAC Files
#                      Version 0.8
#                       sirjaren
#------------------------------------------------------------

#-----------------------------------------------------------------
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#-----------------------------------------------------------------

# TODO: Make auCDtect skip files that are higher than 16bit/44.1kHz
# TODO: Use tput to print information using the entire terminal screen
#       independent of size

#--------------
# Dependencies
#--------------
# BASH
# FLAC
# Metaflac
# Coreutils
#--------------

tags=(
########################
#  USER CONFIGURATION  #
########################
# List the tags to be kept in each FLAC file
# The tags are case sensitive!
# The default is listed below.
# Be sure not to delete the parenthesis below
# or put wanted tags below it!

TITLE
ARTIST
ALBUM
DISCNUMBER
DATE
TRACKNUMBER
TRACKTOTAL
GENRE
COMPRESSION

)

# Set the number of threads/cores to use
# when running this script.  The default
# number of threads/cores used is 2
CORES=2

# Set the where you want the error logs to
# be placed. By default, they are placed in
# the user's HOME directory.
ERROR_LOG="$HOME"

# Set where the auCDtect command is located.
# By default, the script will look in:
# /usr/local/bin
AUCDTECT_COMMAND="/usr/local/bin/auCDtect"

##########################
#  END OF CONFIGURATION  #
##########################

# Version
VERSION="0.8"

# Export auCDtect command to allow subshell access
export AUCDTECT_COMMAND

# Export the tag array using some trickery (BASH doesn't
# support exporting arrays natively)
export EXPORT_TAG="$(echo -n "${tags[@]}")"

# Colors on by default
# Export to allow subshell access
export BOLD_GREEN="\033[1;32m"
export BOLD_RED="\033[1;31m"
export NORMAL="\033[0m"
export YELLOW="\033[0;33m"

# Log files with timestamp
# Export to allow subshell access
export VERIFY_ERRORS="$ERROR_LOG/FLAC_Verify_Errors $(date "+[%Y-%m-%d %R]")"
export TEST_ERRORS="$ERROR_LOG/FLAC_Test_Errors $(date "+[%Y-%m-%d %R]")"
export MD5_ERRORS="$ERROR_LOG/MD5_Signature_Errors $(date "+[%Y-%m-%d %R]")"
export METADATA_ERRORS="$ERROR_LOG/FLAC_Metadata_Errors $(date "+[%Y-%m-%d %R]")"
export AUCDTECT_ERRORS="$ERROR_LOG/auCDtect_Errors $(date "+[%Y-%m-%d %R]")"

# Set arguments to false
# If enabled they will be changed to true
COMPRESS="false"
TEST="false"
AUCDTECT="false"
MD5CHECK="false"
PRUNE="false"
REDO="false"

# Various information printed to stdout
# Displaying currently running tasks
function title_compress_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Compressing FLAC files with level 8 compression and verifying output"
}

function title_analyze_tags {
	echo -e " ${BOLD_GREEN}*${NORMAL} Analyzing FLAC Tags"
}

function title_setting_tags {
	echo -e " ${BOLD_GREEN}*${NORMAL} Setting new FLAC Tags"
}

function title_testing_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Testing the integrity of each FLAC file"
}

function title_aucdtect_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Validating FLAC is not lossy sourced"
}

function title_md5check_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Verifying the MD5 Signature in each FLAC file"
}

function title_prune_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Removing the SEEKTABLE and PADDING block from each FLAC file"
}

# Error messages
function no_flacs {
	echo -e " $BOLD_RED*${NORMAL} There are not any FLAC files to process"
}

# Information relating to currently running tasks
function print_compressing_flac {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s" \
	"[" "Compressing FLAC" "]" "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_testing_flac {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s" \
	"[" "Testing FLAC" "]" "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_failed_flac {
	printf "\r%75s${BOLD_RED}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
	"[" "FAILED" "]          " "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_checking_md5 {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s" \
	"[" "Checking MD5" "]" "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_ok_flac {
	printf "\r%75s${BOLD_GREEN}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
	"[" "OK" "]              " "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_aucdtect_flac {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
	"[" "Validating FLAC" "]  " "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_aucdtect_issue {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
	"[" "ISSUE" "]           " "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_done_flac {
    printf "\r%75s${BOLD_GREEN}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
	"[" "DONE" "]            " "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_level_8 {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
	"[" "Already At Level 8" "]" "     " "*" " $(basename "$i" | cut -c1-65)"
}

function print_analyzing_tags {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s" \
	"[" "Analyzing Tags" "]" "     " "*" " $(basename "$i"     | cut -c1-65)"
}

function print_setting_tags {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s" \
	"[" "Setting Tags" "]" "     " "*" " $(basename "$i"     | cut -c1-65)"
}

function print_prune_flac {
	printf "\r%75s${YELLOW}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s" \
	"[" "Pruning Metadata" "]" "     " "*" " $(basename "$i"     | cut -c1-65)"
}

# Export all the above functions for subshell access
export -f print_compressing_flac
export -f print_testing_flac
export -f print_failed_flac
export -f print_checking_md5
export -f print_ok_flac
export -f print_aucdtect_flac
export -f print_aucdtect_issue
export -f print_done_flac
export -f print_level_8
export -f print_analyzing_tags 
export -f print_setting_tags
export -f print_prune_flac

# General abort script to use BASH's trap command on SIGINT
function normal_abort {
	echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
	exit $?
}

# Create a countdown function for the metadata
# to allow user to quit script safely
function countdown_metadata {
	# Creates the listing of tags to be kept
	function tags_countdown {
		# Recreate the tags array so it can be parsed easily
		eval "tags=(${EXPORT_TAG[*]})"
		for i in "${tags[@]}" ; do
			echo -e "     $i"
		done
	}

	# Creates the 10 second countdown
	function countdown_10 {
		COUNT=10
		while [[ $COUNT -gt 1 ]] ; do
			echo -en "${BOLD_RED}${COUNT}${NORMAL} "
			sleep 1
			((COUNT--))
		done
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap normal_abort SIGINT

	echo -e " ${YELLOW}*${NORMAL} CAUTION! These are the tag fields that will be kept"
	echo -e " ${YELLOW}*${NORMAL} when re-tagging the selected files:\n"
	tags_countdown
	echo -e "\n ${YELLOW}*${NORMAL} Waiting 10 seconds before starting script..."
	echo -e " ${YELLOW}*${NORMAL} Ctrl+C (Control-C) to abort..."
	echo -en " ${BOLD_GREEN}*${NORMAL} Starting in: "
	countdown_10
	# Below is the last second of the countdown
	# Put here for UI refinement (No extra spacing after last second)
	echo -e "${BOLD_RED}1${NORMAL}\n"
	sleep 1
}

# Compress FLAC files and verify output
function compress_flacs {
	title_compress_flac

	FIND_FLACS="$(find "$DIRECTORY" -name "*.flac" -print)"
	if [[ -z "$FIND_FLACS" ]] ; then
		no_flacs
		exit 0
	fi

	# Abort script and remove temporarily encoded FLAC files (if any)
	# and check for any errors thus far
	function compress_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, removing temporary files and exiting script..."
		find "$DIRECTORY" -name *.tmp,fl-ac+en\'c -exec rm "{}" \;
		if [[ -f "$VERIFY_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check"
			echo -e " ${BOLD_RED}*${NORMAL} \"$VERIFY_ERRORS\" for errors"
		fi
		exit $?
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap compress_abort SIGINT

	function compress_f {
		for i ; do
			# Trap errors into a variable as the output doesn't help
			# for there is a better way to test below using the
			# ERROR variable
			COMPRESSION="$((metaflac --show-tag=COMPRESSION "$i") 2>&1)"
			if [[ "$COMPRESSION" != "COMPRESSION=8" ]] ; then
				print_compressing_flac
				# This must come after the above command for proper formatting
				ERROR="$((flac -f -8 -V -s "$i") 2>&1)"
				if [[ ! -z "$ERROR" ]] ; then
					print_failed_flac
					echo -e "[[$i]]\n"  "$ERROR\n" >> "$VERIFY_ERRORS"
				else
					metaflac --remove-tag=COMPRESSION "$i"
					metaflac --set-tag=COMPRESSION=8 "$i"
					print_ok_flac
				fi
			# If already at level 8 compression, test the FLAC file instead
			else
				print_level_8
				print_testing_flac
				ERROR="$((flac -ts "$i") 2>&1)"
				if [[ ! -z "$ERROR" ]] ; then
					print_failed_flac
					echo -e "[[$i]]\n"  "$ERROR\n" >> "$VERIFY_ERRORS"
				else 
					print_ok_flac
				fi
			fi
		done
	}
	export -f compress_f

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'compress_f "$@"' --
	
	if [[ -f "$VERIFY_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check"
		echo -e " ${BOLD_RED}*${NORMAL} \"$VERIFY_ERRORS\" for errors"
		exit 0
	fi
}

# Test FLAC files
function test_flacs {
	title_testing_flac

	FIND_FLACS="$(find "$DIRECTORY" -name "*.flac" -print)"
	if [[ -z "$FIND_FLACS" ]] ; then
		no_flacs
		exit 0
	fi

	# Abort script and check for any errors thus far
	function test_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
		if [[ -f "$TEST_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check"
			echo -e " ${BOLD_RED}*${NORMAL} \"$TEST_ERRORS\" for errors"
		fi
		exit $?
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap test_abort SIGINT

	function test_f {
		for i ; do
			print_testing_flac
			ERROR="$((flac -ts "$i") 2>&1)"
			if [[ ! -z "$ERROR" ]] ; then
				print_failed_flac
				echo -e "[[$i]]\n"  "$ERROR\n" >> "$TEST_ERRORS"
			else
				print_ok_flac
			fi
		done
	}
	export -f test_f

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'test_f "$@"' --

	if [[ -f "$TEST_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check"
		echo -e " ${BOLD_RED}*${NORMAL} \"$TEST_ERRORS\" for errors"
		exit 0
	fi
}

# Use auCDtect to check FLAC validity
function aucdtect {
	title_aucdtect_flac

	FIND_FLACS="$(find "$DIRECTORY" -name "*.flac" -print)"
	if [[ -z "$FIND_FLACS" ]] ; then
		no_flacs
		exit 0
	fi

	# Abort script and check for any errors thus far
	function aucdtect_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
		# Don't remove WAV files in case user has WAV files there purposefully
		# The script cannot determine between existing and script-created WAV files
		WAV_FILES="$(find "$DIRECTORY" -name *.wav -print)"
		if [[ -f "$AUCDTECT_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files may be lossy sourced, please check"
			echo -e " ${BOLD_RED}*${NORMAL} \"$AUCDTECT_ERRORS\" for errors"
		fi
		if [[ -n "$WAV_FILES" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} There are some temporary WAV files leftover that"
			echo -e " ${BOLD_RED}*${NORMAL} couldn't be deleted because of script interruption"
			echo
			echo -e " ${YELLOW}*${NORMAL} This script cannot determine between existing WAV files"
			echo -e " ${YELLOW}*${NORMAL} and script-created files by design.  Please delete the"
			echo -e " ${YELLOW}*${NORMAL} below files manually:"
			# Find all WAV files in chosen directory to display for manual deletion
			find "$DIRECTORY" -name *.wav -print | while read i ; do
				echo -e " ${YELLOW}*${NORMAL}     $i"
			done
		fi
		exit $?
	}
	
	# Trap SIGINT (Control-C) to abort cleanly
	trap aucdtect_abort SIGINT

	function aucdtect_f {
		for i ; do
			print_aucdtect_flac
			# Decompress FLAC to WAV so auCDtect can read the audio file
			flac --totally-silent -d "$i"
			# The actual auCDtect command with highest accuracy setting
			AUCDTECT_CHECK="$("$AUCDTECT_COMMAND" -m0 "${i%.flac}.wav")"
			ERROR="$(echo "$AUCDTECT_CHECK" | tail -n1)"
			if [[ "$ERROR" != "This track looks like CDDA with probability 100%" ]] ; then
				print_aucdtect_issue
				echo -e "[[$i]]\n"  "$ERROR\n" >> "$AUCDTECT_ERRORS"
			else
				print_ok_flac
			fi
			# Remove temporary WAV file
			rm "${i%.flac}.wav"
		done
	}
	export -f aucdtect_f

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'aucdtect_f "$@"' --

	if [[ -f "$AUCDTECT_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files may be lossy sourced, please check"
		echo -e " ${BOLD_RED}*${NORMAL} \"$AUCDTECT_ERRORS\" for issues"
		exit 0
	fi
}

# Check for unset MD5 Signatures in FLAC files
function md5_check {
	title_md5check_flac

	FIND_FLACS="$(find "$DIRECTORY" -name "*.flac" -print)"
	if [[ -z "$FIND_FLACS" ]] ; then
		no_flacs
		exit 0
	fi

	# Abort script and check for any errors thus far
	function md5_check_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
		if [[ -f "$MD5_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} The MD5 Signature is unset for some FLAC files, please check"
			echo -e " ${BOLD_RED}*${NORMAL} \"$MD5_ERRORS\" for details"
		fi
		exit $?
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap md5_check_abort SIGINT

	function md5_c {
		for i ; do
			print_checking_md5
			MD5_SUM="$(metaflac --show-md5sum "$i")"
			if [[ "$MD5_SUM" == "00000000000000000000000000000000" ]] ; then
				print_failed_flac
				echo -e "[[$i]]\n"  "MD5 Signature: $MD5_SUM" >> "$MD5_ERRORS"
			else
				print_ok_flac
			fi
		done
	}
	export -f md5_c

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'md5_c "$@"' --
	
	if [[ -f "$MD5_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} The MD5 Signature is unset for some FLAC files, please check"
		echo -e " ${BOLD_RED}*${NORMAL} \"$MD5_ERRORS\" for details"
		exit 0
	fi  
}

# Extract wanted FLAC metadata
function extract_vorbis_tags {
	# Recreate the tags array so it can be used by the child process
	eval "tags=(${EXPORT_TAG[*]})"
	# Iterate through the tag array and test to see if each tag is set
	for j in "${tags[@]}" ; do
		# Set a temporary variable to be easily parsed by `eval`
		local TEMP_TAG="$(metaflac --show-tag="$j" "$i" | sed "s/${j}=//")"
		# Evaluate TEMP_TAG into the dynamic tag
		eval "${j}"_TAG='"${TEMP_TAG}"'
		# If tags are not found, log output
		if [[ -z "$(eval "echo "\$${j}_TAG"")" ]] ; then
			echo -e "${j} tag not found for $i" >> "$METADATA_ERRORS"
		fi
	done
}
export -f extract_vorbis_tags

# Set the FLAC metadata to each FLAC file
function set_vorbis_tags {
	# Iterate through the tag array and set a variable for each tag
	for j in "${tags[@]}" ; do
		# Set a temporary variable to be easily parsed by `eval`
		local TEMP_TAG="$(metaflac --show-tag="${j}" "$i" | sed "s/${j}=//")"
		# Evaluate TEMP_TAG into the dynamic tag
		eval "${j}"_SET='"${TEMP_TAG}"'
	done

	# Remove all the tags
	metaflac --remove-all "$i"

	# Iterate through the tag array and add the saved tags back
	for j in "${tags[@]}" ; do
		metaflac --set-tag="${j}"="$(eval "echo \$${j}_SET")" "$i"
	done
}
export -f set_vorbis_tags

# Check for missing tags and retag FLAC files if all files
# are not missing tags
function redo_tags {
	title_analyze_tags

	FIND_FLACS="$(find "$DIRECTORY" -name "*.flac" -print)"
	if [[ -z "$FIND_FLACS" ]] ; then
		no_flacs
		exit 0
	fi
	
	# Keep SIGINT from exiting the script (Can cause all tags
	# to be lost if done when tags are being removed!)
	trap '' SIGINT

	function analyze_tags {
		# Recreate the tags array so it can be used by the child process
		eval "tags=(${EXPORT_TAG[*]})"
		for i ; do
			print_analyzing_tags
			extract_vorbis_tags
			print_done_flac
		done
	}
	export -f analyze_tags

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'analyze_tags "$@"' --

	if [[ -f "$METADATA_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files have missing tags, please check"
		echo -e " ${BOLD_RED}*${NORMAL} \"$METADATA_ERRORS\" for details."
		echo -e " ${BOLD_RED}*${NORMAL} Not Re-Tagging files."
		exit 0
	fi

	title_setting_tags

	function set_tags {
		# Recreate the tags array so it can be used by the child process
		eval "tags=(${EXPORT_TAG[*]})"
		for i ; do
			print_setting_tags
			set_vorbis_tags
			print_ok_flac
		done
	}
	export -f set_tags
	
	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'set_tags "$@"' --
}

# Clear excess FLAC metadata from each FLAC file
function prune_flacs {
	title_prune_flac

	FIND_FLACS="$(find "$DIRECTORY" -name "*.flac" -print)"
	if [[ -z "$FIND_FLACS" ]] ; then
		no_flacs
		exit 0
	fi

	# Trap SIGINT (Control-C) to abort cleanly	
	trap normal_abort SIGINT

	function prune_f {
		for i ; do
			print_prune_flac
			metaflac --remove --block-type=SEEKTABLE "$i"
			metaflac --remove --dont-use-padding --block-type=PADDING "$i"
			print_ok_flac
		done
	}
	export -f prune_f
	
	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name *.flac -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'prune_f "$@"' --
}

# Display a lot of help
function long_help {
	cat << EOF
  Usage: $0 [OPTION] [OPTION]... [PATH_TO_FLAC(s)]
  Options:
    -c, --compress          Compress the FLAC files with level 8 compression AND verify the
                            resultant files.  This option will add a tag to all successfully
                            verified FLAC files: COMPRESSION=8.

                            If any FLAC files already have the "COMPRESSION=8" tag (a sure sign
                            the files are already compressed at level 8), the script will instead
                            test the FLAC files for any errors.  This is useful to check your
                            entire library to make sure all the FLAC files are compressed at the
                            the highest level.

                            If any files are found to be corrupt, this script will quit upon
                            finishing the compression of any other files and produce an error
                            log.

    -t, --test              Same as compress but instead of compressing the FLAC files, this
                            script just verfies the files.  This option will NOT add the
                            compression tag to the files.

                            As with the "--compress" option, this will produce an error log if
                            any FLAC files are found to be corrupt.

    -a, --aucdtect          Uses the auCDtect program by Oleg Berngardt and Alexander Djourik to
                            analyze FLAC files and check with fairly accurate precision whether
                            the FLAC files are lossy sourced or not.  For example, an MP3 file
                            converted to FLAC is no longer lossless therefore lossy sourced.

                            While this program isn't foolproof, it gives a good idea which FLAC
                            files will need further investigation (ie a spectrograph).  This program
                            does not work on FLAC files which have a sample rate and bit depth more
                            than a typical audio CD (16bit / 44.1kHz), and will skip files that have
                            a higher bit depth and sample rate.

                            If any files are found to not be perfect (100% CDDA), a log will be created
                            with the questionable FLAC files recorded in it.

    -m, --md5check          Check the FLAC files for unset MD5 Signatures and log the output of
                            any unset signatures.  An unset MD5 signature doesn't necessarily mean
                            a FLAC file is corrupt, and can be repaired with a re-encoding of the
                            said FLAC file.

    -p, --prune             Delete the SEEKTABLE from each FLAC file and follow up with the removal
                            of any excess PADDING in each FLAC file.

    -r, --redo              Extract the configured tags in each FLAC file and clear the rest before 
                            retagging the file.  The default tags kept are:

                                        TITLE
                                        ARTIST
                                        ALBUM
                                        DISCNUMBER
                                        DATE
                                        TRACKNUMBER
                                        TRACKTOTAL
                                        GENRE
                                        COMPRESSION

                            If any FLAC files have missing tags (from those configured to be kept),
                            the file and the missing tag will be recorded in a log.

                            The tags that can be kept are eseentially infinite, as long as the
                            tags to be kept are set in the tag configuration located at the top of
                            this script.

                            If this option is specified, a warning will appear upon script
                            execution.  This warning will show which of the configured TAG fields
                            to keep when re-tagging the FLAC files.  A countdown will appear
                            giving the user 10 seconds to abort the script, after which, the script
                            will begin running it's course.

                            If the (-d, --disable-warning) option is used, this warning will not
                            appear.  This is useful for veteran users.

    -n, --no-color          Turn off color output

    -d, --disable-warning   Disable the FLAC metadata warning about the TAG fields to be displayed
                            before beginning the script.  This will also disable the countdown
                            timer that prefaces the script.

    -v, --version           Display script version and exit.

    -h, --help              Shows this help message.

    Pseudo Multithreading is now available throughout this script.  By default, this script will
    use two (2) threads, which can be configured under USER CONFIGURATION (located near the top
    of this script).

    Multithreading is achieved by utilizing the "xargs" command which comes bundled with the
    "find" command.  While not true multithreading, this psuedo multithreading will greatly speed
    up the processing if the host has more than one CPU.

  Examples:
    # Compress to level 8 compression and verify FLAC files
    $0 --compress /media/Music_Files

    # Same as above but check MD5 Signature of all FLAC files if all files are verified as OK
    # from previous command
    $0 -c -m Music/FLACS    <--- **RELATIVE PATHS ALLOWED**

    # Same as above but remove the SEEKTABLE and excess PADDING in all of the FLAC files if all
    # files are verified as OK from previous command
    $0 -c -m -p /some/path/to/files

    # Same as above but with long argument notation
    $0 --compress --md5check --prune /some/path/to/files

    # Same as above but with mixed argument notation
    $0 --compress -m -p /some/path/to/files

    # Clear excess tags from each FLAC file
    $0 --redo /some/path/to/files

    # Compress FLAC files to level 8 compression and redo
    # the FLAC tags without the warning/countdown
    $0 -c -r -d /some/path/to/files
EOF
}

# Display short help
function short_help {
	echo "  Usage: $0 [OPTION] [OPTION]... [PATH_TO_FLAC(s)]"
	echo "  Options:"
	echo "    -c, --compress"
	echo "    -t, --test"
	echo "    -m, --md5check"
	echo "    -a, --aucdtect"
	echo "    -p, --prune"
	echo "    -r, --redo"
	echo "    -n, --no-color"
	echo "    -d, --disable-warning"
	echo "    -v, --version"
	echo "    -h, --help"
	echo "  This is the short help; for details use '$0 --help' or '$0 -h'"
}

# Display script version
function print_version {
	echo "Version $VERSION"
}

###############
# Begin Script
###############

# Add case where only one argument is specified
if [[ "$#" -eq 1 ]] ; then
	case "$1" in
		--version|-v)
			print_version
			exit 0
			;;
		--help|-h)
			long_help
			exit 0
			;;
		*)
			short_help
			exit 0
			;;
	esac
fi

# Handle various command switches
while [[ "$#" -gt 1 ]] ; do
	case "$1" in
		--compress|-c)
			COMPRESS="true"
			shift
			;;
		--test|-t)
			TEST="true"
			shift
			;;
		--aucdtect|-a)
			AUCDTECT="true"
			shift
			;;
		--md5check|-m)
			MD5CHECK="true"
			shift
			;;
		--prune|-p)
			PRUNE="true"
			shift
			;;
		--redo|-r)
			REDO="true"
			shift
			;;
		--no-color|-n)
			NO_COLOR="true"
			shift
			;;
		--disable-warning|-d)
			DISABLE_WARNING="true"
			shift
			;;
		*)
			short_help
			exit 0
			;;
	esac
done

# Set the last argument as the directory
DIRECTORY="$1"

# Check whether DIRECTORY is not null and whether the directory exists
if [[ ! -z "$DIRECTORY" && ! -d "$DIRECTORY" ]] ; then
	echo -e "  Usage: $0 [OPTION] [PATH_TO_FLAC(s)]...\n"
	echo -e " ${BOLD_RED}*${NORMAL} Please specify a directory!"
	exit 0
fi

# If no arguments are made to the script show usage
if [[ "$#" -eq 0 ]] ; then
	short_help
	exit 0
fi

# Make sure compress and test aren't both specified
if [[ "$COMPRESS" == "true" && "$TEST" == "true" ]] ; then
	echo -e " ${BOLD_RED}*${NORMAL} Running both \"--compress\" and \"--test\" is redundant as \"--compress\""
	echo -e " ${BOLD_RED}*${NORMAL} already tests the FLAC files while compressing them.  Please"
	echo -e " ${BOLD_RED}*${NORMAL} choose one or the other."
	exit 0
fi

# Execute the various options within the script if the arguments
# were specified at the start

# This must come before the other options in
# order for it to take effect
if [[ "$NO_COLOR" == "true" ]] ; then
	BOLD_GREEN=""
	BOLD_RED=""
	NORMAL=""
	YELLOW=""
fi

# The below order is probably the best bet in ensuring time
# isn't wasted on doing unnecessary operations if the
# FLAC files are corrupt or have metadata issues
if [[ "$REDO" == "true" && "$DISABLE_WARNING" != "true" ]] ; then
	countdown_metadata
fi

if [[ "$COMPRESS" == "true" ]] ; then
	compress_flacs
fi

if [[ "$TEST" == "true" ]] ; then
	test_flacs
fi

if [[ "$MD5CHECK" == "true" ]] ; then
	md5_check
fi

if [[ "$AUCDTECT" == "true" ]] ; then
	# Check if auCDtect is found/installed
	if [[ -f "$AUCDTECT_COMMAND" ]] ; then
		aucdtect
	else
		echo -e " ${BOLD_RED}*${NORMAL} It appears auCDtect is not installed or you have not"
		echo -e " ${BOLD_RED}*${NORMAL} configured this script to find it. Please verify you"
		echo -e " ${BOLD_RED}*${NORMAL} have this program installed."
		exit 1
	fi
fi

if [[ "$REDO" == "true" ]] ; then
	redo_tags
fi

if [[ "$PRUNE" == "true" ]] ; then
	prune_flacs
fi
