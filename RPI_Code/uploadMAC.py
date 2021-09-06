import time
import math
import datetime
from influxdb import InfluxDBClient
from threading import Event, Thread, Timer
from multiprocessing import Queue
import serial
import socket
import sys
from dbSetting import *

# Create a UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# Bind the socket to the port
server_address = ('localhost', 10000)
print('starting up on {} port {}'.format(*server_address))
sock.bind(server_address)


ser = serial.Serial('/dev/ttyAMA1',57600,timeout=1)

serialLock = False

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



def call_repeatedly(interval, func, *args):
    stopped = Event()
    print("[call_repeatedly] Starting")
    def loop():
        while not stopped.wait(interval - time.time() % interval): # the first call is in `interval` secs
            func(*args)
    Thread(target=loop).start()
    return stopped.set


def readData():
    global serialLock
    while serialLock:
        time.sleep(0.01)
    try:
        time.sleep(0.5)    
        serialLock = True
        ser.flushInput()
        ser.write(b'^')
        line = ser.readline() 
        serialLock = False
        line = line.decode("utf-8").strip('\r\n')
        print(line)
        data = line.split(',')
        body = [
            {
                "measurement": "MAC",
                "time": datetime.datetime.utcnow(),
                "fields": {
                    "BITE": int(data[0]),
                    "Version": data[1],
                    "SerialNumber": data[2],
                    "TEC Control": int(data[3])/1000,
                    "RF Control": int(data[4])/10,
                    "DDS Frequency Center Current": int(data[5])/100,
                    "CellHeaterCurrent": int(data[6]),
                    "DCSignal": int(data[7]),
                    "Temperature": int(data[8])/1000,
                    "Digital Tuning": int(data[9]),
                    "Analog Tuning On/Off": int(data[10]),
                    "Analog Tuning": int(data[11])
                }
            }
        ]
        print(body)
        dataQueue.put(body)
    except Exception as e:
        print(e)
        pass

cancel_future_calls = call_repeatedly(1, readData)

try:
    ser.flushInput()
    while 1:
        try:
            print('\nwaiting to receive message')
            data, address = sock.recvfrom(4096)
            print('<===received {} bytes from {}'.format(len(data), address))
            print(data)
            while serialLock:
                time.sleep(0.01)
            serialLock = True
            ser.write(data)
            line = ser.readline() 
            print("==>Send:%s"%line)
            sent = sock.sendto(line, address)
            serialLock = False
            pass
        except Exception as e:
            print(e)
            serialLock = False
            pass
except KeyboardInterrupt:
    sys.exit()


