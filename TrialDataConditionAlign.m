classdef TrialDataConditionAlign < TrialData

    properties(SetAccess=protected)
        conditionInfo
        alignInfo
    end

    % Properties which read through to ConditionInfo
    properties(Dependent)
        nConditions
        listByCondition
        conditionIdx
        conditionSubs
        conditions
        conditionNames
        conditionAppearances
    end

    % Initializing and building
    methods
        function td = TrialDataConditionAlign(varargin)
            td = td@TrialData(varargin{:});
            td = td.initializeConditionInfo();
            td = td.initializeAlignInfo();
            td = td.updateValid();
        end
    end
    
    methods
        function disp(td)
            td.printDescriptionShort();
            fprintf('\n');
            
            td.alignInfo.printOneLineDescription();
            fprintf('\n');
            td.conditionInfo.printDescription();
            
            fprintf('\n');
            td.printChannelInfo();
            fprintf('\n');
        end

        function td = updateValid(td)
            td.warnIfNoArgOut(nargout);
            cvalid = td.conditionInfo.computedValid;
            avalid = td.alignInfo.computedValid;

            % combine and update the validity masks 
            td.valid = cvalid & avalid;
            td.conditionInfo.setInvalid(~td.valid);
            td.alignInfo = td.alignInfo.setInvalid(~td.valid);
        end
    end

    % ConditionInfo control
    methods
        function td = initializeConditionInfo(td)
            td.warnIfNoArgOut(nargout);
            td.conditionInfo = ConditionInfo();
            td.conditionInfo.applyToTrialData(td);
        end

        function td = createCopyConditionInfo(td)
            td.warnIfNoArgOut(nargout);
            td.conditionInfo = td.conditionInfo.copy();
        end

        function td = selectTrials(td, mask)
            td.warnIfNoArgOut(nargout);
            td = selectTrials@TrialData(td, mask);
            td = td.createCopyConditionInfo();
            td.conditionInfo.selectTrials(mask);
            td.alignInfo = td.alignInfo.selectTrials(mask);
        end
        
        function td = groupBy(td, paramList, varargin)
            td.warnIfNoArgOut(nargout);
            p = inputParser;
            p.addRequired('paramList', @(x) isempty(x) || ischar(x) || iscellstr(x));
            p.parse(paramList, varargin{:});

            paramList = p.Results.paramList;
            if isempty(paramList)
                paramList = {};
            end
            if ischar(paramList)
                paramList = {paramList};
            end

            % TrialData are not handle classes, copy conditionInfo to
            % achieve independence
            td.conditionInfo = ConditionInfo();
            td.conditionInfo.noUpdateCache = true;
            
            for iAttr = 1:numel(paramList)
                td.conditionInfo.addAttribute(paramList{iAttr});
            end
            td.conditionInfo.groupBy(paramList);
            td.conditionInfo.applyToTrialData(td);
            
            td.conditionInfo.noUpdateCache = false;
            td.conditionInfo.updateCache();

            td = td.updateValid();
        end

        % filter trials that are valid based on ConditionInfo
        function td = filterValidTrialsConditionInfo(td, varargin)
            td.warnIfNoArgOut(nargout);
            td = td.createCopyConditionInfo();
            td = td.selectTrials(td.conditionInfo.valid);
        end

        % filter trials where a specific attribute matches a specific value
        % pass-thru to ConditionInfo
        function td = filteredByAttribute(td, varargin)
            % call on ConditionInfo, and filter based on its valid trials
            td.warnIfNoArgOut(nargout);
            % no need to copy, filteredBy already copies the conditionInfo
            td.conditionInfo = td.conditionInfo.filteredByAttribute(varargin{:});
            td = td.filterValidTrialsConditionInfo();
        end

        % filter trials based on matching attribute values, 
        % pass thru to ConditionInfo
        function td = filteredByAttributeStruct(td, varargin)
            % call on ConditionInfo, and filter based on its valid trials
            td.warnIfNoArgOut(nargout);
            % no need to copy, filteredBy already copies the conditionInfo
            td.conditionInfo = td.conditionInfo.filteredByAttributeStruct(varargin{:});
            td = td.filterValidTrialsConditionInfo();
        end

        function tdCell = getTrialDataByCondition(td)
            tdCell = arrayfun(@(condition) td.filteredByAttributeStruct(condition), ...
                td.conditions, 'UniformOutput', false);
        end

        function v = get.conditions(td)
            v = td.conditionInfo.conditions;
        end

        function n = get.nConditions(td)
            n = td.conditionInfo.nConditions;
        end

        function v = get.conditionNames(td)
            v = td.conditionInfo.names;
        end

        function v = get.conditionAppearances(td)
            v = td.conditionInfo.appearances;
        end

        function v = get.listByCondition(td)
            v = td.conditionInfo.listByCondition;
        end

        function v = get.conditionIdx(td)
            v = td.conditionInfo.conditionIdx;
        end

        function v = get.conditionSubs(td)
            v = td.conditionInfo.conditionSubs;
        end
    end

    % Data access by group via ConditionInfo
    methods
        % given a cellvec or nmeric vector, group its elements
        function varargout = groupElements(td, varargin)
            for i = 1:numel(varargin)
                data = varargin{i};
                assert(isvector(data) && numel(data) == td.nTrials, ...
                    'Data must be a vector with length == number of trials');
                varargout{i} = cellfun(@(idx) data(idx), td.listByCondition, 'UniformOutput', false);
            end
        end

        function [dCell tCell] = getAnalogGrouped(td, name)
            [dataCell, timeCell] = td.getAnalog(name);
            [dCell, tCell] = td.groupElements(dataCell, timeCell);
        end
        
        function [dataCell, timeCell] = getAnalogSampleGrouped(td, name, varargin)
            [dataVec, timeVec] = td.getAnalogSample(name);
            [dataCell, timeCell] = td.groupElements(dataVec, timeVec);
        end 

        function dCell = getEventGrouped(td, name)
            dCell = td.groupElements(td.getAnalog(name));
        end

        function dCell = getParamGrouped(td, name)
            dCell = td.groupElements(td.getParam(name));
        end
    end

    % AlignInfo control
    methods
        function td = initializeAlignInfo(td)
            td.warnIfNoArgOut(nargout);
            td.alignInfo = AlignInfo();
            td.alignInfo = td.alignInfo.applyToTrialData(td);
        end

        function td = align(td, ad)
            td.warnIfNoArgOut(nargout);
            if ischar(ad)
                ad = AlignInfo(ad);
            else
                assert(isa(ad, 'AlignDescriptor'));
                if ~isa(ad, 'AlignInfo')
                    ad = AlignInfo.fromAlignDescriptor(ad);
                end
            end

            td.alignInfo = ad.applyToTrialData(td);
            td = td.updateValid();
        end
    end
    
    % AlignInfo data access
    methods
        % return aligned analog channel
        function [data time] = getAnalog(td, name)
            [data time] = getAnalog@TrialData(td, name);
            [data time] = td.alignInfo.getAlignedTimeseries(data, time);
        end
        
        % return aligned event times
        function timesCell = getEvent(td, name)
            timesCell = getEvent@TrialData(td, name);
            timesCell = td.alignInfo.getAlignedTimes(timesCell);
        end

        % return aligned unit spike times
        function [timesCell] = getSpikeTimesForUnit(td, unitName); 
            timesCell = getSpikeTimesForUnit@TrialData(td, unitName);
            timesCell = td.alignInfo.getAlignedTimes(timesCell);
        end
    end

    % Spike data
    methods
        function sr = buildSpikeRasterForUnit(td, unitName)
            sr = SpikeRaster(td, unitName, 'conditionInfo', td.conditionInfo, 'alignInfo', td.alignInfo);
        end
    end

    % Plotting
    methods
        function plotAnalogGroupedEachTrial(td, name, varargin) 
            p = inputParser();
            p.addParamValue('plotOptions', {}, @(x) iscell(x));
            p.KeepUnmatched;
            p.parse(varargin{:});

            axh = td.getRequestedPlotAxis(p.Unmatched);

            [dataByGroup timeByGroup] = td.getAnalogGrouped(name);     
            app = td.conditionAppearances;

            for iCond = 1:td.nConditions
                dataCell = dataByGroup{iCond};
                timeCell = timeByGroup{iCond};
                for iTrial = 1:numel(dataCell)
                    if ~isempty(timeCell{iTrial}) && ~isempty(dataCell{iTrial})
                        plot(axh, double(timeCell{iTrial}), dataCell{iTrial}, '-', 'Color', app(iCond).color, ...
                            'LineWidth', app(iCond).lineWidth, p.Results.plotOptions{:});
                    end
                    if iTrial == 1, hold(axh, 'on'); end
                end
            end
            box(axh, 'off');
            axis(axh, 'tight');
            
            xlabel(td.getTimeAxisLabel());
            ylabel(td.getAxisLabelForChannel(name));
        end
        
        function plotAnalogGroupedEachTrial2D(td, name1, name2, varargin) 
            p = inputParser();
            p.addParamValue('plotOptions', {}, @(x) iscell(x));
            p.KeepUnmatched;
            p.parse(varargin{:});

            axh = td.getRequestedPlotAxis(p.Unmatched);

            dataByGroup1 = td.getAnalogGrouped(name1);  
            dataByGroup2 = td.getAnalogGrouped(name2);  
            app = td.conditionAppearances;

            for iCond = 1:td.nConditions
                dataCell1 = dataByGroup1{iCond};
                dataCell2 = dataByGroup2{iCond};
                for iTrial = 1:numel(dataCell1)
                    plot(axh, dataCell1{iTrial}, dataCell2{iTrial}, '-', 'Color', app(iCond).color, ...
                        'LineWidth', app(iCond).lineWidth, p.Results.plotOptions{:});
                    if iTrial == 1, hold(axh, 'on'); end
                end
            end
            box(axh, 'off');
            axis(axh, 'tight');
            
            xlabel(td.getAxisLabelForChannel(name1));
            ylabel(td.getAxisLabelForChannel(name2));
        end
        
        function plotAnalogGroupedEachTrial3D(td, name1, name2, name3, varargin) 
            p = inputParser();
            p.addParamValue('plotOptions', {}, @(x) iscell(x));
            p.KeepUnmatched;
            p.parse(varargin{:});

            axh = td.getRequestedPlotAxis(p.Unmatched);

            dataByGroup1 = td.getAnalogGrouped(name1);  
            dataByGroup2 = td.getAnalogGrouped(name2);
            dataByGroup3 = td.getAnalogGrouped(name3);
            app = td.conditionAppearances;

            for iCond = 1:td.nConditions
                dataCell1 = dataByGroup1{iCond};
                dataCell2 = dataByGroup2{iCond};
                dataCell3 = dataByGroup3{iCond};
                for iTrial = 1:numel(dataCell1)
                    plot3(axh, dataCell1{iTrial}, dataCell2{iTrial}, dataCell3{iTrial}, ...
                        '-', 'Color', app(iCond).color, ...
                        'LineWidth', app(iCond).lineWidth, p.Results.plotOptions{:});
                    if iTrial == 1, hold(axh, 'on'); end
                end
            end
            box(axh, 'off');
            axis(axh, 'tight');
            axis(axh, 'vis3d');
            
            xlabel(td.getAxisLabelForChannel(name1));
            ylabel(td.getAxisLabelForChannel(name2));
            zlabel(td.getAxisLabelForChannel(name3));
        end
    end

end
