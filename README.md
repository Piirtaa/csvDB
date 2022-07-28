# csvDB

"Relational database"-like functionality on CSV files done entirely in bash.

Since a CSV file is a set of fields data, it is possible to convert this data to files named for each field/value combination (within file system name limitations) consisting of line references to the source CSV.  This has the effect of creating an index file for each field/value, as searching for entries where field "A" has a value of "X" becomes as trivial as dumping the file contents of the file representing the combination of field="A" && value="X".  This conversion also facilitates set operations.  For example, returning the records where field "A"="X" and field "B"="Y" becomes an intersection between 2 files.  This is the premise of csvDB.

The advantages of this type of approach are:
 - Shell only.  No external dependencies.  
 - The dataset one is searching thru can be trivially split up into different file sets, and paralled processed using different shell instances.  The configuration of the splitting being the main variable with regards to achieving performance improvement.  ie. Scaling for read/query performance isn't that hard to do.
 - Since the data is contained in files the typical shell utilities like core-utils, etc. are available to refine queries.
 - Mutation of the underlying records can be reflected in underlying index files with relatively little difficulty.  Additionally it is very conceivable to handle mutations in separate files that could then be merged/overlayed afterwards, thus limiting the size of "critical sections" when concurrent mutations are happening.  Again, scaling performance on writes and not just reads is very conceivable.
 - The processing cost of querying is mostly done once per indexing/loading instead of per query.  Per query costs are in the set operations themselves and can be optimized with external (ie. non-shell) implementations.
 - Simple Design.  The core functionality exists within a few scripts, is not difficult to audit, is conceptually simple, and has a limited number of edges to worry about.

## Moving Parts:


### parseCSVDB.sh

This is the "importer".  This script parses the CSV according to the supplied configuration (which indicates which fields we want to index), and produces files with the naming standard of "***{Field}***\_.\_***{Value}***.txt" , placing these in the "data" subdirectory of the folder where parseCSVDB.sh exists.  The contents of these files will be lines of ***{Key} {SourceFile}***, identifying the source record. 

#### Usage:  
`./parseCSVDB.sh pathToMyConfigFile pathToMyCsvFile `
- where configFile is a text file containing the field mapping information describing the CSV.
 
#### config file layout:

line 1:  the csv file delimiter (must be a single character)

line 2:  the hasHeaderSwitch (must be "true" if there is a header line in the csvFile, or any other value to indicate there is no header line)

line 3:  ***{indexPos1} {indexPos2} {indexPos3}*** ... (space delimited list of field indices that constitute "the record key")

line 4+:  ***{posX} {fieldName}*** (space delimited integer and string mapping column to field name)
     


### queryCSVDB.sh

This is a utility to query the data.  

#### Usage:

##### lists all indexed fields

```
   ./queryCSVDB.sh -fields
```   

##### lists all values indexed for the field named "myField"
   
```
   ./queryCSVDB.sh -values myField
```   

##### validates the supplied query for correct syntax and schema 
 
```   
   ./queryCSVDB.sh -validate myQuery
```   

##### performs a query against the imported data returning a list of ***{Key} {SourceFile}***

``` 
   ./queryCSVDB.sh -query myQuery
```   

     
#### Query syntax:  

***{clauseA}*** _AND_ ***{clauseB}*** _AND_ ***{clauseC}*** ... 
   
#### Clause syntax:

***{operation}*** ***{myFieldname}*** ***{myFieldValue}*** (optional:) -matchOnKey 
 
 Operation can be one of:
 
 ***+***  (union) 
 
 ***-***  (remove) 
 
 ***N***  (intersection)
          
 If the switch "-matchOnKey" is provided in a clause, the set operation will only consider the "key" column as uniquely identifying a record rather than the default behaviour of "key & source" columns being considered uniquely identifying.  This allows for the same keys from different sources to be considered pointing to the same record as we carry out our set operations. 
     
 #### Query Example:  find the set of FieldA/ValueA, and intersect this with the set of FieldB/ValueB, and remove the set of FieldC/ValueC using keys only
  
 `+ FieldA ValueA _AND_ N FieldB ValueB _AND_ - FieldC ValueC -matchOnKey`
 
        
     
      
      
