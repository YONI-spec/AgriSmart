% Grille de balayage 10x10 sur le champ
field_size = 50;  % mètres
step = 5;
altitude = 10;
waypoints = [];

rows = 0:step:field_size;
for i = 1:length(rows)
    cols = 0:step:field_size;
    if mod(i,2) == 0, cols = fliplr(cols); end
    for j = 1:length(cols)
        waypoints(end+1,:) = [cols(j), rows(i), altitude];
    end
end
save('waypoints.mat','waypoints');
disp(['Waypoints générés : ' num2str(size(waypoints,1))]);