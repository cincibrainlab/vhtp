% using the htpAnalysis Class
htpReporter = htpReporterClass();

htpReporter.entryPoint('start');

% start new logging sessions
hr('start');


	htpReporter('start');	% start new logging session.
	htpReporter('stop');	stop logging session.
	htpReporter('reset');	reset logging session.
	htpReporter('add', 'function', [vHTP function name], 'EEG', [EEG SET(s)]);	add log for function and results.


% check for dependencies
[res, path_names] = htpDoctor;

% example of dependency fix:
htpDoctor('fix_braph');

% create analysis class
ha = htpAnalysisClass;

util_htpNewAnalysisTemplate('sat')


ht = util_htpNewAnalysisTemplate;