function hplot(S1,S2,xl)

figprep();

if nargin < 2
    xl = [];
    S2 = [];
end
if nargin == 2 && ~isstruct(S2)
    xl = S2;
end

S1 = tflab_metadata(S1);

Hstrs = {'H_{xx}','H_{xy}','H_{yx}','H_{yy}'};

Zi = zinterp(S1.fe,S1.Z,size(S1.In,1));
[H,t] = z2h(Zi);
H = fftshift(H);
t = fftshift(t);

if isstruct(S1) && ~isstruct(S2)
    
    if isempty(xl)
        [a,b] = findss(H);
    else
        a = find(t>=xl(1),1);
        if isempty(a),a = 1;end
        b = find(t>=xl(2),1);
        if isempty(b),b = length(t);end        
    end
    
    if b-a > 20
        plot(t(a:b), H(a:b),'k','marker','.','markersize',5);
    else
        stem(t(a:b),H(a:b),'filled','ko','MarkerSize',5);
        set(gca,'XTick',[t(a):t(b)]);
    end
    
    grid on;box on;hold on;

    unitstr = '';
    if ~isempty(S1.Metadata.outunit)
        unitstr = sprintf('[(%s)/%s]',...
            S1.Metadata.outunit,S1.Metadata.inunit);
        ylabel(unitstr);
    end
    title(S1.Options.description,'FontWeight','Normal');
    legend('$H$', 'Location', 'NorthEast');
    timeunit = '';
    if ~isempty(S1.Metadata.timeunit)
        timeunit = sprintf(' [%s]',S1.Metadata.timeunit);
    end
    xlabel(sprintf('$t$%s', timeunit));
    if ~isempty(xl)
        set(gca(),'XLim',xl);
    end
end

if nargin > 1 && isstruct(S2)
    % Assumes units are the same. TODO: Allow different unit labels.

    H1 = fftshift(S1.H);
    H2 = fftshift(S2.H);

    [a1,b1] = findss(H1);
    [a2,b2] = findss(H2);

    tH1 = fftshift(S1.tH);
    tH2 = fftshift(S2.tH);

    if b1-a1 > 10
        plot(tH1(a1:b1),H1(a1:b1));
    else
        stem(tH1(a1:b1),H1(a1:b1),'ko','MarkerSize',2);    
    end
    grid on;box on;hold on;
    
    if b1-a1 > 10    
        plot(tH2(a2:b2),H2(a2:b2));
    else
        %stem(tH2(a2:b2),H2(a2:b2));
        stem(tH2,H2);
    end

    ylabel(sprintf('[%s/(%s)]', S1.Options.info.inunit, S1.Options.info.outunit));
    legend(['$H$ $\,$ ', S1.Options.description],...
           ['$H$ $\,$ ', S2.Options.description],...
           'Location','NorthEast');
    xlabel(sprintf('$t$ [%s]', S1.Options.info.timeunit));
    if nargin > 2
        set(gca(),'XLim',xl);
    end
end

end

function [a,b] = findss(x, w, t)
    % Find limits above/below which x is "steady state".

    if nargin < 2
        w = 10;
    end
    if nargin < 3
        t = 0.05;
    end
    if length(x) < w
        a = 1;
        b = length(x);
        return;
    end

    % Compute std in non-overlaping windows of length w.
    x = x(1:w*floor(length(x)/w));
    xr = reshape(x,w,round(length(x)/w));
    xs = std(xr);

    % ss start is start of window where this condition true.
    a = w*find(xs/max(xs) > t,1,'first')-w+1;

    % ss end is end of window where this condition is true.
    b = w*find(xs/max(xs) > t,1,'last');
    
    if isempty(a) || isempty(b)
        a = 1;
        b = length(x);
    end
end
