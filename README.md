# IP CAMERA TIMELAPSE with LINUX SCRIPTS

### This is an example of how to create a TIMELAPSE automation with linux scripts.

First of all, create a directory to use, call it, for example "timelapse".

Then, enter this directory and create other called "img".

Copy the two files ( **snapshot.sh & timelapse.sh** ) into the directory "timelapse".

Edit both files and replace the required fields as needed.

Finally, you need to configure **CRONTAB** :

Log in as ROOT and open crontab

_crontab -e_

_\*/1 \* \* \* \* /PATH TO .sh FILES/snapshot.sh_

_0 \*/"X" \* \* \* sh /PATH TO .sh FILES/timelapse.sh #change "X" to make timelapse every X hours, as desired._

SAVE & EXIT

To test it is working, wait 5 minutes and open the "img" folder. There shoud be some images.

After one day, there should be a 1 minute video generated.

HELP EMAIL & PROBLEMS: [eduardo@tend.es](mailto:eduardo@tend.es)