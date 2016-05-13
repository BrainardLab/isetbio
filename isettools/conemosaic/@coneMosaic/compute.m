function absorptions = compute(obj,oi,varargin)
%Compute absorptions using cone mosaic parameters and optical image 
%
%   coneM.compute(oi,'showBar',true)
%
%  This  top-level function  combines the parameters of an image sensor
%  array (sensor) and an optical image (oi) to produce the sensor volts
%  (electrons).
%
% Inputs
%    oi:       Optical irradiance data
%    showBar:  Show waitbar if 1, default is off (0)
%
% Return
%    coneM.absorptions contains the pattern of absorptions
%
%  The computation checks a variety of parameters and flags in the sensor
%  structure to perform the calculation.  These parameters and flags can be
%  set either through the graphical user interface (sensorImageWindow) or
%  by scripts.
%
%  One of the most important sensor parameters is the noise flag.  In
%  general, the sensorCompute includes photon and electrical noise in the
%  computation. But it is often useful to run the calculation without any
%  noise, or with photon noise only.  To set the type of noise calculation,
%  you must set the value of the sensor noise flag:
%
%    sensor = sensorSet(sensor,'noise flag',0);   % No noise
%    sensor = sensorSet(sensor,'noise flag',1);   % Photon only
%    sensor = sensorSet(sensor,'noise flag',2);   % Photon and electrical
%
%
% COMPUTATIONAL OUTLINE:
%
%   This routine provides an overview of the algorithms.  The specific
%   algorithms are described in the routines themselves.
%
%   2. Compute the mean image: sensorComputeImage()
%   4. Noise, analog gain, clipping, quantization
%
%  The value of showBar determines whether the waitbar is displayed to
%  indicate progress during the computation.
%
% See also:  sensorComputeNoise, sensorAddNoise
%
% Key computational flags:
%
%   Exposure Duration
%   Noise calculations
%
% Examples:
%   sensor = sensorCompute;   % Use selected sensor and oi
%   tmp = sensorCompute(vcGetObject('sensor'),vcGetObject('oi'),0);
%
%  Or, compute with specific sensors
%   scene = sceneCreate; scene = sceneSet(scene,'hfov',4);
%   oi = oiCreate; sensor = sensorCreate;
%   oi = oiCompute(oi,scene); sensor = sensorCompute(sensor,oi);
%   vcAddAndSelectObject(sensor); sensorWindow('scale',1);
%
% Copyright ImagEval Consultants, LLC, 2011

%% Define and initialize parameters



if showBar, wBar = waitbar(0,sprintf('Sensor %d image:  ',ss)); end

% Determine the exposure model
integrationTime = obj.integrationTime;
pattern = obj.pattern;
if (integrationTime == 0)
    % This could be auto-exposure.  But for this condition, we probably
    % shouldn't allow that.  So, let's just set it to 10 ms
    integrationTime = 0.010;
end

%% Calculate current
% This factor converts pixel current to volts for this integration time
% The conversion units are
%
%   sec * (V/e) * (e/charge) = V / (charge / sec) = V / current (amps).
%
% Given the basic rule V = IR, k is effectively a measure of resistance
% that converts current into volts given the exposure duration.
%
% We handle the case in which the integration time is a vector or
% matrix, by creating a matching conversion from current to volts.
q = vcConstants('q');     %Charge/electron
pixel = sensorGet(sensor,'pixel');
    
    % Convert current (Amps) to volts
    % Check the units:
    %  S * (V / e) * (Coulombs / e)^-1   % https://en.wikipedia.org/wiki/Coulomb
    %    = S * (V / e) * (( A S ) / e) ^-1
    %    = S * (V / e) * ( e / (A S)) = (V / A)
    cur2volt = sensorGet(sensor,'integrationTime') * ...
        pixelGet(pixel,'conversionGain') / q;
    cur2volt = cur2volt(:);
    
    % Calculate the signal current assuming cur2volt = 1;
    if showBar, unitSigCurrent = signalCurrent(oi,sensor,wBar);
    else            unitSigCurrent = signalCurrent(oi,sensor);
    end
    
    
    %% Convert to volts
    % Handle multiple exposure value case.
    if numel(cur2volt) == 1
        % There is only one exposure time.  Conventional calculation
        voltImage = cur2volt*unitSigCurrent;
    else
        % Multiple exposure times, so we copy the unit term into multiple
        % dimensions
        voltImage = repmat(unitSigCurrent,[1 1 length(cur2volt)]);
        % Multiply each dimension by its own scale factor
        for ii=1:length(cur2volt)
            voltImage (:,:,ii) = cur2volt(ii) * voltImage (:,:,ii);
        end
    end
    
    %% Calculate etendue from pixel vignetting
    % We want an array (wavelength-independent) of scale factors that account
    % for the loss of light() at each pixel as a function of the chief ray
    % angle. This method only works for wavelength-independent relative
    % illumination. See notes in signalCurrentDensity for another approach that
    % we might use some day, say in ISET-3.0
    if showBar, waitbar(0.4,wBar,'Sensor image: Optical Efficiency'); end
    sensor    = sensorVignetting(sensor);
    etendue   = sensorGet(sensor,'sensorEtendue');  
    % vcNewGraphWin; imagesc(etendue)
    
    voltImage = bsxfun(@times, voltImage, etendue);
    % vcNewGraphWin; imagesc(voltImage); colormap(gray)
    
    % This can be a single matrix or it can a volume of data. We should
    % consider whether we want to place the volume elsewhere and always
    % have voltImage be a matrix is displayed into the sensor window
    voltImage(voltImage < 0) = 0;
    sensor = sensorSet(sensor, 'volts', voltImage);
    
    % Something went wrong.  Return data empty,  including the noise images.
    if isempty(voltImage),
        % Something went wrong. Clean up the mess and return control to the
        % main processes.
        delete(wBar); return;
    end
    
    %% We have the mean image computed.  We add noise, clip and quantize
    
    % If there is some request for noise (noiseFlag not 0) run the noise.
    if sensorGet(sensor, 'noiseFlag')
        % If you have the mean and all you want is noise, you can just run
        % this.
        sensor = sensorComputeNoise(sensor,wBar);
    end
    
    
end

function signalCurrentImage = signalCurrent(OI,ISA,wBar)
% Compute the signal current at each pixel position
%
%    signalCurrentImage = signalCurrent(oi,sensor,wBarHandles)
%
%  The signal current is computed from the optical image (OI) and the image
%  sensor array properties (ISA). The units returned are charge/pixel/sec. 
%
%  This is a key routine called by sensorCompute.
%  The routine can compute the current in either the default spatial
%  resolution mode (1 spatial sample per pixel) or in a high-resolution
%  made in which the pixel is modeled as a grid of sub-pixels and we
%  integrate the spectral irradiance field across this grid, weighting it
%  for the light intensity and the pixel.  
%  
%  The default or high-resolution mode computation is governed by the
%  nSamplesPerPixel parameter in the sensor 
%
%        sensorGet(sensor,'nSamplesPerPixel');  
%
%  The default mode has a value of 1.  High resolution modes can be
%  computed with sensor = sensorSet(sensor,'nSamplesPerPixel',5) or some
%  other value.  If 5 is chosen, then there is a 5x5 grid placed over the
%  pixel to account for spatial sampling.
%
%  wBar is the handle to the waitbar image. 
%
% Copyright ImagEval Consultants, LLC, 2003.

% Programming note.  
% It might have been better to do the spatial integration to the pixel in
% the optical domain first, before computing the current density.  Then we
% could apply pixel optics at that stage rather than being limited as we
% are.  See related notes in signalCurrentDensity.

if notDefined('wBar'), showBar = 0; else showBar = 1; end 

% signalCurrentDensityImage samples the current/meter with a sample size of
% [nRows x nCols x nColors] that matches the optical image.
% The spatial integration to account for the pixel size happens next.
if showBar, waitbar(0.4,wBar,'Sensor image: Signal Current Density'); end
signalCurrentDensityImage = SignalCurrentDensity(OI,ISA);	    % [A/m^2]

if isempty(signalCurrentDensityImage)
    % This should never happen.
    signalCurrentImage = [];
    return;
else
    % Spatially interpolate the optical image with the image sensor array.
    % The optical image values describe the incident rate of photons.
    %
    % It should be possible to super-sample by setting gridSpacing to, say,
    % 0.2.  We could do this in the user-interface some day.  I am not sure
    % that it has much benefit, but it does take a lot more time and
    % memory.
    gridSpacing = 1/sensorGet(ISA, 'nSamplesPerPixel');
    if showBar
        waitbar(0.5, wBar, ...
            sprintf('Sensor image: Spatial (grid: %.2f)',gridSpacing));
    end
    signalCurrentImage = spatialIntegration(signalCurrentDensityImage,OI,ISA,gridSpacing); % [A]
end

end

function scdImage = SignalCurrentDensity(OI,ISA)
% Estimate signal current density (current (amps) /meter^2) across the sensor surface 
%
%       scdImage = SignalCurrentDensity(OI,ISA)
%
%  This image has a spatial sampling density equal to the spatial sampling
%  of the scene and describes the current (amps) per meter.
%
%  We perform the calculation two ways, depending on image size. First, we
%  try to calculate using a quick matrix multiplication. If this fail, we
%  compute the signal current by looping over all wavebands. It's slower,
%  but it works.
%
% Computational steps:
%
%   The irradiance image in photons (quanta) is multiplied by the spectral
%   QE information. 
%
%   The calculation treats the input data as irradiance (photons per wave
%   per square meter per sec), and estimates the fraction of these that are
%   effective. This is a (charge per second = current) per unit area (m^2).
%
%   Subsequent calculations (signalCurrent) account for the photodetector
%   area.
%
%   There are many comments in the code explaining each step.
%
% See: signalCurrent, sensorCompute, spatialIntegration
%
% Copyright ImagEval Consultants, LLC, 2003.

q = vcConstants('q');       % Charge per electron

% Hack.  But if we use sceneGet, we get all the data back.
if ~checkfields(OI, 'data', 'photons')   
    warning('Optical image irradiance in photons is required.'); 
    signalCurrentDensityImage = []; %#ok<NASGU>
    return; 
end

% Optical image variables.
oiWaveBinwidth = oiGet(OI,'binwidth');
nRows   = oiGet(OI,'rows');
nCols   = oiGet(OI,'cols');
oiWave  = oiGet(OI,'wave');
oiNWave = oiGet(OI,'nwave');

% Sensor variables
nFilters = sensorGet(ISA,'nfilters');
spectralQE = sensorGet(ISA,'spectralqe'); 
sensorWave = sensorGet(ISA,'wave');

% It is possible that the sensor spectral QE is not specified at the
% same wavelength sampling resolution as the irradiance.  In that case,
% we resample to the lower wavelength sampling resolution.
if ~isequal(oiWave,sensorWave) 
    % Adjust the sensor spectral QE wavelength sampling, in all of the
    % sensor color channels,  to match the irradiance wavelength sampling.
    % We do not change the sensor wavelength data here.
    if length(sensorWave) > 1
        spectralQE = interp1(sensorWave,spectralQE,oiWave,'linear',0);
    elseif ~isequal(sensorWave,oiWave)
        errordlg('Mis-match in sensor and oi wavelength functions.');
    end
end

%  At this point, the spectral quantum efficiency is defined over
%  wavelength bins of size oiWaveBinWidth. To count the number photons in
%  the entire bin, we must multiply by the bin width.
sQE = spectralQE*oiWaveBinwidth;

% Sensor etendue:  In all ISET calculations we treat the etendue (i.e. the
% pixel vignetting) as if it is wavelength independent.  This is an OK
% approximation.  But if we ever want to treat etendue as a function of
% wavelength, we will have to account for it at this point, before we
% collapse all the wavelength information into a single number (the signal
% current density).
%
% If we do that, we may need a space-varying wavelength calculation.  That
% would be computationally expensive.  We aren't yet ready for that level
% of detail.
%
% At present the etendue calculation is incorporated as a single scale
% factor at each pixel and incorporated in the sensorCompute routine. 

% sQE is a wavelength x nSensor matrix, and it includes a conversion
% factor that will maps the electrons per square meter into amps per
% square meter

% Multiply the optical image with the photodetector QE and the color
% filters.  Accumulated this way, we form a current density image at every
% position for all the color filters.
% Output units: [A/m^2]

try
    % This is probably much faster.  But if we are trying to limit the
    % memory size, we should use the other part of the loop that calculates
    % one waveband at a time.
    irradiance = oiGet(OI,'photons');       % quanta/m2/nm/sec
    irradiance = RGB2XWFormat(irradiance);
    
    scdImage =  irradiance * sQE; % (quanta/m2/sec)
    scdImage = XW2RGBFormat(scdImage,nRows,nCols);
    % At this point, if we multiply by the photodetector area and the
    % integration time, that gives us the number of electrons at a pixel.
catch
    % For large images, don't take all of the data out at once.  Do it a
    % waveband at a time.
    scdImage = zeros(nRows,nCols,nFilters);
    for ii=1:oiNWave
        irradiance = oiGet(OI,'photons',oiWave(ii));
        
        for jj=1:nFilters
            scdImage(:,:,jj) = scdImage(:,:,jj) + irradiance*sQE(ii,jj);
        end
    end
end

% Convert the photons into a charge using the constant that defines
% charge/electron.  This is the signal current density (scd) image 
% It has units of quanta/m2/sec/bin * charge/quanta = charge/m2/sec/bin
scdImage = scdImage * q;  

end


function signalCurrentImage = spatialIntegration(scdi,OI,ISA,gridSpacing) 
% Measure current at each sensor photodetector
%
%  signalCurrentImage = spatialIntegration(scdi,OI,ISA,[gridSpacing = 1/5])
%
% The signal current density image (scdi) specifies the current (A/m2)
% across the sensor surface at a set of sample values specified by the
% optical image (OI).  This routine converts the scdi to a set of currents at
% each photodetector. 
%
% The routine can operate in two modes.  In the first (lower resolution,
% fast, default) mode, the routine assumes that each photodetector is
% centered in the pixel.  In the second (high resolution, slow) mode, the
% routine accounts for the position and size of the photodetectors within
% each pixel.
%
% Algorithms:
%    The sensor pixels define a coordinate frame that can be measured (in
%    units of meters).  The optical image also has a size that can be
%    measured in meters.  In both modes, we represent  the OI and the ISA
%    sample positions in meters in a spatial coordinate frame with a common
%    center.  Then we interpolate the values of the OI onto sample points
%    within the ISA grid (regridOI2ISA).  
%
%    The first mode (default).  In this mode the current is computed with
%    one sample per pixel.  Specifically, the irradiance at each wavelength
%    is linearly interpolated to obtain a value at the center of the pixel.
%       
%    The second mode (high-resolution). This high-resolution mode requires
%    a great deal more memory than the first mode. In this method a grid is
%    placed over the sensor and the irradiance field is interpolated to
%    every point in that grid (e.g., a 5x5 grid).  The pixel is computed by
%    summing across those grid points (weighted appropriately).
%
%    The high-reoslution mode used to be the default mode (before 2004).
%    But over time we came to believe that it is better to understand the
%    effects of photodetector placement and pixel optics using the
%    microlenswindow module. For certain applications, though, such as
%    illustrating the effects of wavelength-dependent point spread
%    functions, this mode is valuable.
%
% INPUT:    scdi [nRows x nCols]   [A/m^2]
%           OI:  optical image [structure]
%           ISA:  image sensor array
%           gridSpacing: specifies how finely to interpolate within each
%           pixel, which must be of the form 1/N where N is an odd integer
%
% Copyright ImagEval Consultants, LLC, 2003.

% We can optionally represent the scdi and imager at a finer resolution
% than just pixel positions.  This permits us to account for the size and
% position of the photodetector within the pixel. To do this, however,
% requires that we regrid the signal current density image to a finer
% scale. To do this, the parameter 'spacing' can be set to a value of, say,
% .2 = 1/5.  In that case, the super-sampled new grid is 5x in each
% dimension.  This puts a large demand on memory usage, so we don't
% normally do it.  We use a default of 1 (no gridding).
%
% This is the spacing within a pixel on the sensor array.
if notDefined('gridSpacing'), gridSpacing = 1;
else gridSpacing = 1/round(1/gridSpacing);
end
nGridSamples = 1/gridSpacing;

% regridOI2ISA puts the optical image pixels in the same coordinate frame
% as the sensor pixels.  The sensor pixels coordinate frame is simply the
% pixel position (row,col).   If gridSpacing = 1, then there is a
% one-to-one match between the pixels and the calculated signal current
% density image. If grid spacing is smaller, say 0.2, then there are more
% grid samples per pixel.  This can pay a significant penalty in speed and
% memory usage.
%
%  So the default is gridSpacing of 1.  
%
flatSCDI = regridOI2ISA(scdi,OI,ISA,gridSpacing);

% Calculate the fractional area of the photodetector within each grid
% region of each pixel.  If we are super-sampling, we use sensorPDArray.
% Otherwise, we only need the fill factor.
if nGridSamples == 1, pdArray = sensorGet(ISA,'pixel fillfactor');
else                  pdArray = sensorPDArray(ISA,gridSpacing);
end

% Array pdArray up to match the number of pixels in the array
ISAsize = sensorGet(ISA, 'size');
photoDetectorArray = repmat(pdArray, ISAsize);

% Calculate the signal at each pixel by summing across each pixel within
% the array.
signalCurrentImageLarge = flatSCDI .* photoDetectorArray;
pArea = sensorGet(ISA, 'pixel area');

if nGridSamples == 1, 
    signalCurrentImage = pArea * signalCurrentImageLarge;
else
    % If the grid samples are super-sampled, we must collapse this image,
    % summing across the pixel and create an image that has the same size
    % as the ISA array.  We do this by the blurSample routine.
    %
    % We should probably include a check for the condition when
    % nGridSamples is 2. There can be a problem with the filter in that
    % case. It is OK at nGridSamples=3 and higher.
    % 
    filt = pArea * ones(nGridSamples)/nGridSamples^2;
    signalCurrentImage = blurSample(signalCurrentImageLarge, filt);
end

end

%----------------------------------------------
function sampledData = blurSample(data,filt)
%
%   sampledData = blurSample(data,filt)
%
% Author: ImagEval
% Purpose:
%   Blur the data with filter, and then return the sampled values at the
%   center of the filter position.
%

% Blur the data.
bdata = conv2(data,filt,'same');

fSize = size(filt);

% If the filter is odd, this finds the middle of the sampled data
s = (1 + fSize)/2;

% Sample positions
[r,c] = size(data);
rSamples = s(1):fSize(1):r;
cSamples = s(2):fSize(2):c;

sampledData = bdata(rSamples,cSamples);

end



