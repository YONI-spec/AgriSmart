%% ================================================================
%  AgriSmart — Simulation drone 3D + Heatmap temps réel
%  Requires : UAV Toolbox + Simulink 3D Animation + Deep Learning Toolbox
%  Lance : run_drone_3d.m depuis ton dossier drone/
%% ================================================================
clear; clc; close all;

%% ── CONFIG ──────────────────────────────────────────────────────
MODEL_PATH  = 'AgriSmart.onnx';
IMAGES_DIR  = 'field_images';
GRID        = 10;
FIELD_M     = 50;      % champ 50x50 mètres
ALT         = 12;      % altitude de vol (mètres)
STEP_M      = FIELD_M / GRID;
SPEED       = 4.0;     % m/s
STEP_DELAY  = 0.25;    % secondes entre waypoints

CLASSES_FR  = {'Saine','Acarien vert','Bactériose','Mosaïque','Tache brune'};
CLASSES_TYPE= {'','Parasitaire','Bactérienne','Virale','Fongique'};
COLORS_RGB  = [0.13 0.77 0.37;
               0.98 0.45 0.09;
               0.94 0.27 0.27;
               0.66 0.54 0.98;
               0.98 0.75 0.14];

fprintf('AgriSmart — Démo drone 3D\n');
fprintf('MATLAB R2024b · UAV Toolbox · Simulink 3D Animation\n\n');

%% ── CHARGER LE MODÈLE ───────────────────────────────────────────
fprintf('[1/4] Chargement modèle...\n');
net = [];
if isfile(MODEL_PATH)
    try
        net = importNetworkFromONNX(MODEL_PATH);
        fprintf('      AgriSmart.onnx chargé OK\n');
    catch e
        fprintf('      Erreur ONNX : %s\n      → Mode simulation activé\n', e.message);
    end
else
    fprintf('      AgriSmart.onnx non trouvé → Mode simulation activé\n');
end

%% ── IMAGES ──────────────────────────────────────────────────────
img_files = [];
if isfolder(IMAGES_DIR)
    for ext = {'*.jpg','*.jpeg','*.png','*.JPG','*.PNG'}
        img_files = [img_files; dir(fullfile(IMAGES_DIR, ext{1}))]; %#ok<AGROW>
    end
end
fprintf('[2/4] %d image(s) trouvée(s) dans field_images/\n', numel(img_files));

%% ── WAYPOINTS LAWNMOWER ─────────────────────────────────────────
fprintf('[3/4] Génération trajectoire...\n');
waypoints = [];
for r = 0:GRID-1
    cols = 0:GRID-1;
    if mod(r,2)==1, cols = fliplr(cols); end
    for c = cols
        x = c * STEP_M + STEP_M/2;
        y = r * STEP_M + STEP_M/2;
        waypoints(end+1,:) = [x, y, ALT]; %#ok<AGROW>
    end
end
fprintf('      %d waypoints\n', size(waypoints,1));

%% ── DISEASE MAP (seeded) ────────────────────────────────────────
rng(2025);
p = rand(GRID, GRID);
diseaseMap = zeros(GRID, GRID);
diseaseMap(p >= 0.55 & p < 0.70) = 1;
diseaseMap(p >= 0.70 & p < 0.82) = 2;
diseaseMap(p >= 0.82 & p < 0.91) = 3;
diseaseMap(p >= 0.91)             = 4;

%% ── FIGURE LAYOUT ───────────────────────────────────────────────
fprintf('[4/4] Initialisation du dashboard...\n\n');

fig = figure('Name','AgriSmart — Démo Live 3D', ...
    'Color',[0.05 0.07 0.10], ...
    'Position',[30 30 1400 750], ...
    'NumberTitle','off','MenuBar','none','ToolBar','none');

% ── Vue 3D drone (panneau gauche large) ──────────────────────────
ax3d = axes('Parent',fig,'Position',[0.02 0.08 0.54 0.85]);
set(ax3d,'Color',[0.05 0.10 0.15], ...
    'XColor',[0.3 0.5 0.7],'YColor',[0.3 0.5 0.7],'ZColor',[0.3 0.5 0.7], ...
    'GridColor',[0.12 0.22 0.32],'GridAlpha',1, ...
    'XGrid','on','YGrid','on','ZGrid','on', ...
    'FontName','Courier New','FontSize',8);
hold(ax3d,'on'); axis(ax3d,'equal');
xlim(ax3d,[-2 FIELD_M+2]); ylim(ax3d,[-2 FIELD_M+2]); zlim(ax3d,[0 ALT+8]);
xlabel(ax3d,'X (m)','Color',[0.4 0.6 0.8],'FontSize',9);
ylabel(ax3d,'Y (m)','Color',[0.4 0.6 0.8],'FontSize',9);
zlabel(ax3d,'Alt. (m)','Color',[0.4 0.6 0.8],'FontSize',9);
title(ax3d,'Simulation vol drone — Vue 3D','Color',[0.7 0.9 1],'FontSize',12,'FontName','Courier New');
view(ax3d, -35, 28);

% ── Sol : champ de manioc ────────────────────────────────────────
[gx, gy] = meshgrid(linspace(0,FIELD_M,30), linspace(0,FIELD_M,30));
gz = zeros(size(gx));
% Légère variation de hauteur pour simuler les plants
gz = gz + 0.3*sin(gx*0.8).*cos(gy*0.8);
surf(ax3d, gx, gy, gz, ...
    'FaceColor',[0.10 0.38 0.12], ...
    'EdgeColor',[0.08 0.28 0.09], ...
    'EdgeAlpha',0.4,'FaceAlpha',0.85);

% ── Plants de manioc (cylindres verts) ───────────────────────────
rng(42);
n_plants = 120;
px = rand(1,n_plants)*FIELD_M;
py = rand(1,n_plants)*FIELD_M;
for i = 1:n_plants
    th = linspace(0,2*pi,8);
    plant_h = 0.8 + rand*0.6;
    for h = linspace(0, plant_h, 4)
        r_p = 0.15*(1 - h/plant_h) + 0.05;
        xc = px(i) + r_p*cos(th);
        yc = py(i) + r_p*sin(th);
        zc = ones(size(th))*h;
        fill3(ax3d, xc, yc, zc, [0.13+rand*0.08 0.55+rand*0.15 0.13+rand*0.08], ...
            'EdgeColor','none','FaceAlpha',0.7);
    end
end

% ── Grille du champ (lignes de référence au sol) ─────────────────
for i = 0:GRID
    plot3(ax3d,[i*STEP_M i*STEP_M],[0 FIELD_M],[0.05 0.05],'--', ...
        'Color',[0.2 0.4 0.2],'LineWidth',0.5);
    plot3(ax3d,[0 FIELD_M],[i*STEP_M i*STEP_M],[0.05 0.05],'--', ...
        'Color',[0.2 0.4 0.2],'LineWidth',0.5);
end

% ── Trajectoire planifiée (ligne pointillée en l'air) ────────────
plot3(ax3d, waypoints(:,1), waypoints(:,2), waypoints(:,3), '--', ...
    'Color',[0.2 0.4 0.6],'LineWidth',0.8);

% ── Drone 3D (corps + 4 bras + 4 rotors) ─────────────────────────
drone_color  = [0.15 0.15 0.20];
rotor_color  = [0.22 0.74 0.98];
arm_len = 1.4;
arm_angles = [45 135 225 315];

% Corps central
[sx,sy,sz] = sphere(12);
drone_body = surf(ax3d, 0.5*sx, 0.5*sy, 0.3*sz, ...
    'FaceColor',drone_color,'EdgeColor','none','FaceAlpha',0.95);

% Bras et rotors
arm_h = gobjects(4,1);
rot_h = gobjects(4,1);
for i = 1:4
    ang = deg2rad(arm_angles(i));
    xe = arm_len*cos(ang); ye = arm_len*sin(ang);
    arm_h(i) = plot3(ax3d,[0 xe],[0 ye],[0 0],'-', ...
        'Color',[0.3 0.3 0.35],'LineWidth',3);
    th = linspace(0,2*pi,20);
    rot_h(i) = fill3(ax3d, xe+0.5*cos(th), ye+0.5*sin(th), zeros(size(th)), ...
        rotor_color,'EdgeColor','none','FaceAlpha',0.6);
end

% LED de statut (point rouge clignotant)
led_h = plot3(ax3d,0,0,0,'o','MarkerSize',6, ...
    'MarkerFaceColor',[1 0.2 0.2],'MarkerEdgeColor','none');

% Traînée de vol
trail_h = plot3(ax3d,waypoints(1,1),waypoints(1,2),waypoints(1,3),'-', ...
    'Color',[0.22 0.74 0.98],'LineWidth',1.5,'LineStyle','-');
trail_x = []; trail_y = []; trail_z = [];

% Faisceau caméra vers le sol (ligne verticale)
beam_h = plot3(ax3d,[0 0],[0 0],[0 0],'-', ...
    'Color',[1 1 0.2],'LineWidth',0.8,'LineStyle',':');

% ── Heatmap 2D (panneau haut droite) ─────────────────────────────
ax_heat = axes('Parent',fig,'Position',[0.59 0.38 0.39 0.55]);
set(ax_heat,'Color',[0.06 0.10 0.15], ...
    'XColor',[0.4 0.6 0.8],'YColor',[0.4 0.6 0.8], ...
    'FontName','Courier New','FontSize',8);
heatmap_data = nan(GRID,GRID);
img_heat = imagesc(ax_heat, heatmap_data,[-0.5 4.5]);
colormap(ax_heat, COLORS_RGB);
cb = colorbar(ax_heat,'Color',[0.5 0.7 0.9],'FontName','Courier New','FontSize',7);
cb.Ticks = 0:4;
cb.TickLabels = {'Saine','Acarien','Bactériose','Mosaïque','T.Brune'};
set(ax_heat,'XTick',1:GRID,'YTick',1:GRID, ...
    'XTickLabel',0:GRID-1,'YTickLabel',0:GRID-1,'TickLength',[0 0]);
title(ax_heat,'Carte de santé du champ','Color',[0.7 0.9 1], ...
    'FontSize',10,'FontName','Courier New');
hold(ax_heat,'on');
scan_marker = plot(ax_heat,1,1,'ws','MarkerSize',16,'LineWidth',2,'MarkerFaceColor','none');

% ── Stats (panneau bas droite) ────────────────────────────────────
ax_stats = axes('Parent',fig,'Position',[0.59 0.08 0.39 0.27]);
set(ax_stats,'Color',[0.05 0.07 0.10],'Visible','off');
stats_txt = text(ax_stats,0.03,0.97,'', ...
    'Units','normalized','VerticalAlignment','top', ...
    'Color',[0.7 0.9 1],'FontName','Courier New','FontSize',9, ...
    'Interpreter','none');

% Titre global
annotation(fig,'textbox',[0 0.95 1 0.05], ...
    'String','  AgriSmart  ·  Surveillance Phytosanitaire Manioc  ·  Simulation Drone 3D  ·  Demo Live', ...
    'Color',[0.22 0.74 0.98],'FontSize',11,'FontName','Courier New', ...
    'FontWeight','bold','EdgeColor','none','HorizontalAlignment','center','VerticalAlignment','middle');

%% ── BOUCLE PRINCIPALE ───────────────────────────────────────────
fprintf('Démarrage simulation 3D...\n');
fprintf('Ferme la figure pour arrêter.\n\n');
fprintf('  WP   Col  Row  Classe          Confiance\n');
fprintf('  ─────────────────────────────────────────\n');

counts    = zeros(1,5);
n_scanned = 0;
t_start   = tic;
rotor_angle = 0;

for k = 1:size(waypoints,1)
    if ~ishandle(fig), break; end

    x_now = waypoints(k,1);
    y_now = waypoints(k,2);
    z_now = waypoints(k,3);
    col   = round((x_now - STEP_M/2) / STEP_M);
    row   = round((y_now - STEP_M/2) / STEP_M);

    % ── Animation vol vers ce waypoint ──────────────────────────
    if k > 1
        x_prev = waypoints(k-1,1); y_prev = waypoints(k-1,2); z_prev = waypoints(k-1,3);
        n_interp = 12;
        for t = 1:n_interp
            if ~ishandle(fig), break; end
            alpha = t / n_interp;
            xi = x_prev + alpha*(x_now - x_prev);
            yi = y_prev + alpha*(y_now - y_prev);
            zi = z_prev + alpha*(z_now - z_prev) + 0.8*sin(pi*alpha); % légère bosse

            % Mettre à jour corps drone
            set(drone_body,'XData',xi+0.5*sx,'YData',yi+0.5*sy,'ZData',zi+0.3*sz);
            set(led_h,'XData',xi,'YData',yi,'ZData',zi+0.35);

            % Mettre à jour bras et rotors
            rotor_angle = rotor_angle + 25;
            for i = 1:4
                ang = deg2rad(arm_angles(i));
                xe = xi + arm_len*cos(ang); ye = yi + arm_len*sin(ang);
                set(arm_h(i),'XData',[xi xe],'YData',[yi ye],'ZData',[zi zi]);
                % Rotors animés (rotation)
                th_r = linspace(0,2*pi,20) + deg2rad(rotor_angle + i*90);
                set(rot_h(i), ...
                    'XData', xe+0.5*cos(th_r), ...
                    'YData', ye+0.5*sin(th_r), ...
                    'ZData', zi*ones(1,20));
            end

            % Faisceau caméra
            set(beam_h,'XData',[xi xi],'YData',[yi yi],'ZData',[zi 0.1]);

            % Traînée
            trail_x(end+1)=xi; trail_y(end+1)=yi; trail_z(end+1)=zi; %#ok<AGROW>
            if numel(trail_x)>80
                trail_x=trail_x(end-79:end);
                trail_y=trail_y(end-79:end);
                trail_z=trail_z(end-79:end);
            end
            set(trail_h,'XData',trail_x,'YData',trail_y,'ZData',trail_z);

            % LED clignote
            led_alpha = 0.5 + 0.5*sin(rotor_angle*0.1);
            set(led_h,'MarkerFaceColor',[1 led_alpha*0.2 led_alpha*0.2]);

            drawnow limitrate;
            pause(STEP_DELAY/n_interp);
        end
    else
        % Premier waypoint : positionner directement
        set(drone_body,'XData',x_now+0.5*sx,'YData',y_now+0.5*sy,'ZData',z_now+0.3*sz);
        for i = 1:4
            ang = deg2rad(arm_angles(i));
            xe = x_now+arm_len*cos(ang); ye = y_now+arm_len*sin(ang);
            set(arm_h(i),'XData',[x_now xe],'YData',[y_now ye],'ZData',[z_now z_now]);
            th_r = linspace(0,2*pi,20);
            set(rot_h(i),'XData',xe+0.5*cos(th_r),'YData',ye+0.5*sin(th_r),'ZData',z_now*ones(1,20));
        end
        set(beam_h,'XData',[x_now x_now],'YData',[y_now y_now],'ZData',[z_now 0.1]);
        set(led_h,'XData',x_now,'YData',y_now,'ZData',z_now+0.35);
    end

    % ── Inférence ────────────────────────────────────────────────
    if ~isempty(net) && ~isempty(img_files)
        idx_img  = mod(k-1, numel(img_files)) + 1;
        img_path = fullfile(IMAGES_DIR, img_files(idx_img).name);
        scores   = agri_infer(net, img_path);
    else
        scores = agri_mock(col, row, diseaseMap);
    end
    [conf, cls_idx] = max(scores);
    cls_id = cls_idx - 1;

    % ── Heatmap ──────────────────────────────────────────────────
    heatmap_data(row+1, col+1) = cls_id;
    set(img_heat,'CData',heatmap_data);
    set(scan_marker,'XData',col+1,'YData',row+1);

    % ── Zone colorée sur le sol ──────────────────────────────────
    if cls_id > 0
        zone_c = COLORS_RGB(cls_idx,:);
        fill3(ax3d, ...
            [col*STEP_M (col+1)*STEP_M (col+1)*STEP_M col*STEP_M], ...
            [row*STEP_M row*STEP_M (row+1)*STEP_M (row+1)*STEP_M], ...
            [0.1 0.1 0.1 0.1], zone_c, ...
            'EdgeColor','none','FaceAlpha',0.55);
    end

    % ── Stats ─────────────────────────────────────────────────────
    counts(cls_idx) = counts(cls_idx)+1;
    n_scanned = n_scanned+1;
    n_sick    = n_scanned - counts(1);
    t_el      = toc(t_start);

    stats = sprintf([...
        'MISSION\n' ...
        '─────────────────────\n' ...
        'Waypoint   %3d / 100\n' ...
        'Temps      %02d:%02d\n' ...
        'Altitude   %d m\n\n' ...
        'ZONES\n' ...
        '─────────────────────\n' ...
        'Scannées   %3d\n' ...
        'Saines     %3d\n' ...
        'Malades    %3d  (%.0f%%)\n\n' ...
        'CLASSES\n' ...
        '─────────────────────\n' ...
        'Saine        %3d\n' ...
        'Acarien vert %3d\n' ...
        'Bactériose   %3d\n' ...
        'Mosaïque     %3d\n' ...
        'Tache brune  %3d\n\n' ...
        'DERNIÈRE DÉTECTION\n' ...
        '─────────────────────\n' ...
        '[%d, %d]  %s\n' ...
        'Confiance  %.0f%%\n'], ...
        k, floor(t_el/60), mod(floor(t_el),60), ALT, ...
        n_scanned, counts(1), n_sick, n_sick/n_scanned*100, ...
        counts(1),counts(2),counts(3),counts(4),counts(5), ...
        col, row, CLASSES_FR{cls_idx}, conf*100);
    set(stats_txt,'String',stats);

    % Console
    sym = ' '; if cls_id==2, sym='!'; elseif cls_id>0, sym='*'; end
    fprintf('  [%s] %3d  [%d,%d]  %-16s  %.0f%%\n', ...
        sym, k, col, row, CLASSES_FR{cls_idx}, conf*100);

    drawnow;
    pause(STEP_DELAY);
end

% ── FIN ───────────────────────────────────────────────────────────
if ishandle(fig)
    title(ax_heat,'Carte de santé — MISSION COMPLETE', ...
        'Color',[0.13 0.77 0.37],'FontSize',11,'FontName','Courier New','FontWeight','bold');
    title(ax3d,'Mission terminée — Drone en attente', ...
        'Color',[0.13 0.77 0.37],'FontSize',12,'FontName','Courier New');
end
n_sick = n_scanned - counts(1);
fprintf('\n══════════════════════════════════════\n');
fprintf('  RAPPORT FINAL AgriSmart\n');
fprintf('══════════════════════════════════════\n');
fprintf('Zones scannées : %d/100\n', n_scanned);
fprintf('Zones saines   : %d (%.0f%%)\n', counts(1), counts(1)/n_scanned*100);
fprintf('Zones malades  : %d (%.0f%%)\n', n_sick, n_sick/n_scanned*100);
fprintf('\nDétail :\n');
for i = 2:5
    if counts(i)>0
        fprintf('  %-16s : %2d zones\n', CLASSES_FR{i}, counts(i));
    end
end
fprintf('══════════════════════════════════════\n');


%% ── FONCTIONS LOCALES ───────────────────────────────────────────

function scores = agri_infer(net, img_path)
    try
        img = imread(img_path);
        img = imresize(img,[224 224]);
        if size(img,3)==1, img = cat(3,img,img,img); end
        img = single(img)/255;
        img = reshape(img,[1 224 224 3]);
        raw = double(predict(net, img));
        if max(raw)>1||min(raw)<0
            raw = exp(raw-max(raw)); raw = raw/sum(raw);
        end
        scores = raw;
    catch
        scores = agri_mock(0,0,[]);
    end
end

function scores = agri_mock(col, row, dmap)
    if ~isempty(dmap) && col>=0 && row>=0 && col<size(dmap,2) && row<size(dmap,1)
        cls = dmap(row+1, col+1) + 1;
    else
        v = mod(col*31+row*17+col*row, 100)/100;
        if v<0.55, cls=1; elseif v<0.70, cls=2; elseif v<0.82, cls=3; elseif v<0.91, cls=4; else, cls=5; end
    end
    scores = rand(1,5)*0.07;
    scores(cls) = 0.76 + rand*0.20;
    scores = scores/sum(scores);
end