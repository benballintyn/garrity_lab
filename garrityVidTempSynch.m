function [synchedData] = garrityVidTempSynch(vidDataFname,tempDataFname,varargin)
% Written by Ben Ballintyn (bbal@brandeis.edu) 05/2022
% garrityVidTempSynch(vidDataFname, tempDataFname, varargin)
%
% vidDataFname : string with path to file with video metadata (e.g.
% ~/mydata/metadata.txt
%
% tempDataFname : string with path to file with temperature data. Assumed
% to be a .csv file
%
% varargin : Two optional inputs
%
%   'synchMethod' : either 'exactInterp' or 'nearestNeighbor'.
%   'exactInterp' will find the closest (in time) temperature values to the
%   current video frame and perform a weighted average (weighted by time
%   difference from the video frame). 'nearestNeighbor' simply uses the
%   temperature value that is closest (in time) to the current video frame
%
%   'synchErrorTolerance' : Maximum amount of synchError (in milliseconds)
%   allowed. synchError is defined as the absolute time difference between
%   the current video frame and the nearest temperature value. Default
%   value is 100ms. Any video frames in which there is no temperature value
%   within 'synchErrorTolerance' ms is filled in with NaN values for the
%   temperature.


% Disable warnings until end of table creation
warning('off','all')
nWarns = 0; % Counts number of warnings to produce at the end
warnFlags = {};

% Parse inputs
isASynchMethod = @(x) ismember(x,{'exactInterp','nearestNeighbor'});
p = inputParser;
addRequired(p,'vidDataFname')
addRequired(p,'tempDataFname')
addParameter(p,'synchMethod','exactInterp',isASynchMethod)
addParameter(p,'synchErrorTolerance',100,@isnumeric)
parse(p,vidDataFname,tempDataFname,varargin{:})

% Read in data. Temp data is read into a table. Video metadata is read as a
% JSON file and decoded by jsondecode into a structure
T = readtable(tempDataFname);
fid = fopen(vidDataFname);
raw = fread(fid,inf);
str = char(raw');
fclose(fid);
vidStr = jsondecode(str);

% Extract starting time of temperature recording in ms since start of day
tempTimeStamp = T.Var2{1};
isAM = contains(tempTimeStamp,'AM');
isPM = contains(tempTimeStamp,'PM');
if (~isAM && ~isPM)
    error('Neither AM or PM is listed in the timestamp of the temperature file')
end
spaceInds = strfind(tempTimeStamp,' ');
colonInds = strfind(tempTimeStamp,':');
tempHrs = str2num(tempTimeStamp(spaceInds(1)+1:colonInds(1)-1));
if (isPM)
    tempHrs = tempHrs + 12;
end
tempMins = str2num(tempTimeStamp(colonInds(1)+1:colonInds(2)-1));
tempSecs = str2num(tempTimeStamp(colonInds(2)+1:spaceInds(2)-1));
tempDayTimeInMsecs = (tempHrs*3600 + tempMins*60 + tempSecs)*1000;

% Extract starting time of video recording in ms since start of day
vidTimeStamp = vidStr.Summary.StartTime;
spaceInds = strfind(vidTimeStamp,' ');
colonInds = strfind(vidTimeStamp,':');
dotInds = strfind(vidTimeStamp,'.');
vidHrs = str2num(vidTimeStamp(spaceInds(1)+1:colonInds(1)-1));
vidMins = str2num(vidTimeStamp(colonInds(1)+1:colonInds(2)-1));
vidSecs = str2num(vidTimeStamp(colonInds(2)+1:dotInds(1)-1));
vidMsecs = str2num(vidTimeStamp(dotInds(1)+1:spaceInds(2)-1));
vidDayTimeInMsecs = (vidHrs*3600 + vidMins*60 + vidSecs)*1000 + vidMsecs;

% Convert temp table into new table with times in ms and temperatures in
% celsius (conversion from voltage)
tempOnlyTable = cell2table(cell(0,2),'VariableNames',{'Timestamp','Celsius'});
startInd = 5;
for i=startInd:height(T)
    tempOnlyTable.Timestamp(i-startInd+1) = tempDayTimeInMsecs + str2num(T.Var1{i})*1000;
    tempOnlyTable.Celsius(i-startInd+1) = str2num(T.Var2{i})*0.04113 - 0.67726;
end

% Extract number of video frames
frameCount = 0;
vidFieldNames = fieldnames(vidStr);
for i=1:length(vidFieldNames)
    if (contains(vidFieldNames{i},'Metadata'))
        frameCount = frameCount + 1;
        metaDataFieldNames{frameCount} = vidFieldNames{i};
    end
end
if (frameCount ~= length(metaDataFieldNames))
    error('Numer of counted frames and number of metadata fields do not match')
end

% Extract timestamps and frame numbers into a table
vidOnlyTable = cell2table(cell(0,2),'Variablenames',{'Timestamp','frame'});
for i=1:frameCount
    if (~contains(metaDataFieldNames{i},num2str(i-1)))
        error(['Trying to extract times from frame ' num2str(i) ' but corresponding metadata field is ' metaDataFieldNames{i}])
    end
    elapsed_time = vidStr.(metaDataFieldNames{i}).ElapsedTime_ms;
    vidOnlyTable.Timestamp(i) = vidDayTimeInMsecs + elapsed_time;
    vidOnlyTable.frame(i) = vidStr.(metaDataFieldNames{i}).Frame;
    vidOnlyTable.elapsed_time(i) = elapsed_time;
end

% Begin synching process by determing whether video or temperature was
% started first
tStartDiff = vidDayTimeInMsecs - tempDayTimeInMsecs;
if (tStartDiff > 0)
    disp(['Temperature recording was started ' num2str(tStartDiff) 'ms before the video recording'])
    tdiffs = tempOnlyTable.Timestamp - vidOnlyTable.Timestamp(1);
    [~,tempSynchStartInd] = min(abs(tdiffs));
    disp(['Because of the start time offset, synched temperature values will begin on the ' num2str(tempSynchStartInd) 'th recorded value'])
elseif (tStartDiff < 0)
    disp(['Video recording was started ' num2str(-tStartDiff) 'ms before the temperature recording'])
    tdiffs = vidOnlyTable.Timestamp - tempOnlyTable.Timestamp(1);
    [~,vidSynchStartInd] = min(abs(tdiffs));
    disp(['Because of the start time offset, the first ' num2str(vidSynchStartInd) ' synched values will not contain temperature data'])
else
    disp('Wow! Both recordings were started at the exact same time!')
end

% Synch data using desired method
synchedData = cell2table(cell(0,7),'VariableNames',{'Frame','TimeElapsed','Celsius','SynchError','VideoTime','TempTime','isInterpolated'});
for i=1:frameCount
    synchedData.Frame(i) = vidOnlyTable.frame(i);
    synchedData.TimeElapsed(i) = vidOnlyTable.elapsed_time(i);
    if (strcmp(p.Results.synchMethod,'exactInterp'))
        tdiffs = vidOnlyTable.Timestamp(i) - tempOnlyTable.Timestamp;
        [~,bestInd] = min(abs(tdiffs));
        if (abs(tdiffs(bestInd)) > p.Results.synchErrorTolerance)
            if (~ismember(warnFlags,'synchToleranceExceeded'))
                nWarns = nWarns+1;
                warnFlags{nWarns} = 'synchToleranceExceeded';
            end
            synchedData.Celsius(i) = nan;
            synchedData.SynchError(i) = nan;
            synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
            synchedData.TempTime(i) = nan;
            synchedData.isInterpolated(i) = false;
            continue;
        end
        if (tdiffs(bestInd) > 0)
            if (bestInd ~= height(tempOnlyTable))
                diff1 = tdiffs(bestInd);
                diff2 = tempOnlyTable.Timestamp(bestInd+1) - vidOnlyTable.Timestamp(i);
                interpolatedTemperature = ((1/diff1)*tempOnlyTable.Celsius(bestInd) + (1/diff2)*tempOnlyTable.Celsius(bestInd+1))/((1/diff1)+(1/diff2));
                synchedData.Celsius(i) = interpolatedTemperature;
                synchedData.SynchError(i) = abs(tdiffs(bestInd));
                synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
                synchedData.TempTime(i) = tempOnlyTable.Timestamp(i);
                synchedData.isInterpolated(i) = true;
            else
                synchedData.Celsius(i) = tempOnlyTable.Celsius(bestInd);
                synchedData.SynchError(i) = abs(tdiffs(bestInd));
                synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
                synchedData.TempTime(i) = tempOnlyTable.Timestamp(i);
                synchedData.isInterpolated(i) = false;
            end
        elseif (tdiffs(bestInd) < 0)
            if (bestInd > 1)
                diff1 = -tdiffs(bestInd);
                diff2 = vidOnlyTable.Timestamp(i) - tempOnlyTable.Timestamp(bestInd-1);
                interpolatedTemperature = ((1/diff1)*tempOnlyTable.Celsius(bestInd) + (1/diff2)*tempOnlyTable.Celsius(bestInd-1))/((1/diff1)+(1/diff2));
                synchedData.Celsius(i) = interpolatedTemperature;
                synchedData.SynchError(i) = abs(tdiffs(bestInd));
                synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
                synchedData.TempTime(i) = tempOnlyTable.Timestamp(i);
                synchedData.isInterpolated(i) = true;
            else
                synchedData.Celsius(i) = tempOnlyTable.Celsius(bestInd);
                synchedData.SynchError(i) = abs(tdiffs(bestInd));
                synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
                synchedData.TempTime(i) = tempOnlyTable.Timestamp(i);
                synchedData.isInterpolated(i) = false;
            end
        else
            synchedData.Celsius(i) = tempOnlyTable.Celsius(bestInd);
            synchedData.SynchError(i) = 0;
            synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
            synchedData.TempTime(i) = tempOnlyTable.Timestamp(i);
            synchedData.isInterpolated(i) = false;
        end
    elseif (strcmp(p.Results.synchMethod,'nearestNeighbor'))
        tdiffs = vidOnlyTable.Timestamp(i) - tempOnlyTable.Timestamp;
        [~,bestInd] = min(abs(tdiffs));
        if (abs(tdiffs(bestInd)) > p.Results.synchErrorTolerance)
            if (~ismember(warnFlags,'synchErrorExceeded'))
                nWarns = nWarns + 1;
                warnFlags(nWarns) = 'synchErrorExceeded';
            end
            synchedData.Celsius(i) = nan;
            synchedData.SynchError = nan;
            synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
            synchedData.TempTime(i) = nan;
            synchedData.isInterpolated(i) = false;
        else
            synchedData.Celsius(i) = tempOnlyTable.Celsius(bestInd);
            synchedData.SynchError(i) = abs(tdiffs(bestInd));
            synchedData.VideoTime(i) = vidOnlyTable.Timestamp(i);
            synchedData.TempTime(i) = tempOnlyTable.Timestamp(bestInd);
            synchedData.isInterpolated(i) = false;
        end
    end
end

warning('on','all')
for i=1:nWarns
    switch warnFlags{i}
        case 'synchToleranceExceeded'
            warning(['At least one data point exceeded the allowed synchErrorTolerance, currently set at ' ...
                     num2str(p.Results.synchErrorTolerance) 'ms. This may be because the temperature recording' ...
                     ' was started after the video recording.'])
    end
end
end

