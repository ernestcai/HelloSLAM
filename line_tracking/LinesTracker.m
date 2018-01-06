classdef LinesTracker < handle
    % this class is used to track lines among adjacent sequence images
    % each line get a sequence number and record in which image it appear
    % and coresponding coordinates
    
    properties
        % the line tracking, each line is a struct
        lines_tracking;
        
        % previous data
        img_pre;
        img_idx_pre;
        features_pre;
        points_pre;
        % the indexs of lines in previous image
        lines_idx_pre;
    end
    
    methods
        function obj = LinesTracker(img,lines_in,img_idx)
            % given the first image and coresponding lines for adding
            % Input:
            %       img:            Gray Scale Image
            %       lines_in:       A set of liens in 2D image plane
            
            obj.img_pre = img;
            obj.img_idx_pre = img_idx;
            % extract feature and store it into features_pre
            points = detectSURFFeatures(img);
            [features, points] = extractFeatures(img, points);
            obj.features_pre = features;
            obj.points_pre = points;
            
            % process lines_in
            obj.lines_tracking = [];
            obj.lines_idx_pre = [];
            for i = 1:1:size(lines_in,2)
                obj.lines_tracking = [obj.lines_tracking LineTracking(img_idx,lines_in(:,i))];
                obj.lines_idx_pre = [obj.lines_idx_pre size(obj.lines_tracking,2)];
            end
        end
        
        % add the next img after the previous one
        function add_img(obj, img, lines, img_idx)
            % Input:
            %       img:            Gray Scale Image
            %       lines:          A set of lines in 2D image plane
            
            % compute the homography matrix from the image to the last one
            points_raw = detectSURFFeatures(img);
            [features, points_raw] = extractFeatures(img, points_raw);
            index_pairs = matchFeatures(features, obj.features_pre, 'Unique', true);
            
            points_matched = points_raw(index_pairs(:,1), :);
            points_pre_matched = obj.points_pre(index_pairs(:,2), :);
            
            % H transfrom image from current image to the previous one
            tform = estimateGeometricTransform(points_matched, points_pre_matched,...
            'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);
            H = tform.T';
            
            % for each line in this image, match it with the last one, if
            % it is one line, append it to lines.
            lines = apply_homography(lines, H);
            lines_idx = [];
            for i = 1:1:size(lines,2)
                % j is the tracking line id
                matched_flag = 0;
                for j = 1:1:size(obj.lines_idx_pre,2)
                    [line_pre] = obj.lines_tracking(obj.lines_idx_pre(j)).get_line(obj.img_idx_pre);
                    if (obj.lines_idx_pre(j) == 1)
                        debug = 1;
                    end
                    if (is_similar(lines(:,i), line_pre, 0.05*1080) == 1)
                        % update the line tracking process
                        obj.lines_tracking(obj.lines_idx_pre(j)).add_line(img_idx,lines(:,i));
                        lines_idx = [lines_idx obj.lines_idx_pre(j)];
                        matched_flag = 1;
                        break;
                    end
                end
                
                % Otherwise, create a new line.
                if (matched_flag == 0)
                    obj.lines_tracking = [obj.lines_tracking LineTracking(img_idx,lines(:,i))];
                    lines_idx = [lines_idx size(obj.lines_tracking,2)];
                end
            end
            
            
            % store points and features to previous one
            obj.img_pre = img;
            obj.img_idx_pre = img_idx;
            obj.features_pre = features;
            obj.points_pre = points_raw;
            obj.lines_idx_pre = lines_idx;
        end
    end
end

% determine if two lines are the same line
function [flag] = is_similar(line1, line2, threshold)
    if ((size(line1,1) < 4) || (size(line1,2) ~= 1) ||...
            (size(line2,1) < 4) || (size(line2,2) ~= 1))
        error('The line is of wrong demision');
    end
    % get line orientation
    ori1 = get_line_oriention(line1);
    ori2 = get_line_oriention(line2);
    % if two lines are of different orientation (1 degree torance)
    if (abs(ori1-ori2) > pi/180)
        flag = 0;
        return;
    end
    
    % get point to line distance
    d1 = point_to_line_dist(line1(1:2,1),line2(1:4,1));
    d2 = point_to_line_dist(line1(3:4,1),line2(1:4,1));
    d3 = point_to_line_dist(line2(1:2,1),line1(1:4,1));
    d4 = point_to_line_dist(line2(3:4,1),line1(1:4,1));
    d = min([d1 d2 d3 d4]);
    if (d > threshold)
        flag = 0;
        return; 
    else
        flag = 1;
        return;
    end
end

function [lines_new] = apply_homography(lines, H)
    lines_num = size(lines,2);
    lines1 = [lines(1:2,:); ones(1,lines_num)];
    lines2 = [lines(3:4,:); ones(1,lines_num)];
    
    % apply homography transform
    lines1_new = H * lines1;
    lines1_new = normalize_points(lines1_new);
    lines2_new = H * lines2;
    lines2_new = normalize_points(lines2_new);
    
    lines_new = [lines1_new(1:2,:); lines2_new(1:2,:)];
end

% make sure the 3rd demision is 1
function [points_new] = normalize_points(points)
    points_new = points;
    for i = 1:1:size(points,2)
        points_new(:,i) = points(:,i)/points(3,i);
    end
end