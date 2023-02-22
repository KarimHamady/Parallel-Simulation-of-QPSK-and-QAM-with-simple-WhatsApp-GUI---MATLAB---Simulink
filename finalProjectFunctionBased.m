clc
clear
close
gui = app2;

while(isvalid(gui))
    numberOfBits = 24;
    % Setting parameters for Simulink
    ldpcRate = 9/10;
    bitsSize = ldpcRate*64800;
    
    % Setting parameters for parallel simulation
    %parpool('local')
    modelQPSK = 'cm_ldpc_decode_qpsk';
    modelQAM  = 'cm_ldpc_decode_qpsk_signal_final_trial';
   
    % Waiting for GUI
    waitfor(gui.send, 'Enable', 'off');

    disp("SEND BUTTON PRESSED")

    % This variable represents the transmitted signal by the user whether
    % it's text(1), image(2), audio(3) or video(4)
    transmittedSignalType = getTransmittedSignalType(text, image, audio, video);
    %transmittedSignalType = 4;
    guiTransmittedSignal = getTransmittedSignalPrepared(transmittedSignalType, option, text, image, audio, video);
    tic
    if(option < 3)
        ebno = 71;
        encodedInput = encodeHuffman(guiTransmittedSignal, symbols);
        encodeTime = toc;
        if(option == 1)
            bitsReceivedFromSimulink = callSimulinkParallel(modelQAM, encodedInput, bitsSize);
        elseif(option == 2)
            bitsReceivedFromSimulink = callSimulinkParallel(modelQPSK, encodedInput, bitsSize);
        end
        simulinkTime = toc;
        decodedSignal  = decodeHuffman(bitsReceivedFromSimulink, dict, transmittedSignalType);
        decodeTime = toc;
    elseif(option > 2 && option < 5)
        encodedInput = encodeNormal(guiTransmittedSignal, transmittedSignalType);
        encodeTime = toc;
        if  option == 3
            bitsReceivedFromSimulink = callSimulinkParallel(modelQAM, encodedInput, bitsSize);
        elseif option == 4
            bitsReceivedFromSimulink = callSimulinkParallel(modelQPSK, encodedInput, bitsSize);
        end
        simulinkTime = toc;
        decodedSignal  = decodeNormal(bitsReceivedFromSimulink, transmittedSignalType);
        decodeTime = toc;
    end
    
%     for i = 1:200
%         imshow(decodedSignal(:,:,i:i+2))
%     end
    displayOnGui(gui, decodedSignal, option, transmittedSignalType, encodeTime, decodeTime, simulinkTime);
    set(gui.send, 'Enable', 'on');
    clearvars -except gui 
end

%%%%%%%%%%%%%% TRANSMITTED SIGNAL TYPE %%%%%%%%%%%%%%%%%
function transmittedSignalType = getTransmittedSignalType(text, image, audio, video)
    if ~isempty(image)
            transmittedSignalType = 2;
            symbols = 0:255;
            assignin('base', 'symbols', symbols);
        elseif ~isempty(video)
            transmittedSignalType = 4;
        elseif ~isempty(audio)
            transmittedSignalType = 3;
        elseif ~isempty(text{1,1})
            transmittedSignalType = 1; 
            symbols = 0:126;
            assignin('base', 'symbols', symbols);
    end
end

%%%%%%%%%%%%%% GET TRANSMITTED SIGNAL PREPARED%%%%%%%%%%%%%%%%%
function transmittedSignal = getTransmittedSignalPrepared(transmittedSignalType, option, text, image, audio, video)

    switch transmittedSignalType
        case 1
            % Preparing text
            transmittedSignal = zeros(1, 1);
            newLine = 1;
            for line = 1:size(text, 1)
                t = text{line, 1};
                for character = line+size(transmittedSignal,2)-1:line+size(transmittedSignal,2)+size(t, 2)-2
                    assignin('base', 'character', character);
                    transmittedSignal(1, character) = t(newLine);
                    newLine = newLine + 1;
                end                      
                newLine = 1;
                transmittedSignal(1, character+1) = 13;
            end

        case 2
            rowPixels = 402;
            columnPixels = 405;
            imageSize = [rowPixels, columnPixels];
            imageFromGuiResized = imresize(image, imageSize);
            transmittedSignal = reshape(imageFromGuiResized, 1, []);
        
        case 3
            % Preparinng audio
            if option > 2 
                audio = ((audio+abs(min(audio))).*126);
            end
            transmittedSignal = reshape(audio, 1, []); % Some audio files are 2 channels
        case 4
            videoTransmission(video, audio, option);
    end
end

%%%%%%%%%%%%%% HUFFMAN ENCODING AND DECODING %%%%%%%%%%%%%%%%%

function encodedBitsHuffman = encodeHuffman(decimal1DOriginal, symbols)
    probabilityOfEverySymbol = histc(decimal1DOriginal,symbols)./size(decimal1DOriginal, 2);
    dict = huffmandict(symbols,probabilityOfEverySymbol);
    assignin('base', 'dict', dict);
    encodedBitsHuffman = huffmanenco(decimal1DOriginal,dict);
end

function decodedBitsHuffman = decodeHuffman(binary1DReceived, dict, transmittedSignalType)
    switch transmittedSignalType
        case 1 % Text
           decodedBitsHuffman = reshape(huffmandeco(binary1DReceived,dict), 1, []);
        case 2 % Image
           decodedBitsHuffman = reshape(uint8(huffmandeco(binary1DReceived,dict)), 402, [], 3);
        case 3 % Audio
        case 4 % Video
        otherwise
    end
end

%%%%%%%%%%%%%% NORMAL ENCODING AND DECODING %%%%%%%%%%%%%%%%%

function encodedBitsNormal = encodeNormal(decimal1DOriginal, signalType)
    switch signalType
        case 1
            encodedBitsNormal = reshape((dec2bin(decimal1DOriginal, 8) - '0').', 1, []);
        case 2
            encodedBitsNormal = reshape((dec2bin(decimal1DOriginal, 8) - '0').', 1, []);
        case 3
            encodedBitsNormal = reshape((dec2bin(decimal1DOriginal, 16) - '0').', 1, []);
        case 4
            encodedBitsNormal = encodeNormal(decimal1DOriginal, 2);
    end
    assignin('base', 'audioBitsSent', encodedBitsNormal);
end

function decodedBitsNormal = decodeNormal(binary1DReceived, transmittedSignalType)
    switch transmittedSignalType
        case 1 % Text
           decodedBitsNormal    = reshape(typecast(double(bin2dec(char(reshape(binary1DReceived, 8, []) +'0').')), 'double'), 1, size(binary1DReceived, 2)./8);
        case 2 % Image
           decodedBitsNormal    = reshape(typecast(uint8(bin2dec(char(reshape(binary1DReceived, 8, []) +'0').')), 'uint8'), 402, [], 3);
        case 3 % Audio
            audioBitsReceived   = bin2dec(char(reshape(binary1DReceived, 16, []) +'0').');
            audioReconstructed  = reshape(audioBitsReceived, [], 2);
            averageOfReceived   = mean(audioReconstructed);
            audioReconstructed  = (audioReconstructed-averageOfReceived);
            decodedBitsNormal   = audioReconstructed./averageOfReceived;
        case 4 % Video
            decodedBitsNormal = reshape(typecast(uint8(bin2dec(char(reshape(binary1DReceived, 8 , [])+ '0').')), 'uint8'), videoHeight, videoWidth, 3, []);
        otherwise
    end
end

function videoTransmission(videoFilePath, audio, option)
    bitsSize = 58320;
    modelQPSK = 'cm_ldpc_decode_qpsk';
    modelQAM  = 'cm_ldpc_decode_qpsk_signal_final_trial';
    videoFromSimulink = zeros(1,1);
    video = VideoReader(videoFilePath);

    while(hasFrame(video))
        frame = read(video, [1 Inf]);
    end
    oneDVideo = reshape(frame, 1, []);

    if option == 3 || option == 4
        encodedVideo = encodeNormal(oneDVideo, 2);
    else
        symbols = 0:255;
        probabilityOfEverySymbol = histc(oneDVideo,symbols)./size(oneDVideo, 2);
        dict = huffmandict(symbols,probabilityOfEverySymbol);
        encodedVideo = huffmanenco(oneDVideo,dict);
    end

    if option == 3 || option == 1
        videoFromSimulink = callSimulinkParallel(modelQAM, encodedVideo, bitsSize);
    elseif option == 4 || option == 2
        videoFromSimulink = callSimulinkParallel(modelQPSK, encodedVideo,bitsSize);
    end

    if option == 3 || option == 4
        decodedVideo = reshape(typecast(uint8(bin2dec(char(reshape(videoFromSimulink, 8, []) +'0').')), 'uint8'), video.Height, video.Width, 3, []);
    else
        decodedVideo = reshape(uint8(huffmandeco(videoFromSimulink,dict)),  video.Height, video.Width, 3, []);
    end
    audio = reshape(((audio+abs(min(audio))).*126), 1, []);
    encodedBitsNormal = reshape((dec2bin(audio, 24) - '0').', 1, []);
    if option == 3
        audioFromSimulink = callSimulinkParallel(modelQAM, encodedBitsNormal, bitsSize);
    elseif option == 4
        audioFromSimulink = callSimulinkParallel(modelQPSK, encodedBitsNormal,bitsSize);
    end
    audioBitsReceived   = bin2dec(char(reshape(audioFromSimulink, 24, []) +'0').');
    audioReconstructed  = reshape(audioBitsReceived, [], 2);
    averageOfReceived   = mean(audioReconstructed);
    audioReconstructed  = (audioReconstructed-averageOfReceived);
    decodedAudioNormal   = audioReconstructed./averageOfReceived;


    sound(decodedAudioNormal, 44100, 24);
    for i = 1:200
        imshow(decodedVideo(:,:,i:i+2))
    end

end

function receivedBits = callSimulinkParallel(model_name, code, bitsSize)
   %%%%%%%%%%%%%%%%%%%%%%PREPARATION FOR PARALLEL ENCODING%%%%%%%%%%%%%%%%%%%%%%
    
    % Dividing 1D array to subarrays that can be sent over Simulink
    bufferForSimulinkLDPC = ones(1, (bitsSize*ceil(size(code, 2)/bitsSize)) - size(code, 2));
    code = cat(2, code, bufferForSimulinkLDPC);
    % Running Simulink for first modulation scheme QPSK
    concatReconstructed = [];
    for i = 1:bitsSize:size(code, 2)
        run = ceil(i/bitsSize);
        bitsVariable = code(1, i:i+bitsSize-1);
        in(run) = Simulink.SimulationInput(model_name);
        in(run) = in(run).setVariable('bitsVariable', bitsVariable);
        assignin('base', 'bitsVariable', bitsVariable);
    end

    bitsChannel = parsim(in, 'TransferBaseWorkspaceVariables','on');
    assignin('base', 'bitsChannel', bitsChannel);
    % Getting output from Simulink
    for runOutputs = 1:size(code, 2)/bitsSize
        concatReconstructed = cat(2, concatReconstructed, bitsChannel(1, runOutputs).simout);
    end
    
    % Choosing parts of 1D array for Image and Text
    %receivedBits = concatReconstructed(1, end-bufferForSimulinkLDPC-size(code, 2) + 1:end-bufferForSimulinkLDPC);
    receivedBits = concatReconstructed(1, 1:end-size(bufferForSimulinkLDPC, 2));
    
end

function displayOnGui(gui, decodedSignal, option, transmittedSignalType, encodeTime, decodeTime, simulinkTime)
    sound(audioread('whatsappReceived.mp3'), 44100, 24);
    
    switch option
        case 1
            timeAndBER = uilabel(gui.GMaxHuff); 
            timeAndBER.Text = {cat(2, 'Encoding Time', num2str(encodeTime)), cat(2, 'Simulink Time', num2str(simulinkTime-encodeTime)), cat(2, 'Decoding Time', num2str(decodeTime-simulinkTime-encodeTime))};
            timeAndBER.Position = [500 gui.initialPosition_GMaxHuff_y 200 100];
            timeAndBER.BackgroundColor = [0 0 1];
            switch transmittedSignalType
                case 1 % Text
                    textSent = uilabel(gui.GMaxHuff); 
                    guiText = {};
                    line = 1;
                    startingLine = 1;
                    for c = 1:size(decodedSignal, 2)
                        if(decodedSignal(c) == 13)
                            line = line + 1;
                            startingLine = 1;
                            continue
                        end
                        if(decodedSignal(1, c) == 0)
                            continue      
                        end
                        guiText{line, 1}(1, startingLine) = char(decodedSignal(1, c));
                        startingLine = startingLine + 1;
                        assignin('base', 'guiText', guiText);
                    end
                    textSent.Text = guiText;

                    textSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxHuff_y 200 size(guiText,1)*30];
                    textSent.BackgroundColor = [0 0.7 0];
                    gui.initialPosition_GMaxHuff_y = gui.initialPosition_GMaxHuff_y + 100;
                case 2 % Image
                    imageSent = uiimage(gui.GMaxHuff);
                    imageSent.ImageSource = decodedSignal;
                    imageSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxHuff_y size(decodedSignal, 1) size(decodedSignal, 2)];
                    gui.initialPosition_GMaxHuff_y = gui.initialPosition_GMaxHuff_y + size(decodedSignal, 2);
                case 3 % Audio
                    audioSent = uiaxes(gui.GMaxHuff);
                    plot(decodedSignal, 'Parent', audioSent);
                    audioSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxHuff_y 300 100];
                    gui.initialPosition_GMaxHuff_y = gui.initialPosition_GMaxHuff_y + 100;
                case 4 % Video
                otherwise
            end
        case 2
            timeAndBER = uilabel(gui.GMaxNormal); 
            timeAndBER.Text = {cat(2, 'Encoding Time', num2str(encodeTime)), cat(2, 'Simulink Time', num2str(simulinkTime-encodeTime)), cat(2, 'Decoding Time', num2str(decodeTime-simulinkTime-encodeTime))};
            timeAndBER.Position = [500 gui.initialPosition_GMaxNormal_y 200 100];
            timeAndBER.BackgroundColor = [0 0 1];
            switch transmittedSignalType
                case 1 % Text
                    textSent = uilabel(gui.GMaxNormal); 
                    guiText = {};
                    line = 1;
                    startingLine = 1;
                    for c = 1:size(decodedSignal, 2)
                        if(decodedSignal(c) == 13)
                            line = line + 1;
                            startingLine = 1;
                            continue
                        end
                        if(decodedSignal(1, c) == 0)
                            continue      
                        end
                        guiText{line, 1}(1, startingLine) = char(decodedSignal(1, c));
                        startingLine = startingLine + 1;
                        assignin('base', 'guiText', guiText);
                    end
                    textSent.Text = guiText;

                    textSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxNormal_y 200 size(guiText,1)*30];
                    textSent.BackgroundColor = [0 0.7 0];
                    gui.initialPosition_GMaxNormal_y = gui.initialPosition_GMaxNormal_y + 100;
                case 2 % Image
                    imageSent = uiimage(gui.GMaxNormal);
                    imageSent.ImageSource = decodedSignal;
                    imageSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxNormal_y size(decodedSignal, 1) size(decodedSignal, 2)];
                    gui.initialPosition_GMaxNormal_y = gui.initialPosition_GMaxNormal_y + size(decodedSignal, 2);
                case 3 % Audio
                    audioSent = uiaxes(gui.GMaxNormal);
                    plot(decodedSignal, 'Parent', audioSent);
                    audioSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxNormal_y 300 100];
                    gui.initialPosition_GMaxNormal_y = gui.initialPosition_GMaxNormal_y + 100;
                case 4 % Video
                otherwise
            end
        case 3
            timeAndBER = uilabel(gui.GMaxHuffAndNormal); 
            timeAndBER.Text = {cat(2, 'Encoding Time', num2str(encodeTime)), cat(2, 'Simulink Time', num2str(simulinkTime-encodeTime)), cat(2, 'Decoding Time', num2str(decodeTime-simulinkTime-encodeTime))};
            timeAndBER.Position = [500 gui.initialPosition_GMaxHuffAndNormal_y 200 100];
            timeAndBER.BackgroundColor = [0 0 1];
            switch transmittedSignalType
                case 1 % Text
                    textSent = uilabel(gui.GMaxHuffAndNormal); 
                    guiText = {};
                    line = 1;
                    startingLine = 1;
                    for c = 1:size(decodedSignal, 2)
                        if(decodedSignal(c) == 13)
                            line = line + 1;
                            startingLine = 1;
                            continue
                        end
                        if(decodedSignal(1, c) == 0)
                            continue      
                        end
                        guiText{line, 1}(1, startingLine) = char(decodedSignal(1, c));
                        startingLine = startingLine + 1;
                        assignin('base', 'guiText', guiText);
                    end
                    textSent.Text = guiText;

                    textSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxHuffAndNormal_y 200 size(guiText,1)*30];
                    textSent.BackgroundColor = [0 0.7 0];
                    gui.initialPosition_GMaxHuffAndNormal_y = gui.initialPosition_GMaxHuffAndNormal_y + 100;
                case 2 % Image
                    imageSent = uiimage(gui.GMaxHuffAndNormal);
                    imageSent.ImageSource = decodedSignal;
                    imageSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxHuffAndNormal_y size(decodedSignal, 1) size(decodedSignal, 2)];
                    gui.initialPosition_GMaxHuffAndNormal_y = gui.initialPosition_GMaxHuffAndNormal_y + size(decodedSignal, 2);
                case 3 % Audio
                    audioSent = uiaxes(gui.GMaxHuffAndNormal);
                    plot(decodedSignal, 'Parent', audioSent);
                    audioSent.Position = [gui.initialPosition_received_x gui.initialPosition_GMaxHuffAndNormal_y 300 100];
                    gui.initialPosition_GMaxHuffAndNormal_y = gui.initialPosition_GMaxHuffAndNormal_y + 100;
                case 4 % Video
                otherwise
            end
        case 4
            timeAndBER = uilabel(gui.TimeComparison); 
            timeAndBER.Text = {cat(2, 'Encoding Time', num2str(encodeTime)), cat(2, 'Simulink Time', num2str(simulinkTime-encodeTime)), cat(2, 'Decoding Time', num2str(decodeTime-simulinkTime-encodeTime))};
            timeAndBER.Position = [500 gui.initialPosition_TimeComparison_y 200 100];
            timeAndBER.BackgroundColor = [0 0 1];
            switch transmittedSignalType
                case 1 % Text
                    textSent = uilabel(gui.TimeComparison); 
                    guiText = {};
                    line = 1;
                    startingLine = 1;
                    for c = 1:size(decodedSignal, 2)
                        if(decodedSignal(c) == 13)
                            line = line + 1;
                            startingLine = 1;
                            continue
                        end
                        if(decodedSignal(1, c) == 0)
                            continue      
                        end
                        guiText{line, 1}(1, startingLine) = char(decodedSignal(1, c));
                        startingLine = startingLine + 1;
                        assignin('base', 'guiText', guiText);
                    end
                    textSent.Text = guiText;

                    textSent.Position = [gui.initialPosition_received_x gui.initialPosition_TimeComparison_y 200 size(guiText,1)*30];
                    textSent.BackgroundColor = [0 0.7 0];
                    gui.initialPosition_TimeComparison_y = gui.initialPosition_TimeComparison_y + 100;
                case 2 % Image
                    imageSent = uiimage(gui.TimeComparison);
                    imageSent.ImageSource = decodedSignal;
                    imageSent.Position = [gui.initialPosition_received_x gui.initialPosition_TimeComparison_y size(decodedSignal, 1) size(decodedSignal, 2)];
                    gui.initialPosition_TimeComparison_y = gui.initialPosition_TimeComparison_y + size(decodedSignal, 2);
                case 3 % Audio
                    audioSent = uiaxes(gui.TimeComparison);
                    plot(decodedSignal, 'Parent', audioSent);
                    audioSent.Position = [gui.initialPosition_received_x gui.initialPosition_TimeComparison_y 300 100];
                    audioSent.YLim = [-2 2];
                    gui.initialPosition_TimeComparison_y = gui.initialPosition_TimeComparison_y + 100;
                case 4 % Video
                otherwise
            end
    end
    if(transmittedSignalType == 3)
        sound(decodedSignal, 44100, 24);
    end
end