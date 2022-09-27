function [estDomainValidation] = GetContrastRangeTrials(...
    sceneParamsStruct, experimentParams, autoResponseParams, window, windowRect, options)
% Get contrast range based on the measured threshold using Method of
% adjustment.
%
% Syntax:
%    [estDomainValidation] = GetContrastRangeTrials(...
%     sceneParamsStruct, experimentParams, autoResponseParams, window, windowRect)
%
% Description:
%    This measures initial contrast sensitivity (threshold) using Method of
%    adjustments. In SACC project, we want to tailor test contrast range
%    per each subject. To do so, this sets the test contrast range based on
%    initial measure of contrast sensitivity. 
% 
%    Here we measure two contrast threshold points, one being from the
%    highest to non-visible, and the other being the lowest to visible. The
%    test contrast range is decided based on the results.
%
% Inputs:
%    sceneParamsStruct
%    experimentParams
%    autoResponseParams
%    window
%    windowRect
%
% Output:
%    estDomainValidation     -
%
% Optional key/value pairs:
%    options.nContrastPoints
%    options.higherLimThresholdEstLog
%    options.lowerLimThresholdEstLog

% History:
%    09/26/22  smo                     - Wrote it.

%% Set parameters.
arguments
    sceneParamsStruct
    experimentParams
    autoResponseParams
    window (1,1)
    windowRect (1,4)
    options.nContrastPoints (1,1) = 6
    options.higherLimThresholdEstLog (1,1) = 0.3
    options.lowerLimThresholdEstLog (1,1) = 0.5
end

%% Load null and test images.
% 
% We will use only images without phase shifts here.
whichPhaseImage = 1;
nullImage = sceneParamsStruct.predefinedRGBImages{whichPhaseImage,1};
testImages = sceneParamsStruct.predefinedRGBImages(whichPhaseImage,2:end);

predefinedContrasts = sceneParamsStruct.predefinedContrasts(2:end);
predefinedContrastsLog = log10(predefinedContrasts);

%% Set the initial screen for instruction.
imageSize = size(nullImage,2);
messageInitialImage_1stLine = 'Press any button to start';
messageInitialImage_2ndLine = 'Pre-experiment session';
initialInstructionImage = insertText(nullImage,[30 imageSize/2-40; 30 imageSize/2+40],{messageInitialImage_1stLine messageInitialImage_2ndLine},...
    'fontsize',70,'Font','FreeSansBold','BoxColor',[1 1 1],'BoxOpacity',0,'TextColor','black','AnchorPoint','LeftCenter');
initialInstructionImage = fliplr(initialInstructionImage);

%% Set the contrast image for sensitivity measure.

% Make a loop to proceed this procedure, one from the highest contrast
% and the other from the lowest contrast.
%
% Start from the image with the highest contrast. Note that the first
% image is null image with out contrast pattern, so we start from
% either lowest or highest contrast.
initialContrast = [length(testImages) 1];
nInitialContrasts = length(initialContrast);

% Start the loop for two sessions starting either from lowest or highest
% contrast.
for cc = 1:nInitialContrasts
    
    %% Display the initial screen.
    SetScreenImage(initialInstructionImage, window, windowRect,'verbose',true);
    
    % Get any button press to proceed.
    GetGamepadResp;
    disp('Practice trial is going to be started!');
 
    %% Set the initial contrast level here.
    %
    % Contrast level starts either highest one or lowest one. Starts
    % from the lower one.
    imageContrastLevel = initialContrast(cc);
    fprintf('Starting initial contrast sensitivity measure (%d/%d) \n',cc,nInitialContrasts);
    setDirectionToDisplay = [];
    
    while 1
        % Set the contrast level.
        testContrast = predefinedContrasts(imageContrastLevel);
        fprintf('Current test contrast is = (%.4f) \n',testContrast);
        
        % Display contrast image here.
        [correct, flipTime, rngValues, whichDirectionToDisplay] = computePerformanceSACCDisplay(nullImage, testImages{imageContrastLevel}, ...
            sceneParamsStruct.predefinedTemporalSupport,sceneParamsStruct.predefinedTemporalSupportCrossbar,testContrast,window,windowRect,...
            'runningMode',experimentParams.runningMode,'autoResponse',autoResponseParams,...
            'expKeyType',experimentParams.expKeyType,'beepSound',false,...
            'debugMode',experimentParams.debugMode,'movieStimuli',experimentParams.movieStimuli,...
            'movieImageDelaySec',experimentParams.movieImageDelaySec,...
            'preStimuliDelaySec',experimentParams.preStimuliDelaySec, 'addNoiseToImage', sceneParamsStruct.addNoiseToImage, ...
            'addFixationPointImage', sceneParamsStruct.addFixationPointImage,...
            'rotateImageDeg',sceneParamsStruct.rotateImageDeg, 'setDirectionToDisplay', setDirectionToDisplay, 'verbose',false);
        
        % Set this to empty so that it displays the image pattern randomly.
        setDirectionToDisplay = [];
        
        % Get a button press here.
        buttonPress = GetGamepadResp;
        
        % Update the state according to button press.
        if strcmp(buttonPress,'down')
            fprintf('Finishing up the session... \n');
            break;
            
        elseif strcmp(buttonPress,'right')
            % Change the contrast level for next display.
            if (cc == 2)
                imageContrastLevel = imageContrastLevel + 1;
            elseif (cc == 1)
                imageContrastLevel = imageContrastLevel - 1;
            end
            
            % Play the sound.
            MakeBeepSound('preset',correct);
            
        elseif strcmp(buttonPress,'left')
            % Show the same contrast level again for next display.
            imageContrastLevel = imageContrastLevel;
            
            % Same direciton of the image will be displayed when repeat. 
            setDirectionToDisplay = whichDirectionToDisplay;
            
            % Play the feedback sound.
            numPlaySound = 2;
            for pp = 1:numPlaySound
                MakeBeepSound('preset',correct);
            end
        end
    end
    
    % Play sound as feedback when the contrast level was decided.
    numPlaySound = 3;
    for pp = 1:numPlaySound
        MakeBeepSound('preset',correct);
    end
    
    % Print out the contrast level we found.
    contrastFoundLinear(cc) = predefinedContrasts(imageContrastLevel);
    fprintf('Contrast was found at (%.3f) \n', contrastFoundLinear(cc));
    fprintf('Initial contast sensitivity measure is in progress -(%d/%d) \n', cc, nInitialContrasts); 
end

%% Set the contrast range based on the results for constant stimuli method.
%
% Make an average of two contrast points as initial guess of threshold.
thresholdEstLinear = mean(contrastFoundLinear);
thresholdEstLog = log10(thresholdEstLinear);

% We set the contrast range based on the above threshold estimation.
higherLimTestContrastLog = thresholdEstLog + options.higherLimThresholdEstLog;
lowerLimTestContrastLog  = thresholdEstLog - options.lowerLimThresholdEstLog;

% Make contrast range equally spaced on log space.
estDomainValidationLinear = logspace(lowerLimTestContrastLog, higherLimTestContrastLog, options.nContrastPoints);
estDomainValidationLogNominal = log10(estDomainValidationLinear);

% Find the neareast point for each target contrast point.
for tt = 1:length(estDomainValidationLogNominal)
    [val idx] = min(abs(estDomainValidationLogNominal(tt)-predefinedContrastsLog));
    estDomainValidation(tt) = predefinedContrastsLog(idx);
end
end