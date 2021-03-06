#!/usr/bin/bash

#Search LOC.gov and OCLC Classify for Library of Congress Classification (LCC) numbers associated with standard number (ISBN, OCLC, UPC, ISSN, etc.) of text file (arg. #1), outputting into one output file (arg. #2).
# If LCC is not found, Dewey tried; if neither found, output will not contain a record for the particular ISBN.

input=`cat ${1:?First argument missing: File containing list of standard numbers (ISBN, OCLC, ISSN, UPC, etc.) required.} | sort -nu | sed '/^$/d'`
output=${2:?Second argument missing: Name of file containing found LCCs required.}

rm -f .tmp?.txt

echo -e "\nFinding LCCs in LOC.gov, using ISBNs...\n"
for i in ${input}
do
    xml=`curl -s "http://lx2.loc.gov:210/lcdb?operation=searchRetrieve&query=bath.isbn=$i&maximumRecords=1&recordSchema=mods"` #https://stackoverflow.com/a/27877972/1429450
    lcc=`echo $xml | grep -o "\"lcc\">[^<]*<" | sed 's/\"lcc\">\([^>]*\)</\1/'`
    title=`echo $xml | grep -o "<title>[^<]*</title>" | sed 's/<title>\([^>]*\)<\/title>/\1/' | tr '\n' ' ' | cut -c-32`
    author=`echo $xml | grep -o "<namePart>[^<]*</namePart>" | sed 's/<namePart>\([^>]*\)<\/namePart>/\1/' | head -n 1 | tr '\n' ' ' | cut -c-32`

    if [[ $lcc ]]; then #if LCC found
	printf "%-24s | %13s | %-32s | %-32s\n" "$lcc" "$i" "$title" "$author" | tee -a .tmp1.txt
    fi
done
touch .tmp1.txt #in case it doesn't yet exist

echo -e "\nFinding LCCs in OCLC Classify, using standard number (ISBN, OCLC, ISSN, UPC, etc.)...\n"
for i in ${input}
do
    xml=`curl -s "http://classify.oclc.org/classify2/Classify?stdnbr=$i&summary=truei&maxrecs=1&orderBy=hold%20desc"`
    response=`echo $xml | grep -oP '<response code="\K[^"]*(?="/>)' | head -1`
    while [[ $response == "4" ]]; do
	owi=`echo $xml | grep -oP 'owi="\K[^"]*(?=")' | head -1`
	xml=`curl -s "http://classify.oclc.org/classify2/Classify?owi=$owi&summary=truei&maxrecs=1&orderBy=hold%20desc"`
	response=`echo $xml | grep -oP '<response code="\K[^"]*(?="/>)' | head -1`
    done

    lcc=`echo $xml | grep -oP 'nsfa="\K[^"]*(?=")' | tail -1`
    title=`echo $xml | grep -oP 'title="\K[^"]*(?=")' | head -1 | cut -c-32`
    author=`echo $xml | grep -oP '<author[^>]*>\K[^<]*(?=</author>)' | head -1 | cut -c-32`

    if [[ $lcc == "FIC" ]]; then
	lcc=`echo $xml | grep -oP 'nsfa="\K[0-9][^"]*(?=")' | tail -1`
    fi

    if [[ $lcc ]]; then #if LCC found
	printf "%-24s | %13s | %-32s | %-32s\n" "$lcc" "$i" "$title" "$author" | tee -a .tmp2.txt
    fi
done
touch .tmp2.txt #in case it doesn't yet exist

echo -e "\nMerging duplicate ISBNs (preferring LCCs from LOC.gov)..."
sort -bunt '|' -k2,2 .tmp1.txt .tmp2.txt | sort -bn | ./sort_LCCs.pl | tee "${output}" #select 1st occurrence (LOC result) of duplicate ISBNs only
echo -e "\nOutput written to ${output}."

echo -e "\nCleaning up..."
rm -vf .tmp1.txt .tmp2.txt

echo -e "\nDone."
