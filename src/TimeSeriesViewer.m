classdef TimeSeriesViewer < handle
%TIMESERIESVIEWER Modern interactive time series viewer.
%   app = TimeSeriesViewer() launches the application.
%
%   A programmatic App Designer app (uifigure-based) for interactive
%   exploration of time series data. Supports 1–4 linked subplot axes,
%   variable assignment via dropdowns, zoom, data labels, and event labels.
%
%   Data is stored internally as a cell array of timetables. Each timetable
%   groups variables that share a common time base. Time is implicit — there
%   is no user-facing time variable selection.

    properties (Access = private)
        % Top-level UI
        UIFigure           matlab.ui.Figure
        MainGrid           matlab.ui.container.GridLayout

        % Toolbar (Row 1)
        ToolbarGrid        matlab.ui.container.GridLayout
        LoadFileButton     matlab.ui.control.Button
        LoadSampleButton   matlab.ui.control.Button
        NumAxesLabel       matlab.ui.control.Label
        NumAxesDropdown    matlab.ui.control.DropDown

        % Variable list panel (Row 2, Col 1)
        VarPanel           matlab.ui.container.Panel
        VariableListBox    matlab.ui.control.ListBox

        % Axes panel (Row 2, Col 2)
        AxesPanel          matlab.ui.container.Panel
        AxesGrid           matlab.ui.container.GridLayout
        PlotAxes

        % Assignment row (Row 3)
        AssignmentGrid     matlab.ui.container.GridLayout
        AxisDropdowns
        AxisDropdownLabels

        % Tools row (Row 4)
        ToolsGrid          matlab.ui.container.GridLayout
        EventLabelButton   matlab.ui.control.Button
        StatusLabel        matlab.ui.control.Label

        % Data storage — timetable-based
        DataTables         cell = {}                  % cell array of timetables
        VarTableIndex      containers.Map             % variable name -> timetable index
        VariableNames      string = string.empty       % all signal variable names

        % UI state
        EventLabelEnabled  logical = false

        % Color order for plotting
        ColorOrder         double
    end

    methods (Access = public)
        function app = TimeSeriesViewer()
            app.ColorOrder = [
                0.0000 0.4470 0.7410
                0.8500 0.3250 0.0980
                0.9290 0.6940 0.1250
                0.4940 0.1840 0.5560
                0.4660 0.6740 0.1880
                0.3010 0.7450 0.9330
                0.6350 0.0780 0.1840
            ];
            app.VarTableIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            app.createComponents();
            app.disableUI();
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end

    methods (Access = private)

        % ---- UI Construction ----

        function createComponents(app)
            % Main figure
            app.UIFigure = uifigure('Name', 'Time Series Viewer', ...
                'Position', [100 100 1200 700], ...
                'HandleVisibility', 'off');

            % Main grid: 4 rows x 2 columns
            app.MainGrid = uigridlayout(app.UIFigure, [4 2]);
            app.MainGrid.RowHeight   = {'fit', '1x', 'fit', 'fit'};
            app.MainGrid.ColumnWidth = {220, '1x'};
            app.MainGrid.Padding     = [5 5 5 5];
            app.MainGrid.RowSpacing  = 5;

            % Row 1: Toolbar spanning both columns
            app.ToolbarGrid = uigridlayout(app.MainGrid, [1 5]);
            app.ToolbarGrid.Layout.Row    = 1;
            app.ToolbarGrid.Layout.Column = [1 2];
            app.ToolbarGrid.ColumnWidth   = {'fit', 'fit', '1x', 'fit', 'fit'};
            app.ToolbarGrid.Padding       = [2 2 2 2];

            app.LoadFileButton = uibutton(app.ToolbarGrid, 'push', ...
                'Text', 'Load File', ...
                'ButtonPushedFcn', @(~,~) app.loadFile());
            app.LoadFileButton.Layout.Column = 1;

            app.LoadSampleButton = uibutton(app.ToolbarGrid, 'push', ...
                'Text', 'Load Sample Data', ...
                'ButtonPushedFcn', @(~,~) app.loadSampleData());
            app.LoadSampleButton.Layout.Column = 2;

            app.NumAxesLabel = uilabel(app.ToolbarGrid, ...
                'Text', '# Axes:');
            app.NumAxesLabel.Layout.Column = 4;
            app.NumAxesLabel.HorizontalAlignment = 'right';

            app.NumAxesDropdown = uidropdown(app.ToolbarGrid, ...
                'Items', {'1','2','3','4'}, ...
                'Value', '2', ...
                'ValueChangedFcn', @(~,~) app.updateAxesLayout());
            app.NumAxesDropdown.Layout.Column = 5;

            % Row 2, Col 1: Variable list panel
            app.VarPanel = uipanel(app.MainGrid, 'Title', 'Variables');
            app.VarPanel.Layout.Row    = 2;
            app.VarPanel.Layout.Column = 1;
            varGrid = uigridlayout(app.VarPanel, [1 1]);
            varGrid.Padding = [2 2 2 2];
            app.VariableListBox = uilistbox(varGrid, ...
                'Items', {}, ...
                'Multiselect', 'on');

            % Row 2, Col 2: Axes panel
            app.AxesPanel = uipanel(app.MainGrid, 'Title', 'Plots');
            app.AxesPanel.Layout.Row    = 2;
            app.AxesPanel.Layout.Column = 2;
            app.AxesGrid = uigridlayout(app.AxesPanel, [4 1]);
            app.AxesGrid.RowHeight = {'1x','1x','1x','1x'};
            app.AxesGrid.Padding   = [5 5 5 5];
            app.AxesGrid.RowSpacing = 3;

            % Create 4 axes with built-in axes toolbars
            app.PlotAxes = gobjects(4, 1);
            for k = 1:4
                app.PlotAxes(k) = uiaxes(app.AxesGrid);
                app.PlotAxes(k).Layout.Row = k;
                app.PlotAxes(k).XGrid = 'on';
                app.PlotAxes(k).YGrid = 'on';
                title(app.PlotAxes(k), "");
                xlabel(app.PlotAxes(k), "");
                ylabel(app.PlotAxes(k), "");
                axtoolbar(app.PlotAxes(k), {'datacursor','pan','zoomin','zoomout','restoreview'});
            end

            % Row 3: Assignment dropdowns spanning both columns
            app.AssignmentGrid = uigridlayout(app.MainGrid, [1 8]);
            app.AssignmentGrid.Layout.Row    = 3;
            app.AssignmentGrid.Layout.Column = [1 2];
            app.AssignmentGrid.ColumnWidth   = repmat({'fit', '1x'}, 1, 4);
            app.AssignmentGrid.Padding       = [5 2 5 2];

            app.AxisDropdowns      = gobjects(4, 1);
            app.AxisDropdownLabels = gobjects(4, 1);
            for k = 1:4
                app.AxisDropdownLabels(k) = uilabel(app.AssignmentGrid, ...
                    'Text', sprintf('Axis %d:', k));
                app.AxisDropdownLabels(k).Layout.Column = 2*(k-1) + 1;

                app.AxisDropdowns(k) = uidropdown(app.AssignmentGrid, ...
                    'Items', {}, ...
                    'Editable', 'off', ...
                    'ValueChangedFcn', @(~,~) app.plotAxis(k));
                app.AxisDropdowns(k).Layout.Column = 2*(k-1) + 2;
            end

            % Row 4: Tools row spanning both columns
            app.ToolsGrid = uigridlayout(app.MainGrid, [1 3]);
            app.ToolsGrid.Layout.Row    = 4;
            app.ToolsGrid.Layout.Column = [1 2];
            app.ToolsGrid.ColumnWidth   = {'fit', '1x', 'fit'};
            app.ToolsGrid.Padding       = [5 2 5 2];

            app.EventLabelButton = uibutton(app.ToolsGrid, 'push', ...
                'Text', 'Event Labels', ...
                'ButtonPushedFcn', @(~,~) app.onEventLabelToggle());
            app.EventLabelButton.Layout.Column = 1;

            app.StatusLabel = uilabel(app.ToolsGrid, ...
                'Text', 'Ready — load a file to begin');
            app.StatusLabel.Layout.Column = 3;

            % Initial layout
            app.updateAxesLayout();
        end

        function disableUI(app)
            app.NumAxesDropdown.Enable  = 'off';
            app.VariableListBox.Enable  = 'off';
            app.EventLabelButton.Enable = 'off';
            for k = 1:4
                app.AxisDropdowns(k).Enable = 'off';
            end
        end

        function enableUI(app)
            app.NumAxesDropdown.Enable  = 'on';
            app.VariableListBox.Enable  = 'on';
            app.EventLabelButton.Enable = 'on';
            numAx = str2double(app.NumAxesDropdown.Value);
            for k = 1:4
                if k <= numAx
                    app.AxisDropdowns(k).Enable = 'on';
                else
                    app.AxisDropdowns(k).Enable = 'off';
                end
            end
        end

        % ---- Data Loading ----

        function loadFile(app)
            [file, path] = uigetfile({'*.mat','MAT files'; '*.csv','CSV files'}, ...
                'Select Data File');
            if isequal(file, 0)
                return
            end
            fullPath = fullfile(path, file);
            [~, ~, ext] = fileparts(fullPath);

            try
                if strcmpi(ext, '.mat')
                    raw = load(fullPath);
                    app.loadFromMatStruct(raw);
                elseif strcmpi(ext, '.csv')
                    tbl = readtable(fullPath);
                    app.loadFromTable(tbl);
                end
                app.StatusLabel.Text = sprintf('Loaded: %s  (%d variables)', ...
                    file, numel(app.VariableNames));
            catch e
                uialert(app.UIFigure, e.message, 'Load Error');
            end
        end

        function loadSampleData(app)
            try
                tables = generateSampleData();
                app.setTimetables(tables);
                app.StatusLabel.Text = sprintf('Sample data loaded  (%d variables)', ...
                    numel(app.VariableNames));
            catch e
                uialert(app.UIFigure, e.message, 'Sample Data Error');
            end
        end

        function loadFromMatStruct(app, raw)
            % Load a struct produced by load(). Handles two cases:
            %   1) Fields are timetables — use directly
            %   2) Fields are numeric vectors — auto-detect time bases, group into timetables
            fields = fieldnames(raw);
            tables = {};

            % Check if any fields are timetables
            ttFields = false(numel(fields), 1);
            for k = 1:numel(fields)
                ttFields(k) = istimetable(raw.(fields{k}));
            end

            if any(ttFields)
                % Case 1: timetables already present — collect them
                for k = 1:numel(fields)
                    if ttFields(k)
                        tables{end+1} = raw.(fields{k}); %#ok<AGROW>
                    end
                end
            else
                % Case 2: flat numeric vectors — group by time base
                tables = TimeSeriesViewer.vectorsToTimetables(raw);
            end

            app.setTimetables(tables);
        end

        function loadFromTable(app, tbl)
            % Convert a regular table (from CSV) into timetables.
            % First monotonically increasing numeric column becomes time.
            varNames = tbl.Properties.VariableNames;
            timeCol = '';
            for k = 1:numel(varNames)
                col = tbl.(varNames{k});
                if isnumeric(col) && TimeSeriesViewer.isMonotonic(col)
                    timeCol = varNames{k};
                    break
                end
            end

            if isempty(timeCol)
                % No time column found — use row index
                timeVec = seconds((0:height(tbl)-1)');
                signalCols = varNames;
            else
                timeVec = seconds(tbl.(timeCol));
                signalCols = setdiff(varNames, {timeCol}, 'stable');
            end

            % Keep only numeric columns
            keep = false(size(signalCols));
            for k = 1:numel(signalCols)
                keep(k) = isnumeric(tbl.(signalCols{k}));
            end
            signalCols = signalCols(keep);

            tt = timetable(timeVec, 'VariableNames', {'Time'});
            for k = 1:numel(signalCols)
                tt.(signalCols{k}) = tbl.(signalCols{k});
            end
            % Remove the dummy 'Time' variable — it's just the RowTimes
            if ismember('Time', tt.Properties.VariableNames)
                tt.Time = [];
            end

            app.setTimetables({tt});
        end

        function setTimetables(app, tables)
            % Central method to set loaded data. Builds the variable index
            % and populates the UI.
            app.DataTables = tables(:)';
            app.VarTableIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            app.VariableNames = string.empty;

            for k = 1:numel(tables)
                tt = tables{k};
                vars = string(tt.Properties.VariableNames);
                for j = 1:numel(vars)
                    app.VarTableIndex(char(vars(j))) = k;
                    app.VariableNames(end+1) = vars(j);
                end
            end

            app.populateUI();
            app.enableUI();
        end

        function populateUI(app)
            app.VariableListBox.Items = cellstr(app.VariableNames);
            app.VariableListBox.ItemsData = cellstr(app.VariableNames);

            % Populate axis dropdowns
            signalItems = cellstr(["(none)"; app.VariableNames(:)]);
            for k = 1:4
                app.AxisDropdowns(k).Items = signalItems;
                app.AxisDropdowns(k).Value = '(none)';
            end
            % Auto-assign first few signals
            for k = 1:min(numel(app.VariableNames), 4)
                app.AxisDropdowns(k).Value = char(app.VariableNames(k));
            end
            app.updateAllPlots();
        end

        % ---- Axes Layout ----

        function updateAxesLayout(app)
            numAx = str2double(app.NumAxesDropdown.Value);
            for k = 1:4
                if k <= numAx
                    app.PlotAxes(k).Visible = 'on';
                    app.AxisDropdowns(k).Enable = 'on';
                    app.AxisDropdownLabels(k).Visible = 'on';
                    app.AxisDropdowns(k).Visible = 'on';
                else
                    app.PlotAxes(k).Visible = 'off';
                    app.AxisDropdowns(k).Enable = 'off';
                    app.AxisDropdownLabels(k).Visible = 'off';
                    app.AxisDropdowns(k).Visible = 'off';
                end
            end
            % Adjust grid rows
            heights = repmat({'1x'}, 1, 4);
            for k = (numAx+1):4
                heights{k} = 0;
            end
            app.AxesGrid.RowHeight = heights;

            % Link x-axes for visible axes
            if numAx > 1
                linkaxes(app.PlotAxes(1:numAx), 'x');
            end
        end

        % ---- Plotting ----

        function plotAxis(app, axIndex)
            ax = app.PlotAxes(axIndex);
            cla(ax);
            legend(ax, 'off');

            varName = app.AxisDropdowns(axIndex).Value;
            if strcmp(varName, '(none)') || isempty(varName)
                title(ax, "");
                return
            end

            if ~app.VarTableIndex.isKey(varName)
                return
            end

            ttIdx = app.VarTableIndex(varName);
            tt = app.DataTables{ttIdx};
            timeSec = seconds(tt.Time);
            values = tt.(varName);

            ax.XLim=[0 max(timeSec)];           % always use Autoscale for XLim
           
            plot(ax, timeSec, values, 'LineWidth', 1, ...
                'Color', app.ColorOrder(1,:));
            xlabel(ax, 'Time (s)');
            ylabel(ax, varName, 'Interpreter', 'none');
            title(ax, varName, 'Interpreter', 'none');
            ax.XGrid = 'on';
            ax.YGrid = 'on';
        end

        function updateAllPlots(app)
            numAx = str2double(app.NumAxesDropdown.Value);
            for k = 1:numAx
                app.plotAxis(k);
            end
            % Relink after replotting
            if numAx > 1
                linkaxes(app.PlotAxes(1:numAx), 'x');
            end
        end

        % ---- Interactive Tools ----

        function onEventLabelToggle(app)
            app.EventLabelEnabled = ~app.EventLabelEnabled;
            if app.EventLabelEnabled
                app.EventLabelButton.BackgroundColor = [0.7 0.85 1.0];
                app.StatusLabel.Text = 'Event Labels: ON — click on an axis to add event';
                numAx = str2double(app.NumAxesDropdown.Value);
                for k = 1:numAx
                    app.PlotAxes(k).ButtonDownFcn = @(src,evt) app.addEventLabel(src, evt);
                    lines = findobj(app.PlotAxes(k), 'Type', 'line');
                    for j = 1:numel(lines)
                        lines(j).ButtonDownFcn = @(~,evt) app.addEventLabel(app.PlotAxes(k), evt);
                    end
                end
            else
                app.EventLabelButton.BackgroundColor = [0.96 0.96 0.96];
                for k = 1:4
                    app.PlotAxes(k).ButtonDownFcn = '';
                    lines = findobj(app.PlotAxes(k), 'Type', 'line');
                    for j = 1:numel(lines)
                        lines(j).ButtonDownFcn = '';
                    end
                end
                app.StatusLabel.Text = 'Event Labels: OFF';
            end
        end

        function addEventLabel(app, ax, evt)
            clickPt = evt.IntersectionPoint;
            xVal = clickPt(1);

            answer = inputdlg('Event name:', 'Add Event', [1 35], {''});
            if isempty(answer) || isempty(answer{1})
                return
            end
            eventName = answer{1};

            hold(ax, 'on');
            yl = ylim(ax);
            plot(ax, [xVal xVal], yl, '--r', 'LineWidth', 1.5, ...
                'Tag', 'EventLine', 'HitTest', 'off');
            text(ax, xVal, yl(2), ['  ' eventName], ...
                'VerticalAlignment', 'top', ...
                'Color', 'r', 'FontWeight', 'bold', ...
                'Tag', 'EventLabel', 'HitTest', 'off');
            hold(ax, 'off');
            app.StatusLabel.Text = sprintf('Event added: %s at t=%.2f', eventName, xVal);
        end
    end

    % ---- Static helper methods (testable without GUI) ----

    methods (Static)
        function tf = isMonotonic(v)
            %ISMONOTONIC True if vector is strictly monotonically increasing.
            v = v(:);
            if numel(v) < 2
                tf = false;
                return
            end
            tf = all(diff(v) > 0);
        end

        function tables = vectorsToTimetables(raw)
            %VECTORSTOTIMETABLES Convert flat struct of vectors to timetables.
            %   TABLES = vectorsToTimetables(RAW) groups numeric vectors by
            %   matching length to detected time bases (monotonically increasing
            %   vectors). Returns a cell array of timetables.
            fields = fieldnames(raw);

            % Identify time-base candidates
            timeCandidates = {};
            timeLengths    = [];
            for k = 1:numel(fields)
                val = raw.(fields{k});
                if isnumeric(val) && isvector(val) && numel(val) > 1
                    if TimeSeriesViewer.isMonotonic(val)
                        timeCandidates{end+1} = fields{k};   %#ok<AGROW>
                        timeLengths(end+1)    = numel(val);   %#ok<AGROW>
                    end
                end
            end

            if isempty(timeCandidates)
                % No time base found — use row index for everything
                % Collect all numeric vectors into one timetable
                allVecs = {};
                allNames = {};
                maxLen = 0;
                for k = 1:numel(fields)
                    val = raw.(fields{k});
                    if isnumeric(val) && isvector(val) && numel(val) > 1
                        allVecs{end+1}  = val(:);  %#ok<AGROW>
                        allNames{end+1} = fields{k}; %#ok<AGROW>
                        maxLen = max(maxLen, numel(val));
                    end
                end
                if isempty(allVecs)
                    tables = {};
                    return
                end
                timeVec = seconds((0:maxLen-1)');
                tt = timetable(timeVec);
                for k = 1:numel(allVecs)
                    v = allVecs{k};
                    if numel(v) < maxLen
                        v(end+1:maxLen) = NaN;
                    end
                    tt.(allNames{k}) = v;
                end
                tables = {tt};
                return
            end

            % Deduplicate time bases by unique length
            [uniqueLengths, ia] = unique(timeLengths, 'first');
            uniqueTimeCols = timeCandidates(ia);

            % Group signals by matching length to a time base
            tables = cell(1, numel(uniqueLengths));
            for g = 1:numel(uniqueLengths)
                tVec = raw.(uniqueTimeCols{g});
                tVec = tVec(:);
                tt = timetable(seconds(tVec));
                targetLen = uniqueLengths(g);
                for k = 1:numel(fields)
                    val = raw.(fields{k});
                    if isnumeric(val) && isvector(val) && numel(val) == targetLen
                        % Skip the time column itself
                        if strcmp(fields{k}, uniqueTimeCols{g})
                            continue
                        end
                        tt.(fields{k}) = val(:);
                    end
                end
                % Only keep if it has signal variables
                if width(tt) > 0
                    tables{g} = tt;
                end
            end
            tables = tables(~cellfun('isempty', tables));
        end

        function cOut = lightenColor(c, factor)
            %LIGHTENCOLOR Lighten an RGB color towards white.
            %   cOut = lightenColor([r g b], factor) where factor in [0,1].
            %   factor=0 returns original, factor=1 returns white.
            if nargin < 2
                factor = 0.5;
            end
            factor = max(0, min(1, factor));
            cOut = c + (1 - c) * factor;
            cOut = max(0, min(1, cOut));
        end

        function dydx = computeDerivative(t, y)
            %COMPUTEDERIVATIVE Compute normalized derivative dy/dt.
            t = t(:);
            y = y(:);
            dt = diff(t);
            dy = diff(y);
            dydx = dy ./ dt;
            % Pad to same length as input (repeat last value)
            dydx = [dydx; dydx(end)];
        end

        function idx = findValueConditional(values, condition, threshold)
            %FINDVALUECONDITIONAL Find indices where condition is met.
            %   idx = findValueConditional(values, '>', 500)
            %   Supported conditions: '>', '<', '>=', '<=', '==', '~='
            switch condition
                case '>'
                    idx = find(values > threshold);
                case '<'
                    idx = find(values < threshold);
                case '>='
                    idx = find(values >= threshold);
                case '<='
                    idx = find(values <= threshold);
                case '=='
                    idx = find(values == threshold);
                case '~='
                    idx = find(values ~= threshold);
                otherwise
                    error('TimeSeriesViewer:InvalidCondition', ...
                        'Unknown condition: %s', condition);
            end
        end
    end
end
