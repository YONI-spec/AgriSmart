% ── Charger le modèle converti ──────────────────────────────────
net = importNetworkFromONNX('AgriSmart.onnx');
% Si erreur : Deep Learning Toolbox requis → ver() pour vérifier

% ── Noms de classes dans le même ordre que ton modèle ──────────
classes = {'healthy','green mite','bacterial blight','mosaic','brown spot'};
classes_fr = {'Saine','Acarien vert','Bactériose','Mosaïque','Tache brune'};
types   = {'','Parasitaire','Bactérienne','Virale','Fongique'};

% ── Prétraitement (adapter si ton modèle n'utilise pas 224x224) ─
function img_ready = preprocess(img_path)
    img = imread(img_path);
    img = imresize(img, [224 224]);
    if size(img,3)==1, img = cat(3,img,img,img); end  % grayscale → RGB
    img_ready = single(img) / 255.0;
    img_ready = permute(img_ready, [1 2 3]);  % HxWxC
    img_ready = reshape(img_ready, [1 224 224 3]); % batch=1
end

% ── Inférence sur une image ─────────────────────────────────────
img_ready = preprocess('zone_test.jpg');
scores = predict(net, img_ready);      % vecteur 1×5
scores = double(scores);
[conf, idx] = max(scores);

fprintf('Classe détectée : %s (%s)\n', classes_fr{idx}, types{idx});
fprintf('Confiance       : %.1f%%\n', conf*100);
fprintf('Scores complets :\n');
for i = 1:5
    fprintf('  %-20s %.1f%%\n', classes_fr{i}, scores(i)*100);
end