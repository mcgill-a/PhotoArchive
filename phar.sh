#!/bin/sh

# Image Archive Script
# Author: 40276245 (Alex McGill)
# Description: 	This script allows the user to copy specified images from any directory
#				and sub-directories to an archive directory without creating duplicate files.
#				If there are any duplicate files, the absolute pathname of the duplicate image
#				file is sent to a text file called duplicates.txt, stored in the archive directory.
#				Absolute paths will only show up in the duplicates.txt file once to prevent spam.
# Current Version: 1.0
# Recent Modifications: - Changed the file storing absolute file paths from the original directory to a temporary file
#						- Added comments
#						- Added trap command (file cleanup and exit)

# Check to ensure that only two parameters were provided by the user
if [ "$#" -ne 2 ]; then
	# If not then ouput the proper command usage instructions to the user and exit the program
	echo "Usage : phar image_path archive_path"
	exit
fi


# Declare program variables

# Current working directory
WD=$(pwd)
# User specified source file
SOURCE=$1
# User specified archive file
ARCHIVE=$2
# Duplicates text file
DUPLICATES=$ARCHIVE/duplicates.txt
# Temporary file to store absolute path of each image in source file
tempFile=$(mktemp)

# Check to see whether the source is a relative path
# (if it doesn't start with '/')
if [[ "$SOURCE" != /* ]]; then
	# Change the relative path to an absolute path using the current working directory
	SOURCE=$WD/$SOURCE
fi

# Check to see whether the archive is a relative path
# (if it doesn't start with '/')
if [[ "$ARCHIVE" != /* ]]; then
	# Change the relative path to an absolute path using the current working directory
	ARCHIVE=$WD/$ARCHIVE
fi

# If the source directory does not exist
if [ ! -d $SOURCE ]; then
	# Tell the user and exit the program
	echo "Error: Source directory does not exist"
	exit
fi

# If the archive directory does not exist
if [ ! -d $ARCHIVE ]; then
	# Create a new directory for the archive images
	mkdir -p $2
	echo "Info: Created a new archive directory - $ARCHIVE"
else
	echo "Info: Using an existing archive directory - $ARCHIVE"
fi

# If the duplicates text file does not already exist
if [ ! -f $DUPLICATES ]; then
	# Create a new text file and send 'archive duplicate files' to the first line
	echo "Archive duplicate files:" >> $DUPLICATES
fi

# Search through the entire source directory and sub directories using the find command to get image files
# Use the output of the find command and loop through each line
find $SOURCE -type f | egrep "IMG_[0-9]{4}\.(JPG|jpg|PNG|png|GIF|gif|XPM|xpm)$" | while read -r line ; do
	# Send the file path (line) to a temporary file which will store all the absolute file paths of the images
	echo $line >> $tempFile
done

# Read each line of the temp file containing the absolute file paths
while IFS= read -r line
do
	# Set the current image name variable to the basename (filename) of the file, to remove the rest of the file path
	IMGNAME=$(basename $line)
	# Set the image path variable to the basename of the file but in the archive directory
	IMGPATH=$ARCHIVE/$IMGNAME
	# Set variable for checking if MD5 matches to false
	MATCH=false
	# If an image with the same basename doesn't exist in the archive directory
	if [ ! -f $IMGPATH ]; then
		# Copy the file from the absolute file path into archive directory
		cp $line $IMGPATH
	else
		# Get the MD5sum of the image 
		lineMD5=$(md5sum ${line} | awk '{ print $1 }')
		# Get only the name of the image file, not the extension
		search=$(echo $IMGNAME | cut -f1,1 -d".")
		# Store the files from the find command in an array
		FILES=($(find $ARCHIVE -name "$search.*"))
		# Loop through each result in the array
		for current in "${FILES[@]}"
		do
			# Get the basename of the current image in the array
			currentName=$(basename $current)
			# Get the MD5sum of the current image in the array
			currentMD5=$(md5sum ${current} | awk '{ print $1 }')
			# If the MD5sum of the line image matches the MD5sum of the current arary image
			if [ "$lineMD5" == "$currentMD5" ] ; then
				# Set 'match' to true
				MATCH=true
			fi
		done
		# If match is set to true
		if [ "$MATCH" = true ]; then
			# Set 'duplicateCheck' to false
			duplicateCheck=false
			# Loop through the 'duplicates.txt' file
			while IFS= read -r dupeLine
			do
			# If the absolute file path of the linge image already exists in the duplicates.txt file
				if [ "$dupeLine" == "$line" ]; then
					# Set the duplicate check to true
					duplicateCheck=true
					# Exit the loop
					break
				fi
				# Send the duplicates variable (duplicates.txt) as the input for the loop
			done < "$DUPLICATES"
			
			# If duplicate check is still set to false (the absolute file path wasn't found in the duplicates.txt file)
			if [ "$duplicateCheck" = false ]; then
			# Send the absolute file path of the line image to the duplicates.txt file
				echo "$line" >> $DUPLICATES
			fi
		else
			# Set the copy name to the name of the image
			copyName=$IMGNAME
			# Get the extension from the name of the image
			EXTEN=$(echo $copyName | rev | cut -d'.' -f 1 | rev)
			# While a file exists with the copy name
			while [ -f $ARCHIVE/$copyName ]
			do
				# Add the extension on to the end of the existing image+extension
				# For example: x.jpg = x.JPG.JPG
				copyName="$copyName.$EXTEN"
			done
			# Copy the image into the archive folder with the new name
			cp $line $ARCHIVE/$copyName
		fi
	fi
# Send the temporary file storing the image file paths to the loop and use as input
done < "$tempFile"


# Tell the user the script is complete
echo "- - - Archive Complete - - -"

# Function to remove temporary files created during the running of the program
cleaner() {
	# Removed the temporary storing the absolute file paths of the images returned by the original find command
	rm -rf $tempFile
	# Exits the program
	exit
}

# Run the cleaner function
trap cleaner EXIT