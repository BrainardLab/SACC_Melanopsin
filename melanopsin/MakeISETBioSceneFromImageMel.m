function [ISETBioGaborObject] = MakeISETBioSceneFromImageMel(colorDirectionParams,gaborImageObject, ...
    ISETBioDisplayObject,stimulusHorizSizeMeters,stimulusHorizSizeDeg,options)
% Make ISETBio scene from the gabor image.
%
% Syntax:
%    [ISETBioGaborCalObject] = MakeISETBioSceneFromImageMel(colorDirectionParams,gaborImageObject,standardGaborCalObject,...
%                              ISETBioDisplayObject,stimulusHorizSizeMeters,stimulusHorizSizeDeg)
%
% Description:
%    This puts the target gabor image into ISETBio scene.
%
% Inputs:
%    colorDirectionParams          - Structure with the parameters to
%                                    calculate a contrast gabor image.
%    gaborImageObject              - Structure with the gabor contrast image in
%                                    image format.
%    ISETBioDisplayObject          - Structure with the parameters to make the
%                                    ISETBio scene from image.
%    stimulusHorizSizeMeters       - The horizontal size of the gabor image
%                                    in meters.
%    stimulusHorizSizeDeg          - The horizontal size of the gabor image
%                                    in degrees.
%
% Outputs:
%    ISETBioGaborObject            - Structure with gabor contrast image in
%                                    the ISETBio scene format.
%
% Optional key/value pairs:
%    verbose                       - Boolean. Default true. Controls
%                                    plotting and printout.
%
% See also:
%    SpectralCalCompute, SpectralCalCheck, SpectralCalAnalyze,
%    SpectralCalISETBio, GetSettingsFromISETBioScene

% History:
%   01/21/22  dhb,gka,smo     - Wrote it.
%   01/24/22  smo             - Made it work.
%   01/31/22  smo             - It is possible to work on multiple
%                               target contrast gabors inside this
%                               function.
%   05/09/22  smo             - Added an option to make a phase shift on
%                               sine image.
%   09/06/23  dhb             - Use T_receptor field to compute responses
%                               if it exists. Defaults back to T_cones if
%                               T_receptor field is not there.  This change
%                               to handle simulations/experiments with
%                               melanopsin.
%   09/07/23  dhb             - Don't pass standard object in - a source of
%                               confusion and bugs.

%% Set parameters.
arguments
    colorDirectionParams
    gaborImageObject
    ISETBioDisplayObject
    stimulusHorizSizeMeters
    stimulusHorizSizeDeg
    options.verbose (1,1) = true
end

%% Put the image into an ISETBio scene.
%
% These calls are a bit slow for large images and the fine wavelength
% sampling used here. But these would be done as pre-compute steps so
% it doesn't seem worth trying to optimize at this point.
nContrastPoints = size(gaborImageObject.settingsGaborImage,2);
nPhaseShifts = size(gaborImageObject.settingsGaborImage,1);

for ss = 1:nPhaseShifts
    for cc = 1:nContrastPoints
        % Make ISETBio scene from the gabor image.
        ISETBioGaborScene = sceneFromFile(gaborImageObject.settingsGaborImage{ss,cc},'rgb', [], ISETBioDisplayObject);
        
        % Show the image on ISETBio scene window.
        if (options.verbose)
            sceneWindow(ISETBioGaborScene);
        end
        
        % Check stimulus dimensions match. These are good to about a percent, which
        % we can live with.
        stimulusHorizSizeMetersChk = sceneGet(ISETBioGaborScene,'width');
        stimulusHorizSizeDegChk = sceneGet(ISETBioGaborScene,'horizontal fov');
        if (abs(stimulusHorizSizeMeters - stimulusHorizSizeMetersChk)/stimulusHorizSizeMeters > 0.01)
            error('Horizontal size in meters mismatch of too much');
        end
        if (abs(stimulusHorizSizeDeg - stimulusHorizSizeDegChk)/stimulusHorizSizeDeg > 0.01)
            error('Horizontal size in deg mismatch of too much');
        end
        
        %% Calculate cone excitations from the ISETBio scene.
        % These should match what we get when we compute
        % outside of ISETBio. And indeed!
        %
        % ISETBio energy comes back as power per nm, we need to convert to power
        % per wlband to work with PTB, by multiplying by S(2).
        ISETBioGaborImageSpd = sceneGet(ISETBioGaborScene,'energy') * colorDirectionParams.S(2);
        [ISETBioGaborImageSpdCal,ISETBioM,ISETBioN] = ImageToCalFormat(ISETBioGaborImageSpd);
        if (isfield(colorDirectionParams,'T_receptors'))
            ISETBioPredictedExcitationsGaborCal = colorDirectionParams.T_receptors * ISETBioGaborImageSpdCal;
        else
            ISETBioPredictedExcitationsGaborCal = colorDirectionParams.T_cones * ISETBioGaborImageSpdCal;
        end
        limMin = 0.01; limMax = 0.02;
        
        % Check if it predicts well.
        temp = ImageToCalFormat(gaborImageObject.excitationsGaborImage{ss,cc});
        if (max(abs(temp(:) - ISETBioPredictedExcitationsGaborCal(:)) ./ temp(:)) > 1e-5)
            error('Passed and ISETBio data do not agree well enough');
        end
        
        % Save the results in a struct.
        ISETBioGaborObject.ISETBioGaborScene{ss,cc} = ISETBioGaborScene;
        ISETBioGaborObject.ISETBioGaborImage{ss,cc} = ISETBioGaborImageSpd;
        ISETBioGaborObject.ISETBioPredictedExcitationsGaborCal{ss,cc} = ISETBioPredictedExcitationsGaborCal;
        ISETBioGaborObject.ISETBioGaborImageSpdCal{ss,cc} = ISETBioGaborImageSpdCal;
        
        % Print out if everything goes well.
        if (options.verbose)
            disp('Gabor image has been successfully calculated from the ISETBio scene!');
        end
    end
end
end
