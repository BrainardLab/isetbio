function [spacing, aperture, density, params, comment] = ...
    coneSizeReadData(varargin)
% Read in data about cone size parameters.
%
% Syntax:
%   [spacing, aperture, density, params, comment] = ...
%       coneSizeReadData([varargin])
%
% Descirption:
%    Calculate expected cone spacing and aperture size at this eccentricity
%    and angle. This is done based on cone density, obtained via parameter
%    coneDensitySource.
%
%    The coordinate system is as defined by coneDensityReadData.
%
%    By default, the aperature is set to 0.7*spacing. We are not sure this
%    is a perfect number.
%
% Inputs:
%    ecc               - Numeric. The eccentricity in meters.
%    ang               - Numeric. The angle in degrees.
%
% Outputs:
%    spacing          - Numeric. The center to center spacing in meters.
%    aperture         - Numeric. The inner segment linear capture size in
%                       meters. Typically, we set the photoPigment
%                       pdHeight and pdWidth both equal to this.
%    density          - Numeric. The cones per mm2. This is the density
%                       returned by coneDensityReadData.
%    params           - Struct. The parameters structure.
%    comment          - String. A short descriptive comment string.
%
% Optional key/value pairs:
%    species           - String. The species? Default 'human'.
%    coneDensitySource - Source for cone density estimate, on which other
%                        values are based. This is passed on to
%                        coneDensityReadData. See help for that function.
%    eccentricity      - Vector/Numeric. The retinal eccentricity, default
%                        0. Units according to eccentricityUnits. May be a
%                        vector, must have same length as angle.
%    angle             - Vector/Numeric. Polar angle of retinal position in
%                        degrees, default 0. Units according to angleUnits.
%                        May be a vector, if so, must be of the same length
%                        as eccentricity.
%    whichEye          - String. The eye, 'left' or 'right', default 'left'
%    eccentriticyUnits - String. The string specifying the units for
%                        eccentricity. Default 'm'. Options are:
%           'm': Meters (default).
%           'mm': Millimeters.
%           'um': Micrometers.
%           'deg': Degrees of visual angle, 0.3 mm/deg.
%    angleUnits        - String. The string specifying units  for angle.
%                        Default 'deg'. Options are:
%           'deg': Degrees (default).
%           'rad': Radians.
%    useParfor         - Boolean. Default false. Used to parallelize the
%                        interp1 function calls which take a long time.
%                        Useful when generating large > 5 deg mosaics.
%
% See Also:
%   coneDensityReadData.
%

% History:
%    XX/XX/16  BW   ISETBIO Team, 2016
%    08/16/17  dhb  Call through new coneDensityReadData rather than the
%                   old coneDensity.
%    02/17/19  npc  Added useParfor k/v pair
%    09/03/19  JNM  Documentation pass

%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;
p.addParameter('species', 'human', @ischar);
p.addParameter('coneDensitySource', 'Curcio1990', ...
    @(x) (ischar(x) | isa(x, 'function_handle')));
p.addParameter('eccentricity', 0, @isnumeric);
p.addParameter('angle', 0, @isnumeric);
p.addParameter('whichEye', 'left', @(x)(ismember(x, {'left', 'right'})));
p.addParameter('eccentricityUnits', 'm', @ischar);
p.addParameter('angleUnits', 'deg', @ischar);
p.addParameter('useParfor', false, @(x)((islogical(x))||(isempty(x))));
p.parse(varargin{:});

%% Set up params return.
params = p.Results;

%% Take care of case where a function handle is specified as source
% This allows for custom data to be defined by a user, via a function that
% could live outside of ISETBio.
%
% This function needs to handle
if (isa(params.coneDensitySource, 'function_handle'))
    [spacing, aperture, density, comment] = ...
        params.coneSizeSource(varargin{:});
    return;
end

%% Get density
% This can just take the params structure, except we change the source name
[density, ~, comment] = coneDensityReadData(varargin{:});
conesPerMM = sqrt(density);
conesPerM = conesPerMM * 1e3;

%% Compute spacing and aperture
spacing = 1 ./ conesPerM;
aperture = 0.7 * spacing;

end
