# curationscripts


This is a collection of scripts (mostly shell scripts) that automate the processing of our Scholarworks backups for digtital archiving.
 
Creating a digital preservation copy of the GVSU’s ScholarWorks files involves four steps:
 
1. Syncing data from S3 to EC2:  No processing can actually be done on files in-place on S3, so they must be copied to the EC2 “curation server”. As part of this process, we wanted to reorganize the files into logical directories (alphabetized), so that it would be easier to locate and process files, and to better organize the virus reports and bags the process generates.
 
2. Virus and format reports with Brunnhilde:  The synced files are then run through Brunnhilde’s suite of tools.  Brunnhilde will generate both a command-line summary of problems found and detailed reports that are deposited with the files.  The reports stay with the files as they move through the process. 
 
3. Preservation Packaging with BagIt:  Once the files are checked, they need to be put in “bags” for storage and archiving using the Bagit tool.  This will bundle the files in a data directory and generate metadata that can be used to check their integrity.  
 
4. Syncing files to S3 and Glacier: Checked and bagged files are then moved to a different S3 bucket for nearline storage.  From that bucket, we have set up automated processes (“lifecycle management[MOU1] ,” in AWS parlance) to migrate the files on a quarterly schedule into Amazon Glacier, our long-term storage solution.
 
Once the process has been done once, new files are incorporated and re-synced on a quarterly basis to the Bagit data directories and re-checked with Brunnhilde.  The Bagit metadata must then be updated and re-verified using Bagit, and the changes synced to the destination S3 bucket.
 
 
Process_backup is the main script. It handles each of the four processing stages outlined above.  As it does so, it stores the output of those tasks in log files, so they can be examined later.  In addition, it emails notifications to our task management system (Asana), so that our curation staff can check on the process.

Credential data, such as passwords, are kept in a config.sh file (not included in this repo for obvious reasons). A smaplke config file is included so that you can see how to set one up.

After the first time the process is run, the metadata that Bagit generates has to be updated to reflect new data.  The version of Bagit we are using (Python) can’t do this from the command line, but it does have an API with a command that will update existing “bag” metadata. So, we created a small Python script to do this (regen_bagit_manifest.py).  The shell script invokes this script at the third stage if bags have previously been created.

Finally, the update.sh script automatically updates all the tools used in the process and emails curation staff when the process is done.
 
We then schedule the scripts to run automatically using the Unix cron utility.

bagit_check.py is a spot-checking script.  It's designed to pull manifest files and data files from the destination s# bucket, reconstitute them, and re-verify the bag.  It's written in python and requires a number of specific libraries to work.  You can check all the bags or you can specify a bag by passing the script a letter designation when you invoke the script:

./bagit_check.py (all bags)
./bagit_check.py a (only bag a)
