 % Step 1: Create an empty resource grid (complex grid)
% Each transmit antenna port has its own grid (NumLayers)
numSymbols = carrier.SymbolsPerSlot;
numSubcarriers = carrier.NSizeGrid * 12;
resourceGrid = zeros(numSubcarriers, numSymbols, pdsch.NumLayers);

% Step 2: Map DMRS symbols to the resource grid
% The symbolIndices is an M-by-3 matrix: [subcarrier, symbol, layer]
for idx = 1:size(symbolIndices, 1)
    sc = symbolIndices(idx, 1);  % subcarrier index (1-based)
    symb = symbolIndices(idx, 2); % OFDM symbol index
    layer = symbolIndices(idx, 3); % layer index
    resourceGrid(sc, symb, layer) = DMRSsymbols(idx);
end

% Step 3: Visualize DMRS in the resource grid
% You can visualize any layer; here, visualize the first layer
layerToPlot = 1;
dmrsGrid = abs(resourceGrid(:, :, layerToPlot)); % take magnitude for visualization

% Use imagesc to visualize DMRS placement
figure;
imagesc(dmrsGrid);
xlabel('OFDM Symbol Index');
ylabel('Subcarrier Index');
title(sprintf('DMRS Pattern in Resource Grid (Layer %d)', layerToPlot));
colorbar;
axis xy;  % Flip y-axis to match LTE/5G plotting conventions
