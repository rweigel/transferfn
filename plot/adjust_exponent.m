function adjust_exponent(direction,force)
%ADJUST_EXPONENT - Relabel axes number with exponents
%
%  ADJUST_EXPONENT() Relabels x, y, and z labels
%
%  ADJUST_EXPONENT(s) Relabels s labels only, where s = 'x',
%  'y', or 'z'.
%
%  On log axes, relabels
%     10^{-1} to 0.1
%     10^{0} to 1
%     10^{1} to 10
%     10^{2} to 100
%
%  On linear axes, removes an offsetted x10^{N} if it appears near last
%  axis label and makes it not offset and uses a center dot instead of and
%  x.
%

if nargin < 2
    force = 0; 
    % For use if algorthim for detecting offsetted x10^{N} does not catch
    % all cases.
end

if nargin == 0
    adjust_exponent('x');
    adjust_exponent('y');
    adjust_exponent('z');
    return;
end

assert(any(strcmp(direction,{'x','y','z'})),'dir must be x, y, or z');

drawnow;

% Relabel 10^{-1} to 0.1, 10^{0} to 1, 10^{1} to 10, and 10^{2} to 100.
if strcmp(get(gca, [direction,'Scale']), 'log')
    labels = get(gca, [direction,'TickLabel']);
    if isempty(labels)
        return;
    end
    for i = 1:length(labels)
        if strcmp(labels{i},'10^{-1}')
            labels{i} = '0.1';
        end
        if strcmp(labels{i},'$10^{-1}$')
            labels{i} = '$0.1$';
        end
        if strcmp(labels{i},'10^{0}')
            labels{i} = '1';
        end
        if strcmp(labels{i},'$10^{0}$')
            labels{i} = '$1$';
        end
        if strcmp(labels{i},'10^{1}')
            labels{i} = '10';
        end
        if strcmp(labels{i},'$10^{1}$')
            labels{i} = '$10$';
        end
        if strcmp(labels{i},'10^{2}')
            labels{i} = '100';
        end
        if strcmp(labels{i},'$10^{2}$')
            labels{i} = '$100$';
        end
    end
    set(gca,[direction,'TickLabel'],labels);
end

% Remove the offsetted x10^{N} notation that appears on last axis label
% and add it to the last label.
if strcmp(get(gca, [direction,'Scale']),'linear')
    labels = get(gca,[direction,'TickLabel'])
    ticks = get(gca, [direction,'Tick'])
    if isempty(labels)
        return;
    end
    if force || ticks(end) > 1000 % Check 1
        % There does not seem to be a direct way of determining if the
        % offset notation is used, so Check 1 and Check 2 are used.

        if ~iscell(labels)
            for i = 1:length(ticks)
                labelsc{i} = labels(i,:);
            end
            labels = labelsc;
        end
        if force || ticks(end) < 10*str2double(labels{end})
            % Check 2.
            % E.g., ticks(end) = 2000 and labels{end} = '2';
            return;
        end
        
        labels
        for i = 1:length(ticks)-1
            labels_new{i} = sprintf('%s',labels{i});
        end
        labels_new{i+1} = sprintf('%s$\\cdot 10^{3}$',labels{i+1});
        %set(gca,[dir,'TickLabel'],labels_new);
        labels_new
        set(gca, [direction,'TickLabel'], labels_new);
    end
end
