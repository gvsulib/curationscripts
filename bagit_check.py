#!/usr/bin/python

#aws python library
import boto3
#need to parse command-line arguments
import sys

#python bagit module
import bagit

#needed for error catching
import subprocess

#not sure why, but you seem to have to import this to get proper error handling for boto3
import botocore
import os

#neccessary for easy file/directory deletions
import shutil

#used for sorting versions of files by date
from collections import OrderedDict

#regular expression functions, for parsing files and file paths
import re

alphaList = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]


if sys.argv[1] != "":

	if sys.argv[1] in alphaList:
		alphaList = [sys.argv[1]]
	else:
		print "Passed argument does not match an allowable bag, please try again."
		exit(1) 

#function to figure out which version of a file is the most recent undeleted version
def latestVersionID (key, bucket):

        versions = list(bucket.object_versions.filter(Prefix=key))

        timestamps = {}

	#are there no versions for this file?  If so, return false
	if len(versions) < 1:
		return False

        for version in versions:
                if version.is_latest:
                        if version.storage_class != None:
                                return version.id
                else:
                        timestamps[version.id] = version.last_modified
        #if we make it this far, the latest version is deleted, and we need to find the most recent undeleted version
        orderedTimeStamp = OrderedDict(sorted(timestamps.items(), key=lambda x: x[1]))
        
	first = orderedTimeStamp.popitem()
	return first[0]
print "Deleting any existing directories and creating new one to place bag"
#check to see if local directory for files exists, and scrub it if it does
if os.path.exists("bagit_verify"):
	shutil.rmtree("bagit_verify")

#now recreate it
os.makedirs("bagit_verify")
	
if os.path.exists("bagit_verify.log"):
	os.remove("bagit_verify.log")

logfile = open("bagit_verify.log", "w")
print "Opening s3 bucket"
#access the S3 bucket
s3 = boto3.resource('s3')

bucket = s3.Bucket('scholarworkslifecycle')

print "Populating bag(s)"
#start constructing the local bags
for alpha in alphaList:
 
	path = "bagit_verify/sw-" + alpha
	print "Constructing " + path + ", Downloading manifest files" 
	keyList = ["manifest-sha256.txt",
			"manifest-sha512.txt",
			"tagmanifest-sha256.txt",
			"tagmanifest-sha512.txt",
			"bagit.txt",
			"bag-info.txt" ]
	os.makedirs(path)	
	for key in keyList:
		try:
		
			bucket.download_file("sw-" + alpha + "/" + key, path + "/" + key)
		except botocore.exceptions.ClientError as e:
			if e.response['Error']['Code'] == "404":
        			print("The object: "+ key +" does not exist.")
    			else:
        			raise e
	

	#open the manifest file and extract all the file keys
	manifest = open(path + "/manifest-sha512.txt", "r")
	lines = manifest.readlines()
	files = []
	for line in lines:
		extract = re.split(r'\s', line)
		
		key = extract[2]
		key = "sw-" + alpha + "/" + key
		files.append(key)
	
	manifest.close()
	print "Populating data directory"
	#now start downloading all the files in the manifest, checking for ones that have been deleted and getting the most recent 
	#undeleted versions instead
	for key in files:
	
		#extract the filename for downloading
		filename = re.search(r'/.*$', key)
		filename = filename.group(0)

		#get the rest of the file path so we can make sure the directory structure exists
		file_path = re.search(r'/.*/', key)
		file_path = file_path.group(0)						
		#if the directory structure doesn't exist, create it.
		if not os.path.exists(path + file_path):
			os.makedirs(path + file_path)

		
		
		idnum = latestVersionID(key, bucket)
		if idnum == False:
			print("Cound not find any versions of file: " + key)
			
		bucket.download_file(key, path + "/" + filename, ExtraArgs={'VersionId': idnum})
	

	print "Importing bag into script"
        try:
                bag = bagit.Bag(path)
        except bagit.BagError as e:
                print("error accessing bag" + path)
                logfile.write("error accessing bag: " + path)
                logfile.write(str(e))
                continue

        isError = False

	print "Attempting to validate bag"
        try:
                bag.validate()
        except bagit.BagValidationError as e:

                logfile.write("problem validating bag " + path)
                logfile.write(str(e))

                isError = True

        if isError:
                print("Problem verifying bag " + path + " Check bagit_verify.log for further details")
        else:
                print("Bag " + path + " downloaded and successfully verified, moving on to next bag.")
		
	
		
		
		
			


