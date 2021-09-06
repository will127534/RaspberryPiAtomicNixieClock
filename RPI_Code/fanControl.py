from simple_pid import PID
import time
from adafruit_extended_bus import ExtendedI2C as I2C
import adafruit_tmp117
import os 
from influxdb import InfluxDBClient
from threading import Event, Thread, Timer
from multiprocessing import Queue
import datetime
from dbSetting import *

time.sleep(10)

dataQueue = Queue(300)

class uploadDataThread (Thread):
    def __init__(self, ifuser, ifpass, ifdb, ifhost, queue): 
        Thread.__init__(self)
        self.ifuser = ifuser
        self.ifpass = ifpass
        self.ifdb = ifdb
        self.ifhost = ifhost
        self.ifport = ifport
        self.queue = queue

    def run(self):
        print("[Upload Thread] Starting")
        self.ifclient = InfluxDBClient(ifhost,ifport,ifuser,ifpass,ifdb,timeout=2,retries=3)
        while 1:
            val = self.queue.get()
            try:
                self.ifclient.write_points(val)
            except Exception as e:
                print(e)

uploadDataThread(ifuser, ifpass, ifdb, ifhost, dataQueue).start()


i2c = I2C(0)
#i2c = busio.I2C(board.SCL, board.SDA)
tmp117 = adafruit_tmp117.TMP117(i2c, address=0x49)


def write_fan(value):
	#print('i2cset -y 0 0x2f 0x30 '+ hex(value))
	os.system('/usr/sbin/i2cset -y 0 0x2f 0x30 '+ hex(value))

os.system('/usr/sbin/i2cset -y 0 0x2f 0x31 0x01')
pid = PID(Kp=-70, Ki=-1.5, Kd=0, setpoint=48)
pid.sample_time = 0.5
pid.output_limits = (10, 255)
pid.set_auto_mode(True)
# Assume we have a system we want to control in controlled_system
v = tmp117.temperature

while True:
    # Compute new output from the PID according to the systems current value
    control = pid(v)
    write_fan(int(control))
    v = tmp117.temperature
    print('%f,%d' % (v,control))
    body = [
        {
            "measurement": "Fan",
            "time": datetime.datetime.utcnow(),
            "fields": {
                "Under Temperature": v,
                "FAN PWM": int(control)
            }
        }
    ]
    print(body)
    dataQueue.put(body)
    time.sleep(0.5)

