#!/bin/bash

#script to auto-update our digital curation tools.  run periodically by a cron job

rm -f update.log

touch update.log

apt-get update

echo "attempting to update clamAV" | tee update.log

freshclam 2>&1 | tee update.log

echo "attempting to update brunnhilde" | tee update.log

pip install brunnhilde --upgrade 2>&1 | tee update.log

echo "attempting to update bagit" | tee update.log

sudo pip install bagit --upgrade 2>&1 | tee update.log

echo "Update of curatiuon tools complete" | mail  -s "Curation Tool Update" schultzm@gvsu.edu -A update.log
