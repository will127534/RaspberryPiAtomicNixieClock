# Raspberry Pi Code

The code is intended to document the communication with the FPGA and SA.3xm Atomic Clock.

## Setup

### Python Library
```
pip install -r requirements.txt
```
Library List:
* influxdb Client
* pyserial
* simple_pid
* adafruit-circuitpython-TMP117
* python-dateutil

### GPS
gpsd is not actually needed but I'm using it to parse some GPS NEMA data and connect to ntpd, so the program is designed around gpsd and take its serial dump and parse the UBX format phase error data.

Note also you should enable UBX-TIM-TP output of the uBlox GPS module.

### InfluxDB
InfluxDB is used to collect time series data. The setting is in **dbSetting.py**

## Code List

* **uploadClock.py**
    * The main program to communicate with FPGA
    * Reading FPGA data, including TDC7200 measurement
    * Setting up FPGA time and inital PPS alignment
    * Reading GPS Serial data from stdin and calculate corrected PPS error
    * Nixie Tube animate to prevent cathode poisoning
* **uploadMAC.py**
    * Reading MAC status and creating UDP server for other program to communicate with MAC. (**calibrateClock.py**)
* **calibrateClock.py**
    * The program to read current PPS error using InfluxDB and tune the clock EFC. The EFC tuning cmd is send via UDP package to **uploadMAC.py**. The tuning algroithm is a simple accumlated error.
* **readADC**
    * The C program to poll ADC reading and output frequency and Vrms data to stdio.
    * `gcc -o readADC ./readADC.c -lm -mcpu='cortex-a72' -O3`
    * `./readADC [folderPath]`
* **autoBrightness**
    * The C program to control Nixie Tube brightness. Reading Lux sensor and send cmd to FPGA.
    * `g++ -o autoBrightness ./main.cpp ./Adafruit_PWMServoDriver.cpp ./TSL2561.cpp -lwiringPi`
    * `autoBrightness [lowest_pwm]`
* **fanControl.py**
    * Reading TMP117 and using PID loop on the bottom fan to maintain the clock temperature
* mountdrive.sh
    * Create 512MB ramdisk to store AC waveform, and mounting NVMe drive.
* **moveFile.py**
    * Copy the file from ramdisk to NVMe drive.
* **uploadFPGA.py**
    * Uploading FPGA bin file via SPI
* **uploadFPGA.sh**
    * The helper shell script of **uploadFPGA.py**
* **dbSetting.py**
    * The settings for InfluxDB location
    
