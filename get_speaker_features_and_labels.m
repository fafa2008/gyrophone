function [feature_matrix, labels] = ...
    get_features_and_labels(db, speakers)
    
    % feature_matrix - Feature matrix for input to Diffusion Maps
    % labels - Label for each column of feature_matrix
    % mu_train - GMM mean values matrices for each speaker
    % sigma_train - GMM variance matrices for each speaker
    % c_train - GMM weight vectors for each speaker
    
    feature_matrix = [];
    labels = [];
       
    total_entries = 0; % counter of handled entries
    
    NUM_OF_SPEAKERS = length(speakers);
    for k = 1:NUM_OF_SPEAKERS
        speaker_db = filterdb(db, 'speaker', speakers{k});
        
        % extract features for all speaker samples
        func = @calc_mfcc;
        [speaker_features, num_of_success] = extract_features(speaker_db, func);
        
        labels = [labels; ones(num_of_success, 1) * k];
        feature_matrix = [feature_matrix speaker_features];
        
        total_entries = total_entries + num_of_success;
    end
    
    fprintf('Handled %d entries\n', total_entries);
end

function [feature_matrix, num_of_success] = extract_features(db, func)
	% db - a database to extract the features from
	% func - a function that extracts the features for a single database entry

	feature_matrix = [];
	num_of_success = 0;

	NUM_OF_ENTRIES = length(db);
	GYRO_DIM = 1;
    FS = 8000;

	for k = 1:NUM_OF_ENTRIES
		try
			[wavdata, samp_rate] = read(db, k);
			wavdata = wavdata{1};
            wavdata = resample(wavdata(:, GYRO_DIM), FS, samp_rate);
			new_features = func(wavdata, FS);
			feature_matrix(:, end+1) = new_features;
			num_of_success = num_of_success + 1;
		catch ME
			% print error source
			ME.stack(1)
		end
	end
end

function mfcc_features = calc_mfcc(wavdata, samp_rate)
	% MFCC extraction from samples
	FRAME_LEN = 512; % 20 ms for sampling rate of 200 Hz

	audio = miraudio(wavdata, samp_rate);
	frames = mirframe(audio, 'Length', FRAME_LEN, 'sp');
	frame_mfcc = mirmfcc(frames);
	mfcc_data = mirgetdata(frame_mfcc);
	mfcc_features = values_to_features(mfcc_data);
end

function features = values_to_features(values)
	% Convert a time-series obtained from a sample to a feature using
	% different kind of statistics over the values and the derivatives

	mean_val = nanmean(values, 2);
	variance = nanvar(values, 0, 2);
	% feature_skewness = skewness(values(~isnan(values)));
	% feature_kurtosis = kurtosis(values(~isnan(values)));

	abs_delta = abs(values(:, 2:end) - values(:, 1:end-1));
	mean_delta = nanmean(abs_delta, 2);
	var_delta = nanvar(abs_delta, 0, 2);

	maximum = max(values, [], 2);
	minimum = min(values, [], 2);

	features = [mean_val; variance; ... 
	%           feature_skewness; feature_kurtosis; ...
                mean_delta; var_delta; maximum; minimum];
end