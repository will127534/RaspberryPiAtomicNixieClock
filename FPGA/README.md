# Verilog Files

Designed for iCE5LP

## File List
 * main.v - top verilog code
 * Driver
     * ADS8681.v - ADS8681 Driver
     * tdc7200.v - tdc7200 Driver
     * nixie.v - HV5623/HV5623 Driver
     * spi_master.v - SoftIP SPI
     * spi_slave.v - Using HardIP block
 * Utility
     * coarsecounter.v - Simple Counter
     * bin2bcd.v - Binary to BCD Code for Nixie Tube
     * delayPPS.v - Generate constant cycle delay for a given input signal
     * fifo.v - FIFO using BRAM blocks
     * pps.v - Generate PPS signal, and optionaly can align with external PPS
     * pwm.v - Actually it is generating PDM signal
     * rtc.v - Really simple RTC, just counting the time for Nixie Clock
 * Testbench
     * counter_test.v - coarsecounter.v testing
     * pdm_test.v - pwm.v testing
     * spi_m_test.v
     * spi_s_test.v
 * pins.pcf - pin definition

## iCECube2 output 
> Device Utilization Summary
    LogicCells                  :	2050/3520
    PLBs                        :	346/440
    BRAMs                       :	16/20
    IOs and GBIOs               :	31/35
    PLLs                        :	0/1
    I2Cs                        :	0/2
    SPIs                        :	2/2
    DSPs                        :	0/4
    SBIOODs                     :	3/4
    LEDDRVs                     :	0/1
    RGBDRVs                     :	0/1
    IRDRVs                      :	0/1
    LEDDIPs                     :	0/1
    LFOSCs                      :	0/1
    HFOSCs                      :	1/1

>Number of clocks: 5
Clock: main|CLOCK | Frequency: 65.57 MHz | Target: 15.00 MHz
Clock: main|SCK | Frequency: 394.30 MHz | Target: 15.00 MHz
Clock: osc2.hfosc/CLKHF | Frequency: 113.89 MHz | Target: 48.00 MHz
Clock: rpi_adc_dev.sb_spi_inst/SCKO | Frequency: N/A | Target: 25.00 MHz
Clock: rpi_spi_dev.sb_spi_inst/SCKO | Frequency: N/A | Target: 25.00 MHz
