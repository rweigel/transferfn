clear

addpath(fullfile(fileparts(mfilename('fullpath'))),'..');
tflab_setpaths();

short_run = 1;

if short_run
    start = '20120712';
    stop = '20120716';
else
    start = '20120712';
    stop = '20121107';
end

dirstr  = sprintf('tfs-%s-%s',start,stop);
rundir = fullfile(scriptdir(),'data','Middelpos',dirstr);

for tfn = 1:2
    fname{tfn} = fullfile(rundir, sprintf('Middelpos-tf%d.mat',tfn));
    TFs{tfn} = loadtf(fname{tfn});
    TFs{tfn} = tflab_preprocess(TFs{tfn});
    TFs{tfn} = tflab_metrics(TFs{tfn});
end

%% Set common print options
copts = struct();
    copts.print = 0; % Set to 1 to print pdf of each figure created.
    copts.printOptions.printDir = fullfile(rundir,'figures');
    copts.printOptions.printFormats = {'pdf'};

dock on;figure(1);close all;

%% Time series plots
tsopts = copts;
tsopts.type = 'original';
tsopts.printOptions.printFormats = {'png'};

if (0)
figure();
    tsplot(TFs{1},tsopts);
figure();
    tsopts.type = 'final';
    tsplot(TFs{3},tsopts);
end

tsopts = copts;
tsopts.type = 'error';
figure();
    tsplot(TFs{1},tsopts);
figure();
    tsplot(TFs{2},tsopts);

%% DFT plots
if 0
    figure();
        dftopts = copts;
        dftopts.type = 'original-averaged';
        dftplot(TFs{1},dftopts);

    figure();
        dftopts = copts;
        dftopts.type = 'original-averaged-reals';
        dftplot(TFs{1},dftopts);

    figure();
        dftopts = copts;
        dftopts.type = 'original-averaged-imaginaries';
        dftplot(TFs{1},dftopts);

    % Plot Fourier phases for In/Out of TF1 (will be the same for both)
    figure();
        dftopts = copts;
        dftopts.type = 'original-averaged-phases';
        dftplot(TFs{1},dftopts);

        % Compare TF1 and TF2
        figure();
            dftopts = copts;
            dftopts.type = 'error-averaged-realimag';
            dftplot(TFs{1},dftopts);
end

%% SN plots
figure();
    snopts = copts;
    snplot(TFs(:),snopts);

%% Z plots
figure();
    zopts = copts;
    zopts.type = 1;
    %zopts.period_range = [1, 86400];
    zplot(TFs([1,2]),zopts);

%% Regression plots
% Plot regression errors for a component of S1's Z at a single frequency
% for one of the segments. (For S2, there is only one segment that was
% used to compute Z.)

figure();
    qqopts = copts;
    qqopts.printOptions.printDir = fullfile(rundir,'figures','qqplot');
    fidx = 20; % frequency number
    comp = 2;  % component (x = 1, y = 2)
    qqplot_(TFs{1},qqopts,comp,fidx);

figure();
        qqopts = copts;
        qqopts.printOptions.printDir = fullfile(rundir,'figures','qqplot');
        qqopts.type = 'combined';
        qqplot_(TFs{1},qqopts);
