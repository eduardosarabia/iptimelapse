#!/bin/bash


# Webcam URL
URL_WEBCAM="URL TO GENERATED JPG IMAGE (SNAPSHOT)"

# User
USER="" 
# Password
PASS=""

# Output DIR
DIR="PATH TO IMG DIR"



NAME=`date +%d-%m-%Y_%H:%M:%S`
wget --no-check-certificate --no-verbose --user $USER --password $PASS $URL_WEBCAM -O $DIR$NAME.jpg
jpeginfo -d $DIR$NAME.jpg
while [ ! -f $DIR$NAME.jpg ] ;
    do
        NAME=`date +%d-%m-%Y_%H:%M:%S`
        wget --no-check-certificate --no-verbose --user $USER --password $PASS $URL_WEBCAM -O $DIR$NAME.jpg
        jpeginfo -d $DIR$NAME.jpg
    done
