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

EMAIL="felkerk@gvsu.edu"

AWSURL="scholarworksbackup/archive/scholarworks.gvsu.edu"

COPYLOCATION="/home/ubuntu/scholarworks/"

LOGLOCATION="/home/ubuntu/"

rm -r ${LOGLOCATION}process.log

rm -r ${LOGLOCATION}sync_error.log

touch ${LOGLOCATION}process.log || { echo "could not create proces logfile" >&2; exit 1; }

touch ${LOGLOCATION}sync_error.log || { echo "could not create sync error log" >&2; exit 1; }

rm -r $COPYLOCATION
if [ $EMAILSEND -ne 0 ]
then
	echo "Beginning processing of Scholarworks files." | mail  -s "Scholarworks curation proces beginning" $EMAIL || { echo "Cannot send email: check email logs" >> process.log; exit 1; }
fi

echo "Starting Sync Process" >> process.log

mkdir $COPYLOCATION || { echo "could not create directory for sync" >> process.log; exit 1; }

#running with a limited number of folders for testing-include the rest of the alphabet for production
alpha_array=("a")


for i in "${alpha_array[@]}"
do
	mkdir ${COPYLOCATION}-$i || { echo "could not create sw-$i directory for sync" >> process.log; exit 1; }
	aws s3 sync s3://$AWSURL ${COPYLOCATION}-$i --only-show-errors --exclude "*" --include "${i}*" &>> sync_error.log 

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
		echo "Sync of Scholarworks S3 files have completed, but there were $ERRORS errors." | mail  -s "Sync Errors" $EMAIL -A sync_error.log || { echo "cannot send email" >> process.log; exit 1; }
	fi
	if [ $IGNOREERROR -eq 0 ]
	then	
		echo "$ERRORS in sync, terminating preservation process" >> process.log
		exit 1
	fi
else
	if [ $EMAILSEND -ne 0 ]
	then
		echo "Sync of Scholarworks S3 files have completed-no errors." | mail  -s "Scholarworks Sync Complete" $EMAIL || { echo "cannot send email" >> process.log; exit 1; }
	fi
	echo "Sync complete-no errors" >> process.log
fi	
