function ris_visualizer_and_simulator()
% RIS_VISUALIZER_AND_SIMULATOR
% Combined GUI for editing 16x16 RIS patterns and simulating their effect
% on a 5G downlink waveform. Click "Load Excel" to load patterns (col 2
% by default). Toggle cells by clicking. Click "Simulate" to run the
% waveform generation + RIS reflection using current matrix.
%
% Run: >> ris_visualizer_and_simulator

%% --- Configuration ---
defaultExcelCol = 2;   % change if patterns are in a different column
figW = 1100; figH = 620;

%% --- App Data / State ---
state.patternsHex = {};   % cell array of 64-hex strings
state.matrices = {};      % cell array of 16x16 numeric matrices (0/1)
state.currIdx = 1;
state.filename = '';

%% --- Build UI ---
hFig = figure('Name','RIS 16x16 Visualizer + Simulator','NumberTitle','off',...
    'MenuBar','none','ToolBar','none','Position',[200 120 figW figH]);

% Left: axes for grid
ax = axes('Parent',hFig,'Units','pixels','Position',[30 60 520 520]);
axis(ax,'equal','off');
title(ax,'RIS 16 \times 16');

% Panel for controls on right
uicontrol('Style','pushbutton','Parent',hFig,'String','Load Excel',...
    'Position',[580 520 160 40],'Callback',@onLoad);

uicontrol('Style','pushbutton','Parent',hFig,'String','Prev','Position',[580 470 75 30],...
    'Callback',@onPrev);
uicontrol('Style','pushbutton','Parent',hFig,'String','Next','Position',[665 470 75 30],...
    'Callback',@onNext);

uicontrol('Style','text','Parent',hFig,'String','Pattern #','Position',[580 430 60 20],'HorizontalAlignment','left');
hIndex = uicontrol('Style','edit','Parent',hFig,'String','1','Position',[640 430 80 24],'Callback',@onIndexEdit);

uicontrol('Style','pushbutton','Parent',hFig,'String','Go','Position',[740 430 60 24],'Callback',@onGo);

uicontrol('Style','text','Parent',hFig,'String','Pattern slider','Position',[580 395 80 20],'HorizontalAlignment','left');
hSlider = uicontrol('Style','slider','Parent',hFig,'Min',1,'Max',1,'Value',1,'SliderStep',[1 1],...
    'Position',[580 370 220 20],'Callback',@onSlider);

% Hex display
uicontrol('Style','text','Parent',hFig,'String','Current 64-hex (editable)','Position',[580 335 200 18],'HorizontalAlignment','left');
hHexEdit = uicontrol('Style','edit','Parent',hFig,'String','','Position',[580 300 220 34],'Max',2,'HorizontalAlignment','left','Callback',@onHexEdit);

% Save button
uicontrol('Style','pushbutton','Parent',hFig,'String','Save current to Excel','Position',[580 260 220 30],'Callback',@onSave);

% Simulation controls
uicontrol('Style','text','Parent',hFig,'String','Simulation','FontWeight','bold','Position',[580 220 200 18],'HorizontalAlignment','left');
uicontrol('Style','pushbutton','Parent',hFig,'String','Simulate (Run)','Position',[580 190 220 36],'Callback',@onSimulate);

% Export / Assign to base
uicontrol('Style','pushbutton','Parent',hFig,'String','Export current to workspace','Position',[580 150 220 30],'Callback',@onExportWorkspace);

% Info text
hInfo = uicontrol('Style','text','Parent',hFig,'String','No file loaded.','Position',[580 110 500 30],'HorizontalAlignment','left');

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
            if ~isempty(raw{k})
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
                % skip
                continue;
            end
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

    function onHexEdit(src,~)
        app = guidata(hFig);
        s = cleanHex(get(src,'String'));
        if strlength(s) ~= 64
            set(hInfo,'String','Hex must be exactly 64 hex characters after cleaning.');
            return;
        end
        % update matrix & state
        mat = hex64ToMatrix16(char(s));
        app.state.matrices{app.state.currIdx} = mat;
        app.state.patternsHex{app.state.currIdx} = char(s);
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
            outTable = table(app.state.patternsHex,'VariableNames',{'Pattern64Hex'});
            writetable(outTable,outname,'Sheet',1);
            set(hInfo,'String',sprintf('Saved %d patterns to %s',numel(app.state.patternsHex),outname));
        catch ME
            set(hInfo,'String',['Error saving file: ' ME.message]);
        end
    end

    function onExportWorkspace(~,~)
        app = guidata(hFig);
        if isempty(app.state.matrices), set(hInfo,'String','No matrix to export.'); return; end
        mat = app.state.matrices{app.state.currIdx};
        assignin('base','currentRISMatrix',mat);
        set(hInfo,'String','Exported currentRISMatrix to workspace.');
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

    function onSimulate(~,~)
        % Main simulate callback: reads current matrix, forms RIS, waveform,
        % computes H_RIS and applies it to waveform, and plots results.
        app = guidata(hFig);
        if isempty(app.state.matrices)
            set(hInfo,'String','No pattern loaded for simulation.');
            return;
        end
        mat_RIS = app.state.matrices{app.state.currIdx}; % 16x16 of 0/1
        assignin('base','currentRISMatrix',mat_RIS); % convenience

        set(hInfo,'String','Simulating... (this may take a few seconds)');

        try
            %% ----- RIS / geometry params -----
            fc = 3.5e9;
            c = 3e8;
            lamda = c/fc;
            Nr = 16; Nc = 16;
            dx = 0.5*lamda;
            dy = 0.5*lamda;
            W = 0.026;       % Patch width  (26 mm)
            L = 0.026;       % Patch length (26 mm)
            h = 4 * 0.0032;  % Total PCB thickness (12.8 mm)
            
            % --- Substrate (single-layer equivalent of 4 layers) ---
            sub = dielectric( ...
                "Name", "FR4", ...
                "EpsilonR", 4.4, ...
                "LossTangent", 0.01, ...
                "Thickness", h );
            
            % --- Valid Feed Position (must use FeedOffset) ---
            feedOffset = [W/4, 0];   % 6.5 mm from center (inside patch)
            
            % --- Patch Microstrip Element ---
            elem = patchMicrostrip( ...
                "Length", L, ...
                "Width",  W, ...
                "Height", h, ...                      
                "Substrate", sub, ...
                "GroundPlaneLength", 0.05, ...
                "GroundPlaneWidth",  0.05, ...
                "FeedOffset", feedOffset );          
            


            risArray = phased.URA('Element',elem,'Size',[Nr Nc],'ElementSpacing',[dx dy]);

            % positions in meters (Nx3)
            pos = getElementPosition(risArray).'; % returns 3xN -> Tx/Rx steering uses this

            %% ----- Geometry (gNB, RIS, UE) -----
            % Generic geometry: gNB and UE placed relative to RIS at known az/el
            gNB_pos = [10; 0; 0];
            azimuth_deg = 30; % place UE at some azimuth
            UE_pos = [10*cosd(azimuth_deg); 10*sind(azimuth_deg); 0];
            RIS_pos = [0;0;0];

            vec_tx_ris = RIS_pos - gNB_pos;
            [az_tx_ris, el_tx_ris, ~] = cart2sph(vec_tx_ris(1), vec_tx_ris(2), vec_tx_ris(3));
            az_tx_ris = rad2deg(az_tx_ris); el_tx_ris = rad2deg(el_tx_ris);

            vec_ris_ue = UE_pos - RIS_pos;
            [az_ris_ue, el_ris_ue, ~] = cart2sph(vec_ris_ue(1), vec_ris_ue(2), vec_ris_ue(3));
            az_ris_ue = rad2deg(az_ris_ue); el_ris_ue = rad2deg(el_ris_ue);

            %% ----- RIS phase mask -----
            % map mat_RIS (16x16) to phase: 1 -> pi, 0 -> 0
            phi = pi * mat_RIS;                 % rows=1..16 top->bottom, cols=1..16 left->right
            mask = exp(1j * phi);               % complex mask matrix

            % reshape mask into column-major vector matching sensor ordering:
            % The phased.URA element ordering is column-major (IIRC) but to be safe
            % use reshape consistent with earlier helper functions (we used col-major there):
            mask_vec = reshape(mask, [], 1);    % 256x1 complex vector

            %% ----- Steering vectors -----
            % use phased.SteeringVector with our array
            sv = phased.SteeringVector('SensorArray',risArray,'PropagationSpeed',c,'IncludeElementResponse',true);
            a_tx = sv(fc,[az_tx_ris; el_tx_ris]);   % Nx1 vector gNB->RIS
            a_rx = sv(fc,[az_ris_ue; el_ris_ue]);   % Nx1 vector RIS->UE

            % Composite RIS response scalar (1x1)
            % H_RIS = a_rx.' * diag(mask_vec) * a_tx  -> create scalar
            H_RIS = (a_rx.' * (mask_vec .* a_tx)); % elementwise multiply then sum => same as diag* vec

            % Normalize for plotting convenience
            H_RIS = H_RIS / max(abs(H_RIS));

            %% ----- Waveform generation (your nrWaveformGenerator config) -----
            waveconfig=nrDLCarrierConfig;
            waveconfig.Label='DL Carrier 1';
            waveconfig.ChannelBandwidth=50;
            waveconfig.FrequencyRange = 'FR1';
            waveconfig.NumSubframes = 2;    % keep short for quick sim
            waveconfig.SampleRate =53.76e6;
            waveconfig.CarrierFrequency = fc;

            scscarrier = nrSCSCarrierConfig;
            scscarrier.SubcarrierSpacing = 30;
            scscarrier.NSizeGrid = 132;
            scscarrier.NStartGrid =0;

            bwp=nrWavegenBWPConfig;
            bwp.BandwidthPartID=1;
            bwp.Label='BWP of scs 30kHz';
            bwp.SubcarrierSpacing=30;
            bwp.CyclicPrefix='Normal';
            bwp.NStartBWP=0;

            ssburst = nrWavegenSSBurstConfig;
            ssburst.Enable = 1;
            ssburst.Power = 0;
            ssburst.BlockPattern = 'Case B';
            ssburst.TransmittedBlocks = [1 1 1 1];
            ssburst.Period = 20;
            ssburst.NCRBSSB = [];

            pdsch=nrWavegenPDSCHConfig;
            pdsch.Enable = 1;
            pdsch.Label = 'UE 1 - PDSCH @ 30 kHz';
            pdsch.BandwidthPartID=1;
            pdsch.Power=0;
            pdsch.Coding=1;
            pdsch.DataSource = 'PN9';
            pdsch.TargetCodeRate = 0.4785;
            pdsch.XOverhead = 0;
            pdsch.Modulation = '16QAM';
            pdsch.NumLayers = 1;
            pdsch.SymbolAllocation = [2 9];
            pdsch.SlotAllocation = 0:19;
            pdsch.Period = 30;
            pdsch.PRBSet = [0:5, 10:20 , 30:45];
            pdsch.RNTI = 11;
            pdsch.NID = 1;
            pdsch.MappingType = 'A';
            pdsch.DMRSPower = 0;
            pdsch.DMRS.DMRSConfigurationType = 2;
            pdsch.DMRS.NumCDMGroupsWithoutData = 1;
            pdsch.DMRS.DMRSPortSet = [];
            pdsch.DMRS.DMRSTypeAPosition = 2;
            pdsch.DMRS.DMRSLength = 1;
            pdsch.DMRS.DMRSAdditionalPosition = 0;
            pdsch.DMRS.NIDNSCID = 1;
            pdsch.DMRS.NSCID = 0;

            waveconfig.SSBurst = ssburst;
            waveconfig.SCSCarriers = {scscarrier};
            waveconfig.BandwidthParts ={bwp};
            waveconfig.PDSCH ={pdsch};

            [waveform,info] = nrWaveformGenerator(waveconfig);

            % Choose first antenna (single-stream)
            tx_wave = waveform(:,1);

            %% ----- Apply RIS response -----
            % For this simple model we scale the entire baseband by scalar H_RIS.
            rx_wave_after = tx_wave * H_RIS;

            %% ----- Plots: before/after + spectrograms -----
            f1 = figure('Name','Waveform Before & After RIS','NumberTitle','off','Position',[100 100 1000 600]);
            subplot(2,2,1);
            plot(abs(tx_wave));
            title('Magnitude of Tx Waveform (before RIS)');
            xlabel('Sample'); ylabel('Magnitude');

            subplot(2,2,2);
            plot(abs(rx_wave_after));
            title('Magnitude after RIS (scaled by H\_RIS)');
            xlabel('Sample'); ylabel('Magnitude');

            subplot(2,2,3);
            samplerate = info.ResourceGrids(1).Info.SampleRate;
            nfft = info.ResourceGrids(1).Info.Nfft;
            spectrogram(tx_wave,ones(nfft,1),0,nfft,'centered',samplerate,'yaxis','MinThreshold',-130);
            title('Spectrogram - before RIS');

            subplot(2,2,4);
            spectrogram(rx_wave_after,ones(nfft,1),0,nfft,'centered',samplerate,'yaxis','MinThreshold',-130);
            title('Spectrogram - after RIS');

            % Also display H_RIS magnitude and phase
            figure('Name','H\_RIS (composite)','NumberTitle','off');
            subplot(2,1,1); stem(abs(H_RIS)); ylabel('|H\_RIS|'); title('Composite RIS response magnitude (scalar normalized)');
            subplot(2,1,2); stem(angle(H_RIS)); ylabel('phase(H\_RIS)'); xlabel('index'); title('phase (rad)');

            set(hInfo,'String',sprintf('Simulation complete. |H_RIS|=%.3f, angle=%.3f rad',abs(H_RIS),angle(H_RIS)));
        catch ME
            set(hInfo,'String',['Simulation error: ' ME.message]);
            rethrow(ME);
        end
    end

end

%% Functions for patterns in GUI

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
    val = hex2dec(nib);
    bits = dec2bin(val,16); % string length 16
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
    binstr = sprintf('%d',bits);
    val = bin2dec(binstr);
    parts(col) = dec2hex(val,4); % 4 hex chars
end
hex64 = strjoin(parts,'');
hex64 = char(upper(hex64));
end
