#!/bin/bash


DIR="PATH TO IMG DIR"
FILENAME="NAME OF FINAL .mp4 TIMELAPSE"
OUTFOLDER="PATH TO SEND THE RESULT VIDEO"


find $DIR -name "*.jpg" -type f -mmin +1440 -delete
cd $DIR
rm timelapse.avi
ls > frames.txt
mencoder -nosound -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:trell:autoaspect:vqscale=3 -vf scale=1920:1080 -o timelapse.avi -mf type=jpeg:fps=24 mf://@frames.txt
rm $FILENAME.mp4
ffmpeg -i timelapse.avi $FILENAME.mp4
rm $OUTFOLDER/$FILENAME.mp4
mv $FILENAME.mp4 $OUTFOLDER
