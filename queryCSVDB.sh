#!/bin/bash
#usage:  queryCSVDB.sh 

#string helpers---------------------------------------------------------

#description:  returns standard in
#usage:  STDIN=$(getStdIn)
getStdIn()
{
	local STDIN
	STDIN=""
	if [[ -p /dev/stdin ]]; then
		STDIN="$(cat -)"
	else
		return 1	
	fi
	echo "$STDIN"
	return 0
}
readonly -f getStdIn

#description:  gets index of substring.  -1 if not found
#usage: echo abcdef | getIndexOf cd
getIndexOf()
{
	local STDIN SEARCH POS STRING RV
	STDIN=$(getStdIn)
	SEARCH="$1"
	   
	# strip the first substring and everything beyond
	STRING="${STDIN%%"$SEARCH"*}"
	RV=$?
	
	#note if the search string is not found the entire string is returned
	if [[ "$STRING" == "$STDIN" ]]; then
		echo "-1"
		return 0
	fi
	
	if [[ "$RV" == 0 ]]; then
		# the position is calculated
		POS=${#STRING}
 		echo "$POS"
 		return 0	
	fi
	
	return 1
}
readonly -f getIndexOf

#description:  gets portion of string before provided argument
#usage: echo abcdef | getBefore cd (opt) -echoIfNotFound
getBefore()
{	
	local STDIN SEARCH POS RV
	STDIN=$(getStdIn)
	SEARCH="$1"
	POS=$(getIndexOf "$SEARCH" < <(echo "$STDIN"))
	RV=$?
	
	if [[ "$RV" == 0 ]]; then
		if [[ "$POS" == "-1" ]]; then
			if [[ "$2" == "-echoIfNotFound" ]]; then
				echo "$STDIN"
				return 0
			fi
			return 1	
		else 
			echo "${STDIN:0:$POS}"
			return 0	
		fi 
	fi
	return 1
}
readonly -f getBefore

#description:  gets portion of string after provided argument
#usage: echo abcdef | getAfter cd (opt) -echoIfNotFound
getAfter()
{
	local STDIN SEARCH POS RV LEN
	STDIN=$(getStdIn)
	SEARCH="$1"
	POS=$(getIndexOf "$SEARCH" < <(echo "$STDIN"))
	RV=$?
	if [[ "$RV" == 0 ]]; then
		if [[ "$POS" == "-1" ]]; then
			if [[ "$2" == "-echoIfNotFound" ]]; then
				echo "$STDIN"
				return 0
			fi
			return 1	
		else 
			LEN="${#SEARCH}"
			POS=$((POS + LEN))
			echo "${STDIN:$POS}"
			return 0
		fi	
	fi
	return 1
}
readonly -f getAfter

#field and fieldValue lookup functions----------------------------------
KEYDELIM="_/_"
FIELDDELIM="_._"
	
#description: gets all fields 
#usage:  getAllFields
getAllFields()
{
	local FILE FIELDVALUE FIELD
    for FILE in ./data/*; do
        FIELDVALUE=$(basename -s .txt "$FILE") 
        echo "$FIELDVALUE" | getBefore "$FIELDDELIM" 
    done | sort | uniq
}

#description: gets all field values  
#usage:  getAllFieldValues field
getAllFieldValues()
{
	local FIELD 
	FIELD="$1"
	
	local FILE 
    for FILE in ./data/"$FIELD""$FIELDDELIM"*; do
        basename -s .txt "$FILE" | getAfter "$FIELDDELIM"
    done | sort | uniq
}

#description:  returns the ids/source 
#usage:  getFieldValueSet field value 
getFieldValueSet()
{
	local FIELD VALUE 

	FIELD="$1"
	VALUE="$2"
	
	local FILEPATH
	FILEPATH=./data/"$FIELD""$FIELDDELIM""$VALUE".txt
	if [[ ! -f "$FILEPATH" ]]; then
		LAST_ERROR="invalid field value set ""$FIELD"" ""$VALUE"
		return 1 
	fi
	
	cat "$FILEPATH" 
	return 0
}


#define query functions-------------------------------------------------
#ie. mutations, validation, execution of

#state
LAST_ERROR=""

#validations:

#description:  validates field value exist
#usage:  validateFieldValue field value
validateFieldValue()
{
	local FIELD VALUE 

	FIELD="$1"
	VALUE="$2"
	
	local FILEPATH
	FILEPATH=./data/"$FIELD""$FIELDDELIM""$VALUE".txt
	
	#does the fieldvalue file exist?
	if [[ ! -f "$FILEPATH" ]]; then
		LAST_ERROR="invalid field value set ""$FIELD"" ""$VALUE"
		return 1 
	fi
	return 0
}

#query syntax:
#+ field value (opt) -matchOnKey-> union (ie. increase working set)
#N field value (opt) -matchOnKey-> intersect (ie. decrease working set)
#- field value (opt) -matchOnKey-> remove (ie. decrease working set)
#matchOnKey means that any set operations will only consider key and not key/source 

STEPDELIM="_AND_"
#example queries
#+ myField myValueA _AND_ + myField myValueB _AND_ - myFieldB myValueC true

#description:  splits query into steps and populates provided array
#usage:  splitQueryIntoSteps arrayName query
__splitQueryIntoSteps()
{
	local -n MYARRAY=$1 #uses nameref bash 4.3+
	shift;
	local QUERY
	QUERY="$@"
	
	local STEP RV
	while true; do
		STEP=$(echo "$QUERY" | getBefore "$STEPDELIM" -echoIfNotFound | xargs)
		MYARRAY+=("$STEP")
		QUERY=$(echo "$QUERY" | getAfter "$STEPDELIM")
		RV=$?
		if [[ "$RV" == 1 ]]; then
			break
		fi
	done
	
	return 0
}

#description:  walks the query expression and validates each filter
#usage:  validateQuery query
validateQuery()
{
	local QUERY
	QUERY="$@"
	
	#if the query is empty return error
	if [[ -z "QUERY" ]]; then
		return 1
	fi
	
	local SPLIT=()
	__splitQueryIntoSteps SPLIT "$QUERY"
	
	local CLAUSE ARGS RV
	for CLAUSE in "${SPLIT[@]}"
	do
		#there should be 3-4 parts
		ARGS=($CLAUSE)

		case "${ARGS[0]}" in
			"+" | "-" | "N" | "n" )
				validateFieldValue "${ARGS[1]}" "${ARGS[2]}"
				RV=$?
				if [[ "$RV" != 0 ]]; then
					LAST_ERROR="invalid field value in '""$CLAUSE""'"
					return 1
				fi
				
				if [[ ! -z "${ARGS[3]}" ]]; then
					if [[ "${ARGS[3]}" != "-matchOnKey" ]]; then
						LAST_ERROR="invalid switch in '""$CLAUSE""'"
						return 1
					fi
				fi
				;;
			*)
				LAST_ERROR="invalid operation in '""$CLAUSE""'"
				return 1
				;;
		esac
	done

	return 0
}

#query functions:



#description:  evaluates a query expression returning ids/source
#usage:  runQuery query
runQuery()
{
	local QUERY
	QUERY="$@"
	
	#if the query is empty return error
	if [[ -z "QUERY" ]]; then
		return 1
	fi

	local SPLIT=()
	__splitQueryIntoSteps SPLIT "$QUERY"
	
	local CLAUSE ARGS RV WORKINGSET CLAUSESET TEMPWORKINGSET TEMPCLAUSESET PADSET LEN
	for CLAUSE in "${SPLIT[@]}"
	do
		#there should be 3-4 parts
		ARGS=($CLAUSE)

		case "${ARGS[0]}" in
			"+" )
				#union
				CLAUSESET=$(getFieldValueSet "${ARGS[1]}" "${ARGS[2]}")
				if [[ ! -z "$LAST_ERROR" ]]; then
					return 1
				fi
				
				#we don't care about -matchOnKey for unions
				WORKINGSET=$(cat <(echo "$WORKINGSET") <(echo "$CLAUSESET") | sort | uniq)
				;;
			"N" | "n" )
				#intersect
				CLAUSESET=$(getFieldValueSet "${ARGS[1]}" "${ARGS[2]}")
				if [[ ! -z "$LAST_ERROR" ]]; then
					return 1
				fi
				
				if [[ ! -z "${ARGS[3]}" ]] && [[ "${ARGS[3]}" == "-matchOnKey" ]]; then
					TEMPWORKINGSET=$(echo "$WORKINGSET" | cut -d ' ' -f1)
					TEMPCLAUSESET=$(echo "$CLAUSESET" | cut -d ' ' -f1)
					
					#get common entries
					#-1 :suppress first column(lines unique to first file).
					#-2 :suppress second column(lines unique to second file).
					TEMPWORKINGSET=$(comm -1 -2 <(echo "$TEMPWORKINGSET") <(echo "$TEMPCLAUSESET") | sort | uniq)
					
					#create a padding set
					LEN=$(echo "$TEMPWORKINGSET" | wc -l) 
					PADSET=$(yes "_PAD_" | head -n "$LEN")
					 
					#paste to temp working set
					TEMPWORKINGSET=$(paste <(echo "$TEMPWORKINGSET") <(echo "$PADSET"))
					
					#now remerge temp working set with working set
					TEMPWORKINGSET=$(join <(echo "$TEMPWORKINGSET") <(echo "$WORKINGSET"))

					#every line with PAD on it is what we want
					TEMPWORKINGSET=$(echo "$TEMPWORKINGSET" | grep "_PAD_")
					
					#now remove the PAD column
					WORKINGSET=$(echo "$TEMPWORKINGSET" | cut -d ' ' -f3)
				else
					WORKINGSET=$(comm -1 -2 <(echo "$WORKINGSET") <(echo "$CLAUSESET") | sort )
				fi
				;;
			"-" )
				#remove
				CLAUSESET=$(getFieldValueSet "${ARGS[1]}" "${ARGS[2]}")
				if [[ ! -z "$LAST_ERROR" ]]; then
					return 1
				fi
				
				if [[ ! -z "${ARGS[3]}" ]] && [[ "${ARGS[3]}" == "-matchOnKey" ]]; then
					TEMPWORKINGSET=$(echo "$WORKINGSET" | cut -d ' ' -f1)
					TEMPCLAUSESET=$(echo "$CLAUSESET" | cut -d ' ' -f1)

					#get entries only in TEMPWORKINGSET
					#-1 :suppress first column(lines unique to first file).
					#-2 :suppress second column(lines unique to second file).
					#-3 :suppress third column(lines common to both files).
					TEMPWORKINGSET=$(comm -2 -3 <(echo "$TEMPWORKINGSET") <(echo "$TEMPCLAUSESET") | sort | uniq)
					
					#create a padding set
					LEN=$(echo "$TEMPWORKINGSET" | wc -l) 
					PADSET=$(yes "_PAD_" | head -n "$LEN")
					 
					#paste to temp working set
					TEMPWORKINGSET=$(paste <(echo "$TEMPWORKINGSET") <(echo "$PADSET"))
					
					#now remerge temp working set with working set
					TEMPWORKINGSET=$(join <(echo "$TEMPWORKINGSET") <(echo "$WORKINGSET"))

					#every line with PAD on it is what we want
					TEMPWORKINGSET=$(echo "$TEMPWORKINGSET" | grep "_PAD_")
					
					#now remove the PAD column
					WORKINGSET=$(echo "$TEMPWORKINGSET" | cut -d ' ' -f3)
				else
					WORKINGSET=$(comm -2 -3 <(echo "$WORKINGSET") <(echo "$CLAUSESET") | sort )
				fi
				;;	
			*)
				LAST_ERROR="invalid operation in '""$CLAUSE""'"
				return 1
				;;
		esac
	done
	
	#return the result
	echo "$WORKINGSET"
	return 0
}


SWITCH="$1"
shift

#the command switches
case "$SWITCH" in
	fields)
			getAllFields 
			;;
	values)
			getAllFieldValues "$1"
			;;
	validate)
			validateQuery "$@"
			if [[ ! -z "$LAST_ERROR" ]]; then
				echo error "$LAST_ERROR"
			else
				echo valid
			fi
			;;
	query)
			runQuery "$@"
			;;
	*)
			args=( "fields" "values" "validate" "query" )
			desc=( "lists all fields" "lists all values for a given field.  eg. values MYFIELD " "validates a query expression. eg. + myField myValueA -> + myField myValueB -> - myFieldB myValueC true" "performs a query.  eg. query + myField myValueA -> + myField myValueB -> - myFieldB myValueC true" )
			echo -e "Usage:\tqueryCSVDB.sh [argument]\n"
			for ((i=0; i < ${#args[@]}; i++))
			do
				printf "\t%-15s%-s\n" "${args[i]}" "${desc[i]}"
			done
			exit
			;;
esac

