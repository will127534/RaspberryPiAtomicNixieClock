sudo mount -t tmpfs -o size=500M tmpfs /home/pi/ramdisk/
sudo mount /dev/nvme0n1p1 /home/pi/external/
sudo sysctl fs.pipe-max-size=33554432