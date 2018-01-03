% Method to set ISETBIO-specific UnitTestToolbx preferences.
%
% This default version assumes that you have isetbio on your path
% already.  In that case there is some chance this script will just
% run for you.
%
% This function should be edited for your account and run once.
%
% ISETBIO Team, 2015

function ieValidatePreferences

p = struct(...
    'projectName',           'isetbio', ...                                                                                   % The project's name (also the preferences group name)
    'validationRootDir',     fullfile(isetbioRootPath, 'validation'), ...                                                     % Directory location where the 'scripts' subdirectory resides.
    'alternateFastDataDir',  '',  ...                                                                                         % Alternate FAST (hash) data directory location. Specify '' to use the default location, i.e., $validationRootDir/data/fast
    'alternateFullDataDir',  '', ...                                                                                          % Alternate FULL data directory location. Specify '' to use the default location, i.e., $validationRootDir/data/full
    'useRemoteDataToolbox',  true, ...                                                                                        % If true use Remote Data Toolbox to fetch full validation data on demand.
    'remoteDataToolboxConfig', 'isetbio', ...                                                                                 % Struct, file path, or project name with Remote Data Toolbox configuration.
    'githubRepoURL',         'http://isetbio.github.io/isetbio', ...                                                          % Github URL for the project. This is only used for publishing tutorials.
    'generateGroundTruthDataIfNotFound',   false, ...                                                                         % Flag indicating whether to generate ground truth if one is not found
    'listingScript',         'ieValidateListAllValidationDirs', ...
    'coreListingScript',     'ieValidateListCoreValidationFiles', ...
    'numericTolerance',      1e-11 ...                                                                                        % Numeric tolerance for comparisons with validation data.
    );

% These options are added to the struct for some of the more advanced
% users (i.e., Nicolas Cottaris).
%
% 'clonedWikiLocation',    fullfile(filesep,'Users',  'Shared', 'Matlab', 'Toolboxes', 'ISETBIO_Wiki', 'isetbio.wiki'), ... % Local path to the directory where the wiki is cloned. Only relevant for publishing tutorials.
% 'clonedGhPagesLocation', fullfile(filesep,'Users',  'Shared', 'Matlab', 'Toolboxes', 'ISETBIO_GhPages', 'isetbio'), ...   % Local path to the directory where the gh-pages repository is cloned. Only relevant for publishing tutorials.

% This adds the preference to the Matlab prefs
generatePreferenceGroup(p);

% This makes the settings known to UnitTestToolbox
UnitTest.usePreferencesForProject(p.projectName);

end

% Simple helper for setting prefs
function generatePreferenceGroup(p)
% remove any existing preferences for this project
if ispref(p.projectName)
    rmpref(p.projectName);
end

% generate and save the project-specific preferences
setpref(p.projectName, 'projectSpecificPreferences', p);
fprintf('Generated and saved preferences specific to the ''%s'' project.\n', p.projectName);
end
