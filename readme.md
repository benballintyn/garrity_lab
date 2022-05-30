This function takes as input two filenames (paths to files). The first file contains the video metadata. Example provided when writing the code was a .txt file but had .json format. The second file is a .csv file containing the temperature data. Example file when writing code had 4 header rows ('Timestamp', 'Interval', 'Channel name', and 'Unit') before the first data point.

In order to synch the video frames and temperature data as closely as possible, it is necessary to read out the timestamps of both data types. These timestamps were provided in the hr:min:sec format (or in the case of the video file hr:min:sec.msec). If this format changes, this code will no longer work.

In addition to the filenames, this function accepts 2 optional arguments via varargin:

1) 'synchMethod' : Can be either 'exactInterp' or 'nearestNeighbor'. Default is 'exactInterp'.\
'exactInterp'
: Uses a simple form of inverse distance weighting to determine the temperature value at the timepoint of a given video frame. For a given video frame, the nearest temperature readings (in time, before and after the video frame) are weighted and averaged according to:\
$$\hat{T}(t) =  \dfrac{(\dfrac{1}{\Delta t_1})T_1 + (\dfrac{1}{\Delta t_2})T_2}{\dfrac{1}{\Delta T_1} + \dfrac{1}{\Delta T_2}} $$ \
\
where:\
$T_1$ is the temperature at $t_1$ and $\Delta T_1$ is the time difference between the time of the video frame and $t_1$

In the case where the video frame and a temperature value are already perfectly synched (unlikely), only that temperature value is used.\
In the case where the time of video frame is slightly before the first temperature reading (within 'synchErrorTolerance', see below) or slightly after the last temperature reading, only that first or last temperature reading is assigned to that video frame.

2) 'synchErrorTolerance'
: The maximum allowable time difference (in ms) between a video frame timestamp and its nearest (in time) temperature reading. Default value is 100ms. Video frames with no temperature reading within 'synchErrorTolerance' ms will have a NaN as the reported temperature value.\
\
Output:\
synchedData
: A table with 7 columns\
1\) Frame      : Video frame #\
2\) TimeElapsed: Time elapsed (in ms) since the beginning of the video recording. This value is taken from the ElapsedTime_ms field in the metadata.\
3\) Celsius    : Temperature in degrees Celsius. Converted from the raw voltage values by $$Celsius = Voltage \times 0.04113 - 0.67726$$\
4\) SynchError : Time in ms between the video frame timestamp and the nearest temperature value\
5\) VideoTime  : Time in ms from the start of the day (12am) to the current video frame\
6\) TempTime   : Time in ms from the start of the day (12am) to the nearest temperature value\
7\) isInterpolated : Boolean value indicating whether the Celsius value was derived from the above interpolation or not (1 = true, 0 = false)


