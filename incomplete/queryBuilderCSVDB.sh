#!/bin/bash
#usage:  queryBuilderCSVDB.sh 

#starts a cli client that builds a query
	#displays existing query expression at top	

#initial dialog
#	on l ->	list fields dialog
#			on s -> list field/values dialog
#					on u -> union with current expression
#					on i -> intersect with current expression
#					on r -> remove from current expression
#	on h -> list query history dialog
#			on s -> select item
#	on c -> clear current expression dialog
#	on e -> edit current expression dialog
#	on q -> run query dialog


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

#description:  gets index of substring
#usage: echo abcdef | getIndexOf cd
getIndexOf()
{
	local STDIN SEARCH POS STRING RV
	STDIN=$(getStdIn)
	SEARCH="$1"
	   
	# strip the first substring and everything beyond
	STRING="${STDIN%%"$SEARCH"*}"
	RV=$?
	
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
#usage: echo abcdef | getBefore cd
getBefore()
{	
	local STDIN SEARCH POS RV
	STDIN=$(getStdIn)
	SEARCH="$1"
	POS=$(getIndexOf "$SEARCH" < <(echo "$STDIN"))
	
	RV=$?
	if [[ "$RV" == 0 ]]; then
		echo "${STDIN:0:$POS}"
		return 0	
	fi
	return 1
}
readonly -f getBefore

#description:  gets portion of string after provided argument
#usage: echo abcdef | getAfter cd
getAfter()
{
	local STDIN SEARCH POS RV LEN
	STDIN=$(getStdIn)
	SEARCH="$1"
	POS=$(getIndexOf "$SEARCH" < <(echo "$STDIN"))
	
	RV=$?
	if [[ "$RV" == 0 ]]; then
		LEN="${#SEARCH}"
		POS=$((POS + LEN))
		echo "${STDIN:$POS}"
		return 0	
	fi
	return 1
}
readonly -f getAfter

#define query functions-------------------------------------------------
#ie. mutations, validation, execution of

#jargon:
#	a "fieldValue set" is a file named {field}.{value}.txt that is created by parseCSVDB.sh.  it contains the key and sourcefile it came from.
#	a "working set" are datalines of key/sourceCSV that are the result of "filters"
#  	a "filter" are the contents of a "fieldValue set" and whether this data will INTERSECT or UNION with the "working set"
#	a "query" is a set of filters interpreted left to right and operates on the "working set"    

#state
LAST_ERROR=""
EXPRDELIM="___"

#validations:

#description:  validates a filter (ie. a single query step)
#usage:  validateFilter op(UNION, INTERSECT) fieldValue
validateFilter()
{
	local FIELDVALUE OP
	OP="$1"
	
	if [ "$OP" != "UNION" ] && [ "$OP" != "INTERSECT" ]; then
		#error
		LAST_ERROR="invalid filter ""$@"
		return 1
	fi
	shift
	FIELDVALUE="$@"
	local SPLIT=($FIELDVALUE)
	
	#does the fieldvalue file exist?
	if [[ ! -f ./data/"${SPLIT[0]}".txt ]]; then
		LAST_ERROR="invalid filter ""$@" - "fieldvalue file does not exist"
		return 1
	fi
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

	local BEFORE CAKE RV
	CAKE="$QUERY"
	BEFORE=""
	RV=0
	
	#keep slicing cake before the delimiter
	while true; do
		BEFORE=""
		BEFORE=$(echo "$CAKE" | getBefore "$EXPRDELIM")

		#if there is a delimiter we can still parse the next step
		if [[ ! -z "$BEFORE" ]]; then
			validateFilter "$BEFORE"
			RV=$?
			if [[ "$RV" != 0 ]]; then
				break
			fi
			
			CAKE=$(echo "$CAKE" | getAfter "$EXPRDELIM")
		else
			#there is no delimiter so the query is a single step 
			validateFilter $CAKE
			RV=$?
	
			break
		fi
	done
	return "$RV"
}

#query functions:

#description:  returns the ids/source 
#usage:  runFilter fieldValue #todo:  (opt) operation (opt) opArg
runFilter()
{
	local FIELDVALUE
	FIELDVALUE="$1"
	if [[ -z "$FIELDVALUE" ]]; then
		return 1
	fi
	
	cat ./data/"$FIELDVALUE".txt # | cut -d ' ' -f1
}

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

	local FILTER CAKE RV WORKINGSET FILTERSET SPLIT FIELDVALUE OP
	CAKE="$QUERY"
	FILTER=""
	RV=0
	WORKINGSET=""
	FILTERSET=""
	
	#get the first filter
	FILTER=$(echo "$CAKE" | getBefore "$EXPRDELIM")
	RV=$?
	
	#we don't have any delimiters so we have a single filter statement
	if [[ "$RV" != 0 ]]; then
		FILTER="$CAKE"
	fi
	
	SPLIT=($FILTER)
	#for the first filter we ignore UNION and INTERSECTION directives
	#OP="${SPLIT[0]}"
	FIELDVALUE="${SPLIT[1]}"
	WORKINGSET=$(runFilter "$FIELDVALUE")
	
	#slice the cake
	CAKE=$(echo "$CAKE" | getAfter "$EXPRDELIM")
		
	while true; do
		if [[ -z "$CAKE" ]]; then
			break
		fi
		
		FILTER=$(echo "$CAKE" | getBefore "$EXPRDELIM")
		RV=$?
		
		if [[ "$RV" != 0 ]]; then
			FILTER="$CAKE"
		fi
			
		#get the components of the filter
		SPLIT=($FILTER)
		OP="${SPLIT[0]}"
		FIELDVALUE="${SPLIT[1]}"
	
		#get the filter set
		FILTERSET=$(runFilter "$FIELDVALUE")
		
		if [[ "$OP" == "UNION" ]]; then
			#it's a union
			WORKINGSET=$(cat <(echo "$WORKINGSET") <(echo "$FILTERSET") | sort)
		else
			#it's an intersection
			WORKINGSET=$(comm -1 -2 <(echo "$WORKINGSET") <(echo "$FILTERSET") | sort)
		fi
		
		#slice the cake
		CAKE=$(echo "$CAKE" | getAfter "$EXPRDELIM")
	done
	
	echo "$WORKINGSET"
	return 0
}

#mutations:
WORKINGQUERY=""

#description:  sets working query 
#usage:  setWorkingQuery query
setWorkingQuery()
{
	local QUERY RV
	QUERY="$1"
	validateQuery "$QUERY"
	RV=$?
	
	if [[ "$RV" = 0 ]]; then
		WORKINGQUERY="$QUERY"
	fi
}

#description:  adds a filter
#usage:  appendWorkingQuery op(UNION, INTERSECT) filter
appendWorkingQuery()
{
	local FILTER OP
	OP="$1"
	
	if [ "$OP" != "UNION" ] && [ "$OP" != "INTERSECT" ]; then
		#error
		LAST_ERROR="invalid query operation"
		return 1
	fi
	shift
	FILTER="$@"
	
	local QUERY
	QUERY="$WORKINGQUERY"
	
	if [[ -z "$QUERY" ]]; then
		QUERY="$OP"" ""$FILTER"
	else
		QUERY="$QUERY""$EXPRDELIM""$OP"" ""$FILTER"
	fi
	
	setWorkingQuery "$QUERY"
	return 0
}

#description:  resets working query
#usage:  clearWorkingQuery
clearWorkingQuery()
{
	WORKINGQUERY=""
	return 0
}


#field and fieldValue lookup functions----------------------------------

#description:  gets all of the datafiles and parses fieldname
#usage:  getAllDataFieldNames
getAllDataFieldNames()
{
	local FILE 
    for FILE in ./data/*; do
        #skip directories
        [[ -d $FILE ]] || continue

        echo "${FILE%%.*}"
        #$(basename "$FILE") )
    done
}

#description: gets all fields 
#usage:  getAllFields
getAllFields()
{
	local FIELDS
	FIELDS=$(getAllFilePrefixes | sort | uniq)
	echo "$FIELDS"
}

#description: gets all field values  
#usage:  getAllFieldValues field
getAllFieldValues()
{
	local FIELD 
	FIELD="$1"
	
	local FILE 
    for FILE in ./data/"$FIELD."*; do
        #skip directories
        [[ -d $FILE ]] || continue

        echo "${FILE%.*}"
        #$(basename "$FILE") )
    done | sort | uniq
}

#dialog functions-------------------------------------------------------

#chaining together the state machine of this
initialDialog()
{
	echo current query = "$QUERYEXPR"
	echo 
	echo commands:
	echo press l to list fields
	echo press h to show query history 
	echo press c to clear current query expression
	echo press e to edit current query expression
	echo press r to run current query expression
	echo press q to quit 
	echo
	
	local selection
	while true; do
		read selection
		case $selection in
			[Ll]* ) listFieldsDialog; break;;
			[Hh]* ) listHistoryDialog; break;;
			[Cc]* ) clearQueryDialog; break;;
			[Ee]* ) editQueryDialog; break;;
			[Rr]* ) runQueryDialog; break;;
			[Qq]* ) exit;;
		esac
	done
}			

listFieldsDialog()
{
	clear
	echo current query = "$QUERYEXPR"
	echo 
	echo select field
	local FIELDS ITEM
	FIELDS="__back "$(getAllFields)
	select ITEM in "$FIELDS"
	do
		if [[ "$ITEM" = "__back" ]]; then
			#go back to the prior dialog
			initialDialog
		else 
			listFieldValuesDialog "$ITEM"
		fi
	done
}

#usage:  listFieldValuesDialog prefix
listFieldValuesDialog()
{
	clear
	echo current query = "$QUERYEXPR"
	echo 
	echo select fieldvalue
	local FIELD FIELDVALUES ITEM
	FIELD="$1"
	FIELDVALUES="__back "$(getAllFieldValues "$FIELD")
	select ITEM in "$FIELDVALUES"
	do
		if [[ "$ITEM" = "__back" ]]; then
			#go back to the prior dialog
			listFieldsDialog
		else 
			selectFieldValuesDialog "$ITEM"
		fi
	done
}

#usage: selectFieldValuesDialog fieldValue
selectFieldValuesDialog()
{
	clear
	echo current query = "$QUERYEXPR"
	echo 
	echo select fieldvalue
	local FIELDVALUE OPTIONS 
	FIELDVALUE="$1"
	OPTIONS="__back union intersect remove"
	select ITEM in "$OPTIONS"
	do
		if [[ "$ITEM" = "__back" ]]; then
			#go back to the prior dialog
			listFieldsDialog
		fi
		case $selection in
			[__back]* ) listFieldValuesDialog "${FIELDVALUE%%.*}"; break;;
			[union]* ) listHistoryDialog; break;;
			[intersect]* ) clearQueryDialog; break;;
			[remove]* ) editQueryDialog; break;;
		esac
	done
}

queryHistoryDialog()
{
	
}




