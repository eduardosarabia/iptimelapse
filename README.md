# IP CAMERA TIMELAPSE with LINUX SCRIPTS

### This is an example of how to create a TIMELAPSE automation with linux scripts.

First of all, create a directory to use, call it, for example "timelapse".

Download timelapse.sh to your working directory.

Edit btimelapse.sh and change the following lines:

RTSP_URL="rtsp://admin:admin@192.168.1.1/stream1" #change to fit your IP camera

BASE_DIR="/home/timelapse/mycamera"
SNAP_DIR="$BASE_DIR/img"                      # captures
OUT_DIR="/var/www/html/timelapse/mycamera"    # videos

Finally, you need to configure **CRONTAB** :

Log in as ROOT and open crontab

_crontab -e_

_\*/1 \* \* \* \* /PATH TO .sh FILES/timelapse.sh capture_

_0 \*/"X" \* \* \* sh /PATH TO .sh FILES/timelapse.sh timelapse #change "X" to make timelapse every X hours, as desired._

SAVE & EXIT

To test it is working, wait 5 minutes and open the "img" folder. There shoud be some images.

After one day, there should be a 1 minute video generated.

HELP EMAIL & PROBLEMS: [eduardo@tend.es](mailto:eduardo@tend.es)
