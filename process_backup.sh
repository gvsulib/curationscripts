#!/bin/bash

#ignore certain non-catascrophic errors and proceed with the script
if [ "$1" = "IGNORE-ERRORS" ] || [ "$2" = "IGNORE-ERRORS" ]
then
	IGNOREERROR=1
else 
	IGNOREERROR=0
fi


#turn emailing on and off.  Neccessary if you are manually running the script
if [ "$1" = "NO-EMAIL" ] || [ "$2" = "NO-EMAIL" ]
then
        EMAILSEND=0
else 
        EMAILSEND=1
fi


#configuration variables
EMAIL="felkerk@gvsu.edu"

AWSURL="scholarworksbackup/archive/scholarworks.gvsu.edu"

COPYLOCATION="./scholarworks/"

LOGLOCATION="./"

DATE=`date +%Y-%m-%d`

rm -r ${LOGLOCATION}process.log

rm -r ${LOGLOCATION}sync_error.log

rm -r ${LOGLOCATION}reporting_error.log

touch ${LOGLOCATION}process.log || { echo "could not create process logfile" >&2; exit 1; }

touch ${LOGLOCATION}sync_error.log || { echo "could not create sync error logfile" >&2; exit 1; }

touch ${LOGLOCATION}reporting_error.log || { echo "could not create reporting error logfile" >&2; exit 1; }

rm -r $COPYLOCATION
if [ $EMAILSEND -ne 0 ]
then
	echo "Beginning processing of Scholarworks files." | mail  -s "Scholarworks curation process beginning" $EMAIL || { echo "Cannot send email: check email logs" | tee process.log; exit 1; }
fi

echo "Starting Sync Process" | tee process.log

mkdir $COPYLOCATION || { echo "could not create directory for sync" | tee process.log; exit 1; }

#running with a limited number of folders for testing-include the rest of the alphabet for production
alpha_array=("a")

#alpha_array=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z")


for i in "${alpha_array[@]}"
do
	mkdir ${COPYLOCATION}-$i || { echo "could not create sw-$i directory for sync" | tee process.log; exit 1; }
	aws s3 sync s3://$AWSURL ${COPYLOCATION}sw-$i --only-show-errors --exclude "*" --include "${i}*" 2>&1 | tee sync_error.log 

done


ERRORS=0

while read -r LINE
do 
	(( ERRORS++ ))
done < sync_error.log



if [ $ERRORS -gt 0 ]
then
	if [ $EMAILSEND -ne 0 ]
	then
		echo "Sync of Scholarworks S3 files have completed, but there were $ERRORS errors." | mail  -s "Sync Errors" $EMAIL -A sync_error.log || { echo "cannot send email" | tee process.log; exit 1; }
	fi
	if [ $IGNOREERROR -eq 0 ]
	then	
		echo "$ERRORS in sync, terminating preservation process" | tee process.log
		exit 1
	fi
else
	if [ $EMAILSEND -ne 0 ]
	then
		echo "Sync of Scholarworks S3 files have completed-no errors." | mail  -s "Scholarworks Sync Complete" $EMAIL || { echo "cannot send email" | tee process.log; exit 1; }
	fi
	echo "Sync complete-no errors" | tee process.log
fi

#If we get to this point with no errors, or we are ignoring errors, start virus and format reporting

echo "Starting virus and format report generation" | tee process.log

for i in "${alpha_array[@]}"

	bunnhilde.py -l ${COPYLOCATION}sw-$i ${COPYLOCATION}sw-${i}/sw-${i}-rpt-${DATE} 2>&1 | tee report_error.log

done	

ERRORS=0

while read -r LINE
do
        (( ERRORS++ ))
done < report_error.log

if [ $ERRORS -gt 0 ]
then
        if [ $EMAILSEND -ne 0 ]
        then
                echo "Brunnhilde has been run, but there were $ERRORS errors." | mail  -s "Bunnhilde Errors" $EMAIL -A report_error.log || { echo "cannot send email" | tee process.log; exit 1; }
        fi
        if [ $IGNOREERROR -eq 0 ]
        then
                echo "$ERRORS running Brunnhilde, terminating preservation process" | tee process.log
                exit 1
        fi
else
        if [ $EMAILSEND -ne 0 ]
        then
                echo "Sync of Scholarworks S3 files have completed-no errors." | mail  -s "Scholarworks Sync Complete" $EMAIL || { echo "cannot send email" | tee process.log; exit 1; }
        fi
        echo "Sync complete-no errors" | tee process.log

