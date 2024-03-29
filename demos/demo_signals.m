function S = demo_signals(stype, opts)
%DEMO_SIGNALS
%
%  S = DEMO_SIGNALS('simple', opts)
%
%  S = DEMO_SIGNALS('powerlaw', opts)
%
%  S = DEMO_SIGNALS('fromH/zpredict()', opts)
%
%  S = DEMO_SIGNALS('fromZ/filter()', opts)

addpath(fullfile(fileparts(mfilename('fullpath')),'..'));
tflab_setpaths();


if strcmp(stype,'simple')

    if nargin < 2
        opts = struct();
        opts.Nt = 1000;
        opts.Z = [1+1j]/sqrt(2);
        opts.k = 10;
        opts.dB = 0;
        opts.dE = 0;
    end

    Nt = opts.Nt;
    Z = opts.Z;

    assert(~(isfield(opts,'f') && isfield(opts,'k')), 'Only k or f may be specified');
    if isfield(opts,'f')
        f = opts.f;
    end
    if isfield(opts,'k')
        k = opts.k;
        f = k/Nt;
    end
    t = (0:Nt-1)';

    % Generate input/output using exact amplitude and phase
    % (A faster and less memory-intensive way to do this is with ifft()
    % on a frequency domain representation of the signals being
    % constructed.)
    for i = 1:length(f)
        B(:,i) = cos(2*pi*f(i)*t);
        E(:,i) = real(Z(i))*cos(2*pi*f(i)*t) - imag(Z(i))*sin(2*pi*f(i)*t);
    end

    S.In  = sum(B,2) + opts.dB*randn(Nt,1);
    S.Out = sum(E,2) + opts.dE*randn(Nt,1);
    S.Z  = Z;
    S.fe = f;

    %S.H = z2h(zinterp(f,Z,N));
    %S.tH = t;
    return
end

if strcmp(stype,'powerlaw')

    % B(t,j,k) = A(j) (f(k).^alpha.B(j)) sin(2*pi*f(k)*t + phase)
    % E(t,j,k) = Z(j)*(f(k).^alpha.Z(k)).*B(t,j,k);

    if nargin < 2
        opts.N = 1000;
        opts.n = 1000;

        opts.A.B = [1];     % Amplitude of Bx
        opts.alpha.B = [1];

        opts.A.dB = [0];
        opts.alpha.dB = [0];

        opts.A.Z = [1];
        opts.alpha.Z = [1];

        opts.A.dE = 0;     % Must be scalar
        opts.alpha.dE = 0; % Must be scalar
    end

    assert(opts.N > 1, 'N > 1 is required');

    % Create signal using N frequencies
    [~,F] = fftfreq(opts.N);

    t = (0:opts.n-1)';
    [~,f] = fftfreq(opts.n);

    % TODO: In the case that n = N, we could create time series by first
    % creating ffts and then inverting ffts. (Analytic formulas also exist
    % for n ~= N).

    if isfield(opts,'keep')
        F = F(opts.keep);
    end

    % Keep only frequencies in range of frequencies in f.
    F = F(F >= f(2) & F <= f(end));

    Ff = repmat(F',length(t),1);
    tf = repmat(t, 1, length(F));
    E = zeros(length(t),length(F));

    for k = 1:length(opts.A.B) % Loop over vector component
        % Give each frequency a random phase
        Phi = 2*pi*rand(1, length(F));
        %Phi = zeros(1, length(F));
        PhiB = repmat(Phi, length(t), 1);

        % PhiB depends on column, not row.
        % Each column in B is a time series with column-dependent freq.
        % Third dimension is component of B.
        B(:,:,k) = opts.A.B(k)*(Ff.^opts.alpha.B(k)).*cos(2*pi*Ff.*tf + PhiB);

        % Add noise to B
        PhidB = 2*pi*rand(1, length(F));
        %PhidB = zeros(1, length(F));
        PhidB = repmat(PhidB, length(t), 1);
        dB(:,:,k) = opts.A.dB(k)*(Ff.^opts.alpha.dB(k)).*cos(2*pi*Ff.*tf + PhidB);

        E = E + opts.A.Z(k)*(Ff.^opts.alpha.Z(k)).*B(:,:,k);
    end

    % Add noise to E
    PhidE = 2*pi*rand(1, length(F));
    PhidE = repmat(PhidE, length(t), 1);
    dE = opts.A.dE.*(Ff.^opts.alpha.dE).*cos(2*pi*Ff.*tf + PhidE);

    E = sum(E,2);
    if dE ~= 0
        S.OutNoise = sum(dE,2);
        E = E + dE;
    end
    for j = 1:size(E,2)
        %E(:,j) = E(:,j)/std(E(:,j));
    end

    B = squeeze(sum(B,2)); % Sum across frequencies
    if dB ~= 0
        S.InNoise = squeeze(sum(dB,2));
        B = B + dB;
    end
    for j = 1:size(B,2)
        %B(:,j) = B(:,j)/std(B(:,j));
    end

    % Compute exact Z at n frequencies
    for k = 1:length(opts.A.B)
        Z(:,k) = opts.A.Z(k)*(f.^opts.alpha.Z(k));%*(cos(Phi(i)) + sqrt(-1)*sin(Phi(i)));
    end

    S.In  = B;
    S.Out = E;
    S.Z  = Z;
    S.fe = f;
    S.H = z2h(zinterp(f,Z,opts.n));
    S.tH = (0:opts.n-1)';
    return
end

if strcmp(stype,'fromH/zpredict()')

    assert(nargin == 2,'Two inputs are required');

    N = opts.N;
    [~,f] = fftfreq(N);
    H = opts.H;
    f = f';
    z = freqz(opts.H,1,f,1);
    Z = zinterp(f,z,opts.N);

    rng(1);
    B = randn(opts.N,1);
    E = zpredict(Z,B);

    S.In  = B;
    S.Out = E;
    S.Z  = z;
    S.fe = f;
    S.H = opts.H;
    S.tH = (0:size(opts.H,1)-1)';
    return
end

if strcmp(stype,'fromH/filter()')

    assert(nargin == 2,'Two inputs are required');

    H = opts.H;
    N = opts.N;

    B = randn(opts.N+length(H),1);
    E = filter(H,1,B);

    % Remove non-steady-state
    B = B(length(H)+1:end);
    E = E(length(H)+1:end);

    S.In  = B;
    S.Out = E;
end

if strcmp(stype,'fromlowpassH')

    assert(nargin == 2,'Two inputs are required');

    % Low pass filter impulse responses

    ndim = opts;

    description = '';

    tau  = 10;  % Filter decay constant
    Ntau = 100; % Number of filter coefficients = Ntau*tau + 1
    N    = 2e4; % Simulation length
    nR   = 2;   % Width of rectangualar window is 2*nR+1
    Nss  = 4;   % Will remove Nss*Ntau*tau from start of all time series
    nb   = 0.0; % Noise in B
    ne   = 0.0; % Noise in E
    ndb  = 0.0; % Noise in dB

    % IRF for dx/dt + x/\tau = delta(0), and ICs x(t=0) = 0; dx/dt|_{t=0} = 0
    % approximated using forward Euler.
    dt = 1;
    gamma = (1-dt/tau);
    for i = 1:Ntau*tau
        h(i,1) = gamma^(i-1);
        t(i,1) = dt*(i-1);
    end
    hstr = sprintf('(1-1/%d)^{t}; t=1 ... %d; h_{xy}(0)=0;', tau, length(h));
    % Add a zero because MATLAB filter function requires it.
    % (Not having it also causes phase drift with frequency.)
    h  = [0;h];            % Exact IRF

    % Add extra values so length is same after cutting off non-steady state
    % part of E and B.
    N = N + Nss*length(h);

    % Noise
    NE  = [ne*randn(N,1),ne*randn(N,1)];
    NB  = [nb*randn(N,1),nb*randn(N,1)];
    NdB = [ndb*randn(N,1),ndb*randn(N,1)];

    % Create signals
    if ndim == 1
        H(:,1) = h;
        B(:,1) = randn(N,1);
        E(:,1) = NE(:,1) + filter(H(:,1),1,B(:,1) + NB(:,1));
    end
    if ndim == 2
        H = zeros(length(h),ndim);
        if tn == 1 % Doing all equal will lead to rank deficient warnings.
            H(:,1) = 0.1*h;
            H(:,2) = 0.2*h;
        end
        if tn == 2
            H(:,1) = 0*h;
            H(:,2) = h;
        end
        B(:,1) = randn(N,1);
        B(:,2) = randn(N,1);
        E(:,1) = NE(:,1) + ...
                    + filter(H(:,1),1,B(:,1) + NB(:,1)) ...
                    + filter(H(:,2),1,B(:,2) + NB(:,2));
    end
    if ndim == 4
        H = zeros(length(h),ndim);
        if tn == 1
            % Doing all equal will lead to rank deficient warnings.
            H(:,1) = 0.1*h;
            H(:,2) = 0.2*h;
            H(:,1) = 0.3*h;
            H(:,2) = 0.4*h;
        end
        if tn == 2
            % Need to explain why Zxx and Zyy are not zero for this case.
            H(:,1) = 0*h;
            H(:,2) = h;
            H(:,3) = 0*h;
            H(:,4) = h;
        end
        B(:,1) = randn(N,1);
        B(:,2) = randn(N,1);
        E(:,1) = NE(:,1) + filter(H(:,1),1,B(:,1) + NB(:,1)) ...
                         + filter(H(:,2),1,B(:,2) + NB(:,2));
        E(:,2) = NE(:,2) + filter(H(:,3),1,B(:,1) + NB(:,1)) ...
                         + filter(H(:,4),1,B(:,2) + NB(:,2));
    end

    % Remove non-steady-state part of signals
    B  = B(Nss*length(h)+1:end,:);
    E  = E(Nss*length(h)+1:end,:);

    NE  = NE(Nss*length(h)+1:end,:);
    NB  = NB(Nss*length(h)+1:end,:);

end
