function ris16x16_visualizer()
% RIS16x16_VISUALIZER
% Simple interactive GUI to load 64-hex RIS patterns from Excel (col 2 by default),
% visualize 16x16 RIS element ON/OFF as a grid, step through patterns, toggle cells,
% and save edited patterns back to Excel.
%
% Usage: run the file in MATLAB: >> ris16x16_visualizer

%% --- Configuration ---
defaultExcelCol = 2;   % change if patterns are in a different column
figW = 900; figH = 560;

%% --- App Data / State ---
state.patternsHex = {};   % cell array of 64-hex strings
state.matrices = {};      % cell array of 16x16 numeric matrices (0/1)
state.currIdx = 1;
state.filename = '';

%% --- Build UI ---
hFig = figure('Name','RIS 16x16 Visualizer','NumberTitle','off',...
    'MenuBar','none','ToolBar','none','Position',[200 150 figW figH]);

% Left: axes for grid
ax = axes('Parent',hFig,'Units','pixels','Position',[30 110 520 520]);
axis(ax,'equal','off');
title(ax,'RIS 16 \times 16');

% Panel for controls on right
uicontrol('Style','pushbutton','Parent',hFig,'String','Load Excel',...
    'Position',[580 480 140 35],'Callback',@onLoad);

uicontrol('Style','pushbutton','Parent',hFig,'String','Prev','Position',[580 430 65 30],...
    'Callback',@onPrev);
uicontrol('Style','pushbutton','Parent',hFig,'String','Next','Position',[655 430 65 30],...
    'Callback',@onNext);

uicontrol('Style','text','Parent',hFig,'String','Pattern #','Position',[580 390 60 20],'HorizontalAlignment','left');
hIndex = uicontrol('Style','edit','Parent',hFig,'String','1','Position',[640 390 80 24],'Callback',@onIndexEdit);

uicontrol('Style','text','Parent',hFig,'String','Go to index','Position',[580 360 60 20],'HorizontalAlignment','left');
hGo = uicontrol('Style','pushbutton','Parent',hFig,'String','Go','Position',[740 390 60 24],'Callback',@onGo);

uicontrol('Style','text','Parent',hFig,'String','Pattern slider','Position',[580 320 80 20],'HorizontalAlignment','left');
hSlider = uicontrol('Style','slider','Parent',hFig,'Min',1,'Max',1,'Value',1,'SliderStep',[1 1],...
    'Position',[580 300 220 20],'Callback',@onSlider);

% Hex display
uicontrol('Style','text','Parent',hFig,'String','Current 64-hex (editable)','Position',[580 260 200 18],'HorizontalAlignment','left');
hHexEdit = uicontrol('Style','edit','Parent',hFig,'String','','Position',[580 230 220 28],'Max',2,'HorizontalAlignment','left');

% Save button
uicontrol('Style','pushbutton','Parent',hFig,'String','Save current to Excel','Position',[580 190 220 30],'Callback',@onSave);

% Info text
hInfo = uicontrol('Style','text','Parent',hFig,'String','No file loaded.','Position',[580 150 300 30],'HorizontalAlignment','left');

% Precreate patch objects (16x16)
cellSize = 1;
pad = 0.02;
rectHandles = gobjects(16,16);
hold(ax,'on');
xlim(ax,[0 16]);
ylim(ax,[0 16]);
for r = 1:16
    for c = 1:16
        % Draw a square (use patch so clickable)
        x = c-1; y = 16-r; % top row r=1 at y=15
        px = [x+pad x+1-pad x+1-pad x+pad];
        py = [y+pad y+pad y+1-pad y+1-pad];
        rectHandles(r,c) = patch('XData',px,'YData',py,'FaceColor','white',...
            'EdgeColor',[0.8 0.8 0.8],'Parent',ax,'ButtonDownFcn',@onCellClick);
    end
end
hold(ax,'off');

% store handles in guidata-like struct
app.handles = struct('fig',hFig,'ax',ax,'rects',rectHandles,'hHexEdit',hHexEdit,...
    'hIndex',hIndex,'hSlider',hSlider,'hInfo',hInfo);
app.state = state;
guidata(hFig,app);

%% --- Callback & Helper functions ---

    function onLoad(~,~)
        [file, path] = uigetfile({'*.xlsx;*.xls','Excel files (*.xlsx,*.xls)'}, 'Select Excel file with 64-hex patterns');
        if isequal(file,0), return; end
        full = fullfile(path,file);
        try
            T = readcell(full,'Sheet',1);
        catch ME
            set(hInfo,'String',['Error reading file: ' ME.message]);
            return;
        end
        % Default: take column 2 (user said patterns in column 2).
        if size(T,2) < defaultExcelCol
            set(hInfo,'String','Excel file has fewer columns than expected.');
            return;
        end
        raw = T(:,defaultExcelCol);
        % Filter non-empty and convert to strings
        patterns = {};
        for k = 1:numel(raw)
            if ~isempty(raw{k}) && ~(isstring(raw{k}) || ischar(raw{k}) && all(isstrprop(raw{k}, 'alpha') | isstrprop(raw{k}, 'digit')))

                s = string(raw{k});
                s = strtrim(s);
                if strlength(s)>0
                    patterns{end+1,1} = char(s); %#ok<AGROW>
                end
            end
        end
        if isempty(patterns)
            set(hInfo,'String','No patterns found in selected column.');
            return;
        end
        % Clean and validate each pattern, convert to matrix
        matrices = {};
        cleaned = {};
        for k = 1:numel(patterns)
            s = cleanHex(patterns{k});
            if strlength(s) ~= 64
                % skip or try to pad? we skip (but keep user informed)
                set(hInfo,'String',sprintf('Skipping entry %d (not 64 hex chars).',k));
                continue;
            end
            % store
            cleaned{end+1,1} = char(s); %#ok<AGROW>
            matrices{end+1,1} = hex64ToMatrix16(char(s));
        end
        if isempty(matrices)
            set(hInfo,'String','No valid 64-hex patterns after cleaning.');
            return;
        end
        app = guidata(hFig);
        app.state.patternsHex = cleaned;
        app.state.matrices = matrices;
        app.state.currIdx = 1;
        app.state.filename = full;
        % update slider range
        set(app.handles.hSlider,'Min',1,'Max',numel(matrices),'Value',1,'SliderStep',[1/(max(1,numel(matrices)-1)) 10/(max(1,numel(matrices)-1))]);
        set(app.handles.hIndex,'String','1');
        guidata(hFig,app);
        updateDisplay();
        set(hInfo,'String',sprintf('Loaded %d patterns from %s (col %d).',numel(matrices),file,defaultExcelCol));
    end

    function onPrev(~,~)
        app = guidata(hFig);
        if isempty(app.state.matrices), return; end
        app.state.currIdx = max(1,app.state.currIdx-1);
        set(app.handles.hSlider,'Value',app.state.currIdx);
        set(app.handles.hIndex,'String',num2str(app.state.currIdx));
        guidata(hFig,app);
        updateDisplay();
    end

    function onNext(~,~)
        app = guidata(hFig);
        if isempty(app.state.matrices), return; end
        app.state.currIdx = min(numel(app.state.matrices), app.state.currIdx+1);
        set(app.handles.hSlider,'Value',app.state.currIdx);
        set(app.handles.hIndex,'String',num2str(app.state.currIdx));
        guidata(hFig,app);
        updateDisplay();
    end

    function onIndexEdit(src,~)
        val = str2double(get(src,'String'));
        if isnan(val), set(hInfo,'String','Invalid index'); return; end
        app = guidata(hFig);
        n = numel(app.state.matrices);
        val = round(val);
        val = max(1,min(n,val));
        app.state.currIdx = val;
        set(app.handles.hSlider,'Value',val);
        set(app.handles.hIndex,'String',num2str(val));
        guidata(hFig,app);
        updateDisplay();
    end

    function onGo(~,~)
        onIndexEdit(app.handles.hIndex);
    end

    function onSlider(src,~)
        val = round(get(src,'Value'));
        app = guidata(hFig);
        app.state.currIdx = val;
        set(app.handles.hIndex,'String',num2str(val));
        guidata(hFig,app);
        updateDisplay();
    end

    function onCellClick(src,~)
        % toggle cell under click
        app = guidata(hFig);
        if isempty(app.state.matrices), return; end
        % find r,c of clicked patch
        [r,c] = find(app.handles.rects == src);
        if isempty(r), return; end
        mat = app.state.matrices{app.state.currIdx};
        mat(r,c) = 1 - mat(r,c);
        app.state.matrices{app.state.currIdx} = mat;
        % update hex edit to reflect change
        newHex = matrix16ToHex64(mat);
        app.state.patternsHex{app.state.currIdx} = newHex;
        set(app.handles.hHexEdit,'String',newHex);
        guidata(hFig,app);
        refreshGrid(mat);
    end

    function onSave(~,~)
        app = guidata(hFig);
        if isempty(app.state.matrices) || isempty(app.state.filename)
            set(hInfo,'String','No patterns loaded to save.');
            return;
        end
        [pathstr,name,ext] = fileparts(app.state.filename);
        outname = fullfile(pathstr, [name '_edited.xlsx']);
        try
            % write patterns back into column 2 (as originally), one per row
            outTable = table(app.state.patternsHex,'VariableNames',{'Pattern64Hex'});
            % If you prefer to keep original structure, more advanced writes can be done.
            writetable(outTable,outname,'Sheet',1);
            set(hInfo,'String',sprintf('Saved %d patterns to %s',numel(app.state.patternsHex),outname));
        catch ME
            set(hInfo,'String',['Error saving file: ' ME.message]);
        end
    end

    function updateDisplay()
        app = guidata(hFig);
        idx = app.state.currIdx;
        mat = app.state.matrices{idx};
        refreshGrid(mat);
        set(app.handles.hHexEdit,'String',app.state.patternsHex{idx});
        set(app.handles.hIndex,'String',num2str(idx));
        set(app.handles.hSlider,'Value',idx);
    end

    function refreshGrid(mat)
        app = guidata(hFig);
        for rr = 1:16
            for cc = 1:16
                if mat(rr,cc)==1
                    set(app.handles.rects(rr,cc),'FaceColor','green');
                else
                    set(app.handles.rects(rr,cc),'FaceColor','white');
                end
            end
        end
        drawnow;
    end

end

%% --- Helper subfunctions (outside main nested functions) ---

function s = cleanHex(raw)
% Accept various formats: with !, 0x, 0X, spaces, lower/upper. Return uppercase no prefix.
if isempty(raw)
    s = '';
    return;
end
s = char(raw);
s = strtrim(s);
% remove leading '!' or '0x' or '0X'
if startsWith(s,'!')
    s = s(2:end);
end
if (length(s)>1) && (strcmpi(s(1:2),'0X'))
    s = s(3:end);
end
% remove spaces
s(s==' ') = [];
s = upper(s);
end

function M = hex64ToMatrix16(hex64)
% hex64 is 64-char string representing 16 nibbles of 4 hex chars each -> each column 16 bits.
% Returns 16x16 numeric matrix where rows 1..16 correspond to top..bottom
if length(hex64) ~= 64
    error('hex64 must be length 64');
end
M = zeros(16,16);
for col = 1:16
    nib = hex64((col-1)*4 + (1:4));
    % nib is 4 hex chars -> 16-bit column
    val = hex2dec(nib);
    bits = dec2bin(val,16); % string length 16
    % bits(1) is MSB -> assign to row 1
    for row = 1:16
        M(row,col) = str2double(bits(row));
    end
end
end

function hex64 = matrix16ToHex64(M)
% Convert 16x16 matrix into 64-char hex string in same col-major nibble format
if ~isequal(size(M),[16 16])
    error('Matrix must be 16x16');
end
parts = strings(1,16);
for col = 1:16
    bits = M(:,col)';
    % bits is 1x16 array with row1 = MSB
    binstr = sprintf('%d',bits);
    val = bin2dec(binstr);
    parts(col) = dec2hex(val,4); % 4 hex chars
end
hex64 = strjoin(parts,'');
hex64 = char(upper(hex64));
end
