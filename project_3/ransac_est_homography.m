function [H,inlier_ind] = ransac_est_homography(y1, x1, y2, x2, thresh)

n_points = length(y1);


maxIter = factorial(n_points)/factorial(n_points-4)/24; %???
min_inliers = round(0.2*n_points);

inlier_ind = [];

iter = 0;
while iter < maxIter
    iter = iter + 1;
    % Randomly sample 4 points
    rnd_idx = randperm(n_points, 4)';
    
    des_y = y1(rnd_idx);
    des_x = x1(rnd_idx);
    src_y = y2(rnd_idx);
    src_x = x2(rnd_idx);

    % Compute homography from samples
    tmpH = est_homography(des_x, des_y, src_x, src_y);

    % Apply homography to the remaining points
    [est_x1 est_y1] = apply_homography(tmpH, x2, y2);
    
    % Vote for this homography
    dists = sqrt((est_y1-y1).^2 + (est_x1-x1).^2);
    
    % If too few inliers then discard this candidate
    if sum(dists<thresh)<min_inliers
        continue;
    % If better than the current best estimate then keep it
    elseif sum(dists<thresh)>size(inlier_ind,1)
%         best_H = tmpH;
        inlier_ind = find(dists<thresh);
%        length(inlier_ind)
    end
            
end

% Refine the transformation
H = est_homography(x1(inlier_ind), y1(inlier_ind), x2(inlier_ind), y2(inlier_ind));


