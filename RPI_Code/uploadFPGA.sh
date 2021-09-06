echo ""
if [ $# -ne 1 ]; then
    echo "Usage: $0 FPGA-bin-file "
    exit 1
fi


#echo ""
#echo "Changing 8 direction to out"
#echo out > /sys/class/gpio/gpio8/direction
#cat /sys/class/gpio/gpio8/direction
#gpio mode 8 out

#echo ""
#echo "Changing 27 direction to out"
#echo out > /sys/class/gpio/gpio27/direction
#cat /sys/class/gpio/gpio27/direction
#gpio mode 27 out

#echo "Setting output to low"
#echo 0 > /sys/class/gpio/gpio8/value
#cat /sys/class/gpio/gpio8/value
#gpio write 8 0

#echo "Reseting"
#echo 0 > /sys/class/gpio/gpio27/value
#echo 1 > /sys/class/gpio/gpio27/value
#gpio write 27 0
#gpio write 27 1

#echo "Continuing with configuration procedure"
dd if=$1 of=/dev/spidev0.0

echo -e "\x0\x0\x0\x0\x0\x0\x0" > /dev/spidev0.0

#echo "Setting output to high"
#echo 1 > /sys/class/gpio/gpio8/value
#cat /sys/class/gpio/gpio8/value
#gpio write 8 1

