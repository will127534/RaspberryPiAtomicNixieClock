#define _GNU_SOURCE
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/types.h>
#include <linux/spi/spidev.h>
#include <string.h>
#include <stdbool.h>
#include <time.h>
#include <fcntl.h>
#include <sys/time.h>
#include <inttypes.h>
#include <math.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

// File Related Var
char *folder;
FILE *ADCFile;
FILE *FreqFile;
bool changed_FreqFile,changed_ADCFile;

// Calculate Freq, Vrms, Max, Low Voltage Related Var
bool positive_flag = 0;
uint16_t last_timestamp = 0;
double last_timestamp_fp = 0;
double last_adc_voltage = 0;
double heighest_voltage = 0;
double lowset_voltage = 0;
double rms_voltage_square_sum = 0;
int rms_voltage_count = 0;

// FPGA data Related Var
uint16_t *read_count;
uint32_t *secondsOfDay;
uint16_t *pps_timestamp;
char *buf_data;

//FIFO Related Var
volatile uint16_t *queue_write;
volatile uint16_t *queue_read;
const uint16_t queue_length = 3000;

//Read FIFO FPGA CMD
const char buf_readFIFO[9] = {128+2,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};

//Init SPIdev
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

//Clear FPGA FIFO
void setup_fifo(int file, struct spi_ioc_transfer xfer_conf){
    int status;
    char buf[2] = {0x00,0x04};
    //xfer.tx_buf = (unsigned long) buf_out;
    //xfer.len = 4; /* Length of  command to write*/
    xfer_conf.rx_buf = (unsigned long) NULL;
    xfer_conf.tx_buf = (unsigned long) buf;
    xfer_conf.len = 2; /* Length of Data to read */

    status = ioctl(file, SPI_IOC_MESSAGE(1), &xfer_conf);
    if (status < 0) {
        perror("SPI_IOC_MESSAGE");
        return ;
    }
}

//Write Frequency to File
void writeFrequency(uint16_t timestamp, double frequency, double rms_voltage){
    time_t current_time;
    struct tm * time_info;
    char buffer[200] = {0};

    time_t s;  // Seconds
    struct timespec spec;
    clock_gettime(CLOCK_REALTIME, &spec);
    s  = spec.tv_sec;
    sprintf(buffer, "%"PRIdMAX".%09ld,%d,%f,%f\n",(intmax_t)s, spec.tv_nsec,timestamp,frequency,rms_voltage);

    fwrite(buffer,1,strlen(buffer),FreqFile);
    time(&current_time);
    time_info = localtime(&current_time);
    if ((time_info->tm_min % 5 == 0) & (changed_FreqFile == 0)) //Switch file per 5 min
    {
        char timeString[100] = {0};
        char fileString[100] = {0};
        strftime(timeString, sizeof(timeString), "ACFREQ_%Y%m%d_%H%M%S.txt", time_info);
        sprintf(fileString,"%s%s",folder,timeString);

        fclose(FreqFile);
        FreqFile = fopen(fileString,"w" );
        changed_FreqFile = 1;
    }
    if ((time_info->tm_min % 5 == 1) & (changed_FreqFile == 1))
    {
        changed_FreqFile = 0;
    }
}

//Process ADC raw data from FPGA
void process_data(int length, uint8_t* buf_in){
    for (int k=0;k<length;k++){
        for (int i=0;i<4;i++){
                uint16_t timestamp = (uint16_t)buf_in[1+k*16+i*4]*256+(uint16_t)buf_in[0+k*16+i*4];
                uint16_t adc_data = (uint16_t)buf_in[3+k*16+i*4]*256+(uint16_t)buf_in[2+k*16+i*4];
                int fifo = 0;
                if(k==0 & i == 0)
                    fifo = *read_count;
                double voltage = ((double)adc_data - 32813.7864224796) * 0.001032546059765 -0.013938492775101;
                if(voltage > heighest_voltage) heighest_voltage = voltage;
                if(voltage < lowset_voltage) lowset_voltage = voltage;
                char buffer[200] = {0};
                //ASCII Format
                //sprintf(buffer, "%d,%d,%d,%d,%f\n",*secondsOfDay,fifo,timestamp,adc_data,voltage);
                //printf("%s",buffer);
                //fwrite(buffer,1,strlen(buffer),ADCFile);

                //Binary File Format 
                memcpy(buffer,secondsOfDay,sizeof(uint32_t));
                memcpy(buffer+4,read_count,sizeof(uint32_t));
                memcpy(buffer+8,&timestamp,sizeof(uint16_t));
                memcpy(buffer+10,&adc_data,sizeof(uint16_t));
                fwrite(buffer,1,12,ADCFile);

                if ( voltage>0 && positive_flag == 0 ){ //Zero corssing from negitive to positive
                    double current_timestamp_fp = -1 * last_adc_voltage / (voltage - last_adc_voltage);
                    uint16_t timestamp_duration = 0;
                    if(timestamp<last_timestamp) timestamp_duration = 50000-last_timestamp+timestamp;
                    else timestamp_duration = timestamp - last_timestamp;
                    double cycle_time = (double)timestamp_duration * 1 / 50000 + (current_timestamp_fp - last_timestamp_fp)* 1 / 50000;
                    double frequency = 1/cycle_time;
                    double rms_voltage = sqrt(rms_voltage_square_sum/rms_voltage_count);
                    printf("%f,%f,%5d.%0.5f,%5d.%0.5f,%f,%f,%f,%f,%f\n",last_adc_voltage,voltage,timestamp,current_timestamp_fp,last_timestamp,last_timestamp_fp,cycle_time,frequency,rms_voltage,heighest_voltage,lowset_voltage);
                    writeFrequency(timestamp,frequency,rms_voltage);
                    last_timestamp = timestamp;
                    last_timestamp_fp = current_timestamp_fp;
                    lowset_voltage = 0;
                    heighest_voltage = 0;
                    rms_voltage_square_sum = 0;
                    rms_voltage_count = 0;
                }

                rms_voltage_square_sum += voltage*voltage;
                rms_voltage_count += 1;

                positive_flag = (voltage>0);
                last_adc_voltage = voltage;
        }
    }
}


void main(int argc, char *argv[]){
    folder = argv[1];

    // Share Memory for Thread communication 
    int shm_id;
    shm_id = shmget(IPC_PRIVATE, 12+3000*16, IPC_CREAT | 0666);
    if (shm_id < 0) {
         printf("shmget error\n");
         exit(1);
    }

    // Forking two thread - Reading and Processing
    pid_t child_a, child_b;
    child_a = fork();

    if (child_a == 0) {
        /* Child code */
        printf("Read Thread Start\n");

        //Get the share memory
        char *shm_addr;
        shm_addr = shmat(shm_id, NULL, 0);
        if (shm_addr == (char *)(-1)) {
            perror("shmat");
            exit(1);
        }

        //Start of the SHM is the pointer of FIFO and FPGA data
        queue_write = (uint16_t*)shm_addr;
        queue_read = (uint16_t*)shm_addr + 2;

        read_count = (uint16_t*)shm_addr + 4;
        secondsOfDay = (uint32_t*)shm_addr + 6;
        pps_timestamp = (uint16_t*)shm_addr + 10;

        //FIFO Data is after this
        buf_data = (char*)shm_addr + 64;

        //Set write point to 0
        *queue_write = 0;

        //Lock the reading thread to CPU 2 only
        cpu_set_t  mask;
        CPU_ZERO(&mask);
        CPU_SET(2, &mask);
        int result = sched_setaffinity(0, sizeof(mask), &mask);


        //INIT SPI
        char buf_in_DATA[255*16+2];
        char buf_in_FIFO[9] = {0};
        int file=spi_init("/dev/spidev0.1");
        int file_conf=spi_init("/dev/spidev0.0"); 

        int mode = SPI_MODE_0;
        ioctl(file,SPI_IOC_WR_MODE,&mode);

        struct spi_ioc_transfer xfer[2];
        struct spi_ioc_transfer xfer_conf;
        memset((void*)&xfer_conf,0,sizeof(xfer_conf));
        memset((void*)xfer,0,sizeof(xfer));

        xfer[0].len = 4; 
        xfer[0].cs_change = 0; 
        xfer[0].delay_usecs = 0,
        xfer[0].speed_hz = 12500000, 
        xfer[0].bits_per_word = 8, 

        xfer[1].len = 4; 
        xfer[1].cs_change = 0; 
        xfer[1].delay_usecs = 0, 
        xfer[1].speed_hz = 12500000,
        xfer[1].bits_per_word = 8, 

        xfer_conf.len = 4; 
        xfer_conf.cs_change = 0; 
        xfer_conf.delay_usecs = 0, 
        xfer_conf.speed_hz = 6250000, 
        xfer_conf.bits_per_word = 8, 

        //CLEAR FIFO
        setup_fifo(file_conf,xfer_conf);

        while(1){
            //Read FIFO count, ADC_Tag, Current Time
            xfer_conf.rx_buf = (unsigned long) buf_in_FIFO;
            xfer_conf.tx_buf = (unsigned long) buf_readFIFO;
            xfer_conf.len = 9;

            int status = ioctl(file_conf, SPI_IOC_MESSAGE(1), &xfer_conf);
            if (status < 0)
                {
                perror("SPI_IOC_MESSAGE");
                return;
                }
            //printf("env: %02x %02x %02x %02x %02x\n", buf_out[0], buf_out[1], buf_out[2], buf_out[3],buf_out[4]);
            //printf("ret: %02x %02x %02x %02x %02x %02x %02x %02x %02x\n", buf_in_2[0], buf_in_2[1], buf_in_2[2], buf_in_2[3], buf_in_2[4], buf_in_2[5], buf_in_2[6], buf_in_2[7], buf_in_2[8]);

            *read_count = buf_in_FIFO[3]*256+buf_in_FIFO[2];
            *secondsOfDay = (int)buf_in_FIFO[8]*3600+(int)buf_in_FIFO[7]*60+(int)buf_in_FIFO[6];
            *pps_timestamp = buf_in_FIFO[5]*256+buf_in_FIFO[4];

            //printf("Reading....%d,%d,%d\n",*read_count,*pps_timestamp,*secondsOfDay);

            //If FIFO count is not zero then read the indicated amount
            if (*read_count == 0) continue;
            int transferCount = *read_count > 255 ? 255 : *read_count;

            xfer[0].rx_buf = (unsigned long) buf_in_DATA;
            xfer[0].tx_buf = (unsigned long) NULL;
            xfer[0].len = transferCount*16 + 2; 

            //printf("Reading....%d\n",transferCount);
            status = ioctl(file, SPI_IOC_MESSAGE(1), &xfer);
            if (status < 0){
                perror("SPI_IOC_MESSAGE");
                return;
            }

            //Put to SHM and advance write pointer
            memcpy(buf_data+*queue_write*16,buf_in_DATA+2,transferCount*16);
            int queue_write_next = (*queue_write+transferCount)%queue_length;
            //*queue_write += transferCount;
            *queue_write = queue_write_next;

            //Clear SPI buffer
            memset(buf_in_DATA,0,sizeof(buf_in_DATA));
        }
    } 
    else {
        printf("Process Thread Start\n");

        //Open file with timestamp
        time_t current_time;
        struct tm * time_info;
        time(&current_time);
        time_info = localtime(&current_time);

        char timeString[100] = {0};
        strftime(timeString, sizeof(timeString), "Waveform_%Y%m%d_%H%M%S.bin", time_info);
        char fileString[100] = {0};
        sprintf(fileString,"%s%s",folder,timeString);
        printf("Write to: %s\n",fileString);
        ADCFile = fopen( fileString,"w");
        //fcntl(ADCFile, F_SETFL, O_NONBLOCK);

        strftime(timeString, sizeof(timeString), "ACFREQ_%Y%m%d_%H%M%S.txt", time_info);
        sprintf(fileString,"%s%s",folder,timeString);
        printf("Write to: %s\n",fileString);
        FreqFile = fopen(fileString,"w");

        int current_fileSecond = 0;

        //Open SHM
        char *shm_addr;
        shm_addr = shmat(shm_id, NULL, 0);
        if (shm_addr == (char *)(-1)) {
            perror("shmat");
            exit(1);
        }

        queue_write = (uint16_t*)shm_addr;
        queue_read = (uint16_t*)shm_addr + 2;

        read_count = (uint16_t*)shm_addr + 4;
        secondsOfDay = (uint32_t*)shm_addr + 6;
        pps_timestamp = (uint16_t*)shm_addr + 10;

        buf_data = shm_addr + 64;

        //Setup read pointer
        *queue_read = 0;

        while(1){
            if(*queue_read == *queue_write){
                //printf("Processing....%d,%d\n",*queue_read,*queue_write);
                usleep(1000*20);
                continue;
            }
            int queue_write_backup = *queue_write;
            //printf("Processing....%d,%d\n",*queue_read,queue_write_backup);
            if(*queue_read > queue_write_backup){
                int read_size = queue_length - *queue_read;
                process_data(read_size, buf_data+*queue_read*16);
                read_size = queue_write_backup;
                process_data(read_size, buf_data);
            }
            else{
                int read_size = queue_write_backup - *queue_read;
                process_data(read_size, buf_data+*queue_read*16);
            }
            *queue_read = queue_write_backup;

            if(*secondsOfDay % 60 == 0 && current_fileSecond != *secondsOfDay){
                fclose(ADCFile);
                time_t current_time;
                struct tm * time_info;
                time(&current_time);
                time_info = localtime(&current_time);

                int hour = *secondsOfDay/3600;
                int minute = (*secondsOfDay/60)%60;
                int seconds = *secondsOfDay%60;

                char dateString[100] = {0};
                strftime(dateString, sizeof(dateString), "Waveform_%Y%m%d_", time_info);
                char timeString[100] = {0};
                sprintf(timeString,"%02d%02d%02d.bin",hour,minute,seconds);
                char fileString[100] = {0};
                sprintf(fileString,"%s%s%s",folder,dateString,timeString);
                printf("Write to: %s\n",fileString);
                ADCFile = fopen(fileString,"w");
                current_fileSecond = *secondsOfDay;
            }
        }
    }
}
