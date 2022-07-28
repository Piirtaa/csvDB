# csvDB
"relational database"-like functionality on CSV files done entirely in bash

Since a CSV file is a set of fields data, it is possible to convert this data to files named for each field/value combination (within file system name limitations) consisting of line references to the source CSV.  This has the effect of creating an index file for each field/value, as searching for "entries where field A has a value of X" becomes as trivial as dumping the file contents of the file representing the "field=A"/"value=X" combination.  This conversion also facilitates set operations.  For example, return the records where Field A = X and Field B = Y.  This is the premise of csvDB.

##Moving Parts:

###parseCSVDB.sh
usage:  `./parseCSVDB.sh configFile csvFile`
 - where configFile is a text file containing the mapping information describing csvFile
  - it has the layout:
   - line 1:  delimiter (must be single character
   - line 2:  hasHeaderSwitch (must be "true" if there is a header line in the csvFile.  or any other value to indicate there is no header line)
   - line 3:  indexPos1 indexPos2 indexPos3 ... (space delimited list of field indices that constitute "the record key")
   - line 4+:  posX fieldName (space delimited integer and string mapping column to field name)
  
 - This is the "importer".  This script parses the CSV according to the supplied configuration (which indicates which fields we want to index), and produces files with the naming standard of *Field*_._*Value*.txt, placing these in the "data" subdirectory of the folder where parseCSVDB.sh exists.  The contents of these files will be lines of *Key* *SourceFile*.    
      
      
###queryCSVDB.sh
usage:  
 `./queryCSVDB.sh fields`
  - lists all indexed fields
      
 `./queryCSVDB.sh values *myField*`
  - lists all values indexed for the field named "myField"
      
 `./queryCSVDB.sh validate *my query*`
  - validates the supplied query for correct syntax and schema 
      
 `./queryCSVDB.sh query *my query*`
  - performs a query against the imported data returning a list of *Key* *SourceFile*
     
 query syntax:
  `*clause* _AND_ *clause* _AND_ *clause* ...`
   - where a clause has the syntax:
    - `*operation* *fieldname* *value* (optional switch: "-matchOnKey")`
   - where operation can be one of:
    - `+` 
     union 
    - `-` 
     removal 
    - `N` 
     intersection
          
   - if the switch "-matchOnKey" is provided in a clause it will only use the "key" column in the set operation and not the "key & source" columns.
      this allows for the same keys from different sources to be considered pointing to the same set record as we carry out our set operations. 
     
   for example:  
    `+ FieldA ValueA _AND_ N FieldB ValueB _AND_ - FieldC ValueC`
     will find the set of FieldA/ValueA and intersect this with the set of FieldB/ValueB and remove the set of FieldC/ValueC
        
     
      
      
