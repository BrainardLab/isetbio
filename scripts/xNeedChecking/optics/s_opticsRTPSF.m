% s_opticsRTPSF
%
%   This script illustrates the ray trace calculation with a point array.
% 
% A scene with a set of points is transformed to an optical image using ray
% trace methods based on the aspherical, 2mm lens computed in Zemax.
%
% The scene is also transformed using diffraction limited methods
% (shift-invariant).  The f# and focal length of the diffraction model are
% set equal to those of the ray trace lens.
%
% The illuminance computed the two ways is then compared.
%
% Copyright ImagEval Consultants, LLC, 2008

%%
s_initISET
wbStatus = ieSessionGet('waitbar');
ieSessionSet('waitbar','on');

%% Scene
scene = sceneCreate('pointArray',512,32);
scene = sceneInterpolateW(scene,450:100:650);
scene = sceneSet(scene,'hfov',15);
scene = sceneSet(scene,'name','psf Point Array');

vcAddAndSelectObject('scene',scene); sceneWindow;

%% Optics
oi = oiCreate('ray trace');

% Load the example Zemax file
fname = fullfile(isetbioDataPath,'optics','rtZemaxExample.mat');
load(fname,'optics'); 

oi = oiSet(oi,'name','ray trace case');
oi = oiSet(oi,'optics',optics);

%% Compute
oi = oiSet(oi,'optics model','ray trace');
oi = oiCompute(scene,oi);
oi = oiSet(oi,'name','ray trace case');
vcAddAndSelectObject('oi',oi); oiWindow;

%% Compute the diffraction limited case
oiDL = oiSet(oi,'name','diffraction case');
optics = oiGet(oiDL,'optics');
fNumber = opticsGet(optics,'rt fnumber');
optics = opticsSet(optics,'fnumber',fNumber*0.8);
oiDL = oiSet(oiDL,'optics',optics);

oiDL = oiSet(oiDL,'optics model','diffraction limited');
oiDL = oiCompute(scene,oiDL);
oiDL = oiSet(oiDL,'name','psf diffraction case');
vcAddAndSelectObject('oi',oiDL); oiWindow;

%%
ieSessionSet('waitbar',wbStatus);
imageMultiview('oi',[1 2],1);
 
 %% End

