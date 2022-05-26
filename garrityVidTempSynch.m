function [vidOnlyTable, tempOnlyTable] = garrityVidTempSynch(vidDataFname,tempDataFname)
% Written by Ben Ballintyn (bbal@brandeis.edu) 05/22

% Disable warnings until end of table creation
warning('off','all')
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
% celcius (conversion from voltage)
tempOnlyTable = cell2table(cell(0,2),'VariableNames',{'Timestamp','Celcius'});
startInd = 5;
for i=startInd:height(T)
    tempOnlyTable.Timestamp(i-startInd+1) = tempDayTimeInMsecs + str2num(T.Var1{i})*1000;
    tempOnlyTable.Celcius(i-startInd+1) = str2num(T.Var2{i})*0.04113 - 0.67726;
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
end


end

