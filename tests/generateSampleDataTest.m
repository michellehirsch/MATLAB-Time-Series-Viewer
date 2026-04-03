classdef generateSampleDataTest < matlab.unittest.TestCase
%GENERATESAMPLEDATATEST Tests for the generateSampleData function.

    properties
        Tables
    end

    methods (TestClassSetup)
        function loadData(testCase)
            testCase.Tables = generateSampleData();
        end
    end

    methods (Test)
        function testOutputIsCellArray(testCase)
            testCase.verifyClass(testCase.Tables, 'cell');
            testCase.verifyLength(testCase.Tables, 2);
        end

        function testTablesAreTimetables(testCase)
            for k = 1:numel(testCase.Tables)
                testCase.verifyTrue(istimetable(testCase.Tables{k}), ...
                    sprintf('Tables{%d} should be a timetable', k));
            end
        end

        function testHighRateSignalsPresent(testCase)
            tt = testCase.Tables{1};
            expected = {'altitude','airspeed','pitch','roll'};
            for k = 1:numel(expected)
                testCase.verifyTrue(ismember(expected{k}, tt.Properties.VariableNames), ...
                    sprintf('High-rate table missing: %s', expected{k}));
            end
        end

        function testLowRateSignalsPresent(testCase)
            tt = testCase.Tables{2};
            expected = {'temperature','pressure'};
            for k = 1:numel(expected)
                testCase.verifyTrue(ismember(expected{k}, tt.Properties.VariableNames), ...
                    sprintf('Low-rate table missing: %s', expected{k}));
            end
        end

        function testTimeVectorsMonotonic(testCase)
            for k = 1:numel(testCase.Tables)
                tt = testCase.Tables{k};
                timeSec = seconds(tt.Time);
                testCase.verifyTrue(all(diff(timeSec) > 0), ...
                    sprintf('Tables{%d}.Time should be strictly increasing', k));
            end
        end

        function testSignalLengths(testCase)
            % High-rate (100 Hz): 10001 points
            testCase.verifyEqual(height(testCase.Tables{1}), 10001);
            % Low-rate (20 Hz): 2001 points
            testCase.verifyEqual(height(testCase.Tables{2}), 2001);
        end

        function testSignalRanges(testCase)
            tt1 = testCase.Tables{1};
            alt = tt1.altitude;
            testCase.verifyGreaterThanOrEqual(min(alt), -500, 'Altitude too low');
            testCase.verifyLessThanOrEqual(max(alt), 11000, 'Altitude too high');

            spd = tt1.airspeed;
            testCase.verifyGreaterThanOrEqual(min(spd), 200, 'Airspeed too low');
            testCase.verifyLessThanOrEqual(max(spd), 350, 'Airspeed too high');

            tt2 = testCase.Tables{2};
            prs = tt2.pressure;
            testCase.verifyGreaterThanOrEqual(min(prs), 800, 'Pressure too low');
            testCase.verifyLessThanOrEqual(max(prs), 1100, 'Pressure too high');
        end

        function testSavesToFile(testCase)
            tmpFile = fullfile(tempdir, 'test_sample_data.mat');
            cleanup = onCleanup(@() delete(tmpFile));
            generateSampleData(tmpFile);
            testCase.verifyTrue(isfile(tmpFile), '.mat file should be created');

            loaded = load(tmpFile);
            testCase.verifyTrue(isfield(loaded, 'highRate'), 'Saved file missing highRate');
            testCase.verifyTrue(isfield(loaded, 'lowRate'),  'Saved file missing lowRate');
            testCase.verifyTrue(istimetable(loaded.highRate), 'highRate should be a timetable');
            testCase.verifyTrue(istimetable(loaded.lowRate),  'lowRate should be a timetable');
        end

        function testTimeRange(testCase)
            % Both tables should span 0–100 seconds
            for k = 1:numel(testCase.Tables)
                tt = testCase.Tables{k};
                timeSec = seconds(tt.Time);
                testCase.verifyEqual(timeSec(1), 0, 'AbsTol', 1e-10);
                testCase.verifyEqual(timeSec(end), 100, 'AbsTol', 1e-10);
            end
        end
    end
end
