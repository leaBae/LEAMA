%% Gabor Matrices
%
% This script executes the paradigm with Gabor Matrices of Lea's MA.
%
% This code requires PsychToolbox. https://psychtoolbox.org
% This was tested with PsychToolbox version 3.0.15, and with MATLAB R2022a.

%% EEG and ET
if TRAINING == 0
    % Start recording EEG
    disp('STARTING EEG RECORDING...');
    initEEG;
end

% Calibrate ET (Tobii Pro Fusion)
disp('CALIBRATING ET...');
calibrateET

%% Task
HideCursor(whichScreen);

% define triggers
TASK_START = 10;
FIXATION = 15; % trigger for fixation cross
PRESENTATION1 = 21; % trigger for presentation of high skewed matrix
PRESENTATION2 = 22; % trigger for presentation of high vertical matrix
PRESENTATION3 = 23; % trigger for presentation of low skewed matrix
PRESENTATION4 = 24; % trigger for presentation of low vertical matrix
STIMOFF = 29; % trigger for change of digit to cfi
BLOCK0 = 39; % trigger for start of training block
BLOCK1 = 31; % trigger for start of task (block)
ENDBLOCK0 = 49; % trigger for end of training block
ENDBLOCK1 = 41; % trigger for end of task (block)
RESP_CHANGE = 87; % trigger for response yes (spacebar)
NO_RESP = 88; % trigger for response no (no input)
RESP_WRONG = 89; % trigger for wrong keyboard input response
TASK_END = 90;

% Set up experiment parameters
% Number of trials for the experiment
if TRAINING == 1
    experiment.nTrials = 12;
else
    experiment.nTrials = 400;           % 1 blocks x 400 trials = 400 trials
end

% Set up equipment parameters
equipment.viewDist = 800;               % Viewing distance in millimetres
equipment.ppm = 3.6;                    % Pixels per millimetre !! NEEDS TO BE SET. USE THE MeasureDpi FUNCTION !!
equipment.greyVal = .5;
equipment.blackVal = 0;
equipment.whiteVal = 1;
equipment.gammaVals = [1 1 1];          % The gamma values for color calibration of the monitor

% Set up stimulus parameters Fixation
stimulus.fixationOn = 1;                % Toggle fixation on (1) or off (0)
stimulus.fixationSize_dva = .5;         % Size of fixation cross in degress of visual angle
stimulus.fixationColor = [1 0 0];       % Color of fixation cross (1 = white, 0 = black, [1 0 0] = red)
stimulus.fixationLineWidth = 3;         % Line width of fixation cross

% Location
stimulus.regionHeight_dva = 7.3;         % Height of the region
stimulus.regionWidth_dva = 4;            % Width of the region
stimulus.regionEccentricity_dva = 3;     % Eccentricity of regions from central fixation

% Set up color parameters
stimulus.nColors = 2;                   % Number of colors used in the experiment
color.white = [255, 255, 255];
color.grey = [128, 128, 128];
color.textVal = 0;                      % Color of text (0 = black)

% Set up text parameters
text.instructionFont = 'Menlo';         % Font of instruction text
text.instructionPoints = 12;            % Size of instruction text (This if overwritten by )
text.instructionStyle = 0;              % Styling of instruction text (0 = normal)
text.instructionWrap = 80;              % Number of characters at which to wrap instruction text
text.color = 0;                         % Color of text (0 = black)

% Define startExperimentText
if TRAINING == 1
    loadingText = 'Loading training task...';
    startExperimentText = ['Training task. \n\n' ...
        'You will see a series of gratings. \n\n' ...
        'Your task is to press SPACE if you see a grating with a vertical orientation. \n\n' ...
        'Otherwise, do not press any button. \n\n' ...
        'Please always use your right hand.' ...
        '\n\n Don''t worry, you can do a training sequence in the beginning. \n\n' ...
        '\n\n Press any key to continue.'];
elseif TRAINING == 0
    loadingText = 'Loading test task...';
    startExperimentText = ['Test task. \n\n' ...
        'You will see a series of gratings. \n\n' ...
        'Your task is to press SPACE if you see a grating with a vertical orientation. \n\n' ...
        'Otherwise, do not press any button. \n\n' ...
        'Please always use your right hand.' ...
        '\n\n Press any key to continue.'];
end

% Set up temporal parameters (all in seconds)
timing.blank = 1;                               % Duration of blank screen

% Shuffle rng for random elements
rng('default');
rng('shuffle');                     % Use MATLAB twister for rng

% Set up Psychtoolbox Pipeline
AssertOpenGL;

% Imaging set up
screenID = whichScreen;
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
Screen('Preference', 'SkipSyncTests', 0); % For linux

% Window set-up
[ptbWindow, winRect] = PsychImaging('OpenWindow', screenID, equipment.greyVal);
PsychColorCorrection('SetEncodingGamma', ptbWindow, equipment.gammaVals);
[screenWidth, screenHeight] = RectSize(winRect);
screenCentreX = round(screenWidth/2);
screenCentreY = round(screenHeight/2);
flipInterval = Screen('GetFlipInterval', ptbWindow);
Screen('BlendFunction', ptbWindow, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
experiment.runPriority = MaxPriority(ptbWindow);

% Set font size for instructions and stimuli
Screen('TextSize', ptbWindow, 40);

global psych_default_colormode;                     % Sets colormode to be unclamped 0-1 range.
psych_default_colormode = 1;

global ptb_drawformattedtext_disableClipping;       % Disable clipping of text
ptb_drawformattedtext_disableClipping = 1;

% Show loading text
DrawFormattedText(ptbWindow,loadingText,'center','center',color.textVal);
Screen('Flip',ptbWindow);

% Retrieve response key
spaceKeyCode = KbName('Space'); % Retrieve key code for spacebar

% Calculate equipment parameters
equipment.mpd = (equipment.viewDist/2)*tan(deg2rad(2*stimulus.regionEccentricity_dva))/stimulus.regionEccentricity_dva; % Millimetres per degree
equipment.ppd = equipment.ppm*equipment.mpd;    % Pixels per degree

% Fix coordiantes for fixation cross
stimulus.fixationSize_pix = round(stimulus.fixationSize_dva*equipment.ppd);
fixHorizontal = [round(-stimulus.fixationSize_pix/2) round(stimulus.fixationSize_pix/2) 0 0];
fixVertical = [0 0 round(-stimulus.fixationSize_pix/2) round(stimulus.fixationSize_pix/2)];
fixCoords = [fixHorizontal; fixVertical];

% Create data structure for preallocating data
data = struct;
data.digitSequence = 0;
data.trialMatch(1:experiment.nTrials) = NaN;
data.allResponses(1:experiment.nTrials) = NaN;
data.allCorrect(1:experiment.nTrials) = NaN;
data.stims(1:experiment.nTrials) = NaN;

% Preallocate reaction time varible
reactionTime(1:experiment.nTrials) = 0;

% Define videoSequence and save
ShuffleVideos;
data.videoSequence = videoSequence;

% Show task instruction text
DrawFormattedText(ptbWindow,startExperimentText,'center','center',color.textVal);
startExperimentTime = Screen('Flip',ptbWindow);
disp('Participant is reading the instructions.');
waitResponse = 1;
while waitResponse
    [time, keyCode] = KbWait(-1,2);
    waitResponse = 0;
end

% Send triggers: task starts. If training, send only ET triggers
if TRAINING == 1
    %     EThndl.sendMessage(TASK_START); % ET
    Eyelink('Message', num2str(TASK_START));
    Eyelink('command', 'record_status_message "TASK_START"');
else
    %     EThndl.sendMessage(TASK_START); % ET
    Eyelink('Message', num2str(TASK_START));
    Eyelink('command', 'record_status_message "TASK_START"');
    sendtrigger(TASK_START,port,SITE,stayup); % EEG
end

% Send triggers for block and output
if TRAINING == 1 % Training condition
    TRIGGER = BLOCK0;
elseif TRAINING == 0 && BLOCK == 1
    TRIGGER = BLOCK1;
end

if TRAINING == 1
    %     EThndl.sendMessage(TRIGGER);
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "START BLOCK"');
else
    %     EThndl.sendMessage(TRIGGER);
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "START BLOCK"');
    sendtrigger(TRIGGER,port,SITE,stayup);
end

if TRAINING == 1
    disp('Start of Training Block.');
else
    disp(['Start of Block ' num2str(BLOCK)]);
end
HideCursor(whichScreen);

% Set photodiode trigger
baseRect = [0 0 15 15];
Rec2plot = CenterRectOnPointd(baseRect, 0, screenHeight - 10);

%% Experiment Loop
noFixation = 0;

for thisTrial = 1:experiment.nTrials
    %% Define stimulus or CFI trial
    if mod(thisTrial,2) == 1
        % CFI trial
        moviename = '/home/methlab/Desktop/LEAMA/videoCFI.mp4';
    elseif mod(thisTrial,2) == 0
        % Stimulus trial
        if videoSequence(thisTrial/2) == 1
            moviename = [ MOV_PATH '/high.mp4' ];
        elseif videoSequence(thisTrial/2) == 2
            moviename = [ MOV_PATH '/high_vertical.mp4' ];
        elseif videoSequence(thisTrial/2) == 3
            moviename = [ MOV_PATH '/low.mp4' ];
        elseif videoSequence(thisTrial/2) == 4
            moviename = [ MOV_PATH '/low_vertical.mp4' ];
        end
%         moviename = [ MOV_PATH '/high-vertical_small.mp4' ];
    end

    %% Start trial

    if mod(thisTrial,2) == 0
        disp(['Start of Trial ' num2str(thisTrial/2)]); % Output of current trial iteration
    end

    %     if thisTrial == 1
    %         Screen('DrawLines',ptbWindow,fixCoords,stimulus.fixationLineWidth,stimulus.fixationColor,[screenCentreX screenCentreY],2); % Draw fixation cross
    %         Screen('Flip', ptbWindow);
    %         TRIGGER = FIXATION;
    %
    %         if TRAINING == 1
    %             %         EThndl.sendMessage(TRIGGER);
    %             Eyelink('Message', num2str(TRIGGER));
    %             Eyelink('command', 'record_status_message "FIXATION"');
    %         else
    %             %         EThndl.sendMessage(TRIGGER);
    %             Eyelink('Message', num2str(TRIGGER));
    %             Eyelink('command', 'record_status_message "FIXATION"');
    %             sendtrigger(TRIGGER,port,SITE,stayup);
    %         end
    %     end
    %     Screen('FillRect',ptbWindow,[1, 0, 0], Rec2plot);

    %% Present stimulus from videoSequence (2000ms)

    % Set windowrect for MovieDisplay
    windowrect = [];
    
    % Wait for release of possible keyboard presses
    KbReleaseWait;

    % Open window for movie (purple loading screen)
    if thisTrial == 1
        win = Screen('OpenWindow', whichScreen, 0, windowrect);
    end

    % %% Open second movie file:
    %     moviename = '/home/methlab/Desktop/LEAMA/exampleMovieType2.mp4';
    %     movie = Screen('OpenMovie', win, moviename);
    %
    %     % Start playback engine:
    %     Screen('PlayMovie', movie, 1);
    %
    %     maxTime = GetSecs + 2;
    %     while 1
    %         % Wait for next movie frame, retrieve texture handle to it
    %         tex = Screen('GetMovieImage', win, movie);
    %
    %         % Valid texture returned? A negative value means end of movie reached:
    %         %         if tex<=0
    %         %             % We're done, break out of loop:
    %         %             break;
    %         %         end
    %         runTime = GetSecs;
    %         if runTime >= maxTime
    %             break;
    %         end
    %
    %         % Draw the new texture immediately to screen:
    %         Screen('DrawTexture', win, tex);
    %         % Update display:
    %         Screen('Flip', win);
    %         % Release texture:
    %         Screen('Close', tex);
    %     end
    %
    %     % Stop playback:
    %     Screen('PlayMovie', movie, 0);
    %     % Close movie:
    %     Screen('CloseMovie', movie);

    %% Play movie file
    % Open movie file:
    movie = Screen('OpenMovie', win, moviename);

    % Start playback engine:
    Screen('PlayMovie', movie, 1);

    if mod(thisTrial,2) == 1
        % CFI trial
        TRIGGER = FIXATION;
    elseif mod(thisTrial,2) == 0
        % Stimulus trial
        if videoSequence(thisTrial/2) == 1
            TRIGGER = PRESENTATION1;
        elseif videoSequence(thisTrial/2) == 2
            TRIGGER = PRESENTATION2;
        elseif videoSequence(thisTrial/2) == 3
            TRIGGER = PRESENTATION3;
        elseif videoSequence(thisTrial/2) == 4
            TRIGGER = PRESENTATION4;
        end
    end

    if TRAINING == 1
        %         EThndl.sendMessage(TRIGGER);
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "PRESENTATION"');
    else
        %         EThndl.sendMessage(TRIGGER);
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "PRESENTATION"');
        sendtrigger(TRIGGER,port,SITE,stayup);
    end

    % Create keyboard monitoring queue with target buttons
    keyFlags = zeros(1,256); % An array of zeros
    keyFlags(spaceKeyCode) = 1; % Monitor only spaces
    %     gki = GetKeyboardIndices; % '10' hardcoded as keyboard in experimental room
    gki = 10;
    KbQueueCreate(gki, keyFlags); % Initialize the Queue

    if mod(thisTrial,2) == 1
        % CFI trial
        timing.cfi = (randsample(2000:6000, 1))/1000; % Randomize the jittered central fixation interval on trial
        maxTime = GetSecs + timing.cfi;
    elseif mod(thisTrial,2) == 0
        % Stimulus trial
        maxTime = GetSecs + 2; % Set maxTime to max. 2 seconds from start of video
    end

    % Start keyboard monitoring
    KbQueueStart(gki);
    queueStartTime = GetSecs;

    % Playback loop
    while 1
        % Wait for next movie frame, retrieve texture handle to it
        tex = Screen('GetMovieImage', win, movie);

        runTime = GetSecs;
        if runTime >= maxTime
            break;
        end

        % Draw the new texture immediately to screen:
        Screen('DrawTexture', win, tex);
        % Update display:
        Screen('Flip', win);
        % Release texture:
        Screen('Close', tex);
    end

    % Stop keyboard monitoring
    KbQueueStop(gki);
    % Get infos for key presses during KbQueue
    [~, firstPress, ~, ~, ~] = KbQueueCheck(gki);
    if mod(thisTrial,2) == 0
        % Get and save reaction time for each trial
        if firstPress > 0
            reactionTime(thisTrial/2) = firstPress - queueStartTime;
        elseif firstPress == 0
            reactionTime(thisTrial/2) = NaN;
        end
    end
    % Remove all unprocessed events from the queue and zeros out any already scored events
    KbQueueFlush(gki);
    % Release queue-associated resources
    KbQueueRelease(gki);

    if mod(thisTrial,2) == 0
        % Save responses (RESPONSE TIMESTAMPS ARE WRONG --> use reactionTime) and send triggers
        if firstPress > 0
            data.allResponses(thisTrial/2) = spaceKeyCode;
            TRIGGER = RESP_CHANGE;
        elseif firstPress == 0
            data.allResponses(thisTrial/2) = 0;
            TRIGGER = NO_RESP;
        end
    end

    % Stop playback:
    Screen('PlayMovie', movie, 0);
    % Close movie:
    Screen('CloseMovie', movie);

    if mod(thisTrial,2) == 0
        % Check if response was correct
        if videoSequence(thisTrial/2) == 1 && data.allResponses(thisTrial/2) == 0 % Skewed + NO button press = correct answer
            data.allCorrect(thisTrial/2) = 1;
        elseif videoSequence(thisTrial/2) == 2 && data.allResponses(thisTrial/2) == spaceKeyCode % Vert + button press
            data.allCorrect(thisTrial/2) = 1;
        elseif videoSequence(thisTrial/2) == 3 && data.allResponses(thisTrial/2) == 0 % Skewed + NO button press = correct answer
            data.allCorrect(thisTrial/2) = 1;
        elseif videoSequence(thisTrial/2) == 4 && data.allResponses(thisTrial/2) == spaceKeyCode % Vert + button press = correct answer
            data.allCorrect(thisTrial/2) = 1;
        else
            data.allCorrect(thisTrial/2) = 0; % Wrong response
        end
    
        % Display (in-)correct response in CW
        if data.allCorrect(thisTrial/2) == 1
            feedbackText = 'Correct!';
        elseif data.allCorrect(thisTrial/2) == 0
            feedbackText = 'Incorrect!';
        end
        disp(['Response to Trial ' num2str(thisTrial/2) ' is ' feedbackText]);
    end

    %% Jittered CFI before presentation of digit (4000ms +/- 2000ms)
    %     if thisTrial > 1
    %         timing.cfi = (randsample(2000:6000, 1))/1000; % Randomize the jittered central fixation interval on trial
    %         Screen('DrawLines',ptbWindow,fixCoords,stimulus.fixationLineWidth,stimulus.fixationColor,[screenCentreX screenCentreY],2); % Draw fixation cross
    %         Screen('Flip', ptbWindow);
    %         TRIGGER = FIXATION;
    %
    %         if TRAINING == 1
    %             %         EThndl.sendMessage(TRIGGER);
    %             Eyelink('Message', num2str(TRIGGER));
    %             Eyelink('command', 'record_status_message "FIXATION"');
    %         else
    %             %         EThndl.sendMessage(TRIGGER);
    %             Eyelink('Message', num2str(TRIGGER));
    %             Eyelink('command', 'record_status_message "FIXATION"');
    %             sendtrigger(TRIGGER,port,SITE,stayup);
    %         end
    %
    %         WaitSecs(timing.cfi);                            % Wait duration of the jittered central fixation interval
    %     end
    %     %     Screen('FillRect',ptbWindow,[1, 0, 0], Rec2plot);

    %% Fixation Check

    %     % Check if subject fixate at center, give warning if not
    %     checkFixation;
    %     if noFixation > 2
    %         disp('Insufficient fixation!')
    %         noFixation = 0; % reset
    %     end

    %     Screen('DrawLines',ptbWindow,fixCoords,stimulus.fixationLineWidth,stimulus.fixationColor,[screenCentreX screenCentreY],2); % Draw fixation cross
    %     Screen('Flip', ptbWindow, [], 1);
end

Screen('CloseAll');

%% End task, save data and inform participant about accuracy and extra cash

% Send triggers to end task
endT = Screen('Flip',ptbWindow);
if TRAINING == 1
    %     EThndl.sendMessage(TASK_END,endT);
    Eyelink('Message', num2str(TASK_END));
    Eyelink('command', 'record_status_message "TASK_END"');
else
    %     EThndl.sendMessage(TASK_END,endT);
    Eyelink('Message', num2str(TASK_END));
    Eyelink('command', 'record_status_message "TASK_END"');
    sendtrigger(TASK_END,port,SITE,stayup)
end

% Send triggers for block and output
if BLOCK == 1 && TRAINING == 0
    TRIGGER = ENDBLOCK1;
elseif BLOCK == 1 && TRAINING == 1
    TRIGGER = ENDBLOCK0; % Training block
end

if TRAINING == 1
    %     EThndl.sendMessage(TRIGGER);
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "END BLOCK"');
    disp('End of Training Block.');
else
    %     EThndl.sendMessage(TRIGGER);
    Eyelink('Message', num2str(TRIGGER));
    Eyelink('command', 'record_status_message "END BLOCK"');
    sendtrigger(TRIGGER,port,SITE,stayup);
    disp(['End of Block ' num2str(BLOCK)]);
end

% Save data
subjectID = num2str(subject.ID);
filePath = fullfile(DATA_PATH, subjectID);
mkdir(filePath)
if TRAINING == 1
    fileName = [subjectID '_', TASK, '_training.mat'];
else
    fileName = [subjectID '_', TASK, '_task.mat'];
end

% % Compute accuracy and report after each block (no additional cash for training task)
% if TRAINING == 1
%     % Get sum of correct responses, but ignore first and last data point
%     totalCorrect = sum(data.allCorrect(1, 2:end-1));
%     totalTrials = thisTrial-2;
%     percentTotalCorrect = totalCorrect / totalTrials * 100;
%     format bank % Change format for display
%     feedbackBlockText = ['Your accuracy in the training task was ' num2str(percentTotalCorrect) ' %. '];
%     disp(['Participant ' subjectID ' had an accuracy of ' num2str(percentTotalCorrect) ' % in the training task.'])
%     DrawFormattedText(ptbWindow,feedbackBlockText,'center','center',color.textVal);
%     format default % Change format back to default
%     Screen('Flip',ptbWindow);
%     WaitSecs(5);
% elseif BLOCK == 1
%     % Get sum of correct responses, but ignore first and last data point
%     totalCorrect = sum(data.allCorrect(1, 2:end-1));
%     totalTrials = thisTrial-2;
%     percentTotalCorrect(BLOCK) = totalCorrect / totalTrials * 100;
%     format bank % Change format for display
%     if percentTotalCorrect(BLOCK) > 80
%         amountCHFextra(BLOCK) = percentTotalCorrect(BLOCK)*0.02;
%         feedbackBlockText = ['Your accuracy was ' num2str(percentTotalCorrect(BLOCK)) ' %. ' ...
%             '\n\n Because of your accuracy you have been awarded an additional ' num2str(amountCHFextra(BLOCK)) ' CHF.' ...
%             '\n\n Keep it up!'];
%     elseif percentTotalCorrect(BLOCK) < 80 && BLOCK == 1
%         amountCHFextra(BLOCK) = 0;
%         feedbackBlockText = ['Your accuracy was ' num2str(percentTotalCorrect(BLOCK)) ' %. ' ...
%             '\n\n Your accuracy was very low in this block. Please stay focused!'];
%         disp(['Low accuracy in Block ' num2str(BLOCK) '.']);
%     end
%     DrawFormattedText(ptbWindow,feedbackBlockText,'center','center',color.textVal);
%     disp(['Participant ' subjectID ' was awarded CHF ' num2str(amountCHFextra(BLOCK)) ' for an accuracy of ' num2str(percentTotalCorrect(BLOCK)) ' % in Block ' num2str(BLOCK) '.'])
%     format default % Change format back to default
%     Screen('Flip',ptbWindow);
%     WaitSecs(5);
% end

% Save data
saves = struct;
saves.data = data;
saves.data.spaceKeyCode = spaceKeyCode;
saves.experiment = experiment;
saves.screenWidth = screenWidth;
saves.screenHeight = screenHeight;
saves.screenCentreX = screenCentreX;
saves.screenCentreY = screenCentreY;
saves.startExperimentTime = startExperimentTime;
saves.startExperimentText = startExperimentText;
saves.stimulus = stimulus;
saves.subjectID = subjectID;
saves.subject = subject;
saves.text = text;
saves.timing = timing;
saves.waitResponse = waitResponse;
saves.flipInterval = flipInterval;
saves.reactionTime = reactionTime;

% Save triggers
trigger = struct;
trigger.TASK_START = TASK_START;
trigger.FIXATION = FIXATION;
trigger.PRESENTATION1 = PRESENTATION1;
trigger.PRESENTATION2 = PRESENTATION2;
trigger.PRESENTATION3 = PRESENTATION3;
trigger.PRESENTATION4 = PRESENTATION4;
trigger.STIMOFF = STIMOFF;
trigger.BLOCK0 = BLOCK0;
trigger.BLOCK1 = BLOCK1;
trigger.ENDBLOCK0 = ENDBLOCK0;
trigger.ENDBLOCK1 = ENDBLOCK1;
trigger.RESP_YES = RESP_CHANGE;
trigger.RESP_NO = NO_RESP;
trigger.RESP_WRONG = RESP_WRONG;
trigger.TASK_END = TASK_END;

% stop and close EEG and ET recordings
if TRAINING == 1
    disp('TRAINING FINISHED...');
else
    disp(['BLOCK ' num2str(BLOCK) ' FINISHED...']);
end
disp('SAVING DATA...');
save(fullfile(filePath, fileName), 'saves', 'trigger');
closeEEGandET;

try
    PsychPortAudio('Close');
catch
end

% Show break instruction text
if TRAINING == 1
    if percentTotalCorrect >= THRESH
        breakInstructionText = 'Well done! \n\n Press any key to start the actual task.';
    else
        breakInstructionText = ['Score too low! ' num2str(percentTotalCorrect) ' % correct. ' ...
            '\n\n Press any key to repeat the training task.'];
    end
elseif BLOCK == 1 && TRAINING == 0
    breakInstructionText = ['End of the Task! ' ...
        '\n\n Press any key to view your stats.'];
end
DrawFormattedText(ptbWindow,breakInstructionText,'center','center',color.textVal);
Screen('Flip',ptbWindow);
waitResponse = 1;
while waitResponse
    [time, keyCode] = KbWait(-1,2);
    waitResponse = 0;
end

% Wait at least 30 Seconds between Blocks (only after Block 1 has finished, not after Block 2)
if TRAINING == 1 && percentTotalCorrect < THRESH
    waitTime = 30;
    intervalTime = 1;
    timePassed = 0;
    printTime = 30;

    waitTimeText = ['Please wait for ' num2str(printTime) ' seconds...' ...
        ' \n\n ' ...
        ' \n\n You can repeat the training task afterwards.'];

    DrawFormattedText(ptbWindow,waitTimeText,'center','center',color.textVal);
    Screen('Flip',ptbWindow);

    while timePassed < waitTime
        pause(intervalTime);
        timePassed = timePassed + intervalTime;
        printTime = waitTime - timePassed;
        waitTimeText = ['Please wait for ' num2str(printTime) ' seconds...' ...
            ' \n\n ' ...
            ' \n\n You can repeat the training task afterwards.'];
        DrawFormattedText(ptbWindow,waitTimeText,'center','center',color.textVal);
        Screen('Flip',ptbWindow);
    end
elseif BLOCK == 1 && TRAINING == 1
    waitTime = 30;
    intervalTime = 1;
    timePassed = 0;
    printTime = 30;

    waitTimeText = ['Please wait for ' num2str(printTime) ' seconds...' ...
        ' \n\n ' ...
        ' \n\n The Gabor Matrix task will start afterwards.'];

    DrawFormattedText(ptbWindow,waitTimeText,'center','center',color.textVal);
    Screen('Flip',ptbWindow);

    while timePassed < waitTime
        pause(intervalTime);
        timePassed = timePassed + intervalTime;
        printTime = waitTime - timePassed;
        waitTimeText = ['Please wait for ' num2str(printTime) ' seconds...' ...
            ' \n\n ' ...
            ' \n\n The Gabor Matrix task will start afterwards.'];
        DrawFormattedText(ptbWindow,waitTimeText,'center','center',color.textVal);
        Screen('Flip',ptbWindow);
    end
end

% Save total amount earned and display
if BLOCK == 1 && TRAINING == 0
    amountCHFextraTotal = sum(amountCHFextra);
    saves.amountCHFextraTotal = amountCHFextraTotal;
    format bank % Change format for display
    endTextCash = ['Well done! You have completed the task.' ...
        ' \n\n Because of your accuracy you have been awarded an additional ' num2str(amountCHFextraTotal) ' CHF in total.' ...
        ' \n\n ' ...
        ' \n\n ' num2str(percentTotalCorrect(1)) ' % accuracy earned you ' num2str(amountCHFextra(1)) ' CHF.' ...
        ' \n\n ' ...
        ' \n\n ' ...
        ' \n\n Press any key to end the task.'];
    DrawFormattedText(ptbWindow,endTextCash,'center','center',color.textVal); % Display output for participant
    disp(['End of Block ' num2str(BLOCK) '. Participant ' num2str(subjectID) ' has earned CHF ' num2str(amountCHFextraTotal) ' extra in total.']);
    statsCW = ['Participant' num2str(subjectID) ' earned ' num2str(amountCHFextra(1)) ' CHF for an accuracy of ' num2str(percentTotalCorrect(1)) '%'];
    disp(statsCW)
    format default % Change format back to default
    Screen('Flip',ptbWindow);
    waitResponse = 1;
    while waitResponse
        [time, keyCode] = KbWait(-1,2);
        waitResponse = 0;
    end
end

% Quit
Screen('CloseAll');