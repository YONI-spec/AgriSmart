load('waypoints.mat');
grid_n = 10;
heatmap = zeros(grid_n, grid_n);

% Simulation : quelques zones "malades" aléatoires
rng(42);
disease_zones = rand(grid_n, grid_n);
disease_zones(disease_zones > 0.7) = 1;   % malade
disease_zones(disease_zones <= 0.7) = 0;  % sain

% Associer chaque waypoint à une case de la grille
for k = 1:size(waypoints,1)
    col = min(floor(waypoints(k,1)/5)+1, grid_n);
    row = min(floor(waypoints(k,2)/5)+1, grid_n);
    heatmap(row, col) = disease_zones(row, col);
end
save('heatmap.mat','heatmap');