#!/bin/bash

#script to auto-update our digital curation tools.  run periodically by a cron job

#load locations of AWS bucket and directories
source config.sh

#load locations of AWS bucket and directories
source config.sh

rm -f update.log

touch update.log

apt-get update

echo "attempting to update clamAV" | tee -a update.log

freshclam 2>&1 | tee update.log

echo "attempting to update brunnhilde" | tee -a update.log

pip install brunnhilde --upgrade 2>&1 | tee -a update.log

echo "attempting to update bagit" | tee -a update.log

sudo pip install bagit --upgrade 2>&1 | tee -a update.log

echo "Update of curation tools complete." | mail -a"From:library@gvsu.edu" -s "Curation Tool Update Report" $EMAIL -A update.log || { echo "Cannot send email: check email logs" | tee -a update.log; exit 1; }
