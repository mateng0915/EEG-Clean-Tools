function [summary, noisyStatistics] = reportReferencedNew(fid, signal, noiseDetection, numbersPerRow, indent)
%% Extracts and outputs parameters for referencing calculation
% Outputs a summary to file fid and returns a cell array of important messages
    summary = {};
    if ~isempty(noiseDetection.errors.reference)
        summary{end+1} =  noiseDetection.errors.reference;
        fprintf(fid, '%s\n', summary{end});
    end
    if ~isfield(noiseDetection, 'reference')
        summary{end+1} = 'Signal wasn''t referenced';
        fprintf(fid, '%s\n', summary{end});
        return;
    end
    reference = noiseDetection.reference;
    noisyStatistics = reference.noisyStatistics;
    fprintf(fid, 'Rereferencing version %s\n',  ...
        noiseDetection.version.Reference);
    fprintf(fid, 'Reference type %s\n',  reference.referenceType);
    fprintf(fid, '\nReference channels (%d channels):\n', ...
        length(reference.referenceChannels));
    printList(fid, reference.referenceChannels, ...
        numbersPerRow, indent);
    fprintf(fid, '\nEvaluation channels (%d channels):\n', ...
        length(reference.evaluationChannels));
    printList(fid, reference.evaluationChannels, ...
        numbersPerRow, indent);
    fprintf(fid, '\nRereferencedChannels (%d channels):\n', ...
        length(reference.rereferencedChannels));
    printList(fid, reference.rereferencedChannels,  ...
        numbersPerRow, indent);
    
    fprintf(fid, 'Noisy channel detection parameters:\n');
    fprintf(fid, '%sRobust deviation threshold (z score): %g\n', ...
        indent, noisyStatistics.robustDeviationThreshold);
    fprintf(fid, '%sHigh frequency noise threshold (ratio): %g\n', ...
        indent, noisyStatistics.highFrequencyNoiseThreshold);
    fprintf(fid, '%sCorrelation window size (in seconds): %g\n', ...
        indent, noisyStatistics.correlationWindowSeconds);
    fprintf(fid, '%sCorrelation threshold (with any channel): %g\n', ...
        indent, noisyStatistics.correlationThreshold);
    fprintf(fid, '%sBad correlation threshold: %g\n', ...
        indent, noisyStatistics.badTimeThreshold);
    fprintf(fid, '%s%s(fraction of time with low correlation or dropout)\n', ...
        indent, indent);
    fprintf(fid, '%sRansac sample size : %g\n', ...
        indent, noisyStatistics.ransacSampleSize);
    fprintf(fid, '%s%s(number channels to use for interpolated estimate)\n', ...
        indent, indent);
    fprintf(fid, '%sRansac channel fraction (for ransac sample size): %g\n', ...
        indent, noisyStatistics.ransacChannelFraction);
    fprintf(fid, '%sRansacCorrelationThreshold: %g\n', ...
        indent, noisyStatistics.ransacCorrelationThreshold);
    fprintf(fid, '%sRansacUnbrokenTime (input parameter): %g\n', ...
        indent, noisyStatistics.ransacUnbrokenTime);
    fprintf(fid, '%sRansacWindowSeconds (in seconds): %g\n', ...
        indent, noisyStatistics.ransacWindowSeconds);
    fprintf(fid, '%sRansacPerformed: %g\n', indent, ...
        noisyStatistics.ransacPerformed);
    fprintf(fid, '%sMaximum reference iterations: %g\n', indent, ...
        getFieldIfExists(reference, 'maxReferenceIterations'));
    fprintf(fid, '%sActual reference iterations: %g\n', indent, ...
          getFieldIfExists(reference, 'actualReferenceIterations'));
    
    %% Listing of noisy channels
    channelLabels = {reference.channelLocations.labels};
    originalBad = reference.interpolatedChannels;
    badList = getLabeledList(originalBad,  ...
        channelLabels(originalBad), numbersPerRow, indent);
    fprintf(fid, '\n\nNoisy channels before referencing:\n %s', badList);
    summary{end+1} = ['Bad channels before referencing: ' badList];
    
    finalBad = noisyStatistics.noisyChannels;
    badList = getLabeledList(finalBad, channelLabels(finalBad), ...
        numbersPerRow, indent);
    fprintf(fid, '\nNoisy channels after referencing:\n %s', badList);
    summary{end+1} = ['Bad channels after referencing: ' badList];
 
    %% NaN criteria
    if isfield(noisyStatistics, 'badChannelsFromNaNs')   % temporary
        badList = getLabeledList(noisyStatistics.badChannelsFromNaNs, ...
            channelLabels(noisyStatistics.badChannelsFromNaNs), ...
            numbersPerRow, indent);
        fprintf(fid, '\n\nBad because of NaN (referenced):\n%s', badList);
    end
    %% All constant criteria
    if isfield(noisyStatistics, 'badChannelsFromNoData')   % temporary      
        badList = getLabeledList(noisyStatistics.badChannelsFromNoData, ...
            channelLabels(noisyStatistics.badChannelsFromNoData), ...
            numbersPerRow, indent);
        fprintf(fid, '\n\nBad because data is constant (referenced):\n%s',...
            badList);
    end
    %% Dropout criteria
    if isfield(noisyStatistics, 'badChannelsFromDropOuts')   % temporary    
        badList = getLabeledList(noisyStatistics.badChannelsFromDropOuts, ...
            channelLabels(noisyStatistics.badChannelsFromDropOuts), ...
            numbersPerRow, indent);
        fprintf(fid, ...
            '\n\nBad because of drop outs (referenced):\n%s', badList);       
    end
    %% Maximum correlation criterion
    badList = getLabeledList(noisyStatistics.badChannelsFromCorrelation, ...
        channelLabels(noisyStatistics.badChannelsFromCorrelation), ...
        numbersPerRow, indent);
    fprintf(fid, ...
        '\n\nBad because of poor max correlation (referenced):\n%s', badList);

    %% Large deviation criterion
    badList = getLabeledList(noisyStatistics.badChannelsFromDeviation, ...
        channelLabels(noisyStatistics.badChannelsFromDeviation), ...
        numbersPerRow, indent);
    fprintf(fid, ...
        '\n\nBad because of large deviation (referenced):\n%s', badList);
    %% HF SNR ratio criterion
    badList = getLabeledList(noisyStatistics.badChannelsFromHFNoise, ...
        channelLabels(noisyStatistics.badChannelsFromHFNoise), ...
        numbersPerRow, indent);
    fprintf(fid, ...
        '\n\nBad because of HF noise (low SNR)(referenced):\n%s', badList);
      
    %% Ransac criteria
    badList = getLabeledList(noisyStatistics.badChannelsFromRansac, ...
        channelLabels(noisyStatistics.badChannelsFromRansac), ...
        numbersPerRow, indent);
    fprintf(fid, '\n\nBad because of poor Ransac predictability (referenced):\n%s', badList);
  

    %% Iteration report
        report = sprintf('\n\nActual interpolation iterations: %d\n', ...
            reference.actualReferenceIterations);
        fprintf(fid, '%s', report);
        summary{end+1} = report;
    
end