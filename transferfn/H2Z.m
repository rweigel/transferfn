function [Z,f] = H2Z(H)
%H2Z - Compute frequency domain transfer function from impulse response
%
%  [Z,f] = H2Z(H) returns Z for frequencies in range fu, where
%  [~,fu] = fftfreq(size(H,1)).
%
%  See also Z2H.

addpath([fileparts(mfilename('fullpath')),'/../fft']);

Z = fft(H);
N = size(H,1);

[~,f] = fftfreq(N);
Z = Z(1:length(f),:);
