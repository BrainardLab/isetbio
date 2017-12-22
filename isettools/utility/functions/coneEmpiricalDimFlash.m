function response = coneEmpiricalDimFlash(coef, t)
% Damped oscillator with S-shaped onset describing dim flash responses
%
% Syntax:
%   response = coneEmpiricalDimFlash(coeffs, time)
%
% Description:
%    Following Schnapf, Baylor, 1990: Damped oscillator with S-shaped onset
%
%    Using the coefficients and time provided by the user, calculate the
%    empirical linear flash response (for dim flashes), following the
%    formula in the referenced paper.
%
%    The calculation is as follows:
%       fit = scFact * (((t / TR) ^ 3) / (1 + ((t / TR) ^ 3))) ...
%             * exp(-((t / TD))) ...
%             * cos(((2 * pi * t) / TP) + (2 * pi * Phi / 360));
%
% Inputs:
%    coef     - The coefficients for the calculations. They will follow the
%               following order in the provided vector:
%                   1 - scFact - Scaling Factor
%                   2 - TauR   - Rising Phase Time Constant
%                   3 - TauD   - Damping Time Constant
%                   4 - TauP   - Oscillator Period
%                   5 - Phi    - Oscillator Phase
%    t        - Time (in milliseconds)
%
% Outputs:
%    response - The calculated linear flash response fit
%
% References:
%    * VISUAL TRANSDUCTION IN CONES OF THE MONKEY MACACA FASCICULARIS P.693
%      https://goo.gl/EfqVwK (shortened link)

% History:
%    04/xx/11  Angueyra  Created 
%    04/xx/11  Rieke     Replaced gaussian by exponential decay
%    01/08/16  dhb       Rename, clean
%    12/04/17  jnm       Formatting

%% Give names to the coefficient vector entries
ScFact = coef(1);  % Scaling Factor
TauR = coef(2);    % Rising Phase Time Constant
TauD = coef(3);    % Dampening Time Constant
TauP = coef(4);    % Oscillator Period
Phi = coef(5);     % Oscillator Phase

%% Compute the response
response = ScFact .* (((t ./ TauR) .^ 3) ./ (1 + ((t ./ TauR) .^ 3))) ...
    .* exp(-((t ./ TauD))) ...
    .* cos(((2 .* pi .* t) ./ TauP) + (2 * pi * Phi / 360));

%% Some earlier versions now not used
% response = ScFact .* (((t ./ TauR) .^ 3) ./ (1 + ((t ./ TauR) .^ 3))) ...
%       .* exp(-((t ./ TauD) .^ 2)) ...
%       .* cos(((2 .* pi .* t) ./ TauP) + (2 * pi * Phi / 360));
% response = ScFact .* (((t ./ TauR) .^ 4) ./ (1 + ((t ./ TauR) .^ 4))) ...
%       .* exp(-((t ./ TauD))) ...
%       .* cos(((2 .* pi .* t) ./ TauP) + (2 * pi * Phi / 360));
