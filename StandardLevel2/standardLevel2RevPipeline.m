function [EEG, computationTimes] = standardLevel2RevPipeline(EEG, params)

%% Standard level 2 pipeline 
% This assumes the following have been set:
%  EEG                       An EEGLAB structure with the data and chanlocs
%  params                    A structure with at least the following:
%
%     name                   A string with a name identifying dataset
%     referenceChannels      A vector of channels to be used for
%                            rereferencing (Usually these are EEG (no
%                            mastoids or EOG)
%     rereferencedChannels   A vector of channels to be high-passed, 
%                            line-noise removed, and referenced. 
%     lineFrequencies        A list of line frequencies
%  
%
% Returns:
%   EEG                      An EEGLAB structure with the data processed
%                            and status written in EEG.etc.noiseDetection
%   computationTimes         Time in seconds for each stage
%
% Additional setup:
%    EEGLAB should be in the path.
%    The EEG-Clean-Tools/StandardLevel2 directory and its subdirectories 
%    should be in the path.
%

%% Setup the output structures and set the input parameters
computationTimes= struct('resampling', 0, 'globalTrend', 0,  ...
    'lineNoise', 0, 'reference', 0);
errorMessages = struct('status', 'good', 'boundary', 0, 'resampling', 0, ...
    'globalTrend', 0, 'trend', 0, 'lineNoise', 0, 'reference', 0);
pop_editoptions('option_single', false, 'option_savetwofiles', false);
if isfield(EEG.etc, 'noiseDetection')
    warning('EEG.etc.noiseDetection already exists and will be cleared\n')
end
if ~exist('params', 'var')
    params = struct();
end
if ~isfield(params, 'name')
    params.name = ['EEG' EEG.filename];
end
EEG.etc.noiseDetection = ...
       struct('name', params.name, 'version', getStandardLevel2Version, ...
              'errors', []);
%% Check for boundary events
try
    defaults = getPipelineDefaults(EEG, 'boundary');
    [boundaryOut, errors] = checkDefaults(params, struct(), defaults);
    if ~isempty(errors)
        error('boundary:BadParameters', ['|' sprintf('%s|', errors{:})]);
    end
    EEG.etc.noiseDetection.boundary = boundaryOut;
    if ~boundaryOut.ignoreBoundaryEvents && ...
            isfield(EEG, 'event') && ~isempty(EEG.event)
        eTypes = find(strcmpi({EEG.event.type}, 'boundary'));
        if ~isempty(eTypes)
            error(['Dataset ' params.name  ...
                ' has boundary events: [' getListString(eTypes) ...
                '] which are treated as discontinuities unless set to ignore']);
        end
    end
catch mex
    errorMessages.boundary = ...
        ['standardLevel2RevPipeline bad boundary events: ' getReport(mex)];
    errorMessages.status = 'unprocessed';
    EEG.etc.noiseDetection.errors = errorMessages;
    return;
end

%% Part I: Resampling
fprintf('Resampling\n');
try
    tic
    [EEG, resampling] = resampleEEG(EEG, params);
    EEG.etc.noiseDetection.resampling = resampling;
    computationTimes.resampling = toc;
catch mex
    errorMessages.resampling = ...
        ['standardLevel2RevPipeline failed resampleEEG: ' getReport(mex)];
    errorMessages.status = 'unprocessed';
    EEG.etc.noiseDetection.errors = errorMessages;
    return;
end

%% Part II: Global detrend
fprintf('Global trend removal\n');
try
    tic
    [EEG, globalTrend] = removeGlobalTrend(EEG, params);
    EEG.etc.noiseDetection.globalTrend = globalTrend;
    computationTimes.globalTrend = toc;
catch mex
    errorMessages.globalTrend = ...
        ['standardLevel2RevPipeline failed removeGlobalTrend: ' getReport(mex)];
    errorMessages.status = 'unprocessed';
    EEG.etc.noiseDetection.errors = errorMessages;
    return;
end 
 
%% Part II: Remove line noise
fprintf('Line noise removal\n');
try
    tic
    [EEG, lineNoise] = cleanLineNoise(EEG, params);
    EEG.etc.noiseDetection.lineNoise = lineNoise;
    computationTimes.lineNoise = toc;
catch mex
    errorMessages.lineNoise = ...
        ['standardLevel2RevPipeline failed cleanLineNoise: ' getReport(mex)];
    errorMessages.status = 'unprocessed';
    EEG.etc.noiseDetection.errors = errorMessages;
    return;
end 

%% Part III:  HP the signal for detecting bad channels
fprintf('Preliminary detrend to compute reference\n');
try
    tic
    [EEGNew, trend] = removeTrend(EEG, params);
    EEG.etc.noiseDetection.trend = trend;
    computationTimes.detrend = toc;
catch mex
    errorMessages.removeTrend = ...
        ['standardLevel2RevPipeline failed removeTrend: ' getReport(mex)];
    errorMessages.status = 'unprocessed';
    EEG.etc.noiseDetection.errors = errorMessages;
    return;
end

%% Part IV: Find reference
fprintf('Find reference\n');
try
    tic
    referenceOut = findReference(EEGNew, params);
    clear EEGNew;
    referenceSignalOriginal = ...
        mean(EEG.data(referenceOut.evaluationChannels, :), 1);
    noisyChannels = referenceOut.interpolatedChannels;
    sourceChannels = setdiff(referenceOut.evaluationChannels, noisyChannels);
    if ~isempty(noisyChannels)
        EEG = interpolateChannels(EEG, noisyChannels, sourceChannels);
        referenceSignal = ...
            mean(EEG.data(referenceOut.evaluationChannels, :), 1);     
    else
        referenceSignal = referenceSignalOriginal;
    end
    EEG = removeReference(EEG, referenceSignal, ...
        referenceOut.rereferencedChannels);
    referenceOut.referenceSignalOriginal = referenceSignalOriginal;
    referenceOut.referenceSignal = referenceSignal;
    [EEGNew, trend] = removeTrend(EEG, params);
    referenceOut.noisyStatistics = findNoisyChannels(EEGNew, referenceOut);
    clear EEGNew;
    EEG.etc.noiseDetection.reference = referenceOut;
    computationTimes.reference = toc;
catch mex
    errorMessages.reference = ...
        ['standardLevel2RevPipeline failed findReference: ' ...
        getReport(mex, 'basic', 'hyperlinks', 'off')];
    errorMessages.status = 'unprocessed';
    EEG.etc.noiseDetection.errors = errorMessages;
    return;
end

%% Report that there were no errors
EEG.etc.noiseDetection.errors = errorMessages;

