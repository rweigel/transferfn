clear;

addpath(fullfile(fileparts(mfilename('fullpath'))),'..');
tflab_setpaths();

% Get input/output data
[B,E,t,infile,outfile] = Middelpos_clean(); 

if 1
    %% Band pass
    addpath(fullfile(scriptdir(),'..','fft'));
    Tm = 6*86400;
    band = [1/Tm,0.5];
    B = bandpass_(B,band);
    E = bandpass_(E,band);
    E = E(Tm+1:end-Tm,:);
    B = B(Tm+1:end-Tm,:);
end

%% Make length an integer number of segments.
pps = 86400;
I = pps*floor(size(B,1)/pps);
B = B(1:I,:);
E = E(1:I,:);
t = t(1:I);

if 1
    % Trim for faster run
    B = B(1:55*pps,:);
    E = E(1:55*pps,:);
    t = t(1:55*pps,:);
end

%% Set output file base name using start/stop times of input data
filestr = sprintf('Middelpos-%s-%s',...
                  datestr(t(1),'yyyymmdd'),datestr(t(end),'yyyymmdd'));

%% Set metadata
meta = struct();
    meta.instr     = {'$B_x$','$B_y$'};
    meta.inunit    = 'nT';
    meta.outstr    = {'$E_x$','$E_y$'};
    meta.outunit   = 'mV/km';
    meta.timeunit  = 's';
    meta.timedelta = 1;
    meta.frequnit  = 'Hz';
    meta.freqsf    = 1;
    meta.timestart = datestr(t(1),'yyyy-mm-ddTHH:MM:SS.FFF');
    meta.chainid   = 'SANSA';
    meta.stationid = 'Middelpos';

%% Compute first TF
%desc1 = sprintf('OLS; %d %d-day segments',size(B,1)/pps,pps/86400);
desc1 = sprintf('6-day bandpass');
opts1 = tflab_options(1);
    opts1.tflab.loglevel = 1;
    opts1.td.window.width = pps;
    opts1.td.window.shift = pps;

TF1 = tflab(B(:,1:2),E,opts1);
% Modify default description of run
TF1.Options.description = desc1;
TF1.Metadata = meta;
%TF1 = tflab_uncertainty(TF1);

fname1 = fullfile(scriptdir(),'data','Middelpos',[filestr,'-tf1.mat']);
savetf(TF1, fname1);

if 0
if 1
    % Get input/output data
    [B,E,t,infile,outfile] = Middelpos_clean(); 
    if 1
        %% Band pass
        addpath(fullfile(scriptdir(),'..','fft'));
        Tm = 3*86400;
        band = [1/Tm,0.5];
        B = bandpass_(B,band);
        E = bandpass_(E,band);
        E = E(Tm+1:end-Tm,:);
        B = B(Tm+1:end-Tm,:);
    end

    %% Make length an integer number of segments.
    pps = 86400;
    I = pps*floor(size(B,1)/pps);
    B = B(1:I,:);
    E = E(1:I,:);
    t = t(1:I);

    desc2 = sprintf('3-day bandpass');
    opts2 = tflab_options(1);
        opts2.tflab.loglevel = 1;
        opts2.td.window.width = pps;
        opts2.td.window.shift = pps;

    TF2 = tflab(B(:,1:2),E,opts2);
    % Modify default description of run
    TF2.Options.description = desc2;
    TF2.Metadata = meta;
    %TF1 = tflab_uncertainty(TF1);

    fname1 = fullfile(scriptdir(),'data','Middelpos',[filestr,'-tf2.mat']);
    savetf(TF2, fname1);
end

if 0
%% Compute first TF
desc2 = sprintf('OLS; %d %d-day segments',size(B,1)/pps,pps/86400);
opts1 = tflab_options(1);
    opts1.tflab.loglevel = 1;
    opts1.td.window.width = 5*pps;
    opts1.td.window.shift = 5*pps;

TF1 = tflab(B(:,1:2),E,opts1);
% Modify default description of run
TF1.Options.description = desc1;
TF1.Metadata = meta;
%TF1 = tflab_uncertainty(TF1);

fname1 = fullfile(scriptdir(),'data','Middelpos',[filestr,'-tf1.mat']);
savetf(TF1, fname1);
end

if 0
%% Compute second TF
desc2 = sprintf('OLS; One %d-day segment',size(B,1)/pps);
opts2 = tflab_options(1);
    opts2.tflab.loglevel = 1;

TF2 = tflab(B(:,1:2),E,opts2);
% Modify default description of run
TF2.Options.description = desc2;
TF2.Metadata = meta;

% Test S2.Z on same segments as S1.
%TF2 = tflab_metrics(TF2,opts2,TF1.Segment.IndexRange);
%TF2 = tflab_uncertainty(TF2);

fname2 = fullfile(scriptdir(),'data','Middelpos',[filestr,'-tf2.mat']);
savetf(TF2, fname2);
end

%% Third TF
if (1)
    %%
    % Get input/output data
    [B,E,t,infile,outfile] = Middelpos_clean();
    % Third TF
    desc3 = sprintf('No bandpass');
    opts3 = tflab_options(1);
        opts3.tflab.loglevel = 1;
        opts3.td.window.width = pps;
        opts3.td.window.shift = pps;
        opts3.filestr = sprintf('%s-tf3',filestr);

    TF3 = tflab(B(:,1:2),E,opts3);
    % Modify default description of run
    TF3.Options.description = desc3;
    TF3.Metadata = meta;


    fname3 = fullfile(scriptdir(),'data','Middelpos',[opts3.filestr,'.mat']);
    savetf(TF3, fname3);
end

%% Fourth TF
if (1)
    %%
    % Get input/output data
    [B,E,t,infile,outfile] = Middelpos_clean();
    % Third TF
    desc4 = sprintf('No segmenting; no bandpass');
    opts4 = tflab_options(1);
        opts4.tflab.loglevel = 1;
        opts4.filestr = sprintf('%s-tf4',filestr);

    TF4 = tflab(B(:,1:2),E,opts4);
    % Modify default description of run
    TF4.Options.description = desc4;
    TF4.Metadata = meta;


    fname4 = fullfile(scriptdir(),'data','Middelpos',[opts4.filestr,'.mat']);
    savetf(TF4, fname4);
end

Middelpos_plot;
end
