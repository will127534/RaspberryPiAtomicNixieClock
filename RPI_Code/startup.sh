/usr/bin/python3 /home/pi/upload.py
screen -dmS Sensor_Env python3 /home/pi/uploadEnv.py
screen -dmS Sensor_AC python3 /home/pi/uploadAC.py
screen -dmS Fan_control python3 /home/pi/fanControl.py
sleep 90
/usr/bin/python3 /home/pi/uploadClock.py
