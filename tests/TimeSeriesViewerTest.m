classdef TimeSeriesViewerTest < matlab.unittest.TestCase
%TIMESERIESVIEWERTEST Non-UI unit tests for TimeSeriesViewer logic.
%   Tests static/helper methods that don't require launching the GUI.

    methods (Test)

        function testLoadMatFileWithTimetables(testCase)
            % Create a .mat file containing timetables and verify loading
            tmpFile = fullfile(tempdir, 'tsv_test_load_tt.mat');
            cleanup = onCleanup(@() delete(tmpFile));

            t = (0:0.01:10)';
            x = sin(t);
            tt = timetable(seconds(t), x, 'VariableNames', {'x'});
            save(tmpFile, 'tt');

            loaded = load(tmpFile);
            testCase.verifyTrue(isfield(loaded, 'tt'));
            testCase.verifyTrue(istimetable(loaded.tt));
            testCase.verifyEqual(height(loaded.tt), 1001);
            testCase.verifyTrue(ismember('x', loaded.tt.Properties.VariableNames));
        end

        function testAutoDetectTimeBases(testCase)
            % Monotonically increasing vectors should be detected
            t = (0:0.1:10)';
            testCase.verifyTrue(TimeSeriesViewer.isMonotonic(t));

            % Non-monotonic should not be detected
            x = sin(t);
            testCase.verifyFalse(TimeSeriesViewer.isMonotonic(x));

            % Constant vector should not be detected
            c = ones(100, 1);
            testCase.verifyFalse(TimeSeriesViewer.isMonotonic(c));

            % Single element should not be detected
            testCase.verifyFalse(TimeSeriesViewer.isMonotonic(5));

            % Row vector should work too
            testCase.verifyTrue(TimeSeriesViewer.isMonotonic(1:10));
        end

        function testVectorsToTimetables(testCase)
            % Simulate a flat .mat struct with two sample rates
            raw.t  = (0:0.01:1)';       % 101 pts
            raw.x  = sin(raw.t);         % 101 pts, matches t
            raw.y  = cos(raw.t);         % 101 pts, matches t
            raw.t2 = (0:0.1:1)';         % 11 pts
            raw.z  = rand(11, 1);        % 11 pts, matches t2

            tables = TimeSeriesViewer.vectorsToTimetables(raw);
            testCase.verifyGreaterThanOrEqual(numel(tables), 2, ...
                'Should produce at least 2 timetables');

            % Find the table with 101 rows and 11 rows
            heights = cellfun(@height, tables);
            tt101 = tables{heights == 101};
            tt11  = tables{heights == 11};

            testCase.verifyTrue(ismember('x', tt101.Properties.VariableNames));
            testCase.verifyTrue(ismember('y', tt101.Properties.VariableNames));
            testCase.verifyTrue(ismember('z', tt11.Properties.VariableNames));

            % Time vectors should be duration
            testCase.verifyClass(tt101.Time, 'duration');
            testCase.verifyClass(tt11.Time, 'duration');
        end

        function testVectorsToTimetablesNoTimeBase(testCase)
            % All non-monotonic vectors — should fall back to row index
            raw.x = sin(1:50)';
            raw.y = cos(1:50)';

            tables = TimeSeriesViewer.vectorsToTimetables(raw);
            testCase.verifyLength(tables, 1);
            testCase.verifyEqual(height(tables{1}), 50);
        end

        function testLightenColor(testCase)
            % Black lightened by 0.5 should be [0.5 0.5 0.5]
            c = TimeSeriesViewer.lightenColor([0 0 0], 0.5);
            testCase.verifyEqual(c, [0.5 0.5 0.5], 'AbsTol', 1e-10);

            % White lightened should stay white
            c = TimeSeriesViewer.lightenColor([1 1 1], 0.5);
            testCase.verifyEqual(c, [1 1 1], 'AbsTol', 1e-10);

            % Factor=0 should return original
            c = TimeSeriesViewer.lightenColor([0.5 0.3 0.1], 0);
            testCase.verifyEqual(c, [0.5 0.3 0.1], 'AbsTol', 1e-10);

            % Factor=1 should return white
            c = TimeSeriesViewer.lightenColor([0.5 0.3 0.1], 1);
            testCase.verifyEqual(c, [1 1 1], 'AbsTol', 1e-10);

            % Output should always be valid RGB [0,1]
            c = TimeSeriesViewer.lightenColor([0.2 0.8 0.5], 0.3);
            testCase.verifyGreaterThanOrEqual(c, [0 0 0]);
            testCase.verifyLessThanOrEqual(c, [1 1 1]);
        end

        function testDerivativeComputation(testCase)
            t = (0:0.01:1)';
            y = t.^2;  % dy/dt = 2t
            dydx = TimeSeriesViewer.computeDerivative(t, y);

            testCase.verifyLength(dydx, numel(t));
            % At t=0.5 (index 51), derivative should be ~1.0
            testCase.verifyEqual(dydx(51), 1.0, 'AbsTol', 0.05);
            % At t=0.9 (index 91), derivative should be ~1.8
            testCase.verifyEqual(dydx(91), 1.8, 'AbsTol', 0.05);
        end

        function testFindValueConditional(testCase)
            values = [1 2 3 4 5 6 7 8 9 10];

            idx = TimeSeriesViewer.findValueConditional(values, '>', 5);
            testCase.verifyEqual(idx, [6 7 8 9 10]);

            idx = TimeSeriesViewer.findValueConditional(values, '<', 3);
            testCase.verifyEqual(idx, [1 2]);

            idx = TimeSeriesViewer.findValueConditional(values, '>=', 9);
            testCase.verifyEqual(idx, [9 10]);

            idx = TimeSeriesViewer.findValueConditional(values, '<=', 2);
            testCase.verifyEqual(idx, [1 2]);

            idx = TimeSeriesViewer.findValueConditional(values, '==', 5);
            testCase.verifyEqual(idx, 5);

            idx = TimeSeriesViewer.findValueConditional(values, '~=', 5);
            testCase.verifyEqual(idx, [1 2 3 4 6 7 8 9 10]);
        end

        function testFindValueConditionalInvalidCondition(testCase)
            testCase.verifyError( ...
                @() TimeSeriesViewer.findValueConditional(1:10, '??', 5), ...
                'TimeSeriesViewer:InvalidCondition');
        end
    end
end
