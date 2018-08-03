#!/usr/bin/python

#python script to update the manifest of an existing bagit bag

#usage:  sudo -H regen_bagit_manifest.py full_path_to_bag_directory

#DO NOT use a path relative to the script location, or you will get an error


import sys
import bagit
import os

try: 
	directory = sys.argv[1]
except IndexError:
	print "Please provide the complete path to the bag whose manifest you wish to regenerate."
	sys.exit()

if not os.path.exists(directory):
	print "Invalid path, make sure the directory exists."
	sys.exit()

bag = bagit.Bag(directory)


# persist changes
if bag:
	bag.save(manifests=True)
	print "Bag manifest updated"
else: 
	print "Manifest could not be updated:  check that the directory is a valid bagit bag"
