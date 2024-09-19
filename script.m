% Nota: o código encontra-se segmentado em concordância com o relatório
% ======================== 0. Leitura da imagem ==========================%
spine = imread("spineP.jpg");

% ========================= 1. Pré-processamento =========================%
% Escala de cinzentos
spine = rgb2gray(spine);

% Aplicar um threshold
threshold = 120;
binaryImage = spine > threshold;

% Remover artefactos com menos de 'n' pixels, onde 'n' é o 2ºargumento da
% função bwareaopen
binaryImage = bwareaopen(binaryImage, 250);

% Valor lógico para uint8
binaryImageUint8 = uint8(binaryImage) * 255;

% Obter o negativa pela 1ªvez
s_neg = imadjust(binaryImageUint8, [0 1], [1 0]);

% Soma aritmética de 50 unidades à máscara negativa
s_neg_plus = s_neg + 50;

% Induzir um intervalo de pixels de [0,255]
s_neg_plus(s_neg_plus > 255) = 255;

% Obter o negativo pela 2ªvez
s_2neg = imadjust(s_neg_plus, [0 1], [1 0]);

% Conversão de volta para valor lógico
s_2neg = s_2neg > 0;

% Dilatação para preencher falhas
se1 = strel('disk', 8);  
s_dil = imdilate(s_2neg, se1);

% Aplicar 'region growing' para preencher completamente os espaços vazios
s_fill = imfill(s_dil, 'holes');

% Aplicar 'closing' com o mesmo elemento estruturante utilizado no
% processo de dilatação
s_close = imclose(s_fill, se1);

% Visualizar a máscara criada
figure ('Name','Máscara a ser utilizada para Region Filling (Etapa 2');
imshow(s_close);
title('Dilatação + Filling + Closing');

% Preencher a imagem original com a máscara criada nos passos anteriores
inpaintedImage = regionfill(spine, s_close);

% Obter uma melhor definição da aplicação da máscara em region fill
adjustedImage = imadjust(inpaintedImage, [0.25 0.8], [0 .9], 0.8);

% Visualização dos resultados
figure ('Name','Aplicação do Region Filling c/Máscara Adaptada (Etapa 2)');
subplot(1, 3, 1);
imshow(spine);
title('Imagem Original (escala de cinzentos)');

subplot(1, 3, 2);
imshow(inpaintedImage);
title('Imagem sem Artefactos');

subplot(1, 3, 3);
imshow(adjustedImage);
title('Imagem sem Artefactos (com mais definição)');

% ===================== 2. Obtenção de contornos =========================%
% Isolar os contornos com o Método de Canny 
spineBW = edge(adjustedImage, "canny", [0.15 0.45]);

% Visualizar a obtenção de contornos
figure ('Name','Isolar os Contornos (Etapa 3)');
subplot(1, 3, 1);
imshow(spine);
title('Original');

subplot(1, 3, 2);
imshow(adjustedImage);
title('Original Pré-Processada');

subplot(1,3,3);
imshow(spineBW);
title('Contornos');

% ==================== 3. Melhoramento de contornos ======================%
% Aplicar High Boost Filter
high_freq_filter = 1/9*[-1 -1 -1; -1 18 -1; -1 -1 -1];
enhanced_edges_img = conv2(double(spineBW), high_freq_filter, 'same');

figure ('Name','Aplicação de um High Boost Filter aos Contornos (Etapa 4)');
subplot(1,2,1);
imshow(spineBW);
title('Original');
subplot(1,2,2);
imshow(enhanced_edges_img);
title('High Boost Filter nos Contornos');

% Magnitude dos Contornos
if size(spine, 3) == 3 % Converter a imagem para 2-D
    grayImage = rgb2gray(enhanced_edges_img);
else
    grayImage = enhanced_edges_img;
end

grayImage = double(grayImage); % Converter para double

imgVert = [1 0 -1; 2 0 -2; 1 0 -1]; % Obter as componentes verticais
imgHoriz = imgVert'; % Obter as componentes horizontais

edgesVertical = conv2(grayImage, imgVert, 'same'); % Executar o processo de convolução
edgesHorizontal = conv2(grayImage, imgHoriz, 'same');

edgesMagnitude = sqrt(edgesVertical.^2 + edgesHorizontal.^2); % Combinação das magnitudes vertical e horizontal

edgesMagnitude = edgesMagnitude / max(edgesMagnitude(:)); % Normalizar a imagem para o intervalo [0,1]

binaryEdges = edgesMagnitude > 0.1; % Induzir o valor lógico com um threshold

% Visualizar os resultados
figure ('Name','Combinação Linear das Magnitudes Vertical e Horizontal (Etapa 4)');
subplot(1,2,1);
imshow(enhanced_edges_img);
title('Contornos Originais');
subplot(1,2,2);
imshow(binaryEdges);
title('$\sqrt{Contornos Verticais^2 + Contornos Horizontais^2}$','Interpreter','latex');

% Conectar os contornos 
se2 = strel('cube', 2); 
closedEdges = imclose(binaryEdges, se2); % Dilatação + erosão

% Escala de Cinzentos para RGB
if size(enhanced_edges_img, 3) == 1
    enhanced_edges_img = cat(3, enhanced_edges_img, enhanced_edges_img, enhanced_edges_img);
end

% Isolar os canais de cor
redChannel = enhanced_edges_img(:, :, 1);
greenChannel = enhanced_edges_img(:, :, 2);
blueChannel = enhanced_edges_img(:, :, 3);

% Sobrepor os canais criados à imagem 
redChannel(rgb2gray(enhanced_edges_img)>0) = 255;
greenChannel(rgb2gray(enhanced_edges_img)>0) = 0;
blueChannel(rgb2gray(enhanced_edges_img)>0) = 0;

% Devolver os canais criados à imagem original
contouredImage = cat(3, redChannel, greenChannel, blueChannel);

% Visualizar os resultados
figure ('Name','Contornos em  (Etapa 4)');
subplot(1,2,1);
imshow(spine);
title('Imagem Original');

subplot(1,2,2);
imshow(contouredImage);
title('Contornos Vermelhos');

% ===================== 4. Segmentação da imagem =========================%
% Rotular os elementos da coluna (vértebras + artefactos)
[labeledImage, numObjects] = bwlabel(rgb2gray(enhanced_edges_img));

% Obter as dimensões das Bounding Boxes de todos os elementos detetados
stats = regionprops(labeledImage, 'BoundingBox');

% Imagem base para vizualização completa
figure('Name','Visualização de todos os elementos detetados pela função bwlabel (Etapa 5)');
imshow(enhanced_edges_img);
hold on;

% Iterar sobre todos os elementos rotulados e desenhar uma Bounding Box
for k = 1:numObjects
    rectangle('Position', stats(k).BoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);
    text(stats(k).BoundingBox(1), stats(k).BoundingBox(2) - 10, num2str(k), 'Color', 'yellow', 'FontSize', 12);
end
hold off;

% Imagem base para vizualização parcial
figure('Name','Visualização dos 4 maiores elementos (Etapa 5)');
imshow(enhanced_edges_img);
hold on;

% Iterar apenas sobre os 4 maiores elementos rotulados e desenhar uma Bounding Box (apenas para efeitos de vizualização)
for k = [6,8,15,20]
    rectangle('Position', stats(k).BoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);
    text(stats(k).BoundingBox(1), stats(k).BoundingBox(2) - 10, num2str(k), 'Color', 'yellow', 'FontSize', 12);
end
hold off;

% ===================== 5. Cálculo das dimensões =========================%
% Inicializar vetores para armazenar os valores da variável stats
width_k15 = [];
height_k8 = [];
height_k15 = [];

% Inicializar variáveis para armazenar o valor da maior altura e a vértebra correspondente
largest_height = 0;
largest_vertebra = -1;
largest_area = 0;

% Iterar sobre todos os elementos e armazenar os valores no vetor correspondente
for k = [6, 8, 15, 20]
    boundingBox = stats(k).BoundingBox;
    x = boundingBox(1);
    y = boundingBox(2);
    width = boundingBox(3);
    height = boundingBox(4);
    
    % Correção para a vértebra 15
    if k == 15
        width_k15 = width;
        height_k15 = height;
    end
    
    % Correção para a vértebra 8
    if k == 8
        height_k8 = height;
    end
end

% Iterar novamente sobre os elementos, aplicar as correções e determinar as dimensões
for k = [6, 8, 15, 20]
    boundingBox = stats(k).BoundingBox;
    x = boundingBox(1);
    y = boundingBox(2);
    width = boundingBox(3);
    height = boundingBox(4);
    
    % Aplicar a correção da vértebra 8
    if k == 8 && ~isempty(width_k15)
        width = width_k15;
    end
    
    % Aplicar a correção da vértebra 15
    if k == 15 && ~isempty(height_k8)
        height = height_k15 - height_k8;
    end
    
    % Calcular a área com os valores corrigidos
    area = width * height;
    
    % Obter a maior altura
    if height > largest_height
        largest_height = height;
        largest_vertebra = k;
        largest_area = area;
    end
    
    % Mostrar as dimensões das 4 maiores vértebras (elementos rotulados) na Command Window
    fprintf('Vertebra %d: x = %.2f, y = %.2f, width = %.2f, height = %.2f, area = %.2f\n', ...
            k, x, y, width, height, area);
end

% Mostrar a dimensão da vértebra maior na Command Window
if largest_vertebra ~= -1
    
    fprintf('Relativamente à altura total do corpo vertebral, a maior vértebra é a nº%d, com uma altura de %.0fpx e uma área da Bounding Box correspondente de %.0fpx^2.\n',largest_vertebra, largest_height, largest_area);
else
    fprintf('Não aplicável.\n');
end

% Visualizar o resultado final
figure('Name','Resultado final (Etapa 6)');
imshow(spine);
hold on;

% Iterar sobre todos os elementos rotulados e desenhar uma Bounding Box
for k = 6
    rectangle('Position', stats(k).BoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);
    text(stats(k).BoundingBox(1), stats(k).BoundingBox(2) - 10, num2str(k), 'Color', 'yellow', 'FontSize', 12);
end
hold off;

