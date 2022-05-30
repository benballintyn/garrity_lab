This function takes as input two filenames (paths to files). The first file contains the video metadata. Example provided when writing the code was a .txt file but had .json format. The second file is a .csv file containing the temperature data. Example file when writing code had 4 header rows ('Timestamp', 'Interval', 'Channel name', and 'Unit') before the first data point.

In order to synch the video frames and temperature data as closely as possible, it is necessary to read out the timestamps of both data types. These timestamps were provided in the hr:min:sec format (or in the case of the video file hr:min:sec.msec). If this format changes, this code will no longer work.

In addition to the filenames, this function accepts 2 optional arguments via varargin:

1) 'synchMethod' : Can be either 'exactInterp' or 'nearestNeighbor'\
'exactInterp'
: Uses a simple form of inverse distance weighting to determine the temperature value at the timepoint of a given video frame. For a given video frame, the nearest temperature readings (in time, before and after the video frame) are weighted and averaged according to:\
$$\hat{T(t)} = (\dfrac{1}{\Delta t_1}) $$


