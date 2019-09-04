function [absorbance, wave, params, comment] = coneAbsorbanceReadData(varargin)
% Return the cone photopigment absorbance (aka optical density)
%
% Syntax:
%   [absorbance, wave, params, comment] = coneAbsorbanceReadData;
%
% Description:
%    Return the cone photopigment absorbance (aka optical density).
%
%    Do not change the defaults for this routine without being aware that
%    they are used by other routines (e.g. photoPigment by default gets its
%    absorbance via this routine.)
%
% Inputs:
%    None required.
%
% Outputs:
%     absorbance          - Numeric. The cone absorbance, in the columns of
%                           a matrix.
%     wave                - Vector. A numeric column vector of sample
%                           wavelengths, in nm.
%     params              - Struct. A structure of key/value pairs used to
%                           generate data.
%     comment             - String. A short comment describing the data.
%
% Optional key/value pairs:
%    species              - String. A string specifying the species.
%                           Default 'human'. Options are:
%           'human': Default. Human L, M and S cones.
%           'macaque': Monkey L, M and S cones. [Note: These are currently
%                      the same as human.]
%    coneAbsorbanceSource - String. The source of the data. Default is
%                           'StockmanSharpe'. Options are:
%           'StockmanSharpe': Default. Values are StockmanSharpe estimates.
%                  Valid when 'species' is 'human' or 'macaque'. Data taken
%                  from Psychtoolbox mat file T_log10coneabsorbance_ss.
%                  These in turn came from CVRL (http://cvrl.org). We raise
%                  10 to the read data so that we return the absorbance
%                  itself, not its log.
%           <Handle>: The value for 'coneAbsorbanceSource' may be passed as
%                  a function handle, in which case the passed function is
%                  called directly with the key/value pairs that were
%                  passed to this routine.
%    wave                 - Vector. A column vector of evenly spaced sample
%                           wavelengths in nm (default, (390:830)').
%
% See Also:
%   rawDataReadData
%

% History:
%    08/10/17  dhb  Drafted.
%    08/17/17  dhb  Don't return log10 anymore, just the absorbance.
%    09/04/19  JNM  Documentation pass

%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;
p.addParameter('species', 'human', @ischar);
p.addParameter('coneAbsorbanceSource', 'StockmanSharpe', @ischar);
p.addParameter('wave', (390:830)', @isnumeric);
p.parse(varargin{:});
params = p.Results;

%% Take care of case where a function handle is specified as source
%
% This allows for custom data to be defined by a user, via a function that
% could live outside of ISETBio.
if (isa(params.coneAbsorbanceSource, 'function_handle'))
    [absorbance, wave, params, comment] = ...
        params.coneAbsorbanceSource(varargin{:});
    return;
end

%% Handle choices
switch (params.species)
    case {'human', 'macaque'}
        switch (params.coneAbsorbanceSource)
            case 'StockmanSharpe'
                % Load the absorbance from the PTB style T_ file, spline to
                % desired wavelength sampling, transpose to match ISETBio
                % convention, and return.
                theData = rawDataReadData('T_log10coneabsorbance_ss', ...
                    'datatype', 'ptbmatfileonpath');
                wavein = SToWls(theData.S_log10coneabsorbance_ss);
                wave = params.wave;
                log10absorbance = SplineCmf(wavein, ...
                    theData.T_log10coneabsorbance_ss, wave)';
                absorbance = 10.^log10absorbance;
                comment = ['Cone absorbance (aka optical density) ', ...
                    'estimated by Stockman/Sharpe, from CVRL via PTB'];
            otherwise
                error('Unsupprted source specified');
        end

    otherwise
        error('Unsupported species specified');
end
        