load('waypoints.mat');
load('heatmap.mat');
grid_n = 10;

% Colormap : vert = sain, rouge = malade
cm = [linspace(0.1,1,128)', linspace(0.6,0,128)', zeros(128,1);
      ones(128,1),      zeros(128,1),              zeros(128,1)];

fig = figure('Name','AgriSmart — Démo Live','Color','k','Position',[100 100 1100 500]);

% Panneau gauche : trajectoire drone
ax1 = subplot(1,2,1); hold on; axis equal;
set(ax1,'Color',[0.05 0.1 0.05],'XColor','w','YColor','w');
title('Vol du drone (vue dessus)','Color','w');
xlabel('X (m)','Color','w'); ylabel('Y (m)','Color','w');
plot(waypoints(:,1), waypoints(:,2), '--','Color',[0.3 0.3 0.3]);
drone_pt = plot(waypoints(1,1), waypoints(1,2), 'o','MarkerSize',12,...
    'MarkerFaceColor',[0.2 0.6 1],'MarkerEdgeColor','w');

% Panneau droit : heatmap progressive
ax2 = subplot(1,2,2);
hmap_display = nan(grid_n, grid_n);
img = imagesc(ax2, hmap_display, [0 1]);
colormap(ax2, cm); colorbar(ax2);
set(ax2,'Color',[0.05 0.05 0.05],'XColor','w','YColor','w');
title('Carte santé du champ','Color','w');
xlabel('Colonnes','Color','w'); ylabel('Lignes','Color','w');

% Animation
for k = 1:size(waypoints,1)
    col = min(floor(waypoints(k,1)/5)+1, grid_n);
    row = min(floor(waypoints(k,2)/5)+1, grid_n);
    
    % Déplacer le drone
    set(drone_pt,'XData',waypoints(k,1),'YData',waypoints(k,2));
    
    % Révéler la zone scannée
    hmap_display(row,col) = heatmap(row,col);
    set(img,'CData',hmap_display);
    
    drawnow;
    pause(0.15);  % 0.15s par waypoint → ~15 sec pour toute la démo
end
title(ax2,'Carte santé du champ — COMPLET','Color',[0.3 1 0.3]);