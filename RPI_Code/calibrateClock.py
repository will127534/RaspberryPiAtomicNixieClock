import socket
import sys
from influxdb import InfluxDBClient
import time
import datetime
from multiprocessing import Queue
from threading import Event, Thread, Timer
from dbSetting import *
from simple_pid import PID

query_where2 = 'SELECT mean("Adjusted Clock") FROM "FPGA" WHERE time > now() - 12h'
#query_where = 'SELECT mean("PPS Duration") FROM "FPGA" WHERE time > now() - 2h'
query_where = 'SELECT "Adjusted Clock" FROM "FPGA" WHERE time > now() - 2s'

# Create a UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server_address = ('localhost', 10000)
sock.settimeout(0.5)

ifclient = InfluxDBClient(ifhost,ifport,ifuser,ifpass,ifdb,timeout=2,retries=3)

#pid = PID(Kp=0, Ki=300, Kd=0, setpoint=0)
#pid.sample_time = 1

accumlated_error = 0

def call_repeatedly(interval, func, *args):
    stopped = Event()
    print("[call_repeatedly] Starting")
    def loop():
        while not stopped.wait(interval - time.time() % interval): # the first call is in `interval` secs
            func(*args)
    Thread(target=loop).start()
    return stopped.set

def readData():
    #global pid
    global accumlated_error
    
    try:
        result = ifclient.query(query_where)
        result2 = ifclient.query(query_where2)
        Average = list(result2.get_points())[0]
        #averageDataPoint = list(result.get_points())[0]
        averageDataPoint = float((list(result.get_points())[-1]['Adjusted Clock']))
        error = averageDataPoint - 10000000
        #error = averageDataPoint['mean'] - 10000000
        #control = pid(error)
        #print(pid.components)
        accumlated_error += error
        control = -1*accumlated_error*300
        print("control:%f"%control)
        cmd = "<FD" + str(int(control)) + ">"
        cmd = cmd.encode()
        print("CMD:%s"%cmd)
        sent = sock.sendto(cmd, server_address)
        data, server = sock.recvfrom(4096)
        print("Received:%s"%data)
        print("Error:%f, accumlated_error:%f, Control:%f "%(error, accumlated_error,control))
    except Exception as e:
        print(e)
        pass


cmd = "<FA>"
cmd = cmd.encode()
sent = sock.sendto(cmd, server_address)
data, server = sock.recvfrom(4096)
print("Received:%s"%data)

time.sleep(1-time.time()%1)
cancel_future_calls = call_repeatedly(1, readData)

try:
    while 1:
        time.sleep(10000)
        pass
except KeyboardInterrupt:
    sys.exit()
