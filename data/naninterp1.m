function X = naninterp1(X,varargin)
%NANINTERP1 - Columnwise interpolation over NaNs
%
%   NANINTERP1(X,varargin) interpolates over NaNs in X columnwise using
%   INTERP1(X(:,j),varargin) for each j.
%
%   See also TRIMNANS, INTERP1.

if nargin < 2
    varargin = {};
end

In = sum(isnan(X));
if isempty(In)
    % No NaNs; nothing to do.
    logmsg('No NaNs.\n');
    return;
end

for c = 1:size(X,2)
    xq = (1:size(X,1))';
    Ig = ~isnan(X(:,c));
    X(:,c) = interp1(xq(Ig),X(Ig,c),xq,varargin{:});
    N = size(X,1)-sum(Ig);
    p = 100*N/size(X,1);
    logmsg('Interpolated over %d of %d points (%.3f%%) in column %d\n',...
            N,size(X,1),p,c);
end
    