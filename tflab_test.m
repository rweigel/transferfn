clear;

% NB: Tests are intentially not deterministic.
% TODO: Allow deterministic by setting random number seed.

clear;
addpath(fullfile(fileparts(mfilename('fullpath'))));
tflab_setpaths();

close all;
set(0,'defaultFigureWindowStyle','docked');

%% Basic calculation test 1.
% B = randn(), E = B. With evalfreqs = DFT frequencies, should produce
% perfect predictions b/c # of free parameters in fitted Z equals number of
% data points.
logmsg(['Basic calculation; Test 1.1 - '...
        'B = randn(), E = B. 1 DFT point per freq. band.\n']);

N = [99,100];
for n = N
    B = randn(n,1);
    B = B - mean(B);
    E = B;

    opts = tflab_options(0);
    S = tflab(B,E,opts);

    % TODO: Justify 10*eps.
    assert(1-S.Metrics.PE < 10*eps);
    assert(S.Metrics.MSE < 10*eps);
    assert(1-S.Metrics.CC < 10*eps);
end
fprintf('\n');


%% Basic calculation test 2.
% B = cos(w*t), E = A(w)*cos(w*t + phi(w)). No leakage
logmsg(['Basic calculation; Test 1.2. - '...
        'B = cos(w*t), E ~ w*cos(w*t + w). No leakage.\n']);

clear E B
N = 101;
f = fftfreqp(N);
t = (0:N-1)';
for i = 2:length(f)
    A(i,1)   = (i-1);       % Exact amplitude
    Phi(i,1) = -2*pi*f(i);  % Exact phase
    
    % Generate input/output using exact amplitude and phase
    B(:,i) = cos(2*pi*f(i)*t);
    E(:,i) = A(i)*cos(2*pi*f(i)*t + Phi(i));
end

% Input and Output are sum over all frequencies
B = sum(B,2);
E = sum(E,2);

% DC component
A(1) = mean(E)/mean(B);
if A(1) >= 0
    Phi(1) = 0;
else
    Phi(1) = pi;
end
A(1) = abs(A(1));

opts = tflab_options(0); 
S = tflab(B,E,opts); % Estimate transfer function

% TODO: Justify 1e-12.
assert(max( real(S.Z) - real(A) ) < 1e-12 );
assert(max( imag(S.Z) - imag(A) ) < 1e-12 );
fprintf('\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Basic calculation test 3.
% B = randn(), H = [1]. evalfreqs = DFT frequencies.

if 0
    % TODO: Test is failing at 
    %   assert(max(abs(H - H1(1:L))) <= 3*eps);
    %   assert(max(abs(H1(L+1:end))) <= 3*eps);
    % because max diffs ~0.1.

    logmsg(['Basic calculation; Test 1.3. - '...
            'H = [1,0,...] with varying # of zeros. '...
            '1 DFT point per freq. band.\n']);
    
    for i = 1:3     
        H = zeros(i+1,1);
        H(1) = 1;
        S0 = demo_signals('fromH/filter()', struct('H', H, 'N', 100));
    
        opts = tflab_options(0);
        S1 = tflab(S0.In, S0.Out, opts);
    
        Z1i = zinterp(S1.fe,S1.Z,size(S1.In,1));
        [H1,t1] = z2h(Z1i);
        
        % Computed H should match used H and be zero for lags longer than
        % used H.
        L = length(H);
        assert(max(abs(H - H1(1:L))) <= 3*eps);
        assert(max(abs(H1(L+1:end))) <= 3*eps);
        
        % Analytically, real part of Z is 1, imaginary part is 0.    
        re = real(S1.Z)-1; 
        assert(max(abs(re)) <= 1000*eps);
        assert(max(abs(imag(S1.Z))) <= 1000*eps);
        fprintf('---\n');
    end
end
fprintf('\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Regression test 1.
% Expect results to be identical to within ~ machine precision.
logmsg(['Basic calculation; Test 2.1. - '...
                'ols_regress() using real or complex arguments.\n']);

B = randn(n,1);
E = B;

opts = tflab_options(0);

% Use default regression (uses complex matrices).
S1 = tflab(B,E,opts);

% Use regress() with only real matrices.
opts.fd.regression.functionargs = {'regress-real'};
S2 = tflab(B,E,opts);

% TODO: Justify 4*eps.
assert(all(abs(S1.Z(:) - S2.Z(:)) <= 4*eps),'');
fprintf('\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Regression test 2.

logmsg(['Regression comparison; Test 2.2 - Compare ols_regress() w/ '...
                'robustfit() and no noise.\n']);
     
N = [99,100];
for n = N
    B = randn(n,1);
    E = B;

    opts = tflab_options(0);

    opts.fd.evalfreq.function = @evalfreq;
    % Can't use 1 DFT point per freq. band because robust regression will
    % have rank deficiency.
    opts.fd.evalfreq.functionstr  = '3 DFT points per freq. band';
    opts.fd.evalfreq.functionargs = {[1,1],'linear'};

    % Uses default regression function.
    S1 = tflab(B,E,opts);

    opts.fd.regression.function = @regress_robustfit_tflab;
    opts.fd.regression.functionargs = {};
    opts.fd.regression.functionstr = ...
                            'Robust regression using regress_robustfit_tflab() function';
    S2 = tflab(B,E,opts);

    assert(S1.Metrics.PE - S2.Metrics.PE <= 2*eps);
    assert(S1.Metrics.CC - S2.Metrics.CC <= 2*eps);
    assert(S1.Metrics.MSE - S2.Metrics.MSE <= 2*eps);

    opts.fd.regression.function = @regress_robustfit_tflab;
    opts.fd.regression.functionargs = {[],[],'off'};
    opts.fd.regression.functionstr = ...
                            'Robust regression using regress_robustfit_matlab() function';
    S3 = tflab(B,E,opts);

    assert(S1.Metrics.PE - S3.Metrics.PE <= 2*eps);
    assert(S1.Metrics.CC - S3.Metrics.CC <= 2*eps);
    assert(S1.Metrics.MSE - S3.Metrics.MSE <= 2*eps);
end
fprintf('\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% API Test - Multiple Inputs and Ouputs
logmsg('API I/O Test; Test 3.1. - One or Two Outputs, One Input.\n');

N = 1000;
B = randn(N,2);
E = B;

opts = tflab_options(1);
opts.td.window.width = N;
opts.td.window.shift = N;

% 1 input, one or two outputs
S1 = tflab(B(:,1),E(:,1),opts);
fprintf('---\n');
S2 = tflab(B(:,1),[E(:,1),E(:,1)],opts);

assert(all(S1.Out_.Predicted == S2.Out_.Predicted(:,1)));
assert(all(S1.Out_.Predicted == S2.Out_.Predicted(:,2)));

%%%
fprintf('\n');
%%%
logmsg('API I/O Test; Test 3.2. - Two Outputs, Two Inputs\n');

% 2 inputs, one or two outputs
S1 = tflab(B,E(:,1),opts);
fprintf('---\n');
S2 = tflab(B,E(:,2),opts);
fprintf('---\n');
S3 = tflab(B,E,opts);

assert(all(S1.Out_.Predicted == S3.Out_.Predicted(:,1)));
assert(all(S2.Out_.Predicted == S3.Out_.Predicted(:,2)));
fprintf('\n');


%% API Test - Segments
% E and B are split into segments and transfer functions are computed for
% each segment.
logmsg('API Segmenting; Test 3.3.\n');

N = 1000;
B = randn(N,1);
E = B;

opts = tflab_options(1);
opts.td.window.width = N;
opts.td.window.shift = N;

S1 = tflab(B,E,opts);
fprintf('---\n');
S2 = tflab([B;B],[E;E],opts);

% Results for two segments in S2 should be same a single segment in S1.
assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,1,1)));
assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,1,2)));
assert(all(S1.Z == S2.Segment.Z(:,:,1)))
assert(all(S1.Z == S2.Segment.Z(:,:,2)))
assert(all(S1.Z(:) == S2.Z(:)));

%%%
fprintf('\n');
%%%
logmsg('API Segmenting; Test 3.4.\n');

N = 1000;
B = randn(N,2);
E = B;

opts = tflab_options(1);
opts.td.window.width = N;
opts.td.window.shift = N;

S1 = tflab(B(:,1),E(:,1),opts);
fprintf('---\n');
S2 = tflab([B(:,1);B(:,1)],[E;E],opts);

assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,1,1)));
assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,1,2)));

fprintf('\n');
%%%
logmsg('API Segmenting; Test 3.5.\n');

S3 = tflab(B,E,opts);
S4 = tflab([B;B],[E;E],opts);
assert(all(S3.Out_.Predicted(:,1) == S4.Segment.Out_.Predicted(:,1,1)));
assert(all(S3.Out_.Predicted(:,2) == S4.Segment.Out_.Predicted(:,2,1)));
assert(all(S3.Out_.Predicted(:,1) == S4.Segment.Out_.Predicted(:,1,2)));
assert(all(S3.Out_.Predicted(:,2) == S4.Segment.Out_.Predicted(:,2,2)));

% 2:end to remove Z(f = 0) which may have NaNs for Z
tmp = S3.Z(2:end,:) == S4.Z(2:end,:);
assert(all(tmp(:)));
fprintf('\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% API Test - Intervals
% When there are gaps in time in the input/data, one can pass a cell array
% of intervals and then the transfer function is computed on each interval.
% The intervals may be segemented by specifying a window width and window
% shift that is less than the interval length.
logmsg('API Intervals; Test 3.6.\n');

N = 1000;
B = randn(N,1);
E = B;

opts = tflab_options(1);
opts.td.window.width = N;
opts.td.window.shift = N;

S1 = tflab([B;B],[E;E],opts);
fprintf('---\n');
S2 = tflab({B;B},{E;E},opts);
assert(all(S1.Z(:) == S2.Z(:)));
assert(all(S1.Segment.Out_.Predicted(:) == S2.Segment.Out_.Predicted(:)))

%%%
fprintf('\n');
%%%
logmsg('API Intervals; Test 3.7.\n');

S1 = tflab(B,E,opts);
fprintf('---\n');
S2 = tflab({B,[B;B]},{E,[E;E]},opts);
fprintf('---\n');
S3 = tflab({B,[B;B]},{0.5*E,[1.0*E;1.5*E]},opts);

assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,:,1)))
assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,:,2)))
assert(all(S1.Out_.Predicted == S2.Segment.Out_.Predicted(:,:,3)))
% DC value will be different for S3, so omit from test:
assert(all(S1.Z(2:end)-S3.Z(2:end) < 10*eps));

% Average TF should be 1.0 for all fe, same as S1.Z.
fprintf('\n');


%% API Test - Stack Regression
% When intervals and/or segments are used, the default is to compute a
% transfer function that is the average of each segment. 
logmsg('API Stack Regression; Test 3.8.\n');

N = 1000;
B = randn(N,2);
E = B;

% 1 input/1 output. When using 1 segment, non-stack average should be same
% as stack average result
opts = tflab_options(1);
% The following two lines are not needed as this is default for behavior
% when tflab_options(1)
opts.td.window.width = N; 
opts.td.window.shift = N; 

S1 = tflab(B(:,1),E(:,1),opts);
fprintf('---\n');
opts.fd.stack.average.function = ''; % Don't compute stack average.
S2 = tflab(B(:,1),E(:,1),opts);
assert(all(S1.Z(:) == S2.Z(:)))

fprintf('\n');
%%%
logmsg('API Stack Regression; Test 3.9.\n');

% 2 inputs/2 outputs. When using 1 segment, stack regression should be
% same as stack average result
opts = tflab_options(1);
% The following two lines are not needed as this is default for behavior 
% when tflab_options(1)
opts.td.window.width = N;
opts.td.window.shift = N;

S1 = tflab(B,E,opts);
fprintf('---\n');
opts.fd.stack.average.function = ''; % Don't compute stack average.
S2 = tflab(B,E,opts);

% 2:end to remove Z(f = 0) which may have NaNs for Z
tmp = S1.Z(2:end,:) == S2.Z(2:end,:);
assert(all(tmp(:)));

fprintf('\n');
%%%
logmsg('API Stack Regression; Test 3.10.\n');

% Compare stack average Z to stack regression Z. Results not expected to be
% identical. For the stack average method, Z for each segment in a given
% frequency band is computed by regressing on the DFTs in that band segment
% Z values are averaged. For the stack regression method, the DFTs in a
% given frequency band are computed for each segment and then the segment
% frequency band DFTs are combined and a single regression is performed.
% DFTs.
N = 1000;
B = randn(N,1);
E = B;

opts = tflab_options(1);
opts.td.window.width = N; % Will result in two intervals.
opts.td.window.shift = N; % Will result in two intervals.

S3 = tflab([B;B],[E;E],opts);
fprintf('---\n');

opts.fd.stack.average.function = '';
S4 = tflab([B;B],[E;E],opts); % window.width and window.shift ignored.
assert(all(abs(S3.Z(:) - S4.Z(:)) < 10*eps))

fprintf('\n');
%%%
logmsg('API Stack Regression; Test 3.11.\n');

% Verify that get same answer when continuous and discontinuous segments
% are used. Expect identical results.
opts = tflab_options(1);
opts.td.window.width = N;
opts.td.window.shift = N;
opts.fd.stack.average.function = '';

S3 = tflab([B;B],[E;E],opts);
fprintf('---\n');

% Each element of cell array is treated as having gap in time stamps.
S4 = tflab({B,B},{E,E},opts);
assert(all(S3.Z(:) == S4.Z(:)))

%assert(all(S1.Z == S2.Z));
fprintf('\n');
logmsg('tflab_test.m: All tests passed.\n');
