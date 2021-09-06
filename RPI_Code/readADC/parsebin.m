close all
clear all

fid = fopen('Waveform_20210828_155900.bin');
fseek(fid, 0, 'eof');
filesize = ftell(fid)
fclose(fid);

m = memmapfile('Waveform_20210828_155900.bin',                   ...
               'Format', {                      ...
                  'uint32'  [1 1] 'secondsOfDay';       ...
                  'uint32' [1 1] 'fifo';    ...
                  'uint16' [1 1] 'timestamp';   ...
                  'uint16' [1 1] 'adc_data'},   ...
               'Repeat', filesize/12);

           
T = struct2table(m.Data);
m=1;

timestamp = T.timestamp;
seconds=0;
time = cast(timestamp,'double')./50000;
for i=1:size(timestamp,1)
    
    if timestamp(i) == 49999
        seconds = seconds + 1;
    end
    time(i) = time(i) + seconds;
end
%double voltage = ((double)adc_data - 32813.7864224796) * 0.001032546059765 -0.013938492775101;
%ACMains_voltage = 8.81353422918265*VRMS_average +  -3.41515186652297
voltage = (cast(T.adc_data,'double') - 32813.7864224796) * 0.001032546059765 -0.013938492775101;
AC = 8.81353422918265*voltage -3.41515186652297;
plot(time,AC)