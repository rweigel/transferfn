function S = transferfnFD(B,E,t,opts)
%TRANSFERFNFD Frequency domain MIMO transfer function estimate
%
%  S = transferfnFD(B,E) returns a structure with an estimate of the
%  transfer function Z in the expression
%
%    Ex(f) = Zxx(f)Bx(f) + Zxy(f)By(f) + ...
%  
%  given time series for Ex(t), Bx(t), By(t), ... and using the convention
%  that U(f) is the fourier transform of U(t).
%
%  Estimates are made for the complex-valued transfer function Z at a set
%  of evaluation frequencies, fe, using regression with a set of
%  frequencies in a window around each fe on the model equation above.
%  
%  The set of evaluation frequencies and windows are determined using the
%  function evalfreq(). By default, the evaluation frequencies are
%  lograrithmically spaced with approximately 7 frequencies per decade.
%
%  If the number of columns in B is Nb and E has Ne columns, Z will have
%  2*Nb*Ne columns with columns 1:Nb corresponding to the transfer function
%  that gives E(:,1) given B, columns Nb+1:2*Nb corresponding to the
%  transfer function that gives E(:,2) given B, etc.
%
%  In more familar notation, if the input and outputs are
%
%   Bx(t) = B(:,1)  By(t) = B(:,2)
%   Ex(t) = E(:,1)  Ey(t) = E(:,2)
%
%  the model equations are
%
%   Ex(f) = Zxx(f)Bx(f) + Zxy(f)By(f)
%   Ey(f) = Zyx(f)Bx(f) + Zyy(f)By(f)
%
%  and S = transferfnFD(B,E) returns a structure S with a field Z such that
%
%   Zxx = Z(:,1)   Zxy = Z(:,2)
%   Zyx = Z(:,3)   Zyy = Z(:,4)
% 
%  with the rows of Z being estimates of the transfer function at the
%  evaluation frequencies given by field fe in S.
%
%  S = transferfnFD(B,E,t) associates a time value with each row of B and
%  E. Use t = [] to use the default of t = [1:size(B,1)]'.
%
%  S = transferfnFD(B,E,t,options) uses options returned by the function
%  transferfnFD_options.
%
%  See also TRANSFERFNFD_OPTIONS, TRANSFERFNFD_TEST, TRANSFERFNFD_DEMO.

addpath([fileparts(mfilename('fullpath')),'/misc']);
addpath([fileparts(mfilename('fullpath')),'/lib']);
addpath([fileparts(mfilename('fullpath')),'/fft']);
addpath([fileparts(mfilename('fullpath')),'/spectra']);
addpath([fileparts(mfilename('fullpath')),'/regression']);
addpath([fileparts(mfilename('fullpath')),'/stats']);
addpath([fileparts(mfilename('fullpath')),'/deps/printstruct']);

if nargin == 2
    t = [];
    opts = [];
end

if nargin == 3
    % transferfnFD(B,E,t) or
    % transferfnFD(B,E,opts)
    if isstruct(t)
        % transferfnFD(B,E,opts)
        opts = t;
        t = [];
    else
        % transferfnFD(B,E,t)        
        opts = [];
        assert(size(t,1) == size(B,1),...
                'Required: size(t,1) == size(B,1) == size(E,1)');    
    end
end

if nargin < 3 || isempty(opts)
    % transferfnFD(B,E) or
    % transferfnFD(B,E,t)
    % Use default options.
    opts = transferfnFD_options(1);
    if opts.transferfnFD.loglevel
        logmsg(['No options given. '...
                 'Using options returned by transferfnFD_options(1)\n']);
    end
end

if iscell(B)
    
    % Each cell element is an interval and an arbitrary gap in time is
    % assumed between the end of one element and the start of the next
    % element.
    assert(all(size(B) == size(E)),'Required: size(B) == size(E)');
    assert(isvector(B),'Required: B must be vector cell array');
    assert(isvector(E),'Required: E must be vector cell array');
    if ~isempty(t)
        assert(all(size(t) == size(B)),'Required: size(t) == size(B)');
        assert(isvector(t),'Required: t must be vector cell array');
    else
        for c = 1:length(B)
            t{c} = (opts.td.start:opts.td.dt:size(B{c},1))';
        end
    end
    sE = size(E{1},2);
    sB = size(B{1},2);
    % Check that number of columns is same for all intervals.
    for c = 2:length(B)
        assert(size(B{c},2) == sB,...
            'Number of columns in B{%d} must be the same as B{1}.',c);
        assert(size(E{c},2) == sE,...
            'Number of columns in E{%d} must be the same as E{1}.',c);
        Nr(c) = size(B,1);
    end
    if isnan(opts.td.window.width) && length(unique(Nr)) ~= 1
        warning(['opts.td.window.width not given and intervals do not', ...
                'all have the same length.\n', ...
                'Using shortest interval length (%d) for width and shift'],...
                min(Nr));
        opts.td.window.width = min(Nr);
        opts.td.window.shift = min(Nr);
    end
    S = struct();
    S.Segment = struct();
    
    for c = 1:length(B) % Number of segments
        if opts.transferfnFD.loglevel > 0
            logmsg(...
                'Starting computation for disconnected segment c = %d of %d\n',...
                c,length(B));
        end
        % Compute Z for each segment in each interval
        if opts.transferfnFD.loglevel > 0
            logmsg('Calling transferfnFD(B{%d},E{%d},...)\n',c,c);
        end
        
        opts.transferfnFD.no_stack_regression = 1;
        Sc = transferfnFD(B{c},E{c},t{c},opts);
        
        if ~isfield(Sc,'Segment')
            % If an interval had only one segment
            Sc.Segment = Sc;
        end
        if c == 1
            S = Sc;
        else
            % Combine segment fields across third dimension.
            S.Segment = combineStructs(S.Segment,Sc.Segment,3);
        end
    end
    
    if isempty(opts.fd.stack.average.function)
        
        % Remove fields from top level of S b/c they are calculations for
        % the last c segment.
        fns = fieldnames(S);
        for i = 1:length(fns)
            if ~strcmp('Segment',fns{i})
                S = rmfield(S,fns{i});
            end
        end

        if opts.transferfnFD.loglevel > 0
            logmsg( 'Starting stack regression.\n');
        end
        
        % Compute Z at each fe by regressing on all segment DFTs near fe.
        S.Segment = stackRegression(S.Segment, opts);
                
        if opts.transferfnFD.loglevel > 0
            logmsg( 'Finished stack regression.\n');
        end
        
        S.fe = S.Segment.fe;
        S.Z = S.Segment.Z;
        S.Phi = S.Segment.Phi;
        S.H = S.Segment.H;
        S.tH = S.Segment.tH;
        S.Regression = S.Segment.Regression;
        
        S.Segment = rmfield(S.Segment, 'Z');
        S.Segment = rmfield(S.Segment, 'Phi');
        S.Segment = rmfield(S.Segment, 'H');
        S.Segment = rmfield(S.Segment, 'tH');
        S.Segment = rmfield(S.Segment, 'Regression');
        
        % Calculate predicted/metrics/psd for each cell element

        
        Sc = S;
        for c = 1:length(B)
            Sc.In = B{c};
            Sc.Out = E{c};
            Sc.Time = t{c};

            if opts.transferfnFD.loglevel > 0
                logmsg(...
                    ['Computing metrics for B{%d} and E{%d} using stack '...
                     'regression transfer function.\n'],c,c);
            end
            Sc = transferfnMetrics(Sc,opts);
            if opts.transferfnFD.loglevel > 0
                logmsg(...
                    ['Finished computing metrics for B{%d} and E{%d} using '...
                     'stack regression transfer function.\n'],c,c);
            end
            for j = 1:size(Sc.Metrics.PE, 2)
                logmsg( ...
                        'Output col %d, PE/CC/MSE = %.2f/%.2f/%.3f\n',...
                         j,...
                         Sc.Metrics.PE(1,j),...
                         Sc.Metrics.CC(1,j),...
                         Sc.Metrics.MSE(1,j));
            end
            
            S.Predicted{c} = Sc.Predicted;
            S.Metrics{c} = Sc.Metrics;
            S.PSD{c} = Sc.PSD;
        end
        
        S.In = B;
        S.Out = E;
        S.Time = t;
    else       
        % Compute stack average Z and its predicted/metrics/psd for full In/Out
        S.In = B;
        S.Out = E;
        S.Time = t;
        S = rmfield(S,'DFT');
        S = rmfield(S,'Regression');
        S = rmfield(S,'Z');
        S = stackAverage(S,opts);
    end
    return;
end

% Number of time values must be the same.
assert(size(B,1) == size(E,1),...
        'Required: size(B,1) == size(E,1)');

assert(size(B,1) >= size(B,2),...
    ['Not enough time samples: size(B,1) must be greater than '...
     'or equal to size(B,2)']);

if nargin < 3 || isempty(t)
    t = (opts.td.start:opts.td.dt:size(B,1))';
end

if size(E,2) > 1
    % Ex = ZxxBx + ZxyBy + ...
    % Ey = ZyxBx + ZyyBy + ...
    % ...
    for j = 1:size(E,2)
        if opts.transferfnFD.loglevel > 0
            logmsg('Calling transferfnFD(B,E(:,%d),...)\n',j);
        end
        Sc = transferfnFD(B,E(:,j),t,opts);    
        if j == 1
            S = Sc;
        else
            S = combineStructs(S,Sc,2);
        end
    end
    return;
end

if opts.transferfnFD.loglevel > 0
    logmsg( ['Computing transfer function for input/output '...
                    'sizes [%d,%d]/[%d,1]\n'],...
                     size(B),size(E,1));
    if opts.transferfnFD.loglevel > 1
        logmsg( 'Options:\n');
        printstruct(opts);
    end
end

if isnan(opts.td.window.width)
    if opts.td.window.loglevel
        logmsg('opts.td.window.with is NaN. Using size(B,1).\n');
    end
    % Set default window width and shift equal to the number of time points.
    opts.td.window.width = size(B,1);
    opts.td.window.shift = size(B,1);
else
    assert(opts.td.window.width > 1,...
            'opts.td.window.width must be greater than 1');
    assert(opts.td.window.shift > 1,...
            'opts.td.window.shift must be greater than 1');
    assert(opts.td.window.width <= size(B,1),...
            'opts.td.window.width must be less than or equal to size(B,1)');
    Tw = opts.td.window.width;
    Ts = opts.td.window.shift;
    a = 1:Ts:size(B,1);
    b = a + Tw - 1;
    if b(end) > size(B,1)
        a = a(1:end-1);
        b = b(1:end-1);
    end
    if b(end) ~= size(B,1)
        warning(...
            ['opts.td.window.width = %d,'...
             'opts.td.window.shift = %d, size(B,1) = %d.'...
             '\n\t Last %d point(s) will not be used.\n'],...
             Tw,Ts,size(B,1),size(B,1)-b(end));
    end
    optsx = opts;
    optsx.td.window.width = NaN;
    optsx.td.window.shift = NaN;
    % Compute TF for each segment
    for s = 1:length(a)
        Iseg = a(s):b(s);
        if opts.transferfnFD.loglevel > 0
            logmsg(...
                    'Starting computation for segment %d of %d\n',...
                    s,length(a));
        end
        % Ss = Segment struct.
        Ss = transferfnFD(B(Iseg,:),E(Iseg,:),t(Iseg),optsx);
        if opts.transferfnFD.loglevel > 0 ...
                        && ~isempty(opts.fd.stack.average.function)
            % Summarize results for each column of E
            for j = 1:size(E,2)
                logmsg(...
                        ['Segment %d of %d PE/CC/MSE '...
                         'of Out(%d:%d,%d) = %.2f/%.2f/%.3f\n'],...
                         s,...
                         length(a),...
                         Iseg(1),...
                         Iseg(end),...
                         j,...
                         Ss.Metrics.PE(j),...
                         Ss.Metrics.CC(j),...
                         Ss.Metrics.MSE(j));
            end
        end
        if s == 1
            S = Ss;
        else
            S = combineStructs(S,Ss,3);
        end
    end
    
    if isempty(opts.fd.stack.average.function)

        if isfield(opts.transferfnFD, 'no_stack_regression')
            if opts.transferfnFD.loglevel > 0
                logmsg(...
                    ['opts.transferfnFD.no_stack_regression set. '...
                     'Not doing stack regression (yet).\n']);
            end
            S.Segment = S;
            S = rmfield(S,'DFT');
            S = rmfield(S,'PSD');
            S = rmfield(S,'Regression');
            return
        else
        
            if opts.transferfnFD.loglevel > 0
                logmsg( 'Starting stack regression.\n');
            end

            S = stackRegression(S, opts);

            if opts.transferfnFD.loglevel > 0
                logmsg( 'Finished stack regression.\n');
            end

            S.Segment = S;
            S.Segment = rmfield(S.Segment,'Z');
            S = rmfield(S,'DFT');
            S = rmfield(S,'Regression');
            S = rmfield(S,'Predicted');
            S = rmfield(S,'Metrics');
            S.In = B;
            S.Out = E;
            S.Time = t;
            S = transferfnMetrics(S,opts);
        end
    else
        if size(S.In,3) > 1
            S.Segment = S;
            S.In = B;
            S.Out = E;
            S.Time = t;
            S = rmfield(S,'DFT');
            S = rmfield(S,'Regression');
            S = rmfield(S,'Z');
            S = stackAverage(S,opts);
        end
    end    
    S.Options = opts;
    return;
end

[~,f] = fftfreq(size(B,1)); % Unique DFT frequencies

[fe,Ic,Ne] = opts.fd.evalfreq.function(...
                size(B,1),opts.fd.evalfreq.functionargs{:});

S = struct();
    S.In = B;
    S.Out = E;
    S.Time = t;
    S.Options = opts;
    S.fe = fe';
    S.Regression = struct();
    S.PSD = struct(); 
        % Note: This will be over-written by computeMetrics().
        S.PSD.In = smoothSpectra(B,opts);
        S.PSD.Out = smoothSpectra(E,opts);

if opts.transferfnFD.plot.timeseries(1)
    timeseries_plot(S,'raw');
end
if opts.transferfnFD.plot.spectrum(1)    
    spectrum_plot(S,'raw');
end

if ~isempty(opts.td.window.function)
    if opts.transferfnFD.loglevel > 0
        logmsg( 'Computing windowed data.\n');
    end
    [B,W] = opts.td.window.function(B,opts.td.window.functionargs{:});
    [E,W] = opts.td.window.function(E,opts.td.window.functionargs{:});
    S.Window = W;
    S.Window.In = B;
    S.Window.Out = E;
    S.Window.PSD = struct(); 
        S.Window.PSD.In = smoothSpectra(B,opts);
        S.Window.PSD.Out = smoothSpectra(E,opts);

    if opts.transferfnFD.plot.timeseries(1)    
        timeseries_plot(S,'windowed');        
    end
    if opts.transferfnFD.plot.spectrum(1)    
        spectrum_plot(S,'windowed');
    end
    
else
    if opts.transferfnFD.loglevel > 0
        logmsg( ...
            'No time domain window applied b/c no function given.\n');
    end
end

if ~isempty(opts.td.prewhiten.function)
    [B,E,Bf,Ef] = opts.td.prewhiten.function(B,E,opts);
    S.Prewhiten = struct();
    S.Prewhiten.In = B;
    S.Prewhiten.InFilter = Bf;
    S.Prewhiten.Out = E;
    S.Prewhiten.OutFilter = Ef;
    S.Window.Comment = ...
        ['S.Prewhiten.In (S.Prewhiten.Out) are S.Window.In (S.Window.Out) '...
         'after application of S.Prewhiten.InFilter (S.Prewhiten.OutFilter)'];
    if opts.td.prewhiten.plot
        prewhiten_plot(S,opts);
    end
    if opts.td.prewhiten.loglevel
        prewhiten_log(S,opts);
    end
else
    if opts.td.prewhiten.loglevel
        logmsg( ...
                ['No time domain prewhitening performed '...
                 'b/c no function given.\n']);
    end
end

if opts.transferfnFD.loglevel > 0
    logmsg( 'Computing raw DFTs of input and output.\n');
end

ftB = fft(B);
ftE = fft(E);

% Compute # of unique frequency values.
N = size(B,1);
if mod(N,2) == 0
    Np = N/2 + 1; % f = -0.5 value is kept.
else
    Np = (N-1)/2 + 1;    
end

ftB = ftB(1:Np,:);
ftE = ftE(1:Np,:);

if opts.transferfnFD.loglevel > 0
    if isempty(opts.fd.stack.average.function)
        logmsg(...
                    'Starting freq band calcs for %d frequencies.\n',...
                     length(Ic)-1);
        logmsg(...
            ['opts.fd.stack.average.function = ''''. \n' ...
            'No regression performed for each freq. band of segement\n']);
    else
        logmsg(['Starting freq band and regression '...
                        'calcs for %d frequencies.\n'],length(Ic)-1);
                    

        fargs = opts.fd.regression.functionargs;
        if iscell(fargs) && ~isempty(fargs)
            p = fargs{1};
        else
            p = fargs;
        end
        if length(p) > 0
            logmsg(...
                'Using %s() with additional arguments\n',...
                func2str(opts.fd.regression.function));
            disp(p)
            fprintf('\b');
        else
            logmsg(...
                'Using %s() with additional arguments\n',...
                func2str(opts.fd.regression.function));
        end
    end
end

winfn = opts.fd.window.function;
if opts.fd.window.loglevel
    logmsg( 'Using FD window function %s\n',func2str(winfn));
end

if opts.fd.evalfreq.loglevel
    evalfreq_log(size(B,1),opts.fd.evalfreq.functionargs{:});
end
if opts.fd.evalfreq.plot(1)
	evalfreq_plot(size(B,1),opts.fd.evalfreq.functionargs{:});
    if opts.fd.evalfreq.plot(2)
        % Print png
    end
    if opts.fd.evalfreq.plot(3)
        % Print pdf
    end    
end

for j = 1:length(Ic)

    if opts.fd.regression.loglevel && ~isempty(opts.fd.stack.average.function)
        logmsg(...
                ['Starting freq band and regression '...
                 'calcs on frequency %d of %d\n'],...
                 j, length(fe)-1);
    end
    
    W = winfn(2*Ne(j)+1);
    W = W/sum(W);
    r = Ic(j)-Ne(j):Ic(j)+Ne(j); % Index range

    W  = sqrt(W);
    Wr = repmat(W,1,size(ftB,2));

    S.DFT.Out{j,1} = ftE(r,1);
    S.DFT.In{j,1} = ftB(r,:);
    S.DFT.f{j,1} = f(r);
    S.DFT.Weights{j,1} = W;
    
    if opts.fd.window.loglevel
        logmsg(...
                ['Band with center of fe = %.8f has %d '...
                 'points; fl = %.8f fh = %.8f\n'],...
                 fe(j),...
                 length(r),...
                 f(Ic(j)-Ne(j)),...
                 f(Ic(j)+Ne(j)));
    end

    if ~isempty(opts.fd.stack.average.function)
        % If not computing Z based on stack averages, don't need to do
        % regression as it is done later.
        args = opts.fd.regression.functionargs;    
            
        warning('');
        [Z(j,:),stats] = opts.fd.regression.function(...
                                Wr.*ftB(r,:),W.*ftE(r,1),args{:});
        [warnMsg, warnId] = lastwarn;                            
        if ~isempty(warnMsg)
            logmsg( 'Warning occured on eval freq. = %d\n', j);
            %ftE
            %ftB
            %keyboard
        end                            
        S.Regression.Stats{j,1} = stats;
    end
    
    if 0
        
        ts = sprintf(['Frequency band centered on fe(%d); [fe(%d),fe(%d)] '...
                      '= [%.4d,%.4d]'],...
                      j-1,j-2,j,fe(j-2),fe(j));
        
        if Ne(j) > 5
            Ea = W.*ftE(r,1);
            Ep = (Wr.*ftB(r,:))*(real(Z(j,:)).');

            qqplot(real(Ea-Ep));grid on;box on;
                set(get(gca,'ylabel'),'String','Re[E(\omega)-E_p(\omega)]');
                set(get(gca,'title'),'String',ts);

            qqplot(imag(Ea-Ep));grid on;box on;
                set(get(gca,'ylabel'),'String','Im[E(\omega)-E_p(\omega)]');
                set(get(gca,'title'),'String',ts);            

            Ea = bandpass(E,[fe(j-2)-eps,fe(j)+eps]);
            Ep = zpredict(Z(j-2:j,:),B,fe(j-2:j));

            qqplot(Ea-Ep);grid on;box on;
                set(get(gca,'ylabel'),'String','Bandpassed E(t)-E_p(t)');
                set(get(gca,'title'),'String','');
                title(ts,'FontWeight','normal');            
                
            figure;hold on;grid on;box on;
                plot(Ea,'b','linewidth',2);
                plot(Ep,'g');
                CC = cc_nonflag(Ea,Ep);
                PE = pe_nonflag(Ea,Ep);
                MSE = mse_nonflag(Ea,Ep);
                SN = sn_nonflag(Ea,Ep);
                ls = sprintf('E_p PE/CC/MSE/SN = %.2g/%.2g/%.2g/%.2g',...
                    CC,PE,MSE,SN);

                title(sprintf(...
                    ['Frequency band centered on fe(%d); '...
                     '[fe(%d),fe(%d)] = [%.4d,%.4d]'],...
                    j-1,j-2,j,fe(j-2),fe(j)),'FontWeight','normal');
                legend('E',ls,'Location','Best','Orientation','Horizontal');
        end
    end

end

if opts.transferfnFD.loglevel > 0
    if isempty(opts.fd.stack.average.function)
        logmsg(...
                ['Finished freq band calculations '...
                 'for %d eval freqs.\n'],...
                 length(Ic)-1);
    else
        logmsg(...
                ['Finished freq band and regression '...
                 'calculations for %d eval. freqs.\n'],...
                 length(Ic)-1);
    end
end

% TODO: Allow TD window and prewhiten to not be same for input and output
% and then compute corrected Z?

if ~isempty(opts.fd.stack.average.function)
    % Compute metrics for predicting segment output based on Z computed
    % using segment's input and output.
    S.Z = Z;

    logmsg( 'Computing Phi\n');    
    S.Phi = atan2(imag(Z),real(Z));
    logmsg( 'Finished computing Phi\n');

    logmsg( 'Interpolating Z\n');    
    Zi = zinterp(S.fe,S.Z,size(S.In,1));
    logmsg( 'Finished interpolating Z\n');
    
    logmsg( 'Computing H\n');
    [S.H,S.tH] = z2h(Zi);
    logmsg( 'Finished computing H\n');

    if opts.transferfnFD.loglevel > 0
        logmsg(...
                ['Computing segment metrics for segement '...
                 'transfer function.\n']);
    end
    
    S = transferfnMetrics(S,opts);
    
    if opts.transferfnFD.loglevel > 0
        logmsg( ...
                ['Finished segment metrics for segment '...
                 'transfer function.\n']);
        logmsg( ...
                'PE/CC/MSE = %.2f/%.2f/%.3f\n',...
                 S.Metrics.PE,...
                 S.Metrics.CC,...
                 S.Metrics.MSE);
    end
    if opts.transferfnFD.plot.timeseries(1)
        timeseries_plot(S,'error');
    end
    if opts.transferfnFD.plot.spectrum(1)    
        spectrum_plot(S,'error');
    end
    if opts.transferfnFD.plot.Z(1)    
        transferfnZ_plot(S);
    end            
    if opts.transferfnFD.plot.H(1)
        transferfnH_plot(S);
    end        
end

end % transferfnFD()

function S = stackAverage(S,opts)

    S.Z = mean(S.Segment.Z,3);
    S.Phi = atan2(imag(S.Z),real(S.Z));
    
    if iscell(S.In)
        S.Predicted = {};
        S.PSD = {};
        S.Metrics = {};
        for i = 1:length(S.In)
            tmp = struct();
            tmp.In = S.In{i};
            tmp.Out = S.Out{i};
            tmp.Z = S.Z;
            tmp.fe = S.fe;
            tmp = transferfnMetrics(tmp,opts);
            S.Predicted{i} = tmp.Predicted;
            S.PSD{i} = tmp.PSD;
            S.Metrics{i} = tmp.Metrics;
        end
    else
        S = transferfnMetrics(S,opts);
    end
end

function S = transferfnMetrics(S,opts)

    if isfield(S,'Segment')
        N = size(S.Segment.In,1);
    else
        N = size(S.In,1);
    end
    
    S.Predicted = [];
    S.Metrics = struct();
    S.PSD = struct();

    Zi = zinterp(S.fe,S.Z,size(S.In,1));
    for k = 1:size(S.Out,3)
        S.Predicted(:,:,k) = zpredict(Zi,S.In(:,:,k));

        S.PSD.In(:,:,k)    = smoothSpectra(S.In(:,:,k),opts,N);
        S.PSD.Out(:,:,k)   = smoothSpectra(S.Out(:,:,k),opts,N);
        S.PSD.Error(:,:,k) = smoothSpectra( ...
                                   S.Out(:,:,k) - S.Predicted(:,:,k),opts,N);
        S.PSD.Predicted(:,:,k) = smoothSpectra(S.Predicted(:,:,k),opts,N);

        S.Metrics.PE(1,:,k)  = pe_nonflag(S.Out(:,:,k),S.Predicted(:,:,k));
        S.Metrics.MSE(1,:,k) = mse(S.Out(:,:,k),S.Predicted(:,:,k));
        S.Metrics.CC(1,:,k)  = cc_nonflag(S.Out(:,:,k),S.Predicted(:,:,k));
        S.Metrics.SN(:,:,k)  = S.PSD.Out(:,:,k)./S.PSD.Error(:,:,k);
        S.Metrics.Coherence(:,:,k) = smoothCoherence(...
                                        S.Out(:,:,k),...
                                        S.Predicted(:,:,k),opts,N);
    end
end

function S = stackRegression(S,opts)

    % At each evaluation frequency index i and output column c and for each
    % segment s, S.DFT.Out(i,c,s) is a single-column matrix with rows of
    % DFTs of segment s in the frequency band associated with i.
    % S.DFT.In(i,1,s) is a matrix with same number of columns of S.In. Each
    % column of S.DFT.In(i,1,s) contains the DFTs for the respective column
    % in S.In for freq. band i and segment s.
    
    % https://www.mathworks.com/matlabcentral/answers/364719-detect-warning-and-take-action#answer_289064    

    for i = 1:size(S.DFT.In, 1) % Eval frequencies
        for c = 1:size(S.DFT.Out, 2) % Columns of E

            if opts.transferfnFD.loglevel > 1
                logmsg( 'Doing stack regression for eval freq. %d and on column %d of input.\n', i, c);
            end
            % S.DFT.Out(i,x,s)
            
            tmp = squeeze(S.DFT.In(i,1,:));
            ftB = cat(1,tmp{:});

            tmp = squeeze(S.DFT.Out(i,c,:));
            ftE = cat(1,tmp{:});

            tmp = squeeze(S.DFT.Weights(i,c,:));
            W   = cat(1,tmp{:});
            Wr  = repmat(W,1,size(ftB,2));
            args = opts.fd.regression.functionargs;

            warning('');
            [z,stats] = opts.fd.regression.function(Wr.*ftB,W.*ftE,args{:});
            [warnMsg, warnId] = lastwarn;
            if ~isempty(warnMsg)
                logmsg( 'Warning occured on output column %d, eval freq. = %g\n', c, S.fe(i,1));
                %ftE
                %ftB
                %keyboard
            end
            S.Regression.Stats{i,c} = stats;
            if c == 1
                Zc = z.';
            else
                Zc = [Zc,z.'];
            end
            if opts.transferfnFD.loglevel > 1
                logmsg( 'Finished stack regression for eval freq. %d and on column %d of input.\n', i, c);
            end            
        end
        Z(i,:) = Zc;
    end

    S.Z = Z;    

    logmsg( 'Computing Phi\n');    
    S.Phi = atan2(imag(Z),real(Z));
    logmsg( 'Finished computing Phi\n');

    logmsg( 'Interpolating Z\n');    
    Zi = zinterp(S.fe,S.Z,size(S.In,1));
    logmsg( 'Finished interpolating Z\n');
    
    logmsg( 'Computing H\n');
    [S.H,S.tH] = z2h(Zi);
    logmsg( 'Finished computing H\n');

    if opts.transferfnFD.loglevel > 0
        logmsg(...
                ['Computing metrics on each segment using stack regression '...
                 'transfer function.\n']);
    end
    S = transferfnMetrics(S,opts);

    if opts.transferfnFD.loglevel > 0
        for c = 1:size(S.Metrics.PE, 2)
            for s = 1:size(S.Metrics.PE, 3)
                logmsg( ...
                        'Output col %d, segment %d: PE/CC/MSE = %.2f/%.2f/%.3f\n',...
                         c,...
                         s,...
                         S.Metrics.PE(1,c,s),...
                         S.Metrics.CC(1,c,s),...
                         S.Metrics.MSE(1,c,s));
            end
        end
        logmsg(...
                ['Finished computing metrics on each segment using stack regression '...
                 'transfer function.\n']);
    end

end

function S = combineStructs(S1,S2,dim)
%combineStructs Combine transferfnFD structures
    
    S = struct();    
    fns = fieldnames(S1);
    for i = 1:length(fns)
        if strcmp(fns{i},'Options')
            continue;
        end
        if isstruct(S1.(fns{i}))
            S.(fns{i}) = combineStructs(S1.(fns{i}),S2.(fns{i}),dim);
        else
            if (dim == 2 && strcmp(fns{i},'In')) || strcmp(fns{i},'fe')
                S.(fns{i}) = S1.(fns{i});
            else
                S.(fns{i}) = cat(dim,S1.(fns{i}),S2.(fns{i}));
            end
        end
    end

end