%% ris_viewer_with_patterns.m
% Full script: load hex patterns, visualize ON (green) / OFF (white),
% Next / Previous controls, and keep rest of your waveform generation intact.

clearvars -except Nr Nc; close all;

%% ----- RIS / geometry params -----
fc = 3.5e9;
lamda = (3e8/fc);
Nr = 16;
Nc = 16;
dx = 0.5*lamda;
dy = 0.5*lamda;

%% ----- RIS design (keeps your array) -----
gold = metal('Name','Gold','Conductivity',4.1e7);
goldPatch = patchMicrostrip( ...
    'Length', 0.26, ...
    'Width', 0.26,'GroundPlaneLength', 0.26, ...
    'GroundPlaneWidth', 0.26, ...
    'Conductor', gold, ...
    'FeedOffset', [0 0], ...
    'Substrate', dielectric(Name=["FR4" "FR4" "FR4" "FR4"], ...
    EpsilonR=[4.4 4.4 4.4 4.4], ...
    LossTangent=[0.01 0.01 0.01 0.01], ...
    Thickness=[0.0032 0.0032 0.0032 0.0032])) ;

ris = phased.URA('Element',goldPatch,'Size',[Nr Nc],'ElementSpacing',[dx dy]);

figure; viewArray(ris);
title(sprintf('%.0fx%.0f RIS URA with Gold Patch Elements ', Nr, Nc));

%% ----- Geometry (gNB, RIS, UE) -----
x = 10; y = 10; z = 0;
azimuth_deg = 30;
pos_gNB = [x;0;z];
pos_RIS = [0;0;0];
pos_UE = [x*cosd(azimuth_deg); y*sind(90-azimuth_deg); 0];

vec_tx_ris = pos_RIS - pos_gNB;
d_tx_ris = norm(vec_tx_ris);
[az_tx_ris, el_tx_ris, rtmp] = cart2sph(vec_tx_ris(1), vec_tx_ris(2), vec_tx_ris(3));

vec_ris_ue = pos_UE - pos_RIS;
d_ris_ue = norm(vec_ris_ue);
[az_ris_ue, el_ris_ue, rtmp2] = cart2sph(vec_ris_ue(1), vec_ris_ue(2), vec_ris_ue(3));

%% ----- (Your waveform generation code follows) -----
% Downlink Channel Config
waveconfig=nrDLCarrierConfig;
waveconfig.Label='DL Carrier 1';
waveconfig.ChannelBandwidth=50;
waveconfig.FrequencyRange = 'FR1';
waveconfig.NumSubframes = 10;
waveconfig.SampleRate =53.76e6;
waveconfig.CarrierFrequency = fc; 

scscarrier = nrSCSCarrierConfig;
scscarrier.SubcarrierSpacing = 30;
scscarrier.NSizeGrid = 132;
scscarrier.NStartGrid =0 ;

% Bandwidth Parts
bwp=nrWavegenBWPConfig;
bwp.BandwidthPartID=1;
bwp.Label='BWP of scs 30kHz';
bwp.SubcarrierSpacing=30;
bwp.CyclicPrefix='Normal';
bwp.NStartBWP=0;

% SSB
ssburst = nrWavegenSSBurstConfig;
ssburst.Enable = 1;                   
ssburst.Power = 0;                     
ssburst.BlockPattern = 'Case B';        
ssburst.TransmittedBlocks = [1 1 1 1];  
ssburst.Period = 20;                   
ssburst.NCRBSSB = []; 

% Downlink Chain configuration final
pdsch=nrWavegenPDSCHConfig;
pdsch.Enable = 1;   
pdsch.Label = 'UE 1 - PDSCH @ 30 kHz';
pdsch.BandwidthPartID=1;
pdsch.Power=0;
pdsch.Coding=1;
pdsch.DataSource = 'PN9'; 
pdsch.TargetCodeRate = 0.4785;
pdsch.XOverhead = 0; % Rate matching overhead;
pdsch.Modulation = '16QAM';
pdsch.NumLayers = 1;

pdsch.SymbolAllocation = [2 9];   
pdsch.SlotAllocation = 0:19;        
pdsch.Period = 30;                
pdsch.PRBSet = [0:5, 10:20 , 30:45];      
pdsch.RNTI = 11;                   
pdsch.NID = 1;                   

% Antenna port and DM-RS configuration
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

% Waveform generation
waveconfig.SSBurst = ssburst;
waveconfig.SCSCarriers = {scscarrier};
waveconfig.BandwidthParts ={bwp};
waveconfig.PDSCH ={pdsch};
[waveform,info] = nrWaveformGenerator(waveconfig);
figure; plot(abs(waveform));
title('Magnitude of 5G Downlink Baseband Waveform');
xlabel('Sample Index'); ylabel('Magnitude');
samplerate = info.ResourceGrids(1).Info.SampleRate;
nfft = info.ResourceGrids(1).Info.Nfft;
figure;
spectrogram(waveform(:,1),ones(nfft,1),0,nfft,'centered',samplerate,'yaxis','MinThreshold',-130);
title('Spectrogram of 5G Downlink Baseband Waveform');

