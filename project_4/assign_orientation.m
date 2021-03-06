function KeyPoints = assign_orientation(dog, keypoints_inds, KeyPoints)

% Generate gaussian weighting function
weight_sigma = 1.5*dog.scale;
weight_size = round(6*weight_sigma);
% Make sure window size is odd
if mod(weight_size,2)==0
    weight_size = weight_size-1;
end
offset = floor(weight_size/2);
% Generate gaussian weighting function
g_weight = fspecial('gaussian', [weight_size weight_size], weight_sigma);


% Gradient direction is within [-pi, pi] !!!
g_dir = dog.g_dir/pi*180;  % degree 
g_mag = dog.g_mag;

% Get all neighbors gradient
[nr nc] = size(g_mag);
[ys xs] = ind2sub([nr nc], keypoints_inds);


% Grab gradient info of neighbors within the Gaussian window
neighbor_g_dir = [];  % to be ?-by-?
neighbor_g_mag = [];
% Reduce 2 loops into 1, and reserve the correct order
[dxs dys] = meshgrid(-offset:offset, -offset:offset);

for idx = 1:numel(dxs)
    ys_new = ys + dys(idx);
    xs_new = xs + dxs(idx);

    % Discard points too close to boundaries
    bad_pts = logical(xs_new<1 | xs_new>nc | ys_new<1 | ys_new>nr);
    xs_new(bad_pts) = [];
    ys_new(bad_pts) = [];
    % Discard bad points thoroughly
    xs(bad_pts)= [];
    ys(bad_pts) = [];
    keypoints_inds(bad_pts) = [];
    if ~isempty(neighbor_g_dir)
        neighbor_g_dir(bad_pts,:) = [];
        neighbor_g_mag(bad_pts,:) = [];
    end

    neighbor_inds = sub2ind([nr nc], ys_new, xs_new);
    neighbor_g_dir = cat(2,neighbor_g_dir, g_dir(neighbor_inds));
    neighbor_g_mag = cat(2,neighbor_g_mag, g_mag(neighbor_inds));

end

% Gaussian weighting the magnitude
neighbor_g_mag = bsxfun(@times, neighbor_g_mag,g_weight(:)');

% Generate Orientation Histogram
hist_ori = zeros(length(keypoints_inds),36);
hist_prep = floor(neighbor_g_dir/10);  % #keys-by-#neighbors

% I KNOW THIS IS KINDA STUPID
bin_length = 10; % degree
for h=-18:18
    % DON'T FORGET THE 36
    g_mag_tmp = neighbor_g_mag;
    g_mag_tmp(hist_prep~=h) = 0;
    % Store the values for this bin
    if h==18
        % Interpolation
        interp_weight = 1- abs(neighbor_g_dir-355)/bin_length;
        hist_ori(:,h+18) = sum(g_mag_tmp.*interp_weight, 2);
    else
        bin_centers = (hist_prep+0.5)*bin_length;
        interp_weight = 1 - abs(neighbor_g_dir-bin_centers)/bin_length;

        hist_ori(:,h+19) = sum(g_mag_tmp.*interp_weight, 2);
    end
end

% Get the dominent orientation for EVERY keypoints
[hist_ori_sorted, hist_ori_idx] = sort(hist_ori,2, 'descend');
peak_bins = hist_ori_idx(:,1);
peak_vals = hist_ori_sorted(:,1);

% Create struct for storing ALL info of keypoints
cnt = numel(KeyPoints)+1;
KeyPoints{cnt} = {};
KeyPoints{cnt}.location = [];
KeyPoints{cnt}.orientation = [];

% Project the points back to original image
ys = ys*dog.oct;
xs = xs*dog.oct;
KeyPoints{cnt}.location = cat(1, KeyPoints{cnt}.location, [xs ys]);
% Record orientations (RADIAN)
KeyPoints{cnt}.orientation = cat(1,KeyPoints{cnt}.orientation,((peak_bins-19)*10 + 5)/180*pi);

% Grab other potentail orientations
ratio = hist_ori_sorted(:,2)./ peak_vals;
remains = logical(ratio>=0.8);
while sum(remains)>0
    % Discard unused points
    KeyPoints{cnt}.location = cat(1,KeyPoints{cnt}.location, [xs(remains), ys(remains)]);
    peak_vals = peak_vals(remains);
    hist_ori_sorted = hist_ori_sorted(remains, 2:end);
    hist_ori_idx = hist_ori_idx(remains, 2:end);

    % Assign multiple orientations
    peak_bins = hist_ori_idx(:,1);
    KeyPoints{cnt}.orientation = cat(1,KeyPoints{cnt}.orientation,((peak_bins-19)*10 + 5)/180*pi);
    
    % Next round
    ratio = hist_ori_sorted(:,2)./ peak_vals;
    remains = logical(ratio>=0.8);

end

KeyPoints{cnt}.scale = dog.scale;




