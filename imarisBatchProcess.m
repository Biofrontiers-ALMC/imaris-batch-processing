%This script will run batch processing using Imaris. To run this script,
%Imaris must first be open, then click on "Surpass". If you are not in the
%Surpass screen, Imaris will crash.
%
%Thie script will run channel arithmetic to average channels 1 and 2, then
%create a mask from a surface object. Note that the surface must already
%have been created in Imaris before running this script. The new data will
%then be saved in a separate file labeled with the suffix "_processed".

clearvars
clc

%Select files
[files, fpath] = uigetfile({'*.ims', 'Imaris files (*.ims)'; ...
    '*.*', 'All files (*.*)'}, ...
    'Select Files', 'MultiSelect', 'on');

if isequal(files, 0)
    disp('No files selected. Stopping.\n')
    return;
end

if ~iscell(files)
    files = {files};
end

for iFile = 1:numel(files)
    files{iFile} = fullfile(fpath, files{iFile});
end

%Connect to a running Imaris instance
imarisApplication = connectToImaris();

if isempty(imarisApplication)
    error('Could not connect to Imaris. Is it running?')
end

%Process each file
for iFile = 1:numel(files)

    %Open the file in Imaris
    imarisApplication.FileOpen(files{iFile},'');

    %Apply channel arithmetic
    channelArithmetic(imarisApplication, '(ch1 + ch2)/2');

    %--Create a mask--%

    %Get image sizes
    imarisImage = imarisApplication.GetImage(0);
    imageSizeC = imarisImage.GetSizeC;
    imageWidthX = imarisImage.GetSizeX;
    imageWidthY = imarisImage.GetSizeY;
    imageWidthZ = imarisImage.GetSizeZ;

    %Create a new channel for the mask
    imarisImage.SetSizeC(imageSizeC + 1);
    imarisImage.SetChannelName(imageSizeC, 'Masked image');

    %Create a mask
    surpassScene = imarisApplication.GetSurpassScene();
    numChildren = surpassScene.GetNumberOfChildren;

    %Find the surface item
    foundSurface = false;
    for ii = 1:numChildren
        item = surpassScene.GetChild(ii - 1);
        if imarisApplication.GetFactory.IsSurfaces(item)
            foundSurface = true;
            disp('Found surface')
            break
        end
    end

    if ~foundSurface
        warning('No surface object found. No mask has been created.')
        continue;
    end
    
    %Convert the item to a surface object
    imarisSurface = imarisApplication.GetFactory.ToSurfaces(item);

    %Make a mask (aMinX, aMinY, aMinZ, aMaxX, aMaxY, aMaxZ, aSizeX, aSizeY,
    %aSizeZ, aTimeIndex)
    imarisMask = imarisSurface.GetMask(0, 0, 0, ...
        imageWidthX, imageWidthY, imageWidthZ,...
        imageWidthX, imageWidthY, imageWidthZ, 0);

    %Convert Imaris mask object to image data
    maskData = uint16(imarisMask.GetDataVolumeAs1DArrayShorts(0, 0));

    %Add the mask data to the new channel
    imarisImage.SetDataVolumeAs1DArrayShorts(maskData, imageSizeC, 0);

    %--End add mask--%

    %Processing is complete. Save the data in a new image.
    imarisApplication.FileSave(fullfile(fn(1:end-4), '_processed.ims'), '');

end

function imarisApplication = connectToImaris()

javaaddpath('C:\Program Files\Bitplane\Imaris 9.8.2\XT\matlab\ImarisLib.jar');
vImarisLib = ImarisLib;
server = vImarisLib.GetServer();
id = server.GetObjectID(0);
imarisApplication = vImarisLib.GetApplication(id);

end




