#!/usr/bin/bash

#Search LOC.gov and OCLC Classify for Library of Congress Numbers (LCNs) associated with ISBNs of text file (arg. #1), merging results into one output file (arg. #2). If output file already exists, results are appended to it.

input=`cat ${1:?First argument missing: File containing list of ISBNs required.} | sort -nu | sed '/^$/d'`
output=${2:?Second argument missing: Name of file containing found LCNs required.}

rm -f .tmp?.txt

echo "Finding LCNs in LOC.gov..."
for i in ${input}
do
    xml=`curl -s "http://lx2.loc.gov:210/lcdb?operation=searchRetrieve&query=bath.isbn=$i&maximumRecords=1&recordSchema=mods"` #https://stackoverflow.com/a/27877972/1429450
    lcc=`echo $xml | grep -o "\"lcc\">[^<]*<" | sed 's/\"lcc\">\([^>]*\)</\1/'`
    title=`echo $xml | grep -o "<title>[^<]*</title>" | sed 's/<title>\([^>]*\)<\/title>/\1/' | tr '\n' ' ' | cut -c-32`
    author=`echo $xml | grep -o "<namePart>[^<]*</namePart>" | sed 's/<namePart>\([^>]*\)<\/namePart>/\1/' | head -n 1 | tr '\n' ' ' | cut -c-32`

    if [[ $lcc ]]; then #if LCN found
	printf "%-24s | %13s | %-32s | %-32s\n" "$lcc" "$i" "$title" "$author" | tee -a .tmp1.txt
    fi    
done

echo -e "\nFinding LCNs in OCLC Classify..."
for i in ${input}
do
    xml=`curl -s "http://classify.oclc.org/classify2/Classify?isbn=$i&summary=true"`
    lcc=`echo $xml | grep -oP 'nsfa="\K[^"]*(?=")' | tail -1`
    title=`echo $xml | grep -oP 'title="\K[^"]*(?=")' | head -1 | cut -c-32`
    author=`echo $xml | grep -oP '<author[^>]*>\K[^<]*(?=</author>)' | head -1 | cut -c-32` 

    if [[ $lcc == "FIC" ]]; then
	lcc=`echo $xml | grep -oP 'nsfa="\K[0-9][^"]*(?=")' | tail -1`
    fi

    if [[ $lcc ]]; then #if LCN found
	printf "%-24s | %13s | %-32s | %-32s\n" "$lcc" "$i" "$title" "$author" | tee -a .tmp2.txt
    fi    
done

echo -e "\nMerging duplicate ISBNs (preferring LCNs from LOC.gov)..."
sort -nbut '|' -k2,2 .tmp1.txt .tmp2.txt | sort -but '|' -k1,1 | tee -a ${output}
echo -e "\nOutput written to ${output}."

echo -e "\nCleaning up..."
rm -vf .tmp1.txt .tmp2.txt

echo -e "\nDone."
