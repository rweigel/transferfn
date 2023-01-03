%% Single frequency not on DFT grid (so leakage)
% Demonstrates use of non-rectangular time domain window (Parzen).

clear;

addpath([fileparts(mfilename('fullpath')),'/../plot']);
addpath([fileparts(mfilename('fullpath')),'/..']);

Nt = 100;
f  = 25.5/Nt;
wf = 0;

Sx_opts = struct('Nt',Nt,'Z',1+1j,'f',f,'dB',0.0,'dE',0.0);
Sx = demo_signals(-3,Sx_opts);

opts1 = transferfnFD_options(0);
    opts1.transferfnFD.loglevel = 1;
    opts1.fd.evalfreq.functionargs = {[1,wf], 'linear'};
    opts1.td.window.function = @tdwindow;
    opts1.td.window.functionstr = 'Rectangle';
    opts1.td.window.functionargs = {@rectwin};
S1 = transferfnFD(Sx.In,Sx.Out,opts1);
S1.Options.description = 'Rectangle';

opts2 = transferfnFD_options(0);
    opts2.transferfnFD.loglevel = 1;
    opts2.fd.evalfreq.functionargs = {[1,wf], 'linear'};
    opts2.td.window.function = @tdwindow;
    opts2.td.window.functionstr = 'Parzen';
    opts2.td.window.functionargs = {@dpss, 1, 1};
S2 = transferfnFD(Sx.In,Sx.Out,opts2);
S2.Options.description = 'Parzen';

% Use same variable labels from S1 for Sa
Sx.Options.info = S1.Options.info; 
Sx.Options.description = 'Actual';


set(0,'DefaultFigureWindowStyle','docked')
f = 1;
figure(f);clf;f = f+1;
    tsplot(S1,struct('type','raw'));
figure(f);clf;f = f+1;
    tsplot(S1,struct('type','windowed'));
figure(f);clf;f = f+1;
    tsplot(S1,struct('type','error','title',S1.Options.description));
figure(f);clf;f = f+1;
    tsplot(S2,struct('type','error','title',S2.Options.description));

figure(f);clf;f = f+1;
    psdplot(S1,struct('type','raw'));
figure(f);clf;f = f+1;
    psdplot({S1,S2},struct('type','windowed'));
figure(f);clf;f = f+1;
    psdplot({S1,S2},struct('type','error'));

figure(f);clf;f = f+1;
    zplot({Sx,S1,S2});
figure(f);clf;f = f+1;
    zplot({Sx,S1,S2},struct('plottype',3));

if wf > 0    
    figure(f);clf;f = f+1;
        qqplot_(S1,Nf-wf+1);
end