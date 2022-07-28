#!/bin/bash
#usage:  parseCSVDB.sh configFile fileToParse 

#configFile has format:
	#	delimiter (must be single character)
	#	hasHeaderSwitch (must be "true" or defaults to no header line)
	#	indexPos1 indexPos2 indexPos3 ... (space delimited list of indices that constitute "the record key")
	#	pos fieldName (space delimited integer and string)
	#	pos fieldName 
	#  	...
	
#configFile defines the output files to generate
#	eg. if the file contained a field line of "1 myfield"
#		a line would be appended to a file named "myfield{valueOfField}"
#			where {valueOfField} would be whatever the field value was on a given line
#			and the contents of the line would be {valueOfIndex1}_{valueOfIndex2}...

#behaviour:
#	split csv into fields/data pointing to the core record (ie. key and filesource) (this avails query)
#	provide a list of all possible fields (this avails autocompletion)
#	provide a list of all possible data for a given field (this avails autocompletion)

CONFIGFILE="$1"
if [[ -z "$CONFIGFILE" ]]; then
	echo "no configuration provided"
	exit 1
fi

PARSEFILE="$2"
if [[ -z "$PARSEFILE" ]]; then
	echo "no file to parse provided"
	exit 1
fi

#define indices and fields to parse
DELIM=""
HASHEADER="false"
INDICES=()
declare -A FIELDS

#hydrates configuration variable
parseConfig()
{
	local LINE 
	
	#redirect stdin to read from $CONFIGFILE
	exec < "$CONFIGFILE"
	
	#read the delimiter
	read LINE
	DELIM="${LINE:=,}"
	#echo delim "$DELIM"
	
	#read the hasheader line
	read LINE
	if [[ "$LINE" = "true" ]]; then
		HASHEADER="true"
	fi
	#echo hasheader "$HASHEADER"
	
	#read the indices line
	read LINE
	INDICES=($LINE)
	#echo indices "$INDICES"
	
	#read the field lines
	while read LINE
	do
		local SPLIT
		SPLIT=($LINE)
		#split the field line into 2 parts
		FIELDS["${SPLIT[0]}"]="${SPLIT[1]}"
		
		#echo field "${SPLIT[0]}" "${SPLIT[1]}"
	done 
}
readonly -f parseConfig

#reads each line of the parse file and creates the field entry
parseFile()
{
	local LINE KEYDELIM FIELDDELIM
	KEYDELIM="_/_"
	FIELDDELIM="_._"
	
	#redirect stdin to read from $PARSEFILE
	exec < "$PARSEFILE"
	
	#read the header/index line
	if [[ "$HASHEADER" = "true" ]]; then
		read LINE #read the first line to advance the cursor
	fi

	#read the lines
	while read LINE
	do
		#read line into an array splitting by comma 
		unset SPLIT
		local SPLIT
		IFS=', ' read -r -a SPLIT <<< "$LINE"
		
		#compose the key
		unset IDX KEY KEYVAL
		local IDX KEY KEYVAL
		for IDX in "${INDICES[@]}"; do
			#echo idx "$IDX"
			KEYVAL="${SPLIT[$IDX]}"
			#echo keyval "$KEYVAL"
			if [[ -z "$KEY" ]] ; then
				KEY="$KEYVAL"
			else
				KEY="$KEY""$KEYDELIM""$KEYVAL"
			fi
		done
		
		#process each configured field
		unset FIELDNAME VAL FILENAME SCRUB
		local FIELDNAME VAL FILENAME SCRUB
		for IDX in "${!FIELDS[@]}"; do
			VAL="${SPLIT[$IDX]}"
			
			#skip empty fields
			if [[ -z "$VAL" ]]; then
				VAL="NULL"
			fi
			
			FIELDNAME="${FIELDS[$IDX]}"
			FILENAME="$FIELDNAME""$FIELDDELIM""$VAL"

			#scrub FILENAME
			SCRUB=${FILENAME//[^A-Za-z0-9._-]/_} 
			
			#write the field record
			echo "$KEY" "$PARSEFILE" >> ./data/"$SCRUB".txt
		done
	done 
}
readonly -f parseFile

parseConfig
parseFile
