import spidev
import sys
import RPi.GPIO as GPIO
import time 
from threading import Event, Thread, Timer
from influxdb import InfluxDBClient
from multiprocessing import Queue
import datetime
import fcntl
import subprocess
import sys
import random
from dateutil import parser
from dbSetting import *
from struct import *

spi_conf = spidev.SpiDev()
spi_conf.open(0, 0)
spi_conf.max_speed_hz = 6250000
spi_conf.mode = 0b00

GPIO.setmode(GPIO.BCM)

previousToF = 0
previousOffset = 0
LastFPGATime = 0
offset = 0
Nextoffset = 0


##============FPGA Functions================##
def writePWM(pwm):
    pwm = pwm.to_bytes(2, byteorder='big')
    pwm_high = pwm[1]
    pwm_low = pwm[0]
    spi_conf.xfer([10,pwm_low])
    spi_conf.xfer([11,pwm_high])

def writePWMDivider(div):
    div = div.to_bytes(2, byteorder='big')
    div_high = div[1]
    div_low = div[0]
    spi_conf.xfer([12,div_low])
    spi_conf.xfer([13,div_high])

def SequenceDigit():
    #Enable Manual Control Nixie 
    spi_conf.xfer([0,0x08])
    #Clear Nixie DP
    spi_conf.xfer([8,0x08])
    spi_conf.xfer([9,0x08])
    for x in range(20):
        for digitno in range(10):
            data = []
            for x in range(4):
                data.append( digitno*16 + digitno)
                pass
            spi_conf.xfer([4,data[0]])
            spi_conf.xfer([5,data[1]])
            spi_conf.xfer([6,data[2]])
            spi_conf.xfer([7,data[3]])
            time.sleep(0.05)
    #Disable Manual Control Nixie 
    spi_conf.xfer([14,0x08])
    Timer(3600 - int(time.localtime().tm_sec) + int(time.localtime().tm_min) * 60, SequenceDigit, ()).start()
    pass

def randomDigit():
    #Enable Manual Control Nixie 
    spi_conf.xfer([0,0x08])
    #Clear Nixie DP
    spi_conf.xfer([8,0x08])
    spi_conf.xfer([9,0x08])
    for x in range(200):
        data = []
        for x in range(4):
            data.append( random.randint(0,9)*16 + random.randint(0,9))
            pass
        spi_conf.xfer([4,data[0]])
        spi_conf.xfer([5,data[1]])
        spi_conf.xfer([6,data[2]])
        spi_conf.xfer([7,data[3]])
        time.sleep(0.02)
    #Disable Manual Control Nixie 
    spi_conf.xfer([14,0x08])
    Timer(3600 - int(time.localtime().tm_sec) + int(time.localtime().tm_min) * 60, randomDigit, ()).start()
    pass

def writeConf(conf):
    spi_conf.xfer([0,conf])

def writeTime(h,m,s):
    h = h % 24
    m = m % 60
    s = s % 60
    spi_conf.xfer([0x01,s])
    spi_conf.xfer([0x02,m])
    spi_conf.xfer([0x03,h])

def readTOF():
    data = spi_conf.xfer([0x01+128,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
    TDC_TIME1 =        data[16]*65536 + data[15]*256 + data[14]
    TDC_TIME2 =        data[13]*65536 + data[12]*256 + data[11]
    TDC_CLOCK_COUNT1 = data[10]*65536 + data[9]*256 + data[8]
    TDC_CALIBRATION1 = data[7]*65536 + data[6]*256 + data[5]
    TDC_CALIBRATION2 = data[4]*65536 + data[3]*256 + data[2]
    calCount = (TDC_CALIBRATION2 - TDC_CALIBRATION1) / 9
    normLSB = 1/10000000/calCount
    #output us
    print(TDC_TIME1,TDC_TIME2,TDC_CLOCK_COUNT1,calCount)
    return (TDC_TIME1-TDC_TIME2)/calCount+TDC_CLOCK_COUNT1

def readFiFo():
    fifo_count = spi_conf.xfer([128+2,0x00,0x00,0x00])
    return fifo_count[3]*256 + fifo_count[2]

def readTime():
    fifo_count = spi_conf.xfer([128+4,0x00,0x00,0x00,0x00])
    return fifo_count[4]*256*256 + fifo_count[3]*256 + fifo_count[2]

def readPPSCourseCounter():
    data = spi_conf.xfer([0x00+128,0x00,0x00,0x00,0x00,0x00])
    return data[5]*16777216 + data[4]*65536 + data[3]*256 + data[2]

def readFiFoOverflow():
    fifo_count = spi_conf.xfer([128+5,0x00,0x00])
    print(fifo_count)
    return fifo_count[2]

##============FPGA Functions END=============##

##============Upload To InfluxDB================##
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

##============Upload To InfluxDB END=============##


#Setup - Close LED
spi_conf.xfer([0,0x02])

#Setup - Align GPS PPS
spi_conf.xfer([0,0x01])
time.sleep(3)
spi_conf.xfer([14,0x01])

#Setup - Time
timeNow = datetime.datetime.utcnow() + datetime.timedelta(hours=-7) + datetime.timedelta(seconds=1)
writeTime(timeNow.hour,timeNow.minute,timeNow.second)


##============Polling FPGA Function=============##
def readData(dataQueue):
    global previousToF
    global LastFPGATime
    global previousOffset
    global offset
    while 1:
        try:
            FPGATime = readTime()
            if(FPGATime == LastFPGATime):
                return
            time.sleep(0.3)
            FPGATime = readTime()
            print(FPGATime)
            ToF = readTOF() - 5000
            PPSCycle = readPPSCourseCounter()
            PPSDuration = (PPSCycle - ToF + previousToF)
            fifo = readFiFo()
            fifo_overflow_flag = readFiFoOverflow()
            print("%f,%d,%f,%d,%d" % (ToF,PPSCycle,PPSDuration,fifo,fifo_overflow_flag))

            body2 = [
                {
                    "measurement": "FPGA",
                    "time": datetime.datetime.utcnow(),
                    "fields": {
                        "GPS": PPSCycle,
                        "Clock": ToF,
                        "PPS Duration": PPSDuration,
                        "FIFO Count": fifo,
                        "FIFO Overrun": fifo_overflow_flag,
                        "Adjusted Clock": PPSDuration+offset-previousOffset,
                        "Adjusted ToF": ToF+offset
                    }
                }
            ]
            print(body2)
            previousOffset = offset
            previousToF = ToF
            dataQueue.put(body2)
            LastFPGATime = FPGATime
            return
        except IOError:
            pass
        except Exception as e:
            print(e)
            pass

def call_repeatedly(interval, func, *args):
    stopped = Event()
    print("[call_repeatedly] Starting")
    def loop():
        while not stopped.wait(interval - time.time() % interval): # the first call is in `interval` secs
            func(*args)
    Thread(target=loop).start()
    return stopped.set

time.sleep(1-time.time()%1)
cancel_future_calls = call_repeatedly(0.2, readData, dataQueue)
readData(dataQueue)
##============Polling FPGA Function END==========##


##============Timed Nixie Refresh Animate=============##
#xx:30 min -> Random Digit Animate
#xx:00 min -> Seq Digit Animate 
next_switch = 3600 - int(time.localtime().tm_sec) - (int(time.localtime().tm_min)*60)
seq_digit = Timer(next_switch, SequenceDigit, ())

if time.localtime().tm_min>30:
    next_switch_random = (90 - int(time.localtime().tm_min)) * 60 - int(time.localtime().tm_sec)
else:
    next_switch_random = (30 - int(time.localtime().tm_min)) * 60 - int(time.localtime().tm_sec)

randomDigit_t = Timer(next_switch_random, randomDigit, ())
randomDigit_t.start()
seq_digit.start()
##============Timed Nixie Refresh Animate END=============##


##Parsing UBX Package
def Checksum(data):
    a = 0x00
    b = 0x00
    for byte in data:
        i = byte
        a += i
        b += a
        a &= 0xff
        b &= 0xff
    return  b*256 + a

flag_UBX = False

try:
    while 1:
        data = sys.stdin.buffer.read(1)
        if data == b'\xB5':
            flag_UBX = True

            SYNC = sys.stdin.buffer.read(1)

            if SYNC != b'\x62':
                continue

            CLASS = sys.stdin.buffer.read(1)
            ID = sys.stdin.buffer.read(1)
            #print("[GPS Parse]",SYNC,CLASS,ID)
            LENGTH = sys.stdin.buffer.read(2)
            (length,) = unpack('H', LENGTH)

            #print(SYNC,CLASS,ID,LENGTH)

            PAYLOAD = sys.stdin.buffer.read(length)

            CHECKSUM = sys.stdin.buffer.read(2)
            (msgCksum,) = unpack('H',CHECKSUM)
            #print ('{:02x}'.format(msgCksum))

            DATA = CLASS+ID+LENGTH+PAYLOAD
            print (''.join(format(x, '02x') for x in DATA))

            if CLASS == b'\x0D' and ID == b'\x01': #TIM_TP
                try:
                    (towMS,towSubMS,qErr,week,flags,refInfo) = unpack('IIiHBB', PAYLOAD)
                    print (''.join(format(x, '02x') for x in PAYLOAD))
                    
                    trueCksum = Checksum(DATA)
                    print(towMS,towSubMS,qErr,week,flags,refInfo)

                    if trueCksum != msgCksum:
                        raise Exception(
                            "Calculated checksum 0x{:02x} does not match 0x{:02x}."
                            .format(trueCksum,msgCksum)
                            )
                    qErrStr = str(time.time()) + "," + str(qErr)
                    qErrStr = qErrStr.encode()
                    print(qErrStr)
                    body = [
                        {
                            "measurement": "GPS",
                            "time": datetime.datetime.utcnow(),
                            "fields": {
                                "Next Clock Offset": qErr
                            }
                        }
                    ]
                    print(body)
                    dataQueue.put(body)
                    offset = Nextoffset
                    Nextoffset = float(qErr)/100000

                except Exception as e:
                    print(e)
                    print(CLASS+ID+PAYLOAD)
                    body = [
                        {
                            "measurement": "GPS",
                            "time": datetime.datetime.utcnow(),
                            "fields": {
                                "Next Clock Offset": 0
                            }
                        }
                    ]
                    print(body)
                    dataQueue.put(body)
                    offset = 0
                    pass

except KeyboardInterrupt:
    sys.exit()