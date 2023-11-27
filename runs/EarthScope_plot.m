clear;
addpath(fullfile(fileparts(mfilename('fullpath'))),'..');
tflab_setpaths();

id = 'VAQ58';

start = '20160610';
stop = '20160616';
time_range_full = {'2016-06-11T00:00:00.000','2016-06-16T12:00:00.000'};
time_range_zoom = {'2016-06-14T18:00:00.000','2016-06-15T06:00:00.000'};

%start = '20160610';
%stop = '20160618';

if 0
start = '20160610';
stop = '20160623';
time_range_full = {'2016-06-11T00:00:00.000','2016-06-16T12:00:00.000'};
time_range_zoom = {'2016-06-14T18:00:00.000','2016-06-23T12:00:00.000'};
end
%start = '20160617';
%stop = '20160620';

outdir = fullfile(scriptdir(),'data','EarthScope',id);

for tfn = 1:3
    f{tfn} = fullfile(outdir, sprintf('VAQ58-%s-%s-tf%d.mat',start,stop,tfn));
end
TF1 = loadtf(f{1});
TF1 = tflab_preprocess(TF1);
TF1 = tflab_metrics(TF1);

TF2 = loadtf(f{2});
TF2 = tflab_preprocess(TF2);
TF2 = tflab_metrics(TF2);

TF3 = loadtf(f{3});
TF3 = tflab_preprocess(TF3);
TF3 = tflab_metrics(TF3);

%% Set common print options
copts.print    = 0; % Set to 1 to print pdf of each figure created.
copts.printdir = fullfile(outdir,'figures');
copts.printfmt = {'pdf','png'};

dock on;figure(1);close all;

%% Time series plots

% Plot original time series data used for TF1 (will be same as that for TF2)
figure();
    tsopts = copts;
    tsopts.type = 'original';
    zoptsoptsts.printname = 'ts-tf1-tf3';
    tsplot(TF1,tsopts);


if 0    
% Plot error for TF1 only
figure();
    tsopts = copts;
    tsopts.type = 'error';
    tsplot(TF1,tsopts);

% Plot error for TF2 only
figure();
    tsopts = copts;
    tsopts.type = 'error';
    tsplot(TF2,tsopts);

% Plot error for TF3 only
figure();
    tsopts = copts;
    tsopts.type = 'error';
    tsplot(TF3,tsopts);
end

%%
% Compare all errors
figure();
    tsopts = copts;
    tsopts.time_range = time_range_full;
    tsopts.type  = 'error';
    tsopts.printname = 'ts-error-tf1-tf3';
    tsplot({TF1,TF3},tsopts);

figure();
    tsopts = copts;
    tsopts.time_range = time_range_zoom;
    tsopts.type  = 'error';
    tsopts.printname = 'ts-error-zoom-tf1-tf3';
    tsplot({TF1,TF3},tsopts);


%% DFT plots
% Plot DFTs for TF1 only (will be same for both)
if 0
figure();
    dftopts = copts;
    dftopts.type = 'original-averaged';
    dftplot(TF1,dftopts);


figure();
    dftopts = copts;
    dftopts.type = 'error-averaged-magphase';
    dftplot(TF1,dftopts);
end

%%
figure()

    fmt = 'yyyy-mm-ddTHH:MM:SS.FFF';
    time_range = {'2016-06-14T18:00:00.000','2016-06-15T06:00:00.000'};
    mldn_range(1) = datenum(time_range{1},fmt);
    mldn_range(2) = datenum(time_range{2},fmt);
    to = datenum(TF2.Metadata.timestart,fmt);
    ppd = 86400;
    nt = size(TF2.Out_.Predicted,1);
    t = to + (0:nt-1)'/ppd;
    tidx = find(t >= mldn_range(1) & t <= mldn_range(2));

    figprep();    
    popts = tflabplot_options(TF2, copts, 'tsplot');
    popts.Positions = {popts.PositionTop, popts.PositionBottom};
    popts.Positions{1}(4) = 0.35;
    popts.Positions{2}(4) = 0.35;
    popts.Positions{1}(2) = 0.49;
    for comp = 1:2
    %ax(comp) = subplot('Position',popts.Positions{comp});
    subplot(2,1,comp)
        y = abs(TF2.Out_.Predicted(tidx,1));
        [N,X] = hist(y,20);
        semilogy(X,N/sum(N),'.','MarkerSize',20);
        hold on;grid on;
        y = abs(TF3.Out_.Predicted(tidx,comp));
        [N3,X3] = hist(y,20);
        semilogy(X3,N3/sum(N3),'.','MarkerSize',20);
        legend('TFLab','EMTF')
        ylabel('Probability')
        xlabel(sprintf('$%s$ Predicted [mV/m]',TF2.Metadata.outstr{comp}),'Interpreter','Latex')
    end
    if copts.print == 1   
        figsave(fullfile(copts.printdir, 'pdf-tf1-tf3.png'));
    end

%% SN plots
figure();
    snopts = copts;
    snopts.period_range = [7,6*3600];
    snopts.printname = 'sn-tf1';
    snplot(TF1,snopts);

% Compare all
figure();
    snopts = copts;
    snopts.period_range = [7,6*3600];
    snopts.printname = 'sn-tf1-tf3';
    snplot({TF1,TF3},snopts);

%% Z plots
if 0
figure();
    zopts = copts;
    zopts.type = 2;
    zplot(TF1,zopts);

figure();    
    zopts = copts;
    zopts.type = 2;
    zplot(TF3,zopts);
end

if 1
% Compare Z between TF1 and TF2    
figure();
    zopts = copts;
    zopts.printname = 'z-tf1-tf3';
    zopts.period_range = [6,6*3600];
    zopts.unwrap = 0;
    zopts.type = 1;
    zopts.print = 1;
    zplot({TF2,TF3},zopts);
    zplot({TF1,TF2,TF3},zopts);
end

if 0
    % Should match http://ds.iris.edu/spud/emtf/15014571
    zopts.type = 2;
    figure();
        zplot({TF1,TF2,TF3},zopts,2);
    figure();
        zplot({TF1,TF2,TF3},zopts,3);
end

%% Regression plots
% Plot regression errors for a component of S1's Z at a single frequency
% for one of the segments. (For S2, there is only one segment that was
% used to compute Z.)

fidx = 10; % frequency number
comp = 1;  % component (Zxx=1, Zxy=2, Zyx=3, Zyy=4).
sidx = 1;  % segment number

figure();
    qopts = copts;
    %qqplot_({TF1,TF2,TF3},qopts,fidx,comp,sidx);
    qqplot_({TF1,TF3},qopts,fidx,comp,sidx);
