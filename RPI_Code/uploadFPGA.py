import RPi.GPIO as GPIO
import time
import os

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)

FPGA_RST = 27
FPGA_CE = 8

GPIO.setup(FPGA_RST, GPIO.OUT)
GPIO.setup(FPGA_CE, GPIO.OUT)

GPIO.output(FPGA_CE, 0)

GPIO.output(FPGA_RST, 0)
time.sleep(1)
GPIO.output(FPGA_RST, 1)

os.system('sudo bash ./uploadfpga.sh main_bitmap.bin')

GPIO.output(FPGA_CE, 1)
