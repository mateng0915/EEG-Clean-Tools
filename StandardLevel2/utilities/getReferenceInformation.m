function referenceOut = findReferenceInformation(signal, referenceIn)
% Find specified reference and return the bad channels for that reference

%% Check the input parameters
if nargin < 1
    error('findReferenceInformation:NotEnoughArguments', 'requires at least 1 argument');
elseif isstruct(signal) && ~isfield(signal, 'data')
    error('findReferenceInformation:NoDataField', 'requires a structure data field');
elseif size(signal.data, 3) ~= 1
    error('findReferenceInformation:DataNotContinuous', 'signal data must be a 2D array');
elseif size(signal.data, 2) < 2
    error('findReferenceInformation:NoData', 'signal data must have multiple points');
elseif ~exist('referenceIn', 'var') || isempty(referenceIn)
    referenceIn = struct();
end
if ~isstruct(referenceIn)
    error('findReferenceInformation:NoData', 'second argument must be a structure')
end

%% Set the defaults and initialize as needed
referenceOut = getReferenceStructure();
defaults = getPipelineDefaults(signal, 'reference');
[referenceOut, errors] = checkDefaults(referenceIn, referenceOut, defaults);
if ~isempty(errors)
    error('findReferenceInformation:BadParameters', ['|' sprintf('%s|', errors{:})]);
end
referenceOut.rereferencedChannels = sort(referenceOut.rereferencedChannels);
referenceOut.referenceChannels = sort(referenceOut.referenceChannels);
referenceOut.evaluationChannels = sort(referenceOut.evaluationChannels);
[referenceOut.badChannelsFromNaNs, ...
    referenceOut.badChannelsFromNoData] = ...
    findUnusableChannels(signal, referenceOut.evaluationChannels);
if strcmpi(referenceOut.referenceType, 'robust') 
    referenceOut.evaluationChannels = referenceOut.referenceChannels;
    [signal, referenceOut] = robustReference(signal, referenceOut); 
elseif strcmpi(referenceOut.referenceType, 'average') 
    referenceOut.evaluationChannels = referenceOut.referenceChannels;
    referenceOut = specificReference(signal, referenceOut); 
elseif strcmpi(referenceOut.referenceType, 'specific')
   if length(union(referenceOut.referenceChannels, ...
                    referenceOut.evaluationChannels)) ...
            == length(referenceOut.referenceChannels)
     warning('performReference:DifferentReference', ...
         ['The evaluation channels for interpolation should be different ' ...
         'from the reference channels for specific reference']);
   end
   referenceOut = specificReference(signal, referenceOut);
else
    error('performReference:UnsupportedReferenceStrategy', ...
        [referenceOut.referenceType ' is not supported']);
end

