#!/bin/bash


#turn emailing on and off.  Neccessary if you are manually running the script
if [ "$1" = "NOEMAIL" ] || [ "$2" = "NOEMAIL" ]
then
        EMAILSEND=0
else 
        EMAILSEND=1
fi


#configuration variables
EMAIL="felkerk@gvsu.edu"

AWSURL="scholarworksbackup/archive/scholarworks.gvsu.edu"

COPYLOCATION="/home/ubuntu/scholarworks/"

LOGLOCATION="./"

DATE=`date +%Y-%m-%d`


#remove all previous logfiles
rm -r ${LOGLOCATION}process.log

rm -r ${LOGLOCATION}sync_error.log

rm -r ${LOGLOCATION}brunnhilde.log

rm -r ${LOGLOCATION}bagit.log


#create logfiles we'll use to track data about the process
touch ${LOGLOCATION}process.log || { echo "could not create process logfile" >&2; exit 1; }

touch ${LOGLOCATION}sync_error.log || { echo "could not create sync error logfile" >&2; exit 1; }

touch ${LOGLOCATION}brunnhilde.log || { echo "could not create brunnhilde logfile" >&2; exit 1; }

touch ${LOGLOCATION}bagit.log || { echo "could not create bagit logfile" >&2; exit 1; }

#check if the main directory exists.  If it does not, create it.

echo "Checking for working directory" | tee -a ${LOGLOCATION}process.log
if [ ! -d "$COPYLOCATION" ]
	
	then
	echo "Directory not found, attempting to create" | tee -a process.log
	mkdir ${COPYLOCATION} || { echo "Work directory ${COPYLOCATION} absent and could not be created" >&2 | tee -a ${LOGLOCATION}process.log; exit 1; }
	
fi

#log (and also email, if applicable) that we are starting the process
if [ $EMAILSEND -ne 0 ]
then
	echo "Beginning processing of Scholarworks files." | mail  -s "Scholarworks curation process beginning" $EMAIL || { echo "Cannot send email: check email logs" | tee -a ${LOGLOCATION}process.log; exit 1; }
fi

echo "Starting Sync Process" | tee -a ${LOGLOCATION}process.log

#running with a limited number of folders for testing-include the rest of the alphabet for production
alpha_array=("a")

#alpha_array=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z")

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
		echo "syncing to main directory"
		aws s3 sync s3://$AWSURL ${COPYLOCATION}sw-$i --only-show-errors --exclude "*" --include "${i}*" 2>&1 | tee -a ${LOGLOCATION}sync_error.log
	else
		echo "Synching to data directory"
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
	if [ $EMAILSEND -ne 0 ]
	then
		echo "Sync of Scholarworks S3 files have completed, but there were $ERRORS errors." | mail  -s "Sync Errors" $EMAIL -A ${LOGLOCATION}sync_error.log || { echo "cannot send email" | tee -a ${LOGLOCATION}process.log; exit 1; }
	fi
else
	if [ $EMAILSEND -ne 0 ]
	then
		echo "Sync of Scholarworks S3 files have completed-no errors." | mail  -s "Scholarworks Sync Complete" $EMAIL || { echo "cannot send email" | tee -a ${LOGLOCATION}process.log; exit 1; }
	fi
	echo "Sync complete-no errors" | tee -a ${LOGLOCATION}process.log
fi

#If we get to this point with no errors, or we are ignoring errors, start virus and format reporting

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
	brunnhilde.py -l ${DIRECTORY} ${DIRECTORY}/ sw-${i}-rpt-${DATE} 2>&1 | tee -a ${LOGLOCATION}brunnhilde.log

done

VIRUSERRORS=$(grep -i -c "No infections found" ${LOGLOCATION}brunnhilde.log) 

if [ $VIRUSERRORS -lt 1 ]
then
	if [ $EMAILSEND -ne 0 ]
        then
                echo "Brunnhilde Scan complete, viruses found, check the log for more information." | mail  -s "Brunnhilde Errors" $EMAIL -A ${LOGLOCATION}brunnhilde.log || { echo "cannot send email" | tee -a ${LOGLOCATION}process.log; exit 1; }
        fi
	echo "Virus and format report generation complete, viruses found" | tee -a process.log
else 

	if [ $EMAILSEND -ne 0 ]
        then
                echo "Brunnhilde reports complete." | mail  -s "Brunnhilde Report" $EMAIL -A brunnhilde.log || { echo "cannot send email" | tee -a process.log; exit 1; }	
	fi
	echo "Virus and format report generation complete" | tee -a process.log
fi


echo "starting bagit" | tee -a process.log

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
        	bagit.py ${DIRECTORY} 2>&1 | tee -a bagit.log
	else 	
		echo "Attempting to update bag manifest for bag sw-$i" | tee -a process.log
		echo "Attempting to update bag manifest for bag sw-$i" >> bagit.log
		python ./regen_bagit_manifest.py ${COPYLOCATION}sw-$i >> bagit.log
	fi
	echo "Verifying directory sw-$i" | tee -a process.log
	echo "Verifying directory sw-$i" >> bagit.log
	bagit.py --validate ${COPYLOCATION}sw-$i 2>&1 | tee -a bagit.log
	LOG_STRING=$(tail -1 bagit.log)
	GREP_ERROR=$(grep -c ERROR <<< "$LOG_STRING")
	if [ $GREP_ERROR -gt 0 ]
		then
			ERRORS=$((ERRORS + 1))
			BAGIT_ERRORS=$BAGIT_ERRORS" "$LOG_STRING			
		
	fi
done

echo "Bagit process complete, $ERRORS errors $BAGIT_ERRORS" | tee -a process.log

if [ $EMAILSEND -ne 0 ]
        then
                echo "Bagit process complete, $ERRORS errors, error text: $BAGIT_ERRORS" | mail  -s "Scholarworks Bagit Report" $EMAIL -A bagit.log || { echo "cannot send email" | tee -a process.log; exit 1; }
		
fi

