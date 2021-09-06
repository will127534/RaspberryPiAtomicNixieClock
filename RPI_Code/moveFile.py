import glob, os

os.chdir("/home/pi/ramdisk/")
fileList = []
for file in glob.glob("Wave*"):
    print(file)
    fileList.append(file)

fileList.sort()
fileList.pop()

for file in fileList:
	print(file)
	os.system('gzip -k ' + file)
	os.system('cp ' + file + '.gz ' + '/home/pi/external' )
	os.system('rm ' + file + '.gz ')
	os.system('rm ' + file )

fileList = []
for file in glob.glob("ACFREQ*"):
	print(file)
	fileList.append(file)

fileList.sort()
fileList.pop()

for file in fileList:
	print(file)
	os.system('cp ' + file  + ' /home/pi/external' )
	os.system('rm ' + file )

