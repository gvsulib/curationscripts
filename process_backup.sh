#!/bin/bash

#usage: sudo -H ./process_backup.sh (NOEMAIL)

#turn emailing on and off.  Neccessary if you are manually running the script
if [ "$1" = "NOEMAIL" ]
then
        EMAILSEND=0
else 
        EMAILSEND=1
fi

DATE=`date +%Y-%m-%d`

#load locations of AWS bucket and directories
source /home/ubuntu/curation_scripts/config.sh

#remove all previous logfiles
rm -r ${LOGLOCATION}process.log

rm -r ${LOGLOCATION}sync_error.log

rm -r ${LOGLOCATION}upload_error.log

rm -r ${LOGLOCATION}brunnhilde.log

rm -r ${LOGLOCATION}bagit.log


#log (and also email, if applicable) that we are starting the process
if [ $EMAILSEND -ne 0 ]
then
        echo "Be sure to check all the log files to ensure the process went off smoothly." | /usr/bin/mail -a"From:library@gvsu.edu" -s "Check Scholarworks Curation Process" $ASANAEMAIL, $EMAIL || { echo "Cannot send email: check email logs" | tee -a ${LOGLOCATION}process.log; exit 1; }
fi

#create logfiles we'll use to track data about the process
touch ${LOGLOCATION}process.log || { echo "could not create process logfile" >&2; exit 1; }

touch ${LOGLOCATION}sync_error.log || { echo "could not create sync error logfile" >&2; exit 1; }

touch ${LOGLOCATION}brunnhilde.log || { echo "could not create brunnhilde logfile" >&2; exit 1; }

touch ${LOGLOCATION}bagit.log || { echo "could not create bagit logfile" >&2; exit 1; }

touch ${LOGLOCATION}upload_error.log || { echo "could not create upload error logfile" >&2; exit 1; }


#check if the main directory exists.  If it does not, create it.

echo "Checking for working directory" | tee -a ${LOGLOCATION}process.log
if [ ! -d "$COPYLOCATION" ]
	
	then
	echo "Directory not found, attempting to create" | tee -a ${LOGLOCATION}process.log
	mkdir ${COPYLOCATION} || { echo "Work directory ${COPYLOCATION} absent and could not be created" >&2 | tee -a ${LOGLOCATION}process.log; exit 1; }
	
fi


echo "Starting Sync Process" | tee -a ${LOGLOCATION}process.log

#running with a limited number of folders for testing-include the rest of the alphabet for production

#alpha_array=("a")

alpha_array=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z")

#start syncing files from the S3 server
for i in "${alpha_array[@]}"
do
	#do the subdirectories exist?  If not, create them
	DIRECTORY=$COPYLOCATION"sw-"$i
	if [ ! -d "$DIRECTORY" ] 
	then
		mkdir ${COPYLOCATION}sw-${i} || { echo "could not create sw-$i directory for sync" | tee -a ${LOGLOCATION}process.log; exit 1; }
	fi

	#does the data directory exist?  If so, sync to it.  If not, sync to the base directory (which should be empty, so it will copy all new files)
	DIRECTORY="$DIRECTORY/data"
	if [ ! -d "$DIRECTORY" ]
	then
		echo "syncing to main directory: $i" | tee -a ${LOGLOCATION}process.log
		aws s3 sync s3://$AWSURL ${COPYLOCATION}sw-$i --only-show-errors --exclude "*" --include "${i}*" 2>&1 | tee -a ${LOGLOCATION}sync_error.log
	else
		echo "Synching to data directory $i" | tee -a ${LOGLOCATION}process.log
		aws s3 sync s3://$AWSURL ${COPYLOCATION}sw-$i/data --only-show-errors --exclude "*" --include "${i}*" 2>&1 | tee -a ${LOGLOCATION}sync_error.log 
		
	fi


done

#check for logged errors in the previous process, and notify folks if there are any and if the user has chosen to be emailed
ERRORS=0

while read -r LINE
do 
	(( ERRORS++ ))
done < ${LOGLOCATION}sync_error.log



if [ $ERRORS -gt 0 ]
then
	echo "Sync complete, $ERRORS logged: check sync_error.log for logged errors." | tee -a ${LOGLOCATION}process.log
else
	echo "Sync complete-no errors" | tee -a ${LOGLOCATION}process.log
fi

if [ $EMAILSEND -ne 0 ]
then
	echo "Sync from S3 complete, $ERRORS errors found." | /usr/bin/mail -a"From:library@gvsu.edu" -s "Check Scholarworks sync log" $ASANAEMAIL, $EMAIL -A ${LOGLOCATION}sync_error.log || { echo "Cannot send email: check email logs" | tee -a ${LOGLOCATION}process.log; exit 1; }
fi

#start virus and format reporting

echo "Starting virus and format report generation" | tee -a ${LOGLOCATION}process.log

for i in "${alpha_array[@]}"
do
	DIRECTORY=$COPYLOCATION"sw-"$i"/data"
	#if the data directory exists, run checks against the stuff in there.  Otherwise, run it against the base directory
	if [ ! -d "$DIRECTORY" ] 
	then
		DIRECTORY=$COPYLOCATION"sw-"$i
	fi
	
	#rm -r ${DIRECTORY}/sw-${i}-rpt-* || { echo "cannot remove old virus and format reports" | tee -a process.log; exit 1; }
	echo "Running Brunnhilde on directory $DIRECTORY" | tee -a ${LOGLOCATION}process.log
	brunnhilde.py -l ${DIRECTORY} ${DIRECTORY}/ sw-${i}-rpt-${DATE} |& tee -a ${LOGLOCATION}brunnhilde.log

done

VIRUSERRORS=$(grep -i -c "No infections found" ${LOGLOCATION}brunnhilde.log) 

if [ $VIRUSERRORS -lt 1 ]
then
	echo "Virus and format report generation complete, viruses found, check brunnhilde reports for more details" | tee -a ${LOGLOCATION}process.log
else 

	echo "Virus and format report generation complete, no viruses logged" | tee -a ${LOGLOCATION}process.log
fi
if [ $EMAILSEND -ne 0 ]
then
	echo "Brunnhilde scans complete, check report logfile." | /usr/bin/mail -a"From:library@gvsu.edu" -s "Check Brunnhilde output" $ASANAEMAIL, $EMAIL -A ${LOGLOCATION}brunnhilde.log || { echo "Cannot send email: check email logs" | tee -a ${LOGLOCATION}process.log; exit 1; }
fi

echo "starting bagit" | tee -a ${LOGLOCATION}process.log

ERRORS=0

BAGIT_ERRORS=""



for i in "${alpha_array[@]}"
do
	DIRECTORY=$COPYLOCATION"sw-"$i"/data"
	if [ ! -d "$DIRECTORY" ]
	then	
		DIRECTORY=$COPYLOCATION"sw-"$i
		echo "Running bagit on directory $DIRECTORY" | tee -a process.log
		echo "Running bagit on directory $DIRECTORY" >> bagit.log
        	bagit.py ${DIRECTORY} |& tee -a bagit.log
	else 	
		echo "Attempting to update bag manifest for bag sw-$i" | tee -a process.log
		echo "Attempting to update bag manifest for bag sw-$i" >> bagit.log
		/home/ubuntu/curation_scripts/regen_bagit_manifest.py ${COPYLOCATION}sw-$i |& tee -a bagit.log
	fi
	echo "Verifying directory sw-$i" | tee -a process.log
	echo "Verifying directory sw-$i" >> bagit.log
	bagit.py --validate ${COPYLOCATION}sw-$i 2>&1 | tee -a bagit.log
	PATTERN=${COPYLOCATION}sw-$i" is valid"
	LOG_STRING=$(tail -n 1 bagit.log)
	GREP_ERROR=$(grep -c "$PATTERN" <<< "$LOG_STRING")
	if [ $GREP_ERROR -ne 1 ]
		then
			ERRORS=$((ERRORS + 1))
			BAGIT_ERRORS=$BAGIT_ERRORS" "$LOG_STRING			
		
	fi
done

echo "Bagit process complete, $ERRORS errors $BAGIT_ERRORS" | tee -a process.log

if [ $EMAILSEND -ne 0 ]
then
	echo "Bagit process complete, $ERRORS errors." | /usr/bin/mail -a"From:library@gvsu.edu" -s "Check Bagit Logs" $ASANAEMAIL, $EMAIL -A ${LOGLOCATION}bagit.log || { echo "cannot send email" | tee -a ${LOGLOCATION}process.log; exit 1; }
fi

if [ $ERRORS -gt 0 ]
        then 
        echo "Bagit verification errors found, closing down process" | tee -a ${LOGLOCATION}process.log
        exit 1;
fi

#now start putting the files on the s3 server for eventual migraton to glacier

echo "Starting copy of bagged files to $SYNCLOCATION" | tee -a ${LOGLOCATION}process.log

aws s3 cp $COPYLOCATION s3://${SYNCLOCATION} --recursive --only-show-errors 2>&1 | tee -a ${LOGLOCATION}upload_error.log

ERRORS=0

while read -r LINE
do
        (( ERRORS++ ))
done < ${LOGLOCATION}upload_error.log



if [ $ERRORS -gt 0 ]
then
	echo "Sync of archive to S3 complete, $ERRORS logged, check upload_error.log for more details" | tee -a ${LOGLOCATION}process.log
else
        echo "Sync of archive to S3 complete-no errors" | tee -a ${LOGLOCATION}process.log
fi

if [ $EMAILSEND -ne 0 ]
then
	echo "Copy of archived files back to S3 have completed, $ERRORS errors logged." | /usr/bin/mail -a"From:library@gvsu.edu" -s "Check Upload logs" $ASANAEMAIL, $EMAIL -A ${LOGLOCATION}upload_error.log || { echo "cannot send email" | tee -a ${LOGLOCATION}process.log; exit 1; }
fi

echo "Process complete" | tee -a ${LOGLOCATION}process.log



