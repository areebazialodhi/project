% =========================================================================
% FILE        : obstacle_dodge_VF.m   (no other files needed)
% GAME        : Obstacle Dodge - collect stars, dodge asteroids
% CODE VERSION: VF 1.1
% OCTAVE      : GNU Octave 11.3.0 (graphics toolkit: qt)
% DATE        : 2026-10-08  (format: YYYY-MM-DD, ISO 8601)
% -------------------------------------------------------------------------
% AUTHORS AND CONTRIBUTIONS
%   Student 1 : AreebaziaLodhi
%   Student 2 : Annasofiakho
%   Contribution: equal contribution of the two authors to the game
%   concept, the coding, the testing, the comments and the documentation.
% -------------------------------------------------------------------------
% SOURCES (AI / sound / images / word list)
%   AI        : initial concept and game design developed by the authors;
%               code rewritten and improved with Claude (Anthropic).
%   Sound     : no sound file. Short tones are computed by the code itself
%               (sine waves) and played with audioplayer(); beep() is the
%               fallback. Key M switches the sound on and off.
%   Images    : none loaded; every shape is drawn with patch() and plot().
%   Word list : none; only our own game messages.
% -------------------------------------------------------------------------
% CONTEXT
%   Coursework for the UE TechnEx (Techniques for empirical research),
%   M1 Neurosciences, Claude Bernard Lyon 1 University, Fall 2026.
%   Arcade game in the spirit of classic "dodge and collect" games, made
%   with a figure, a keyboard callback and a main loop. A pilot flies a
%   ship through a field of stars and asteroids. Design choices: golden
%   stars are worth more but fall faster (risk versus reward), asteroid
%   walls force the player to find a gap, and the difficulty grows with
%   the score and with each round won.
%
% GOAL
%   Collect stars to reach the target score (15 points in round 1, +5 for
%   each new round) before losing your 3 lives to the asteroids.
%
% GAME COMPONENTS
%   - Ship (blue)         : controlled by the player, stays at the bottom.
%   - Star (yellow)       : +1 point.
%   - Golden star (orange): +3 points, but falls 60% faster (risk/reward).
%   - Asteroid (grey)     : touching it costs 1 life.
%   - Asteroid wall       : a row of asteroids with ONE gap to fly through.
%   - HUD                 : score / target, lives, round number.
%   - Red flash           : the screen flashes red when you are hit.
%   - Confetti            : falls on the screen when you win.
%   - Sounds              : star catch, hit, game over and win sounds.
%
% RULES
%   - You start with 3 lives. After a hit the ship blinks for 1.5 s and
%     cannot be hurt again during that time.
%   - WIN  : score reaches the target score.
%   - LOSE : lives reach 0.
%   - Missing a star costs nothing.
%
% WAYS TO MOVE
%   LEFT arrow or A  : push the ship to the left
%   RIGHT arrow or D : push the ship to the right
%   (The ship slides and slows down by itself: each press adds speed.)
%   Other keys: SPACE = start, P = pause, R = replay, M = sound on/off,
%               Q or Esc = quit
%
% MAIN LOOP (what happens every frame)
%   1. Measure the real time since the last frame (frame_time).
%   2. Read the last key command (start, replay, pause, quit).
%   3. Depending on the game state ('start', 'play', 'end'):
%        play: move the ship, spawn objects, move objects, test
%              collisions, update score and lives, test win / lose,
%              start the sounds, the red flash and the confetti.
%   4. Draw everything (ship, flame, objects, background stars, red flash,
%      confetti, HUD).
%   5. Wait briefly and repeat until the window is closed or Q is pressed.
%   All speeds are multiplied by frame_time, so the game runs at the same
%   speed on slow and fast computers.
%
% ACROSS TRIALS (replays)
%   - Spawn positions, object types, sizes and walls are random, so no two
%     games are the same.
%   - After a WIN, R starts the next round: higher target score, faster
%     falling objects, shorter delay between objects, more asteroid walls.
%   - After a LOSS, R retries the same round.
%   - Difficulty also grows inside a round as the score increases.
%   - Score, lives, objects, flash and confetti are reset at each replay.
%
% MAIN VARIABLES
%   game_state       : 'start', 'play' or 'end'
%   round_number     : current difficulty round (1, 2, 3, ...)
%   score, lives     : current points and remaining lives
%   target_score     : score needed to win this round
%   ship_x, ship_velocity : ship position and speed (horizontal)
%   objects          : list of falling things (stars, asteroids)
%   frame_time       : seconds since the previous frame
%   flash_time       : remaining time of the red flash (seconds)
%   confetti_x/_y    : positions of the confetti pieces
%   sound_enabled    : global switch for the sounds (key M)
% =========================================================================

function obstacle_dodge_VF()
    global command_request ship_push sound_enabled
    command_request = '';                                     % last key command from the keyboard callback
    ship_push = 0;                                            % sum of left/right key presses not yet used
    sound_enabled = true;                                     % sounds are on at the start (key M toggles)

    % ---------------------------------------------------------------------
    % SETTINGS (change these numbers to tune the game)
    % ---------------------------------------------------------------------
    world_width = 16;                                         % width of the game world
    world_height = 10;                                        % height of the game world
    ship_y = 1.0;                                             % vertical position of the ship
    ship_half_width = 0.40;                                   % used to keep the ship inside the screen
    ship_hit_radius = 0.45;                                   % collision size of the ship
    ship_impulse = 5.0;                                       % speed added by one key press
    ship_max_speed = 12;                                      % maximum ship speed
    ship_friction = 0.90;                                     % fraction of speed kept every 1/60 s
    starting_lives = 3;                                       % lives at the start of a round
    base_target_score = 15;                                   % target score in round 1
    invulnerable_duration = 1.5;                              % seconds of protection after a hit
    max_frame_time = 0.05;                                    % avoids huge jumps after a freeze
    flash_duration_hit = 0.30;                                % red flash length after a hit (s)
    flash_duration_lose = 0.90;                               % red flash length at game over (s)
    confetti_count = 120;                                     % number of confetti pieces

    show_rules_in_console();

    % ---------------------------------------------------------------------
    % WINDOW AND AXES (axes fill the window, so the figure can be resized)
    % ---------------------------------------------------------------------
    figure_handle = figure('Name', 'Obstacle Dodge', 'NumberTitle', 'off', ...
                           'Color', [0 0 0], 'Position', [100 100 960 600], ...
                           'KeyPressFcn', @key_press_callback);
    axes_handle = axes('Units', 'normalized', 'Position', [0 0 1 1], ...
                       'Color', [0.02 0.02 0.09], ...
                       'XLim', [0 world_width], 'YLim', [0 world_height], ...
                       'XTick', [], 'YTick', [], 'Box', 'on', ...
                       'DataAspectRatio', [1 1 1]);
    hold(axes_handle, 'on');

    % ---------------------------------------------------------------------
    % GRAPHIC OBJECTS: background stars, ship, flame, flash, confetti, texts
    % ---------------------------------------------------------------------
    background_count = 70;
    background_x = world_width * rand(1, background_count);
    background_y = world_height * rand(1, background_count);
    % Each background star falls at its own speed (parallax effect)
    background_speed = 0.5 + 1.5 * rand(1, background_count);
    background_handle = plot(axes_handle, background_x, background_y, '.', ...
                             'Color', [0.8 0.85 1], 'MarkerSize', 5);

    ship_shape_x = [0; 0.40; 0; -0.40];                       % ship outline (nose up)
    ship_shape_y = [0.70; -0.40; -0.15; -0.40];
    ship_handle = patch('Parent', axes_handle, 'XData', ship_shape_x, ...
                        'YData', ship_shape_y + ship_y, ...
                        'FaceColor', [0.3 0.85 1], 'EdgeColor', [1 1 1]);
    flame_handle = patch('Parent', axes_handle, 'XData', [0; 0; 0], ...
                         'YData', [0; 0; 0], 'FaceColor', [1 0.5 0.1], ...
                         'EdgeColor', 'none');

    % Red flash: a see-through red rectangle covering the whole screen
    flash_handle = patch('Parent', axes_handle, ...
                         'XData', [0; world_width; world_width; 0], ...
                         'YData', [0; 0; world_height; world_height], ...
                         'FaceColor', [1 0.1 0.1], 'FaceAlpha', 0.4, ...
                         'EdgeColor', 'none', 'Visible', 'off');

    % Confetti: 6 colour groups, each drawn as one set of small squares
    confetti_colors = [1 0.2 0.3; 1 0.85 0.1; 0.2 0.9 0.4; ...
                       0.3 0.6 1; 1 0.4 0.9; 1 1 1];
    confetti_group = mod(0:confetti_count - 1, 6) + 1;
    confetti_x = world_width * rand(1, confetti_count);
    confetti_y = world_height * (0.5 + 1.5 * rand(1, confetti_count));
    confetti_fall = 2 + 3 * rand(1, confetti_count);          % fall speeds
    confetti_phase = 2 * pi * rand(1, confetti_count);        % sway phases
    confetti_handles = zeros(1, 6);
    for g = 1:6
        confetti_handles(g) = plot(axes_handle, NaN, NaN, 's', ...
                                   'MarkerSize', 7, ...
                                   'MarkerFaceColor', confetti_colors(g, :), ...
                                   'MarkerEdgeColor', 'none', 'Visible', 'off');
    end

    hud_handle = text(0.3, world_height - 0.3, '', 'Parent', axes_handle, ...
                      'Color', [1 1 1], 'FontSize', 12, ...
                      'VerticalAlignment', 'top');
    message_handle = text(world_width / 2, world_height / 2, '', ...
                          'Parent', axes_handle, 'Color', [1 1 1], ...
                          'FontSize', 13, 'HorizontalAlignment', 'center', ...
                          'VerticalAlignment', 'middle', ...
                          'BackgroundColor', [0.05 0.05 0.25], ...
                          'EdgeColor', [1 1 1], 'Visible', 'off');

    % ---------------------------------------------------------------------
    % GAME VARIABLES (initial values)
    % ---------------------------------------------------------------------
    game_state = 'start';
    round_number = 1;
    last_result_won = false;
    objects = [];
    ship_x = world_width / 2;
    ship_velocity = 0;
    score = 0;
    lives = starting_lives;
    target_score = base_target_score;
    time_since_spawn = 0;
    invulnerable_time = 0;
    is_paused = false;
    flash_time = 0;                                           % remaining red flash time
    flash_total = flash_duration_hit;                         % total length of the current flash
    flash_strength = 0.4;                                     % maximum opacity of the current flash
    confetti_active = false;                                  % true only on the win screen

    show_message(message_handle, start_screen_text());

    frame_timer = tic;

    % ---------------------------------------------------------------------
    % MAIN LOOP
    % ---------------------------------------------------------------------
    while ishandle(figure_handle)

        % 1. Real time since the previous frame
        frame_time = min(toc(frame_timer), max_frame_time);
        frame_timer = tic;

        % 2. Read and clear the last keyboard command
        command = command_request;
        command_request = '';
        if strcmp(command, 'quit')
            break;
        end

        begin_round = false;

        % 3. Update the game depending on its state
        switch game_state

            case 'start'
                ship_push = 0;
                if strcmp(command, 'start')
                    begin_round = true;
                end

            case 'play'
                if strcmp(command, 'replay')
                    begin_round = true;
                elseif strcmp(command, 'pause')
                    is_paused = ~is_paused;
                    ship_push = 0;
                    if is_paused
                        show_message(message_handle, 'PAUSED - press P to continue');
                    else
                        show_message(message_handle, '');
                    end
                end

                if is_paused
                    ship_push = 0;                            % keys pressed during the pause are ignored
                end

                if ~is_paused && ~begin_round

                    % --- ship movement (speed, friction, screen limits)
                    ship_velocity = ship_velocity + ship_push * ship_impulse;
                    ship_push = 0;
                    ship_velocity = max(min(ship_velocity, ship_max_speed), -ship_max_speed);
                    ship_velocity = ship_velocity * ship_friction ^ (frame_time * 60);
                    ship_x = ship_x + ship_velocity * frame_time;
                    if ship_x < ship_half_width
                        ship_x = ship_half_width;
                        ship_velocity = 0;
                    elseif ship_x > world_width - ship_half_width
                        ship_x = world_width - ship_half_width;
                        ship_velocity = 0;
                    end

                    % --- difficulty depends on round and current score
                    fall_speed = min(9, 2.5 + 0.5 * (round_number - 1) + 0.07 * score);
                    spawn_interval = max(0.30, 0.95 - 0.06 * (round_number - 1) - 0.012 * score);
                    wall_probability = min(0.25, 0.08 + 0.03 * (round_number - 1));

                    % --- spawn new objects
                    time_since_spawn = time_since_spawn + frame_time;
                    if time_since_spawn >= spawn_interval
                        time_since_spawn = 0;
                        if rand() < wall_probability
                            % asteroid wall with one random gap
                            slot_positions = 1:2:world_width - 1;
                            gap_index = randi(numel(slot_positions));
                            for slot = 1:numel(slot_positions)
                                if slot ~= gap_index
                                    new_object = spawn_object(axes_handle, 'asteroid', ...
                                                              slot_positions(slot), world_height + 1);
                                    % All asteroids of a wall fall at the same speed
                                    new_object.speed_factor = 1.0;
                                    objects = add_object(objects, new_object);
                                end
                            end
                            time_since_spawn = -1.0;          % extra pause after a wall
                        else
                            spawn_x = 0.8 + (world_width - 1.6) * rand();
                            kind_roll = rand();
                            if kind_roll < 0.55
                                kind = 'asteroid';
                            elseif kind_roll < 0.88
                                kind = 'star';
                            else
                                kind = 'golden';
                            end
                            new_object = spawn_object(axes_handle, kind, spawn_x, world_height + 1);
                            objects = add_object(objects, new_object);
                        end
                    end

                    % --- move objects, test collisions (backwards: safe deletion)
                    invulnerable_time = max(0, invulnerable_time - frame_time);
                    hit_happened = false;                     % an asteroid hit the ship this frame
                    star_happened = false;                    % a star was caught this frame
                    for k = numel(objects):-1:1
                        objects(k).y = objects(k).y - objects(k).speed_factor * fall_speed * frame_time;
                        objects(k).spin_angle = objects(k).spin_angle + objects(k).spin_rate * frame_time;
                        [vertex_x, vertex_y] = object_vertices(objects(k));
                        set(objects(k).handle, 'XData', vertex_x, 'YData', vertex_y);

                        distance = hypot(objects(k).x - ship_x, objects(k).y - ship_y);
                        touching = distance < (objects(k).hit_radius + ship_hit_radius);
                        remove_object = false;

                        if touching
                            if strcmp(objects(k).kind, 'asteroid')
                                if invulnerable_time <= 0
                                    lives = lives - 1;
                                    invulnerable_time = invulnerable_duration;
                                    remove_object = true;
                                    hit_happened = true;
                                end
                            else
                                score = score + objects(k).points;
                                remove_object = true;
                                star_happened = true;
                            end
                        end

                        if objects(k).y < -1.5
                            remove_object = true;             % left the screen
                        end

                        if remove_object
                            delete(objects(k).handle);
                            objects(k) = [];
                        end
                    end

                    % --- win / lose test, sounds and visual effects
                    if score >= target_score
                        game_state = 'end';
                        last_result_won = true;
                        show_message(message_handle, sprintf( ...
                            ['YOU WIN!\n\nScore: %d (target %d)\n\n' ...
                             'R = next round (harder)    Q = quit'], score, target_score));
                        play_sound('win');
                        confetti_active = true;               % start the confetti
                        confetti_x = world_width * rand(1, confetti_count);
                        confetti_y = world_height * (0.5 + 1.5 * rand(1, confetti_count));
                        set(confetti_handles, 'Visible', 'on');
                    elseif lives <= 0
                        game_state = 'end';
                        last_result_won = false;
                        show_message(message_handle, sprintf( ...
                            ['GAME OVER\n\nScore: %d (target %d)\n\n' ...
                             'R = try again    Q = quit'], score, target_score));
                        play_sound('lose');
                        flash_time = flash_duration_lose;     % long red flash
                        flash_total = flash_duration_lose;
                        flash_strength = 0.55;
                    else
                        if hit_happened
                            play_sound('hit');
                            flash_time = flash_duration_hit;  % short red flash
                            flash_total = flash_duration_hit;
                            flash_strength = 0.35;
                        end
                        if star_happened
                            play_sound('star');
                        end
                    end
                end

            case 'end'
                ship_push = 0;
                if strcmp(command, 'replay') || strcmp(command, 'start')
                    if last_result_won
                        round_number = round_number + 1;      % harder next round
                    end
                    begin_round = true;
                end
        end

        % Start a new round (first game or replay)
        if begin_round
            objects = clear_objects(objects);
            score = 0;
            lives = starting_lives;
            ship_x = world_width / 2;
            ship_velocity = 0;
            ship_push = 0;
            target_score = base_target_score + 5 * (round_number - 1);
            time_since_spawn = 0;
            invulnerable_time = 0;
            is_paused = false;
            flash_time = 0;                                   % clear the red flash
            confetti_active = false;                          % clear the confetti
            set(confetti_handles, 'Visible', 'off');
            game_state = 'play';
            show_message(message_handle, '');
        end

        % 4. Draw everything
        background_y = background_y - background_speed * frame_time;
        below_screen = background_y < 0;
        background_y(below_screen) = background_y(below_screen) + world_height;
        set(background_handle, 'XData', background_x, 'YData', background_y);

        set(ship_handle, 'XData', ship_x + ship_shape_x, 'YData', ship_y + ship_shape_y);
        flame_length = 0.30 + 0.30 * rand();                  % flickering flame
        set(flame_handle, 'XData', [ship_x - 0.15; ship_x + 0.15; ship_x], ...
                          'YData', [ship_y - 0.30; ship_y - 0.30; ship_y - 0.30 - flame_length]);

        if invulnerable_time > 0 && mod(floor(invulnerable_time * 12), 2) == 0
            set(ship_handle, 'Visible', 'off');               % blinking after a hit
        else
            set(ship_handle, 'Visible', 'on');
        end

        % Red flash: fades out while flash_time goes down to 0
        if flash_time > 0
            flash_time = max(0, flash_time - frame_time);
            set(flash_handle, 'FaceAlpha', flash_strength * flash_time / flash_total, ...
                              'Visible', 'on');
        else
            set(flash_handle, 'Visible', 'off');
        end

        % Confetti: pieces fall, sway sideways and come back at the top
        if confetti_active
            confetti_y = confetti_y - confetti_fall * frame_time;
            confetti_phase = confetti_phase + 3 * frame_time;
            gone = confetti_y < -0.5;
            confetti_y(gone) = world_height + rand(1, sum(gone));
            shown_x = confetti_x + 0.6 * sin(confetti_phase);
            for g = 1:6
                members = (confetti_group == g);
                set(confetti_handles(g), 'XData', shown_x(members), ...
                                         'YData', confetti_y(members));
            end
        end

        if strcmp(game_state, 'start')
            set(hud_handle, 'String', '');
        else
            set(hud_handle, 'String', sprintf('Score: %d / %d     Lives: %s     Round: %d', ...
                score, target_score, repmat('<3 ', 1, max(lives, 0)), round_number));
        end

        drawnow;
        pause(0.015);
    end

    % ---------------------------------------------------------------------
    % END OF THE PROGRAM
    % ---------------------------------------------------------------------
    fprintf('Thanks for playing Obstacle Dodge!\n');
    if ishandle(figure_handle)
        close(figure_handle);
    end
endfunction


% =========================================================================
% KEYBOARD CALLBACK: called by Octave every time a key is pressed
% =========================================================================
function key_press_callback(~, event_data)
    global command_request ship_push sound_enabled
    switch lower(event_data.Key)
        case {'leftarrow', 'a'}
            ship_push = ship_push - 1;
        case {'rightarrow', 'd'}
            ship_push = ship_push + 1;
        case {'space', 'return'}
            command_request = 'start';
        case 'r'
            command_request = 'replay';
        case 'p'
            command_request = 'pause';
        case 'm'
            sound_enabled = ~sound_enabled;                   % sound on / off
        case {'q', 'escape'}
            command_request = 'quit';
    end
endfunction


% =========================================================================
% Create one falling object (asteroid, star or golden star) with its shape
% =========================================================================
function new_object = spawn_object(axes_handle, kind, x, y)
    switch kind
        case 'asteroid'
            vertex_count = 9;
            size_scale = 0.5 + 0.5 * rand();
            angles = (0:vertex_count - 1) * 2 * pi / vertex_count;
            % Random radii give each asteroid a rough rock shape
            radii = size_scale * (0.7 + 0.4 * rand(1, vertex_count));
            hit_radius = 0.8 * size_scale;
            points = 0;
            speed_factor = 0.8 + 0.4 * rand();
            face_color = [0.55 0.42 0.38];
            edge_color = [0.8 0.7 0.6];
        case 'star'
            size_scale = 0.40;
            angles = (0:9) * 2 * pi / 10 + pi / 2;
            radii = size_scale * repmat([1 0.45], 1, 5);      % 5 points
            hit_radius = 0.9 * size_scale;
            points = 1;
            speed_factor = 1.0;
            face_color = [1 0.9 0.3];
            edge_color = [1 1 1];
        otherwise                                             % golden star: worth more, falls faster
            size_scale = 0.55;
            angles = (0:9) * 2 * pi / 10 + pi / 2;
            radii = size_scale * repmat([1 0.45], 1, 5);
            hit_radius = 0.9 * size_scale;
            points = 3;
            speed_factor = 1.6;
            face_color = [1 0.55 0.1];
            edge_color = [1 1 0.6];
    end
    spin_rate = (rand() - 0.5) * 3;                           % radians per second

    new_object = struct('kind', kind, 'x', x, 'y', y, 'angles', angles, ...
                        'radii', radii, 'hit_radius', hit_radius, ...
                        'points', points, 'speed_factor', speed_factor, ...
                        'spin_angle', 0, 'spin_rate', spin_rate, 'handle', 0);
    [vertex_x, vertex_y] = object_vertices(new_object);
    new_object.handle = patch('Parent', axes_handle, 'XData', vertex_x, ...
                              'YData', vertex_y, 'FaceColor', face_color, ...
                              'EdgeColor', edge_color);
endfunction


% =========================================================================
% Corner points of an object at its current position and rotation
% =========================================================================
function [vertex_x, vertex_y] = object_vertices(object)
    vertex_x = (object.x + object.radii .* cos(object.angles + object.spin_angle))';
    vertex_y = (object.y + object.radii .* sin(object.angles + object.spin_angle))';
endfunction


% =========================================================================
% Add one object to the list (handles the empty list case)
% =========================================================================
function objects = add_object(objects, new_object)
    if isempty(objects)
        objects = new_object;
    else
        objects(end + 1) = new_object;
    end
endfunction


% =========================================================================
% Delete every object from the screen and empty the list
% =========================================================================
function objects = clear_objects(objects)
    for k = 1:numel(objects)
        delete(objects(k).handle);
    end
    objects = [];
endfunction


% =========================================================================
% Show a message in the middle of the screen (empty text hides it)
% =========================================================================
function show_message(message_handle, message_text)
    set(message_handle, 'String', message_text);
    if isempty(message_text)
        set(message_handle, 'Visible', 'off');
    else
        set(message_handle, 'Visible', 'on');
    end
endfunction


% =========================================================================
% Text of the start screen (rules and controls)
% =========================================================================
function start_text = start_screen_text()
    start_text = sprintf(['   OBSTACLE DODGE   \n\n' ...
        'GOAL: reach the target score (15 points in round 1)\n' ...
        'before losing all 3 lives.\n' ...
        'After a hit you are safe for 1.5 seconds.\n\n' ...
        'Yellow star = +1 point\n' ...
        'Orange star = +3 points (falls fast: risky!)\n' ...
        'Grey asteroid = lose 1 life\n' ...
        'Asteroid wall = find the gap!\n\n' ...
        'MOVE: LEFT / RIGHT arrows or A / D (the ship slides)\n' ...
        'P = pause   R = replay   M = sound on/off   Q = quit\n\n' ...
        'Click this window, then press SPACE to start']);
endfunction


% =========================================================================
% Print the rules in the Command Window
% =========================================================================
function show_rules_in_console()
    fprintf('\n=====================================\n');
    fprintf('           OBSTACLE DODGE\n');
    fprintf('=====================================\n');
    fprintf('Goal : reach the target score before losing 3 lives.\n');
    fprintf('Stars: yellow +1, orange +3 (faster). Asteroids: -1 life.\n');
    fprintf('Move : LEFT/RIGHT arrows or A/D.\n');
    fprintf('Keys : SPACE start, P pause, R replay, M sound, Q quit.\n');
    fprintf('Click the game window before pressing keys.\n\n');
endfunction


% =========================================================================
% Play a short sound: 'star', 'hit', 'lose' or 'win'. The waveform is
% computed here (no sound file). It never stops the game if sound fails.
% =========================================================================
function play_sound(sound_kind)
    global sound_enabled
    persistent player_list player_count
    if isempty(sound_enabled) || ~sound_enabled
        return;                                               % sound is switched off
    end
    if isempty(player_list)
        player_list = cell(1, 8);                             % keeps the players alive
        player_count = 0;
    end

    sample_rate = 22050;                                      % samples per second
    switch sound_kind
        case 'star'                                           % rising "gulp" sound
            t = 0:1 / sample_rate:0.20;
            wave = sin(2 * pi * (500 * t + 1250 * t .^ 2)) .* exp(-9 * t);
        case 'hit'                                            % low harsh buzz
            t = 0:1 / sample_rate:0.25;
            wave = 0.7 * sign(sin(2 * pi * 80 * t)) .* exp(-10 * t) ...
                   + 0.3 * (rand(size(t)) - 0.5) .* exp(-12 * t);
        case 'lose'                                           % four falling notes
            notes = [392 330 262 196];
            wave = [];
            for n = 1:numel(notes)
                t = 0:1 / sample_rate:0.28;
                wave = [wave, sin(2 * pi * notes(n) * t) .* exp(-3 * t)];
            end
        case 'win'                                            % four rising notes
            notes = [523 659 784 1047];
            wave = [];
            for n = 1:numel(notes)
                if n == numel(notes)
                    note_length = 0.50;
                else
                    note_length = 0.13;
                end
                t = 0:1 / sample_rate:note_length;
                wave = [wave, sin(2 * pi * notes(n) * t) .* exp(-2 * t)];
            end
        otherwise
            return;
    end
    wave = 0.8 * wave / max(abs(wave));                       % normalise the volume

    try
        player_count = mod(player_count, numel(player_list)) + 1;
        player_list{player_count} = audioplayer(wave, sample_rate);
        play(player_list{player_count});                      % play without waiting
    catch
        if any(strcmp(sound_kind, {'hit', 'lose'}))
            try
                beep();                                       % simple fallback
            catch
                % no sound available: ignore
            end_try_catch
        end
    end_try_catch
endfunction
