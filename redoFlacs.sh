#!/bin/bash

#------------------------------------------------------------
# Re-compress, Verify, Test, Re-tag, and Clean Up FLAC Files
#                     Version 0.14.1
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
# You can follow development of this script on Github at:
# https://github.com/sirjaren/redoflacs
#
# Please submit requests/changes/patches and/or comments
#-----------------------------------------------------------------

tags=(
########################
#  USER CONFIGURATION  #
########################
# List the tags to be kept in each FLAC file
# The tags are case sensitive!
# The default is listed below.
# Be sure not to delete the parenthesis ")" below
# or put wanted tags below it! Another common tag
# not added by default is ALBUMARTIST.  Uncomment
# ALBUMARTIST below to allow script to keep this
# tag.

TITLE
ARTIST
#ALBUMARTIST
ALBUM
DISCNUMBER
DATE
TRACKNUMBER
TRACKTOTAL
GENRE

# The COMPRESSION tag is a custom tag to allow
# the script to determine which level of compression
# the FLAC file(s) has/have been compressed at.
COMPRESSION

# The RELEASETYPE tag is a custom tag the author
# of this script uses to catalogue what kind of
# release the album is (ie, Full Length, EP,
# Demo, etc.).
RELEASETYPE

# The SOURCE tag is a custom tag the author of
# this script uses to catalogue which source the
# album has derived from (ie, CD, Vinyl,
# Digital, etc.).
SOURCE

# The MASTERING tag is a custom tag the author of
# this script uses to catalogue how the album has
# been mastered (ie, Lossless, or Lossy).
MASTERING

# The REPLAYGAIN tags below, are added by the
# --replaygain, -g argument.  If you want to
# keep the replaygain tags, make sure you leave
# these here.
REPLAYGAIN_REFERENCE_LOUDNESS
REPLAYGAIN_TRACK_GAIN
REPLAYGAIN_TRACK_PEAK
REPLAYGAIN_ALBUM_GAIN
REPLAYGAIN_ALBUM_PEAK

)

# Set whether to remove embedded artwork within FLAC
# files.  By default, this script will remove any
# artwork it can find, whether it's in the legacy
# COVERART tag or METADATA_BLOCK_PICTURE.  Legal
# values are:
#    "true"  (Remove Artwork)
#    "false" (Keep Artwork)
REMOVE_ARTWORK="true"

# Set the type of COMPRESSION to compress the
# FLAC files.  Numbers range from 1-8, with 1 being
# the lowest compression and 8 being the highest
# compression.  The default is 8.
COMPRESSION_LEVEL=8

# Set the number of threads/cores to use
# when running this script.  The default
# number of threads/cores used is 2
CORES=2

# Set the where you want the error logs to
# be placed. By default, they are placed in
# the user's HOME directory.
ERROR_LOG="$HOME"

# Set where the auCDtect command is located.
# By default, the script will look in $PATH
# An example of changing where to find auCDtect
# is below:
# AUCDTECT_COMMAND="/${HOME}/auCDtect"
AUCDTECT_COMMAND="$(command -v auCDtect)"

# Set where the created spectrogram files should
# be placed. By default, the spectrogram PNG files
# will be placed in the same directory as the tested
# FLAC files. Each PNG will have the same name as
# the tested FLAC file but with the extension ".png"
#
# The special value, "default" does the default
# action.  Other values are interpreted as a
# directory. An example of a user-defined location:
# SPECTROGRAM_LOCATION="${HOME}/Spectrogram_Images"
#
# See "--help" or "-h" for more information.
SPECTROGRAM_LOCATION="default"
##########################
#  END OF CONFIGURATION  #
##########################

######################
#  STATIC VARIABLES  #
######################
# Version
VERSION="0.14.1"

# Export REMOVE_ARTWORK to allow subshell access
export REMOVE_ARTWORK

# Export COMPRESSION_LEVEL to allow subshell access
export COMPRESSION_LEVEL

# Export auCDtect command to allow subshell access
export AUCDTECT_COMMAND

# Export SPECTROGRAM_LOCATION to allow subshell access
export SPECTROGRAM_LOCATION

# Export the tag array using some trickery (BASH doesn't
# support exporting arrays natively)
export EXPORT_TAG="$(echo -n "${tags[@]}")"

# Colors on by default
# Export to allow subshell access
export BOLD_GREEN="\033[1;32m"
export BOLD_RED="\033[1;31m"
export BOLD_BLUE="\033[1;34m"
export CYAN="\033[0;36m"
export NORMAL="\033[0m"
export YELLOW="\033[0;33m"

# Log files with timestamp
# Export to allow subshell access
export VERIFY_ERRORS="$ERROR_LOG/FLAC_Verify_Errors $(date "+[%Y-%m-%d %R]")"
export TEST_ERRORS="$ERROR_LOG/FLAC_Test_Errors $(date "+[%Y-%m-%d %R]")"
export MD5_ERRORS="$ERROR_LOG/MD5_Signature_Errors $(date "+[%Y-%m-%d %R]")"
export METADATA_ERRORS="$ERROR_LOG/FLAC_Metadata_Errors $(date "+[%Y-%m-%d %R]")"
export REPLAY_TEST_ERRORS="$ERROR_LOG/ReplayGain_Test_Errors $(date "+[%Y-%m-%d %R]")"
export REPLAY_ADD_ERRORS="$ERROR_LOG/ReplayGain_Add_Errors $(date "+[%Y-%m-%d %R]")"
export AUCDTECT_ERRORS="$ERROR_LOG/auCDtect_Errors $(date "+[%Y-%m-%d %R]")"
export PRUNE_ERRORS="$ERROR_LOG/FLAC_Prune_Errors $(date "+[%Y-%m-%d %R]")"

# Set arguments to false
# If enabled they will be changed to true
COMPRESS="false"
TEST="false"
AUCDTECT="false"
MD5CHECK="false"
PRUNE="false"
REDO="false"

###################################
#  INFORMATION PRINTED TO STDOUT  # 
###################################
# Displaying currently running tasks
function title_compress_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Compressing FLAC files with level ${COMPRESSION_LEVEL} compression and verifying output :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

function title_test_replaygain {
	echo -e " ${BOLD_GREEN}*${NORMAL} Verifying FLAC Files can have ReplayGain Tags added :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

# This is NOT multithreaded (1 thread only)
# This is intentional and intended
function title_add_replaygain {
	echo -e " ${BOLD_GREEN}*${NORMAL} Applying ReplayGain values by album directory :: ${BOLD_BLUE}[1 Thread(s)]${NORMAL}"
}

function title_analyze_tags {
	echo -e " ${BOLD_GREEN}*${NORMAL} Analyzing FLAC Tags :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

function title_setting_tags {
	echo -e " ${BOLD_GREEN}*${NORMAL} Setting new FLAC Tags :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

function title_testing_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Testing the integrity of each FLAC file :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

function title_aucdtect_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Validating FLAC is not lossy sourced :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

function title_md5check_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Verifying the MD5 Signature in each FLAC file :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

function title_prune_flac {
	echo -e " ${BOLD_GREEN}*${NORMAL} Removing the SEEKTABLE and PADDING block from each FLAC file :: ${BOLD_BLUE}[${CORES} Thread(s)]${NORMAL}"
}

# Error messages
# Don't display threads as script will quit after diplaying
function no_flacs {
	echo -e " ${BOLD_RED}*${NORMAL} There are not any FLAC files to process!"
}

# Information relating to currently running tasks
function print_compressing_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Compressing FLAC" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Compressing FLAC ] (20) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 30))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 20))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Compressing FLAC" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_test_replaygain {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Testing ReplayGain" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Testing ReplayGain ] (22) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 32))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 22))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Testing ReplayGain" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_add_replaygain {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s${CYAN}%s${NORMAL}" \
		"" "[" " " "Adding ReplayGain" " " "]" "     " "*" " $(basename "$FLAC_LOCATION" | awk '{print substr($0,0,65)}') " "[Directory]"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Adding ReplayGain ] (21) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 31))"

		FILENAME_LENGTH="$(basename "$FLAC_LOCATION" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$FLAC_LOCATION" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$FLAC_LOCATION")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 21))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s${CYAN}%s${NORMAL}" \
		"" "[" " " "Adding ReplayGain" " " "]" "     " "*" " ${FILENAME} " "[Directory]"
	fi
}

function print_testing_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Testing FLAC" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Testing FLAC ] (16) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 26))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi
		
		printf "\r${NORMAL}%$((${COLUMNS} - 16))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Testing FLAC" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_failed_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${BOLD_RED}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "FAILED" " " "]" "          " "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ FAILED ] (10) minus 2 (leaves a gap and the gives room for the ellipsis (…))
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 19))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 10))s${BOLD_BLUE}%s${NORMAL}%s${BOLD_RED}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "FAILED" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_failed_replaygain {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${BOLD_RED}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s${CYAN}%s${NORMAL}\n" \
		"" "[" " " "FAILED" " " "]" "          " "*" " $(basename "$FLAC_LOCATION" | awk '{print substr($0,0,65)}') " "[Directory]"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ FAILED ] (10) minus 2 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 19))"

		FILENAME_LENGTH="$(basename "$FLAC_LOCATION" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$FLAC_LOCATION" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$FLAC_LOCATION")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 10))s${BOLD_BLUE}%s${NORMAL}%s${BOLD_RED}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s${CYAN}%s${NORMAL}\n" \
		"" "[" " " "FAILED" " " "]" "     " "*" " ${FILENAME} " "[Directory]"
	fi
}

function print_checking_md5 {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Checking MD5" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Checking MD5 ] (16) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 26))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 16))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Checking MD5" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_ok_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${BOLD_GREEN}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "OK" " " "]" "              " "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ OK ] (6) minus 2 (leaves a gap and the gives room for the ellipsis (…))
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 15))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 6))s${BOLD_BLUE}%s${NORMAL}%s${BOLD_GREEN}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "OK" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_ok_replaygain {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${BOLD_GREEN}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s${CYAN}%s${NORMAL}\n" \
		"" "[" " " "OK" " " "]" "              " "*" " $(basename "$FLAC_LOCATION" | awk '{print substr($0,0,65)}') " "[Directory]"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ OK ] (6) minus 2 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 15))"

		FILENAME_LENGTH="$(basename "$FLAC_LOCATION" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$FLAC_LOCATION" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$FLAC_LOCATION")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 6))s${BOLD_BLUE}%s${NORMAL}%s${BOLD_GREEN}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s${CYAN}%s${NORMAL}\n" \
		"" "[" " " "OK" " " "]" "     " "*" " ${FILENAME} " "[Directory]"
	fi
}

function print_aucdtect_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Validating FLAC" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Validating FLAC ] (19) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 29))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 19))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Validating FLAC" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_aucdtect_issue {
	if [[ "$FALLBACK" == "true" ]] ; then
		# If CREATE_SPECTROGRAM is true, add spacing after [ ISSUE ]
		# so the last 4 characters are hidden from [ Creating Spectrogram ]
		if [[ "$CREATE_SPECTROGRAM" == "true" ]] ; then
			# Add spacing (4 characters)
			printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
			"" "[" " " "ISSUE" " " "]" "               " "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
		else
			# Don't add spacing
			printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
			"" "[" " " "ISSUE" " " "]" "           " "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
		fi
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ ISSUE ] (9) minus 2 (leaves a gap and the gives room for the ellipsis (…))
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 18))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 9))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "ISSUE" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_aucdtect_spectrogram {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Creating Spectrogram" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Creating Spectrogram ] (24) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 34))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 24))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Creating Spectrogram" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_aucdtect_skip {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "SKIPPED" " " "]" "         " "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ SKIPPED ] (11) minus 2 (leaves a gap and the gives room for the ellipsis (…))
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 20))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 11))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "SKIPPED" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_done_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${BOLD_GREEN}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}%s\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "DONE" " " "]" "            " "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ DONE ] (8) minus 2 (leaves a gap and the gives room for the ellipsis (…))
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 17))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 8))s${BOLD_BLUE}%s${NORMAL}%s${BOLD_GREEN}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "DONE" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_level_same_compression {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "Already At Level ${COMPRESSION_LEVEL}" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Already At Level 8 ] (22) minus 2 (leaves a gap and the gives room for
		#the ellipsis (…))
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 31))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 22))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${YELLOW}%s${NORMAL}%s\n" \
		"" "[" " " "Already At Level ${COMPRESSION_LEVEL}" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_analyzing_tags {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Analyzing Tags" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Analyzing Tags ] (18) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 28))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 18))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Analyzing Tags" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_setting_tags {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Setting Tags" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [ Setting Tags ] (16) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 26))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 16))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Setting Tags" " " "]" "     " "*" " ${FILENAME}"
	fi
}

function print_prune_flac {
	if [[ "$FALLBACK" == "true" ]] ; then
		printf "\r${NORMAL}%74s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Pruning Metadata" " " "]" "     " "*" " $(basename "$i" | awk '{print substr($0,0,65)}')"
	else
		COLUMNS="$(tput cols)"

		# This is the number of $COLUMNS minus the indent (7) minus length of the printed
		# message, [Pruning Metadata] (20) minus 3 (leaves a gap and the gives room for the
		# ellipsis (…) and cursor)
		MAX_FILENAME_LENGTH="$((${COLUMNS} - 30))"

		FILENAME_LENGTH="$(basename "$i" | wc -m)"

		if [[ "$FILENAME_LENGTH" -gt "$MAX_FILENAME_LENGTH" ]] ; then
			FILENAME="$(echo "$(basename "$i" | awk '{print substr($0,0,"'"$MAX_FILENAME_LENGTH"'")}')…" )"
		else
			FILENAME="$(basename "$i")"
		fi

		printf "\r${NORMAL}%$((${COLUMNS} - 20))s${BOLD_BLUE}%s${NORMAL}%s${YELLOW}%s${NORMAL}%s${BOLD_BLUE}%s${NORMAL}\r%s${NORMAL}${YELLOW}%s${NORMAL}%s" \
		"" "[" " " "Pruning Metadata" " " "]" "     " "*" " ${FILENAME}"
	fi
}

# Export all the above functions for subshell access
export -f print_compressing_flac
export -f print_test_replaygain
export -f print_add_replaygain
export -f print_testing_flac
export -f print_failed_flac
export -f print_checking_md5
export -f print_ok_flac
export -f print_ok_replaygain
export -f print_aucdtect_flac
export -f print_aucdtect_issue
export -f print_aucdtect_spectrogram
export -f print_aucdtect_skip
export -f print_done_flac
export -f print_level_same_compression
export -f print_analyzing_tags 
export -f print_setting_tags
export -f print_prune_flac

######################################
#  FUNCTIONS TO DO VARIOUS COMMANDS  #
######################################
# General abort script to use BASH's trap command on SIGINT
function normal_abort {
	echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
	exit 1
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
		# Below is the last second of the countdown
		# Put here for UI refinement (No extra spacing after last second)
		echo -en "${BOLD_RED}1${NORMAL}"
		sleep 1
		echo -e "\n"
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap normal_abort SIGINT

	echo -e " ${YELLOW}*${NORMAL} CAUTION! These are the tag fields that will be kept"
	echo -e " ${YELLOW}*${NORMAL} when re-tagging the selected files:\n"
	tags_countdown
	echo -e "\n ${BOLD_RED}*${NORMAL} By default, this script will REMOVE embedded coverart"
	echo -e " ${BOLD_RED}*${NORMAL} when re-tagging the files (that have the legacy COVERART"
	echo -e " ${BOLD_RED}*${NORMAL} tag).  Change the REMOVE_ARTWORK option under USER"
	echo -e " ${BOLD_RED}*${NORMAL} CONFIGURATION to \"false\" to keep embedded artwork.\n"
	echo -e " ${YELLOW}*${NORMAL} Waiting 10 seconds before starting script..."
	echo -e " ${YELLOW}*${NORMAL} Ctrl+C (Control-C) to abort..."
	echo -en " ${BOLD_GREEN}*${NORMAL} Starting in: "
	countdown_10
}

################
#  REPLAYGAIN  #
################
# Add ReplayGain to files and make sure each album disc uses the same
# ReplayGain values (multi-disc albums have their own ReplayGain) as well
# as make the tracks have their own ReplayGain values individually.
function replaygain {
	title_test_replaygain

	# Trap SIGINT (Control-C) to abort cleanly
	trap normal_abort SIGINT

	function test_replaygain {
		for i ; do
			print_test_replaygain

			# Variable to check if file is a FLAC file
			CHECK_FLAC="$(metaflac --show-md5sum "$i" 2>&1 | grep -o "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE")"

			# Test to make sure FLAC file can have ReplayGain tags added to it
			if [[ "$CHECK_FLAC" == "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE" ]] ; then
				echo -e "File:  $i" >> "$REPLAY_TEST_ERRORS"
				echo -e "Error: The above file does not appear to be a FLAC file" >> "$REPLAY_TEST_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$REPLAY_TEST_ERRORS"
				# File is not a FLAC file, display failed
				print_failed_flac
			else
				# File is a FLAC file, erase any ReplayGain tags, display ok
				metaflac --remove-replay-gain "$i"
				print_ok_flac
			fi
		done
	}
	export -f test_replaygain

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'test_replaygain "$@"' --

	if [[ -f "$REPLAY_TEST_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} There were issues with some of the FLAC files,"
		echo -e " ${BOLD_RED}*${NORMAL} please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$REPLAY_TEST_ERRORS\" for details."
		exit 1
	fi

	# The below stuff cannot be done in parallel to prevent race conditions
	# from making the script think some FLAC files have already had
	# ReplayGain tags added to them.  Due to the nature of processing the
	# album tags as a whole, this MUST be done without multithreading.

	title_add_replaygain

	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print | while read i ; do
		# Find where the FLAC file is in the DIRECTORY hierarchy
		FLAC_LOCATION="$(dirname "${i}")"

		# Test if DIRECTORY is the current working directory (AKA: ./)
		# as well as check if FLAC_LOCATION is equal to "./"
		if [[ "$DIRECTORY" == "." && "$FLAC_LOCATION" = "." ]] ; then
			# We want to be able to display a directory path, so we create
			# the pathname to the FLAC files
			FLAC_LOCATION="$PWD"
		fi

		# Find the basename directory from FLAC_LOCATION (this is the supposed
		# album name to be printed)
		ALBUM_BASENAME="$(basename "$FLAC_LOCATION")"

		# Check if FLAC files have existing ReplayGain tags
		REPLAYGAIN_REFERENCE_LOUDNESS="$(metaflac --show-tag=REPLAYGAIN_REFERENCE_LOUDNESS "$i" \
			| sed 's/REPLAYGAIN_REFERENCE_LOUDNESS=//i')"
		REPLAYGAIN_TRACK_GAIN="$(metaflac --show-tag=REPLAYGAIN_TRACK_GAIN "$i" \
			| sed 's/REPLAYGAIN_TRACK_GAIN=//i')"
		REPLAYGAIN_TRACK_PEAK="$(metaflac --show-tag=REPLAYGAIN_TRACK_PEAK "$i" \
			| sed 's/REPLAYGAIN_TRACK_PEAK=//i')"
		REPLAYGAIN_ALBUM_GAIN="$(metaflac --show-tag=REPLAYGAIN_ALBUM_GAIN "$i" \
			| sed 's/REPLAYGAIN_ALBUM_GAIN=//i')"
		REPLAYGAIN_ALBUM_PEAK="$(metaflac --show-tag=REPLAYGAIN_ALBUM_PEAK "$i" \
			| sed 's/REPLAYGAIN_ALBUM_PEAK=//i')"

		if [[ -n "$REPLAYGAIN_REFERENCE_LOUDNESS" && -n "$REPLAYGAIN_TRACK_GAIN" && \
			  -n "$REPLAYGAIN_TRACK_PEAK" && -n "$REPLAYGAIN_ALBUM_GAIN" && \
			  -n "$REPLAYGAIN_ALBUM_PEAK" ]] ; then
			# All ReplayGain tags accounted for, skip this file
			continue
		elif [[ "$REPLAYGAIN_ALBUM_FAILED" == "${ALBUM_BASENAME} FAILED" ]] ; then
			# This album (directory of FLACS) had at LEAST one FLAC fail, so skip
			# files that are in this album (directory)
			continue
		else
			# Add ReplayGain tags to the files in this directory (which SHOULD include
			# the current working FLAC file [$i])
			print_add_replaygain
			ERROR="$((metaflac --add-replay-gain "${FLAC_LOCATION}"/*.[Ff][Ll][Aa][Cc]) 2>&1)"
			if [[ -n "$ERROR" ]] ; then
				print_failed_replaygain
				echo -e "Directory: $FLAC_LOCATION" >> "$REPLAY_ADD_ERRORS"
				echo -e "Error:     $ERROR" >> "$REPLAY_ADD_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$REPLAY_ADD_ERRORS"
				# Set variable to let script know this album failed and not NOT
				# continue checking the files in this album
				REPLAYGAIN_ALBUM_FAILED="${ALBUM_BASENAME} FAILED"
			else
				print_ok_replaygain
			fi
		fi
	done

	if [[ -f "$REPLAY_ADD_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} There were issues with some of the FLAC files,"
		echo -e " ${BOLD_RED}*${NORMAL} please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$REPLAY_TEST_ERRORS\" for details."
		exit 1
	fi
}

#############################
#  COMPRESS & VERIFY FLACS  #
#############################
# Compress FLAC files and verify output
function compress_flacs {
	title_compress_flac

	# Abort script and remove temporarily encoded FLAC files (if any)
	# and check for any errors thus far
	function compress_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, removing temporary files and exiting script..."
		find "$DIRECTORY" -name "*.tmp,fl-ac+en\'c" -exec rm "{}" \;
		if [[ -f "$VERIFY_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check:"
			echo -e " ${BOLD_RED}*${NORMAL} \"$VERIFY_ERRORS\" for errors"
		fi
		exit 1
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap compress_abort SIGINT

	function compress_f {
		for i ; do
			# Trap errors into a variable as the output doesn't help
			# for there is a better way to test below using the
			# ERROR variable
			COMPRESSION="$((metaflac --show-tag=COMPRESSION "$i" | sed 's/^COMPRESSION=//i') 2>&1)"
			if [[ "$COMPRESSION" != "$COMPRESSION_LEVEL" ]] ; then
				print_compressing_flac
				# This must come after the above command for proper formatting
				ERROR="$((flac -f -${COMPRESSION_LEVEL} -V -s "$i") 2>&1)"
				if [[ ! -z "$ERROR" ]] ; then
					print_failed_flac
					echo -e "File:  $i" >> "$VERIFY_ERRORS"
					echo -e "Error: $ERROR" >> "$VERIFY_ERRORS"
					echo -e "------------------------------------------------------------------" >> "$VERIFY_ERRORS"
				else
					metaflac --remove-tag=COMPRESSION "$i"
					metaflac --set-tag=COMPRESSION=${COMPRESSION_LEVEL} "$i"
					print_ok_flac
				fi
			# If already at COMPRESSION_LEVEL, test the FLAC file instead
			# or skip the file if --compress-notest,-C was specified
			else
				print_level_same_compression
				if [[ "$SKIP_TEST" != "true" ]] ; then
					print_testing_flac
					ERROR="$((flac -ts "$i") 2>&1)"
					if [[ ! -z "$ERROR" ]] ; then
						print_failed_flac
						echo -e "File:  $i" >> "$VERIFY_ERRORS"
						echo -e "Error: $ERROR" >> "$VERIFY_ERRORS"
						echo -e "------------------------------------------------------------------" >> "$VERIFY_ERRORS"
					else 
						print_ok_flac
					fi
				fi
			fi
		done
	}
	export -f compress_f

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'compress_f "$@"' --
	
	if [[ -f "$VERIFY_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$VERIFY_ERRORS\" for errors"
		exit 1
	fi
}

################
#  TEST FLACS  #
################
# Test FLAC files
function test_flacs {
	title_testing_flac

	# Abort script and check for any errors thus far
	function test_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
		if [[ -f "$TEST_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check:"
			echo -e " ${BOLD_RED}*${NORMAL} \"$TEST_ERRORS\" for errors"
			exit 1
		fi
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap test_abort SIGINT

	function test_f {
		for i ; do
			print_testing_flac
			ERROR="$((flac -ts "$i") 2>&1)"
			if [[ ! -z "$ERROR" ]] ; then
				print_failed_flac
				echo -e "File:  $i" >> "$TEST_ERRORS"
				echo -e "Error: $ERROR" >> "$TEST_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$TEST_ERRORS"
			else
				print_ok_flac
			fi
		done
	}
	export -f test_f

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'test_f "$@"' --

	if [[ -f "$TEST_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Errors found in some FLAC files, please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$TEST_ERRORS\" for errors"
		exit 1
	fi
}

#######################################
#  CHECK FLAC VALIDITY WITH AUCDTECT  #
#######################################
# Use auCDtect to check FLAC validity
function aucdtect {
	# Check if SPECTROGRAM_LOCATION is user-defined
	if [[ "$SPECTROGRAM_LOCATION" != "default" ]] ; then
		# Put spectrograms in user-defined location
		# Test to make sure directory exists
		if [[ ! -d "$SPECTROGRAM_LOCATION" ]] ; then
			echo -e " ${BOLD_RED}*${NORMAL} \"$SPECTROGRAM_LOCATION\" doesn't exist!"
			echo -e " ${BOLD_RED}*${NORMAL} Please choose a valid directory under USER CONFIGURATION!"
			exit 1
		fi
	fi

	title_aucdtect_flac

	# Abort script and check for any errors thus far
	function aucdtect_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."

		# Don't remove WAV files in case user has WAV files there purposefully
		# The script cannot determine between existing and script-created WAV files
		WAV_FILES="$(find "$DIRECTORY" -name "*.[Ww][Aa][Vv]" -print)"

		if [[ -f "$AUCDTECT_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files may be lossy sourced, please check:"
			echo -e " ${BOLD_RED}*${NORMAL} \"$AUCDTECT_ERRORS\" for details"
		fi

		if [[ -n "$WAV_FILES" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} There are some temporary WAV files leftover that"
			echo -e " ${BOLD_RED}*${NORMAL} couldn't be deleted because of script interruption"
			echo
			echo -e " ${YELLOW}*${NORMAL} This script cannot determine between existing WAV files"
			echo -e " ${YELLOW}*${NORMAL} and script-created files by design.  Please delete the"
			echo -e " ${YELLOW}*${NORMAL} below files manually:"
			# Find all WAV files in chosen directory to display for manual deletion
			find "$DIRECTORY" -name "*.[Ww][Aa][Vv]" -print | while read i ; do
				echo -e " ${YELLOW}*${NORMAL}     $i"
			done
		fi

		exit 1
	}
	
	# Trap SIGINT (Control-C) to abort cleanly
	trap aucdtect_abort SIGINT

	function aucdtect_f {
		for i ; do
			print_aucdtect_flac

			# Check if file is a FLAC file
			CHECK_FLAC="$(metaflac --show-md5sum "$i" 2>&1 | grep -o "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE")"

			if [[ "$CHECK_FLAC" == "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE" ]] ; then
				echo -e "File:  $i" >> "$AUCDTECT_ERRORS"
				echo -e "Error: The above file does not appear to be a FLAC file" >> "$AUCDTECT_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$AUCDTECT_ERRORS"
				# File is not a FLAC file, display failed
				print_failed_flac
			else
				# Get the bit depth of a FLAC file
				BITS="$(metaflac --list --block-type=STREAMINFO "$i" | grep "bits-per-sample" | awk '{print $2}')"

				# Skip the FLAC file if it has a bit depth greater
				# than 16 since auCDtect doesn't support audio
				# files with a higher resolution than a CD.
				if [[ "$BITS" -gt "16" ]] ; then
					print_aucdtect_skip
					echo -e "File:  $i" >> "$AUCDTECT_ERRORS"
					echo -e "Error: The above file has a bit depth greater than 16 and was skipped" >> "$AUCDTECT_ERRORS"
					echo -e "------------------------------------------------------------------" >> "$AUCDTECT_ERRORS"
					continue
				fi

				# Decompress FLAC to WAV so auCDtect can read the audio file
				flac --totally-silent -d "$i"

				# The actual auCDtect command with highest accuracy setting
				# 2> hides the displayed progress to /dev/null so nothing is shown
				AUCDTECT_CHECK="$("$AUCDTECT_COMMAND" -m0 "${i%.[Ff][Ll][Aa][Cc]}.wav" 2> /dev/null)"

				# Reads the last line of the above command which tells what
				# auCDtect came up with for the WAV file
				ERROR="$(echo "$AUCDTECT_CHECK" | tail -n1)"

				# There is an issue with the processed FLAC file
				if [[ "$ERROR" != "This track looks like CDDA with probability 100%" ]] ; then
					# If user specified --aucdtect-spectrogram (-A), then
					# create a spectrogram with SoX and change logging accordingly
					if [[ "$CREATE_SPECTROGRAM" == "true" ]] ; then
						# Check whether to place spectrogram images in user-defined location
						if [[ "$SPECTROGRAM_LOCATION" == "default" ]] ; then
							# Place images in same directory as the FLAC files
							# Make sure we don't clobber any picture files
							if [[ -f "${i%.[Ff][Ll][Aa][Cc]}.png" ]] ; then
								# File exists so prepend "spectrogram" before ".png"
								SPECTROGRAM_PICTURE="$(echo "${i%.[Ff][Ll][Aa][Cc]}.spectrogram.png")"
							else
								# File doesn't exist, so create the spectrogram with the basename of "$i"
								# with ".png" as the extension
								SPECTROGRAM_PICTURE="$(echo "${i%.[Ff][Ll][Aa][Cc]}.png")"
							fi
						else
							# Place images in user-defined location
							SPECTROGRAM_PICTURE="${SPECTROGRAM_LOCATION}/$(basename "${i%.[Ff][Ll][Aa][Cc]}.png")"
						fi

						# Let's create the spectrogram for the failed FLAC file
						# and output progress
						print_aucdtect_spectrogram
						sox "$i" -n spectrogram -c '' -t "$i" -p1 -z90 -Z0 -q249 -wHann -x5000 -y1025 -o "${SPECTROGRAM_PICTURE}"

						# Print ISSUE and log error, and show where to find
						# the created spectrogram of processed FLAC file
						print_aucdtect_issue
						echo -e "File:        $i" >> "$AUCDTECT_ERRORS"
						echo -e "Error:       $ERROR" >> "$AUCDTECT_ERRORS"
						echo -e "Spectrogram: $SPECTROGRAM_PICTURE" >> "$AUCDTECT_ERRORS"
						echo -e "------------------------------------------------------------------" >> "$AUCDTECT_ERRORS"
					else
						# Print ISSUE and log error
						print_aucdtect_issue
						echo -e "File:  $i" >> "$AUCDTECT_ERRORS"
						echo -e "Error: $ERROR" >> "$AUCDTECT_ERRORS"
						echo -e "------------------------------------------------------------------" >> "$AUCDTECT_ERRORS"
					fi
				# The processed FLAC file is OK
				else
					print_ok_flac
				fi

				# Remove temporary WAV file
				rm "${i%.[Ff][Ll][Aa][Cc]}.wav"
			fi
		done
	}
	export -f aucdtect_f

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'aucdtect_f "$@"' --

	if [[ -f "$AUCDTECT_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files may be lossy sourced, please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$AUCDTECT_ERRORS\" for details"
		exit 1
	fi
}

#########################
#  CHECK MD5 SIGNATURE  #
#########################
# Check for unset MD5 Signatures in FLAC files
function md5_check {
	title_md5check_flac

	# Abort script and check for any errors thus far
	function md5_check_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
		if [[ -f "$MD5_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} The MD5 Signature is unset for some FLAC files or there were"
			echo -e " ${BOLD_RED}*${NORMAL} issues with some of the FLAC files, please check:"
			echo -e " ${BOLD_RED}*${NORMAL} \"$MD5_ERRORS\" for details"
			exit 1
		fi
	}

	# Trap SIGINT (Control-C) to abort cleanly
	trap md5_check_abort SIGINT

	function md5_c {
		for i ; do
			print_checking_md5
			MD5_SUM="$(metaflac --show-md5sum "$i" 2>&1)"
			MD5_NOT_FLAC="$(echo "$MD5_SUM" | grep -o "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE")"
			if [[ "$MD5_SUM" == "00000000000000000000000000000000" ]] ; then
				print_failed_flac
				echo -e "File:  $i" >> "$MD5_ERRORS"
				echo -e "Error: MD5 Signature unset ($MD5_SUM)" >> "$MD5_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$MD5_ERRORS"
			elif [[ "$MD5_NOT_FLAC" == "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE" ]] ; then
				print_failed_flac
				echo -e "File:  $i" >> "$MD5_ERRORS"
				echo -e "Error: The above file does not appear to be a FLAC file" >> "$MD5_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$MD5_ERRORS"
			else
				print_ok_flac
			fi
		done
	}
	export -f md5_c

	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'md5_c "$@"' --
	
	if [[ -f "$MD5_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} The MD5 Signature is unset for some FLAC files or there were"
		echo -e " ${BOLD_RED}*${NORMAL} issues with some of the FLAC files, please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$MD5_ERRORS\" for details"
		exit 1
	fi  
}

###############
#  REDO TAGS  #
###############
# Check for missing tags and retag FLAC files if all files
# are not missing tags
function redo_tags {
	# Keep SIGINT from exiting the script (Can cause all tags
	# to be lost if done when tags are being removed!)
	trap '' SIGINT

	################
	# ANALYZE TAGS #
	################

	# Display why COVERART tag should not be used
	function coverart_warning {
		echo -e " ${YELLOW}*${NORMAL} The COVERART tag is deprecated and should not be"
		echo -e " ${YELLOW}*${NORMAL} used. Instead, consider migrating over to the new format:"
		echo -e " ${YELLOW}*${NORMAL} METADATA_BLOCK_PICTURE, using modern tag editors. Read:"
		echo -e " ${YELLOW}*${NORMAL} http://wiki.xiph.org/VorbisComment#Unofficial_COVERART_field_.28deprecated.29"
		echo -e " ${YELLOW}*${NORMAL} for more details."
	}

	# Check if COVERART exists in the tag array.  Notify user
	# of its deprecation and advise against using it, preferring
	# METADATA_BLOCK_PICTURE
	for j in "${tags[@]}" ; do
		if [[ "$j" == "COVERART" ]] ; then
			# If REMOVE_ARTWORK is "true" (remove the artwork), then
			# exit and warn the user you can't specify whether you want to
			# remove artwork, yet keep the COVERART tag in USER CONFIGURATION
			if [[ "$REMOVE_ARTWORK" == "true" ]] ; then
				# Display COVERART tag warning
				coverart_warning

				echo -e "\n ${BOLD_RED}*${NORMAL} It appears you have REMOVE_ARTWORK set to \"true\" under"
				echo -e " ${BOLD_RED}*${NORMAL} USER CONFIGURATION, yet COVERART is specified as one"
				echo -e " ${BOLD_RED}*${NORMAL} (or more) of the FLAC tags to be kept. Please choose either"
				echo -e " ${BOLD_RED}*${NORMAL} to keep album artwork (ie REMOVE_ARTWORK=\"false\") or remove"
				echo -e " ${BOLD_RED}*${NORMAL} the COVERART tag under the USER CONFIGURATION portion of this"
				echo -e " ${BOLD_RED}*${NORMAL} script."
				exit 1
			else
				# Create COVERART_WARNING variable, so script can append
				# the coverart_warning function after completion as well as
				# determine the correct tag array to use (whether we should
				# add COVERART or not)
				COVERART_WARNING="true"
			fi
		fi
	done

	function analyze_tags {
		# Check if file is a FLAC file
		CHECK_FLAC="$(metaflac --show-md5sum "$i" 2>&1 | grep -o "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE")"

		if [[ "$CHECK_FLAC" == "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE" ]] ; then
			echo -e "File:  $i" >> "$METADATA_ERRORS"
			echo -e "Error: The above file does not appear to be a FLAC file" >> "$METADATA_ERRORS"
			echo -e "------------------------------------------------------------------" >> "$METADATA_ERRORS"
			# File is not a FLAC file, display failed
			print_failed_flac
		else
			# Recreate the tags array so it can be used by the child process
			eval "tags=(${EXPORT_TAG[*]})"

			# Iterate through each tag field and check if tag is missing
			for j in "${tags[@]}" ; do
				# Check if ALBUMARTIST is in tag array and apply operations on
				# the tag field if it exists
				if [[ "$j" == "ALBUMARTIST" ]] ; then
					# ALBUMARTIST exists in tag array so allow script to check the
					# various naming conventions within the FLAC files (ie,
					# 'album artist' or 'album_artist')

					# "ALBUMARTIST"
					if [[ -n "$(metaflac --show-tag=ALBUMARTIST "$i")" ]] ; then
						# Set a temporary variable to be easily parsed by `eval`
						local TEMP_TAG="$(metaflac --show-tag=ALBUMARTIST "$i" | sed "s/^ALBUMARTIST=//i")"
					# "album artist"
					elif [[ -n "$(metaflac --show-tag="album artist" "$i")" ]] ; then
						# Set a temporary variable to be easily parsed by `eval`
						local TEMP_TAG="$(metaflac --show-tag="album artist" "$i" | sed "s/^album artist=//i")"
					# "album_artist"
					elif [[ -n "$(metaflac --show-tag="album_artist" "$i")" ]] ; then
						# Set a temporary variable to be easily parsed by `eval`
						local TEMP_TAG="$(metaflac --show-tag="album_artist" "$i" | sed "s/^album_artist=//i")"
					fi
				else
					# Set a temporary variable to be easily parsed by `eval`
					local TEMP_TAG="$(metaflac --show-tag="$j" "$i" | sed "s/^${j}=//i")"
				fi

				# Evaluate TEMP_TAG into the dynamic tag
				eval "${j}"_TAG='"${TEMP_TAG}"'

				# If tags are not found, log output
				if [[ -z "$(eval "echo "\$${j}_TAG"")" ]] ; then
					echo -e "File:  $i" >> "$METADATA_ERRORS"
					echo -e "Error: ${j} tag not found" >> "$METADATA_ERRORS"
					echo -e "------------------------------------------------------------------" >> "$METADATA_ERRORS"
				fi
			done
		fi
	}
	export -f analyze_tags

	function analyze_tags_dont_log_coverart {
		# Check if file is a FLAC file
		CHECK_FLAC="$(metaflac --show-md5sum "$i" 2>&1 | grep -o "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE")"

		if [[ "$CHECK_FLAC" == "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE" ]] ; then
			echo -e "File:  $i" >> "$METADATA_ERRORS"
			echo -e "Error: The above file does not appear to be a FLAC file" >> "$METADATA_ERRORS"
			echo -e "------------------------------------------------------------------" >> "$METADATA_ERRORS"
			# File is not a FLAC file, display failed
			print_failed_flac
		else
			# Recreate the tags array so it can be used by the child process
			eval "tags=(${EXPORT_TAG[*]})"

			# Album artwork is to be kept so preserve COVERART
			tags=( "${tags[@]}" COVERART )

			# Iterate through each tag field and check if tag is missing (except
			# for the COVERART tag)
			for j in "${tags[@]}" ; do
				# Check if ALBUMARTIST is in tag array and apply operations on
				# the tag field if it exists
				if [[ "$j" == "ALBUMARTIST" ]] ; then
					# ALBUMARTIST exists in tag array so allow script to check the
					# various naming conventions within the FLAC files (ie,
					# 'album artist' or 'album_artist')

					# "ALBUMARTIST"
					if [[ -n "$(metaflac --show-tag=ALBUMARTIST "$i")" ]] ; then
						# Set a temporary variable to be easily parsed by `eval`
						local TEMP_TAG="$(metaflac --show-tag=ALBUMARTIST "$i" | sed "s/^ALBUMARTIST=//i")"
					# "album artist"
					elif [[ -n "$(metaflac --show-tag="album artist" "$i")" ]] ; then
						# Set a temporary variable to be easily parsed by `eval`
						local TEMP_TAG="$(metaflac --show-tag="album artist" "$i" | sed "s/^album artist=//i")"
					# "album_artist"
					elif [[ -n "$(metaflac --show-tag="album_artist" "$i")" ]] ; then
						# Set a temporary variable to be easily parsed by `eval`
						local TEMP_TAG="$(metaflac --show-tag="album_artist" "$i" | sed "s/^album_artist=//i")"
					fi
				else
					# Set a temporary variable to be easily parsed by `eval`
					local TEMP_TAG="$(metaflac --show-tag="$j" "$i" | sed "s/^${j}=//i")"
				fi

				# Evaluate TEMP_TAG into the dynamic tag
				eval "${j}"_TAG='"${TEMP_TAG}"'

				# If COVERART_TAG is not null, then log file that has
				# the COVERART tag embedded within it about deprecation
				if [[ -n "$COVERART_TAG" ]] ; then
					echo -e "File:  $i" >> "$METADATA_ERRORS"
					echo -e "Error: \"${j}\" tag is DEPRECATED in above file. Consider migrating to" >> "$METADATA_ERRORS"
					echo -e "       the new format: METADATA_BLOCK_PICTURE." >> "$METADATA_ERRORS"
					echo -e "------------------------------------------------------------------" >> "$METADATA_ERRORS"
				fi

				# If tags are not found, log output. Skip output
				# of COVERART tag as this is a temporary addition to
				# the tag array (for processing legacy artwork)
				if [[ -z "$(eval "echo "\$${j}_TAG"")" && "${j}" != "COVERART" ]] ; then
					echo -e "File:  $i" >> "$METADATA_ERRORS"
					echo -e "Error: ${j} tag not found" >> "$METADATA_ERRORS"
					echo -e "------------------------------------------------------------------" >> "$METADATA_ERRORS"
				fi
			done
		fi
	}
	export -f analyze_tags_dont_log_coverart

	# If COVERART was specified under USER CONFIGURATION
	# set the tag array accordingly and test whether there
	# are missing tags in each FLAC file
	if [[ "$COVERART_WARNING" == "true" ]] ; then
		title_analyze_tags

		# COVERART is already in the tag array. Implies album
		# artwork is to be kept, so log if COVERART tag is missing
		# Function check_tags to allow multithreading
		function check_tags {
			for i ; do
				# Print script operation title
				print_analyzing_tags

				# Analyze FLACs for missing tags
				analyze_tags

				# Done analyzing FLAC file tags
				print_done_flac
			done
		}
		export -f check_tags
	else
		# COVERART is not in the tag array, so add it if album artwork
		# is to be kept
		if [[ "$REMOVE_ARTWORK" == "false" ]] ; then
			title_analyze_tags

			# Analyze tags but don't log COVERART is missing tag
			# Function check_tags to allow multithreading
			function check_tags {
				for i ; do
					# Print script operation title
					print_analyzing_tags

					# Analyze FLACs for missing tags
					# (except for COVERART tag)
					analyze_tags_dont_log_coverart

					# Done analyzing FLAC file tags
					print_done_flac
				done
			}
			export -f check_tags
		else
			title_analyze_tags

			# Album artwork is NOT kept, so process tag fields, omitting COVERART
			# Function check_tags to allow multithreading
			function check_tags {
				for i ; do
					# Print script operation title
					print_analyzing_tags

					# Analyze FLACs for missing tags
					analyze_tags

					# Done analyzing FLAC file tags
					print_done_flac
				done
			}
			export -f check_tags
		fi
	fi

	# Run the "check_tags" function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'check_tags "$@"' --

	# Test for DEPRECATED tag, COVERART in METADATA_ERROR log.  If it
	# exists, set COVERART_WARNING variable to make script output
	# warning upon completion
	grep -sq METADATA_BLOCK_PICTURE "$METADATA_ERRORS"
	if [[ $? -eq 0 ]] ; then
		COVERART_WARNING="true"
	fi

	if [[ -f "$METADATA_ERRORS"  && "$COVERART_WARNING" == "true" ]] ; then
		# Display COVERART warning function and metadata issues
		echo
		coverart_warning
		echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files have missing tags or there were"
		echo -e " ${BOLD_RED}*${NORMAL} issues with some of the FLAC files, please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$METADATA_ERRORS\" for details."
		echo -e " ${BOLD_RED}*${NORMAL} Not Re-Tagging files."
		exit 1
	elif [[ -f "$METADATA_ERRORS" ]] ; then
		# Just display metadata issues
		echo -e "\n ${BOLD_RED}*${NORMAL} Some FLAC files have missing tags or there were"
		echo -e " ${BOLD_RED}*${NORMAL} issues with some of the FLAC files, please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$METADATA_ERRORS\" for details."
		echo -e " ${BOLD_RED}*${NORMAL} Not Re-Tagging files."
		exit 1
	fi

	############
	# SET TAGS #
	############

	# Recreate the tags array as it may have added the
	# COVERART tag.  This way, we ensure that the COVERART
	# tag is, in fact, temporary.
	eval "tags=(${EXPORT_TAG[*]})"

	title_setting_tags

	# Set the FLAC metadata to each FLAC file
	function remove_set_tags {
		# Iterate through the tag array and set a variable for each tag
		for j in "${tags[@]}" ; do
			# Check if ALBUMARTIST is in tag array and apply operations on
			# the tag field if it exists
			if [[ "$j" == "ALBUMARTIST" ]] ; then
				# ALBUMARTIST exists in tag array so allow script to check the
				# various naming conventions within the FLAC files (ie,
				# 'album artist' or 'album_artist')

				# "ALBUMARTIST"
				if [[ -n "$(metaflac --show-tag=ALBUMARTIST "$i")" ]] ; then
					# Set a temporary variable to be easily parsed by `eval`
					local TEMP_TAG="$(metaflac --show-tag=ALBUMARTIST "$i" | sed "s/^ALBUMARTIST=//i")"
				# "album artist"
				elif [[ -n "$(metaflac --show-tag="album artist" "$i")" ]] ; then
					# Set a temporary variable to be easily parsed by `eval`
					local TEMP_TAG="$(metaflac --show-tag="album artist" "$i" | sed "s/^album artist=//i")"
				# "album_artist"
				elif [[ -n "$(metaflac --show-tag="album_artist" "$i")" ]] ; then
					# Set a temporary variable to be easily parsed by `eval`
					local TEMP_TAG="$(metaflac --show-tag="album_artist" "$i" | sed "s/^album_artist=//i")"
				fi
			else
				# Set a temporary variable to be easily parsed by `eval`
				local TEMP_TAG="$(metaflac --show-tag="$j" "$i" | sed "s/^${j}=//i")"
			fi

			# Evaluate TEMP_TAG into the dynamic tag
			eval "${j}"_SET='"${TEMP_TAG}"'
		done
	
		# Remove all the tags
		metaflac --remove --block-type=VORBIS_COMMENT "$i"

		# Iterate through the tag array and add the saved tags back
		for j in "${tags[@]}" ; do
			metaflac --set-tag="${j}"="$(eval "echo \$${j}_SET")" "$i"
		done
	}
	export -f remove_set_tags

	# Function retag_flacs to allow multithreading
	function retag_flacs {
		# Recreate the tags array so it can be used by the child process
		eval "tags=(${EXPORT_TAG[*]})"
		for i ; do
			print_setting_tags
			remove_set_tags
			print_ok_flac
		done
	}
	export -f retag_flacs
	
	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'retag_flacs "$@"' --
}

#################
#  PRUNE FLACS  #
#################
# Clear excess FLAC metadata from each FLAC file
function prune_flacs {
	title_prune_flac

	# Abort script and check for any errors thus far
	function prune_abort {
		echo -e "\n ${BOLD_GREEN}*${NORMAL} Control-C received, exiting script..."
		if [[ -f "$PRUNE_ERRORS" ]] ; then
			echo -e "\n ${BOLD_RED}*${NORMAL} There were issues with some of the FLAC files,"
			echo -e " ${BOLD_RED}*${NORMAL} please check:"
			echo -e " ${BOLD_RED}*${NORMAL} \"$PRUNE_ERRORS\" for details."
			exit 1
		fi
	}

	# Trap SIGINT (Control-C) to abort cleanly	
	trap prune_abort SIGINT

	function prune_f {
		# Don't remove artwork if user wants it kept.  We don't have to check
		# for the legacy COVERART tag as we are NOT removing any VORBIS_COMMENTs.
		if [[ "$REMOVE_ARTWORK" == "true" ]] ; then
			# Remove artwork (exported for subshell access)
			export DONT_PRUNE_FLAC_METADATA="STREAMINFO,VORBIS_COMMENT"
		else
			# Don't remove artwork (exported for subshell access)
			export DONT_PRUNE_FLAC_METADATA="STREAMINFO,PICTURE,VORBIS_COMMENT"
		fi

		for i ; do
			print_prune_flac

			# Check if file is a FLAC file
			CHECK_FLAC="$(metaflac --show-md5sum "$i" 2>&1 | grep -o "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE")"

			if [[ "$CHECK_FLAC" == "FLAC__METADATA_CHAIN_STATUS_NOT_A_FLAC_FILE" ]] ; then
				echo -e "File:  $i" >> "$PRUNE_ERRORS"
				echo -e "Error: The above file does not appear to be a FLAC file" >> "$PRUNE_ERRORS"
				echo -e "------------------------------------------------------------------" >> "$PRUNE_ERRORS"
				# File is not a FLAC file, display failed
				print_failed_flac
			else
				# Remove all information but STREAMINFO,VORBIS_COMMENTs, and
				# possibly METADATA_BLOCK_PICTURE
				metaflac --remove --dont-use-padding --except-block-type="${DONT_PRUNE_FLAC_METADATA}" "$i"
				print_ok_flac
			fi
		done
	}
	export -f prune_f
	
	# Run the above function with the configured threads (multithreaded)
	find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print0 | xargs -0 -n 1 -P "$CORES" bash -c 'prune_f "$@"' --

	if [[ -f "$PRUNE_ERRORS" ]] ; then
		echo -e "\n ${BOLD_RED}*${NORMAL} There were issues with some of the FLAC files,"
		echo -e " ${BOLD_RED}*${NORMAL} please check:"
		echo -e " ${BOLD_RED}*${NORMAL} \"$PRUNE_ERRORS\" for details."
	fi
}

#######################
#  DISPLAY LONG HELP  #
#######################
# Display a lot of help
function long_help {
	cat << EOF
  Usage: $0 [OPTION] [OPTION]... [PATH_TO_FLAC(s)]
  Options:
    -c, --compress
           Compress the FLAC files with the user-specified level of compression
           defined under USER CONFIGURATION (as the variable COMPRESSION_LEVEL)
           and verify the resultant files.

           The default is 8, with the range of values starting from 1 to 8 with
           the smallest compression at 1, and the highest at 8.  This option
           will add a tag to all successfully verified FLAC files.  Below
           shows the default COMPRESSION tag added to each successfully
           verified FLAC:

                       COMPRESSION=8

           If any FLAC files already have the defined COMPRESSION_LEVEL tag (a
           good indicator the files are already compressed at that level), the
           script will instead test the FLAC files for any errors.  This is useful
           to check your entire music library to make sure all the FLAC files are
           compressed at the level specified as well as make sure they are intact.

           If any files are found to be corrupt, this script will quit upon
           finishing the compression of any other files and produce an error
           log.

    -C, --compress-notest
           Same as the "--compress" option, but if any FLAC files already have the
           defined COMPRESSION_LEVEL tag, the script will skip the file and continue
           on to the next without test the FLAC file's integrity.  Useful for
           checking all your FLAC files are compressed at the level specified.

    -t, --test
           Same as compress but instead of compressing the FLAC files, this
           script just verfies the files.  This option will NOT add the
           COMPRESSION tag to the files.

           As with the "--compress" option, this will produce an error log if
           any FLAC files are found to be corrupt.

    -a, --aucdtect
           Uses the auCDtect program by Oleg Berngardt and Alexander Djourik to
           analyze FLAC files and check with fairly accurate precision whether
           the FLAC files are lossy sourced or not.  For example, an MP3 file
           converted to FLAC is no longer lossless therefore lossy sourced.

           While this program isn't foolproof, it gives a good idea which FLAC
           files will need further investigation (ie a spectrogram).  This program
           does not work on FLAC files which have a bit depth more than a typical
           audio CD (16bit), and will skip the files that have a higher bit depth.

           If any files are found to not be perfect (100% CDDA), a log will be created
           with the questionable FLAC files recorded in it.

    -A, --aucdtect-spectrogram
           Same as "-a, --aucdtect" with the addition of creating a spectrogram for
           each FLAC file that fails auCDtect, that is, any FLAC file that does not
           return 100% CDDA from auCDtect will be scanned and a spectrogram will be
           created.

           Any FLAC file skipped (due to having a higher bit depth than 16), will
           NOT have a spectrogram created.

           By default, each spectrogram will be created in the same folder as the
           tested FLAC file with the same name as the tested FLAC file:

               03 - Some FLAC File.flac --> 03 - Some FLAC File.png

           If there already is a PNG file with the same name as the tested FLAC,
           the name "spectrogram" will prepend the ".png" extension:

               03 - Some FLAC File.flac --> 03 - Some FLAC File.spectrogram.png

           The user can change the location of where to store the created
           spectrogram images by changing the value of SPECTROGRAM_LOCATION under
           the USER CONFIGURATION section of this script.  The location defined by
           the user will be tested to see if it exists before starting the script.
           If the location does NOT exist, the script will warn the user and exit.

           The created PNG file is large in resolution to best capture the
           FLAC file's waveform (roughly 5140x2149).

           The spectrogram is created using the program SoX.  If the user tries
           to use this option without having SoX installed, the script will warn
           the user that SoX is missing and exit.

    -m, --md5check
           Check the FLAC files for unset MD5 Signatures and log the output of
           any unset signatures.  An unset MD5 signature doesn't necessarily mean
           a FLAC file is corrupt, and can be repaired with a re-encoding of said
           FLAC file.

    -p, --prune
           Delete every METADATA block in each FLAC file except the STREAMINFO and
           VORBIS_COMMENT block.  If REMOVE_ARTWORK is set to "false", then the
           PICTURE block will NOT be removed.

    -g, --replaygain
           Add ReplayGain tags to the FLAC files.  The ReplayGain is calculated
           for ALBUM and TRACK values. ReplayGain is applied via VORBIS_TAGS and
           as such, will require the redo, --r argument to have these tags kept
           in order to preserve the added ReplayGain values.  The tags added are:

                      REPLAYGAIN_REFERENCE_LOUDNESS
                      REPLAYGAIN_TRACK_GAIN
                      REPLAYGAIN_TRACK_PEAK
                      REPLAYGAIN_ALBUM_GAIN
                      REPLAYGAIN_ALBUM_PEAK

           In order for the ReplayGain values to be applied correctly, the
           script has to determine which FLAC files to add values by directory.
           What this means is that the script must add the ReplayGain values by
           working off the FLAC files' parent directory.  If there are some FLAC
           files found, the script will move up one directory and begin applying
           the ReplayGain values.  This is necessary in order to get the
           REPLAYGAIN_ALBUM_GAIN and REPLAYGAIN_ALBUM_PEAK values set correctly.
           Without doing this, the ALBUM and TRACK values would be identical.

           Ideally, this script would like to be able to apply the values on each
           FLAC file individually, but due to how metaflac determines the
           ReplayGain values for ALBUM values (ie with wildcard characters), this
           isn't simple and/or straightforward.

           A limitation of this option can now be seen.  If a user has many FLAC
           files under one directory (of different albums/artists), the
           ReplayGain ALBUM values are going to be incorrect as the script will
           perceive all those FLAC files to essentially be an album.  For now,
           this is mitigated by having your music library somewhat organized with
           each album housing the correct FLAC files and no others.

           In the future, this script will ideally choose which FLAC files will
           be processed by ARTIST and ALBUM metadata, not requiring physical
           directories to process said FLAC files.

           Due to the nature of how ALBUM values are processed, this option cannot
           use more than one thread, so the CORES configuration option will not be
           honored -- enforcing only one thread.

           If there are any errors found while creating the ReplayGain values
           and/or setting the values, an error log will be produced.

    -r, --redo
           Extract the configured tags in each FLAC file and clear the rest before
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
                      RELEASETYPE
                      SOURCE
                      MASTERING
                      REPLAYGAIN_REFERENCE_LOUDNESS
                      REPLAYGAIN_TRACK_GAIN
                      REPLAYGAIN_TRACK_PEAK
                      REPLAYGAIN_ALBUM_GAIN
                      REPLAYGAIN_ALBUM_PEAK

           If any FLAC files have missing tags (from those configured to be kept),
           the file and the missing tag will be recorded in a log.

           The tags that can be kept are eseentially infinite, as long as the
           tags to be kept are set in the tag configuration located at the top of
           this script under USER CONFIGURATION.

           If this option is specified, a warning will appear upon script
           execution.  This warning will show which of the configured TAG fields
           to keep when re-tagging the FLAC files.  A countdown will appear
           giving the user 10 seconds to abort the script, after which, the script
           will begin running it's course.

           If the (-d, --disable-warning) option is used, this warning will not
           appear.  This is useful for veteran users.

    -l, --all
           This option is short for:

                      -c, --compress
                      -m, --md5check
                      -p, --prune
                      -g, --replaygain
                      -r, --redo

           If any of these options (or variations of the above options) are called, this
           script will warn the user of conflicting options and exit.

    -L, --reallyall
           This option is short for:

                      -c, --compress
                      -m, --md5check
                      -p, --prune
                      -g, --replaygain
                      -r, --redo
                      -A, --aucdtect-spectrogram

           If any of these options (or variations of the above options) are called, this
           script will warn the user of conflicting options and exit.

    -n, --no-color
           Turn off color output.

    -v, --version
           Display script version and exit.

    -h, --help
           Shows this help message.

           This script can use more than one CPU/Cores (threads).  By default, this script will
           use two (2) threads, which can be configured under USER CONFIGURATION (located near the top
           of this script).

           Multithreading is achieved by utilizing the "xargs" command which comes bundled with the
           "find" command.  While not true multithreading, this psuedo multithreading will greatly speed
           up the processing if the host has more than one CPU.


  Invocation Examples:
    # Compress and verify FLAC files
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

    # Compress FLAC files and redo the FLAC tags
    $0 -c -r /some/path/to/files
EOF
}

########################
#  DISPLAY SHORT HELP  #
########################
# Display short help
function short_help {
	echo "  Usage: $0 [OPTION] [OPTION]... [PATH_TO_FLAC(s)]"
	echo "  Options:"
	echo "    -c, --compress"
	echo "    -C, --compress-notest"
	echo "    -t, --test"
	echo "    -m, --md5check"
	echo "    -a, --aucdtect"
	echo "    -A, --aucdtect-spectrogram"
	echo "    -p, --prune"
	echo "    -g, --replaygain"
	echo "    -r, --redo"
	echo "    -l, --all"
	echo "    -L, --reallyall"
	echo "    -n, --no-color"
	echo "    -v, --version"
	echo "    -h, --help"
	echo "  This is the short help; for details use '$0 --help' or '$0 -h'"
}

############################
#  DISPLAY SCRIPT VERSION  #
############################
# Display script version
function print_version {
	echo "Version $VERSION"
}

#######################
#  PRE-SCRIPT CHECKS  #
#######################
# Add case where only one argument is specified
if [[ "$#" -eq 1 ]] ; then
	case "$1" in
		--version|-v)
			print_version
			exit 0
			;;
		--help|-h)
			# Check for less pager.  If available,
			# lets use it.  If not, just display it
			LESS_COMMAND="$(command -v less)"
			if [[ -n "$LESS_COMMAND" ]] ; then
				long_help | less
				exit 0
			else
				long_help
				exit 0
			fi
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
		--all|-l)
			ALL="true"
			shift
			;;
		--reallyall|-L)
			REALLYALL="true"
			shift
			;;
		--compress|-c)
			COMPRESS="true"
			COMPRESS_TEST="true"
			shift
			;;
		--compress-notest|-C)
			COMPRESS="true"
			export SKIP_TEST="true"
			shift
			;;
		--test|-t)
			TEST="true"
			shift
			;;
		--replaygain|-g)
			REPLAYGAIN="true"
			shift
			;;
		--aucdtect|-a)
			AUCDTECT="true"
			# Not used in subshell(s)
			NO_SPECTROGRAM="true"
			shift
			;;
		--aucdtect-spectrogram|-A)
			AUCDTECT="true"
			export CREATE_SPECTROGRAM="true"
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
		*)
			short_help
			exit 0
			;;
	esac
done

# This must come before the other options in
# order for it to take effect
if [[ "$NO_COLOR" == "true" ]] ; then
	BOLD_GREEN=""
	BOLD_RED=""
	BOLD_BLUE=""
	CYAN=""
	NORMAL=""
	YELLOW=""
fi

# Check to make sure script has all the dependencies
# necessary to complete script succesfully
# Check if each command can be found in $PATH
PRINTF_EXISTS="$(command -v printf)"
BASENAME_EXISTS="$(command -v basename)"
DIRNAME_EXISTS="$(command -v dirname)"
SLEEP_EXISTS="$(command -v sleep)"
WC_EXISTS="$(command -v wc)"
CAT_EXISTS="$(command -v cat)"
FIND_EXISTS="$(command -v find)"
XARGS_EXISTS="$(command -v xargs)"
METAFLAC_EXISTS="$(command -v metaflac)"
FLAC_EXISTS="$(command -v flac)"
AWK_EXISTS="$(command -v awk)"
GREP_EXISTS="$(command -v grep)"

# Go through and test if each command was found (by displaying its $PATH).  If
# it's empty, add where you can find the package to an array to be displayed.
if [[ -z "$PRINTF_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"printf\" with the \"coreutils\" package." )
fi

if [[ -z "$BASENAME_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"basename\" with the \"coreutils\" package." )
fi

if [[ -z "$DIRNAME_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"dirname\" with the \"coreutils\" package." )
fi

if [[ -z "$SLEEP_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"sleep\" with the \"coreutils\" package." )
fi

if [[ -z "$WC_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"wc\" with the \"coreutils\" package." )
fi

if [[ -z "$CAT_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"cat\" with the \"coreutils\" package." )
fi

if [[ -z "$FIND_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"find\" with the \"findutils\" package." )
fi

if [[ -z "$XARGS_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"xargs\" with the \"findutils\" package." )
fi

if [[ -z "$METAFLAC_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"metaflac\" with the \"flac\" package." )
fi

if [[ -z "$FLAC_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"flac\" with the \"flac\" package." )
fi

if [[ -z "$AWK_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"awk\" with the \"awk\", \"gawk\", \"nawk\", or \"mawk\" package." )
fi

if [[ -z "$GREP_EXISTS" ]] ; then
	command_exists_array=( "${command_exists_array[@]}" "You can generally install \"grep\" with the \"grep\" package." )
fi

# Display (in bold red) message that system is missing vital programs
function display_missing_commands_header {
	echo -e " ${BOLD_RED}*${NORMAL} You seem to be missing one or more necessary programs"
	echo -e " ${BOLD_RED}*${NORMAL} to run this script reliably.  Below shows the program(s)"
	echo -e " ${BOLD_RED}*${NORMAL} missing, as well as where you can install them from:\n"
}

# If all the programs above were found, continue with script.  Else
# display warning and exit script, printing out which package has
# the missing programs
if [[ -n "${command_exists_array[@]}" ]] ; then
	display_missing_commands_header
	# Iterate through array and print each value
	for i in "${command_exists_array[@]}" ; do
		echo -e " ${YELLOW}*${NORMAL} $i"
	done
	exit 1
fi

# Set the last argument as the directory
DIRECTORY="$1"

# Check whether DIRECTORY is not null and whether the directory exists
if [[ -n "$DIRECTORY" && ! -d "$DIRECTORY" ]] ; then
	echo -e "  Usage: $0 [OPTION] [PATH_TO_FLAC(s)]...\n"
	echo -e " ${BOLD_RED}*${NORMAL} Please specify a directory!"
	exit 1
fi

# If no arguments are made to the script show usage
if [[ "$#" -eq 0 ]] ; then
	short_help
	exit 0
fi

# If "-l, --all" and "-L, --reallyall" are both called, warn and exit
if [[ "$ALL" == "true" && "$REALLYALL" == "true" ]] ; then
	echo -e " ${BOLD_RED}*${NORMAL} Running both \"-l, --all\" and \"-L, --reallyall\" conflict!"
	echo -e " ${BOLD_RED}*${NORMAL} Please choose one or the other." 
	exit 1
fi

# If "-l, --all" or "-L, --reallyall" was called, check if arguments
# were called that already will be performed by the above argument(s).
# If any were called, display a warning and exit the script
if [[ "$ALL" == "true" || "$REALLYALL" == "true" ]] ; then

	# Check for "-c, --compress".  If used add it to array
	if [[ "$COMPRESS" == "true" && "$SKIP_TEST" == "false" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-c, --compress" )
	# Check for "-C, --compress-notest".  If used add it to array
	elif [[ "$COMPRESS" == "true" && "$SKIP_TEST" == "true" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-C, --compress-notest" )
	fi

	# Check for "-t, --test".  If used add it to array
	if [[ "$TEST" == "true" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-t, --test" )
	fi

	# Check for "-m, --md5check".  If used add it to array
	if [[ "$MD5CHECK" == "true" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-m, --md5check" )
	fi

	# Check for "-p, --prune".  If used add it to array
	if [[ "$PRUNE" == "true" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-p, --prune" )
	fi

	# Check for "-g, --replaygain".  If used add it to array
	if [[ "$REPLAYGAIN" == "true" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-g, --replaygain" )
	fi

	# Check for "-r, --redo".  If used add it to array
	if [[ "$REDO" == "true" ]] ; then
		argumentConflict=( "${argumentConflict[@]}" "-r, --redo" )
	fi

	# If "-L, --reallyall" was called, check for the various forms of calling
	# auCDtect.  If it was called, add it to array
	if [[ "$REALLYALL" == "true" ]] ; then
		if [[ "$AUCDTECT" == "true" && "$CREATE_SPECTROGRAM" == "true" ]] ; then
			argumentConflict=( "${argumentConflict[@]}" "-A, --aucdtect-spectrogram" )
		elif [[ "$AUCDTECT" == "true" && "$CREATE_SPECTROGRAM" != "true" ]] ; then
			argumentConflict=( "${argumentConflict[@]}" "-a, --aucdtect" )
		fi
	fi

	# If the array is not empty, the user called some incompatible options with
	# "-l, --all" or "-L, --reallyall", so print which options were called that
	# are incompatible and exit script
	if [[ -n "${argumentConflict[@]}" ]] ; then
		# "-l, --all"
		if [[ "$ALL" == "true" ]] ; then
			echo -e " ${BOLD_RED}*${NORMAL} The below options conflict with \"-l, --all\""
		# "-L, --reallyall"
		elif [[ "$REALLYALL" == "true" ]] ; then
			echo -e " ${BOLD_RED}*${NORMAL} The below options conflict with \"-L, --reallyall\""
		fi

		# Iterate through array and print each value
		for i in "${argumentConflict[@]}" ; do
			echo -e " ${BOLD_RED}*${NORMAL}     $i"
		done

		echo -e " ${BOLD_RED}*${NORMAL} Please remove incompatible options."
		exit 1
	fi
fi

# If "-C, --compress-notest" and "-c, --compress" are both called, warn and exit
if [[ "$SKIP_TEST" == "true" && "$COMPRESS_TEST" == "true" ]] ; then
	echo -e " ${BOLD_RED}*${NORMAL} Running both \"-c, --compress\" and \"-C, --compress-notest\" conflict!"
	echo -e " ${BOLD_RED}*${NORMAL} Please choose one or the other."
	exit 1
fi

# If "-c, --compress" and "-t, --test" are both called, warn and exit
if [[ "$COMPRESS_TEST" == "true" && "$TEST" == "true" ]] ; then
	echo -e " ${BOLD_RED}*${NORMAL} Running both \"-c, --compress\" and \"-t, --test\" conflict!"
	echo -e " ${BOLD_RED}*${NORMAL} Please choose one or the other."
	exit 1
fi

# If "-a, --aucdtect" and "-A, --aucdtect-spectrogram" are both called, warn and exit
if [[ "$NO_SPECTROGRAM" == "true"  && "$CREATE_SPECTROGRAM" == "true" ]] ; then
	echo -e " ${BOLD_RED}*${NORMAL} Running both \"-a, --aucdtect\" and \"-A, --aucdtect-spectrogram\" conflict!"
	echo -e " ${BOLD_RED}*${NORMAL} Please choose one or the other."
	exit 1
fi

# Check if FLAC files exist
FIND_FLACS="$(find "$DIRECTORY" -name "*.[Ff][Ll][Aa][Cc]" -print)"
if [[ -z "$FIND_FLACS" ]] ; then
	no_flacs
	exit 1
fi

# Check if `tput` is installed and do a fallback if not
# installed
hash tput
# Check exit code. If 1, then `tput` is not installed
if [[ "$?" -eq 1 ]] ; then
	# Export to allow subshell access
	export FALLBACK="true"
fi

###########################
#  END PRE-SCRIPT CHECKS  #
###########################

##################
#  BEGIN SCRIPT  #
##################
# If "-l, --all" or "-L, --reallyall" was called,
# enable the various arguments to allow script to
# run them
if [[ "$ALL" == "true" ]] ; then
	COMPRESS="true"
	MD5CHECK="true"
	PRUNE="true"
	REPLAYGAIN="true"
	REDO="true"
elif [[ "$REALLYALL" == "true" ]] ; then
	COMPRESS="true"
	MD5CHECK="true"
	PRUNE="true"
	REPLAYGAIN="true"
	REDO="true"
	AUCDTECT="true"
	# This is needed to let script know that we want auCDtect
	# to create a spectrogram (ie "-A, --aucdtect-spectrogram)
	CREATE_SPECTROGRAM="true"
fi

# The below order is probably the best bet in ensuring time
# isn't wasted on doing unnecessary operations if the
# FLAC files are corrupt or have metadata issues
if [[ "$REDO" == "true" ]] ; then
	countdown_metadata
fi

if [[ "$AUCDTECT" == "true" ]] ; then
	# Check if auCDtect is found/installed
	if [[ -f "$AUCDTECT_COMMAND" ]] ; then
		# If "--aucdtect-spectrogram, -A" was called
		# make sure SoX is installed before starting
		if [[ "$CREATE_SPECTROGRAM" == "true" ]] ; then
			SOX_COMMAND="$(command -v sox)"
			if [[ -z "$SOX_COMMAND" ]] ; then
				# SoX can't be found, exit
				echo -e " ${BOLD_RED}*${NORMAL} It appears SoX is not installed. Please verify you"
				echo -e " ${BOLD_RED}*${NORMAL} have this program installed and can be found in \$PATH"
				exit 1
			fi
		fi
		# Run auCDtect function/command
		aucdtect
	else
		echo -e " ${BOLD_RED}*${NORMAL} It appears auCDtect is not installed or you have not"
		echo -e " ${BOLD_RED}*${NORMAL} configured this script to find it. Please verify you"
		echo -e " ${BOLD_RED}*${NORMAL} have this program installed."
		exit 1
	fi
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

if [[ "$REPLAYGAIN" == "true" ]] ; then
	replaygain
fi

if [[ "$REDO" == "true" ]] ; then
	redo_tags
fi

if [[ "$PRUNE" == "true" ]] ; then
	prune_flacs
fi

# Display warning about legacy COVERART tag, if applicable
if [[ "$COVERART_WARNING" == "true" ]] ; then
	echo
	coverart_warning
fi

################
#  END SCRIPT  #
################
