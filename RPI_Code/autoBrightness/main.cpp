
#include <iostream>
#include <errno.h>
#include <wiringPiI2C.h>
#include "TSL2561.h"
#include "Adafruit_PWMServoDriver.h"
#include <unistd.h>
#include <stdlib.h> 
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/types.h>
#include <linux/spi/spidev.h>
#include <stdio.h>
#include <cstring>
#include <math.h>
using namespace std;

TSL2561 tsl; 
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(0x60);
struct spi_ioc_transfer xfer[2];

int spi_init(char filename[40]){
    int file;

    if ((file = open(filename,O_RDWR)) < 0)
    {
        printf("Failed to open the bus.");
        /* ERROR HANDLING; you can check errno to see what went wrong */
        exit(1);
    }
    return file;
}

void write_PDM_Clock_Divider(int file, uint16_t div){
    int status;
    char buf1[2] = {12,div};
    char buf2[2] = {13,div>>8};
    //xfer.tx_buf = (unsigned long) buf_out;
    //xfer.len = 4; /* Length of  command to write*/
    xfer[0].rx_buf = (unsigned long) NULL;
    xfer[0].tx_buf = (unsigned long) buf1;
    xfer[0].len = 2; /* Length of Data to read */
    xfer[0].cs_change = 1; 
    xfer[1].rx_buf = (unsigned long) NULL;
    xfer[1].tx_buf = (unsigned long) buf2;
    xfer[1].len = 2; /* Length of Data to read */
    
    status = ioctl(file, SPI_IOC_MESSAGE(2), &xfer);
    if (status < 0) {
        perror("SPI_IOC_MESSAGE");
        return ;
    }
}

void write_PDM_value(int file, uint16_t val){
    int status;
    char buf1[2] = {10,val};
    char buf2[2] = {11,val>>8};

    //printf("sent: %02x %02x %02x %02x\n", buf1[0], buf1[1], buf2[0], buf2[1]);
    //xfer.tx_buf = (unsigned long) buf_out;
    //xfer.len = 4; /* Length of  command to write*/
    xfer[0].rx_buf = (unsigned long) NULL;
    xfer[0].tx_buf = (unsigned long) buf1;
    xfer[0].len = 2; /* Length of Data to read */
    xfer[0].cs_change = 1; 
    xfer[1].rx_buf = (unsigned long) NULL;
    xfer[1].tx_buf = (unsigned long) buf2;
    xfer[1].len = 2; /* Length of Data to read */

    
    status = ioctl(file, SPI_IOC_MESSAGE(2), &xfer);
    if (status < 0) {
        perror("SPI_IOC_MESSAGE");
        return ;
    }

}


void enable_PDM(int file){
    int status;
    char buf[2] = {0x00,0x10};
    //xfer.tx_buf = (unsigned long) buf_out;
    //xfer.len = 4; /* Length of  command to write*/
    xfer[0].rx_buf = (unsigned long) NULL;
    xfer[0].tx_buf = (unsigned long) buf;
    xfer[0].len = 2; /* Length of Data to read */

    status = ioctl(file, SPI_IOC_MESSAGE(1), &xfer);
    if (status < 0) {
        perror("SPI_IOC_MESSAGE");
        return ;
    }
}

int main(int argc, char **argv)
{
  if (argc < 2){
    cout << "./main [lowest_pwm]" << "\n"; 
  }
  int input = atoi(argv[1]);
  if(input > 4095) input = 4095;
  if(input < 0) input = 0;
  uint16_t lowest_PWM = input;

  int fd = wiringPiI2CSetup(TSL2561_ADDR_LOW);
  cout << "Init result: "<< fd << endl;

  if (tsl.begin(fd)) {
    cout << "Found sensor"<< fd << endl;
  } else {
    cout << "No sensor"<< fd << endl;
    while (1);
  }

  tsl.setGain(TSL2561_GAIN_16X);
  tsl.setTiming(TSL2561_INTEGRATIONTIME_101MS);


  memset((void*)xfer,0,sizeof(xfer));
  xfer[1].cs_change = 0;
  xfer[1].delay_usecs = 0;
  xfer[1].speed_hz = 6250000;
  xfer[1].bits_per_word = 8;
  xfer[0].cs_change = 0; 
  xfer[0].delay_usecs = 0;
  xfer[0].speed_hz = 6250000;
  xfer[0].bits_per_word = 8;

  int file_conf=spi_init("/dev/spidev0.0"); 
  enable_PDM(file_conf);
  write_PDM_Clock_Divider(file_conf,3000);

  pwm.begin();
  pwm.setPWMFreq(1000);
  for(int i=12;i<16;i++)
    pwm.setPWM(i, 0, 0);
  for (uint8_t pwmnum=4; pwmnum < 12; pwmnum++) {
    pwm.setPWM(pwmnum, 0, 4095);
  }

   while(1)
   {
      uint32_t lum = tsl.getFullLuminosity();
      uint16_t ir, full;
      ir = lum >> 16;
      full = lum & 0xFFFF;
      uint32_t lux = tsl.calculateLux(full, ir);
      

      uint16_t dutyCycle = pow(1.009, lux)*720.161525918474+2000;
      if (dutyCycle>65535){
        dutyCycle = 65535;
      }
      cout << "Lux:" << lux <<endl;
      //cout << "dutyCycle:" << dutyCycle <<endl;
      write_PDM_value(file_conf,dutyCycle);

      /*
      for (uint8_t pwmnum=4; pwmnum < 12; pwmnum++) {
        pwm.setPWM(pwmnum, 0, dutyCycle);
      }
      */
      //result = wiringPiI2CWriteReg16(fd, 0x40, (i & 0xfff) );
      /*
      if(result == -1)
      {
         cout << "Error.  Errno is: " << errno << endl;
      }
      */
   }
}