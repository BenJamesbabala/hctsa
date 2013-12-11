% TSQ_us_cluster
% 
% Inputs a data matrix and clustering options, outputs a new ordering of
% the indicies of this data matrix. Can do this on the full data matrix, or
% input a section and reorder it. The possiblities are literally endless.
% The output from this can also be fed to other algorithms -- to plot
% clusters in different ways, etc.
% Unsupervised Clustering
% Some settings use the Spider package for machine learning in Matlab
% ------------------------------------------------------------------------------
% Copyright (C) 2013,  Ben D. Fulcher <ben.d.fulcher@gmail.com>,
% <http://www.benfulcher.com>
% 
% If you use this code for your research, please cite:
% B. D. Fulcher, M. A. Little, N. S. Jones., "Highly comparative time-series
% analysis: the empirical structure of time series and their methods",
% J. Roy. Soc. Interface 10(83) 20130048 (2010). DOI: 10.1098/rsif.2013.0048
% 
% This work is licensed under the Creative Commons
% Attribution-NonCommercial-ShareAlike 3.0 Unported License. To view a copy of
% this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send
% a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View,
% California, 94041, USA.
% ------------------------------------------------------------------------------

function [ackwgs, acgi, TS_DataMat_cl] = TSQ_us_cluster(norcl,ClusterMethod,ClusterParams,metorts)

%% Check Inputs
% 1) norcl: can be the data matrix, or a string:
%                  'norm' -- loads TS_loc_N,
%                  'cl'   -- loads TS_loc_cl,
if nargin < 1,
    norcl = ''; % not necessary
end

% 2) ClusterMethod: a string specifying the clustering method to use
if nargin < 2 || isempty(ClusterMethod),
    ClusterMethod = 'linkage';
end

% 3) ClusterParams: specify the parameters for the clustering method
if nargin < 3, ClusterParams = {}; end % defaults specified within each method


% 4) metorts: whether to do for metrics ('mets') or time series ('ts')
%             only meaningful when norcl is a string.
if nargin < 4 || isempty(metorts), metorts = 'ts'; end


%% Get the data
switch norcl
case 'cl'
    fprintf(1,'Loading HCTSA_cl.mat...');
    load('HCTSA_cl.mat','TS_DataMat')
    fprintf(1,' Loaded.\n');
case 'norm'
    fprintf(1,'Loading HCTSA_N.mat...');
    load('HCTSA_N.mat','TS_DataMat')
    fprintf(1,' Loaded.\n');
otherwise % Input is a matrix to be clustered -- call it TS_DataMat.
    TS_DataMat = norcl;
end
% Transpose for operations:
if strcmp(metorts,'mets'), TS_DataMat = TS_DataMat'; end


%% Do the unsupervised clustering
switch ClusterMethod
	case 'linkage'
% 		disp('Using inbuilt matlab linkage clustering');
        % parameter is a cell:
        % {dmth, lmth, showdend, clustth, savetofile, customR}
        % Better to make this a structure in future...
        %% Check inputs
        % ** dmth
        if length(ClusterParams)>=1 && ~isempty(ClusterParams{1})
            dmth = ClusterParams{1};
        else
            dmth = 'euclidean';
        end
        
        % ** lmth
        if length(ClusterParams)>=2 && ~isempty(ClusterParams{2})
            lmth = ClusterParams{2};
        else
            lmth = 'average';
        end
        
        disp(['Using ' lmth ' linkage clustering on ' dmth ' distances']);
        
        % ** showdend
        if length(ClusterParams)>=3 && ~isempty(ClusterParams{3})
            showdend = ClusterParams{3};
        else
            showdend = 0;
        end
        if showdend == 0
            disp('suppressing dendrogram output')
        end
        
        % ** clustthresh -- many ways of doing this -- current way searches
        % until number of clusters is less than some threshold (but
        % obtained using inconsistent criterion). Another way is to just
        % specify a number of clusters and use the distance criterion
        % (i.e., just snips the dendrogram off at some threshold)...
        if length(ClusterParams)>=4 && ~isempty(ClusterParams{4})
            clustth = ClusterParams{4}; % method (string), max # clusters (integer)
            % e.g., {'cutoff',10} % will get (max) 10 clusters using cutoff method
            % e.g., {'maxnclust',10} will get 10 clusters using distance criterion
        else
            clustth = []; % don't do clustering
        end
        if ~isempty(clustth)
            clusterM = clustth{1}; % METHOD for forming clusters
            clusterN = clustth{2}; % number of clusters to form
        end
        
        % ** savetofile -- if want to save output of linkage clustering to
        % file, to be read in later by other routines.
        % if 1, saves to file; if 2, loads from file, if zero, doesn't do
        % either -- (outputs only to function outputs).
        % can also specify a filename to load from as savetofile
        if length(ClusterParams)>=5 && ~isempty(ClusterParams{5})
            savetofile = ClusterParams{5};
        else
            savetofile = 0; % don't save output of linkage clustering to file
        end
        
		% output is just one group with a given ordering
		
		%% Linkage
        if isstruct(savetofile) % specify R and links within a structure
            R = savetofile.R;
            links = savetofile.links;
            clear savetofile
        elseif ischar(savetofile) % specify a filename containing R and links
            fn = savetofile;
            load(fn,'R','links'); % load custom distance and linkage information
        elseif savetofile==2 % this means to load from file
            if strcmp(metorts,'ts')
                fn = 'TS_guide_clinksr.mat';
            else
                fn = 'TS_guide_clinksc.mat';
            end
            load(fn,'R','links');
        else
            % pairwise distances
            if strcmp(dmth,'abscorr') % custom distance function
                if any(isnan(TS_DataMat(:)));
                    disp('NaNs in input matrix -- distance calculations are going to be SLOW...')
                    R = benpdist(TS_DataMat,'corr',1);
                else % all good values -- can do this using pdist which is very fast
                    R = pdist(TS_DataMat,'corr');
                end
                R = 1-abs(1-R);
                R(R<0) = 0;% sometimes get numerical error
                disp(['abscorr transformation :: R between ' num2str(min(R)) ' (0) - ' num2str(max(R)) ' (1)'])
            else
                if any(isnan(TS_DataMat(:))) % NaNs: need to do this the slow way:
                    disp('NaNs in input matrix -- distance calculations are going to be SLOW...')
                    R = benpdist(TS_DataMat,dmth,1);
                else
                    R = pdist(TS_DataMat,dmth);
                end
            end
            % links
            links = linkage(R,lmth);

            % Display cophentic correlation (goodness of linkage)
            cpc = cophenet(links,R);
            disp(['Cophenetic correlation is ' num2str(cpc)])

            % Save to file
            if savetofile==1
                disp('Saving R and links to file');
                if strcmp(metorts,'ts')
                    fn = 'TS_guide_clinksr.mat';
                else
                    fn = 'TS_guide_clinksc.mat';
                end
                disp(['Saving the linkage information as ''' fn ''''])
                save(fn,'R','links','-v7.3')
                if nargout<1
                    return % don't bother doing the rest if all we wanted was this
                end
            end
        end

        
        %% Cluster
        % extracts a discrete clustering from the hierarchy obtained above
		if ~isempty(clustth) % do this clustering
            if strcmp(clusterM,'cutoffN')
                % specify number of clusters by inconsistent measure
                depth = 2; % depth down hierarchy to look
                criterion = 'inconsistent';
                
                cr = (0.1:0.1:10);
                nc = length(cr);
                nclusters = zeros(nc,1);
                for i = 1:nc
                    c = cr(i);
                    T = cluster(links,'cutoff',c,'depth',depth,'criterion',criterion);
                    nclusters(i) = max(T);
                    if nclusters(i) <= clusterN % we've got it!
                        break
                    end
                end
                
                % plot the result
                figure('color','w'); box('on');
                plot(cr(1:i),nclusters(1:i),'.-k')
                xlabel('cutoff value, c')
                ylabel('# clusters')
                nclusters = nclusters(i);

                % we've reached our cluster threshold! (or the end of cr)
                % acgi contains indices for members of each cluster
                disp(['Clustering at cutoff ' num2str(c) ' with ' num2str(nclusters) ' clusters'])
            elseif strcmp(clusterM,'cutoff')
                % just do cutoff clustering
                % for this method clusterN is the cutoff value, rather than
                % the actual number of clusters.
                
                depth = 2; % depth down hierarchy to look
                criterion = 'inconsistent';
                T = cluster(links,'cutoff',clusterN,'depth',depth,'criterion',criterion);
                nclusters = max(T);
            elseif strcmp(clusterM,'maxnclust')
                % just do distance-based clustering
                T = cluster(links,'maxclust',clusterN);
                nclusters = max(T);
                disp(['Distance-based clustering with ' num2str(nclusters) ' clusters'])
            else
                disp('Invalid clustering method'); return
            end
            
            acgi = cell(nclusters,1);
            ackwgs = cell(nclusters,1);
            gil = zeros(nclusters,1);
            R = squareform(R); % could be fancy to save memory, but I think we can handle it...
            for j = 1:nclusters
                ackwgs{j} = ['AGG_C' num2str(j)];
                acgi{j} = find(T==j);
                gil(j) = length(acgi{j});
                % reorder in terms to put members closest to 'cluster
                % centre' (chosen by *mean* of group's feature vectors) first
                if gil(j) > 1 % more than one member
                    % MAY BE BETTER TO JUST MINIMIZE DISTANCES TO OTHER
                    % POINTS:
                    % we have our distance matrix R
                    % reorder by sum of distances to other points in the
                    % cluster
                    [~,ix] = sort(sum(R(acgi{j},acgi{j})),'ascend');
                    acgi{j} = acgi{j}(ix);
                    
                    % OLD METHOD: FIND CLOSEST TO CLUSTER CENTRE
%                     % go through all members of cluster and look at distances to
%                     % centre -- centre means something different depending
%                     % on your distance measure
%                     dd = zeros(gil(j),1);
%                     switch dmth
%                         case 'euclidean'
%                             % mean centre and euclidean distances from it
%                             cc = mean(F(acgi{j},:)); % the cluster centre, cc
%                             for k = 1:gil(j)
%                                 dd(k) = sqrt(sum((F(acgi{j}(k),:)-cc).^2)); % euclidean distances
%                             end
%                         case 'abscorr'
%                             % complicated: first distinguish positive from
%                             % negatively-correlated parts
%                             cctmp = F(acgi{j}(1),:); % temporary centre: pick the first element (random)
%                             signs = zeros(gil(j));
%                             for k = 1:gil(j)
%                                 R = corrcoef(F(acgi{j}(k),:),cctmp);
%                                 signs(k) = sign(R(2,1));
%                             end
%                             pc = find(signs==1);
%                             Fp = F(acgi{j}(pc),:); % positively correlated to a test vector
%                             Fn = F(acgi{j}(setxor(pc,1:gil(j))),:); % all others
%                             cc = mean([Fp;1-Fn]); % the cluster centre, cc -- negative-correlation-adjusted
%                             
%                             % now we have an appropriate cluster centre,
%                             % get 1-abs(correlation) distances
%                             for k = 1:gil(j)
%                                 R = corrcoef(F(acgi{j}(k),:),cc);
%                                 dd(k) = 1-abs(R(2,1));
%                             end
%                         case 'mi'
%                             cc = mean(F(acgi{j},:)); % the cluster centre, cc
%                             for k = 1:gil(j)
%                                 dd(k) = -BF_MutualInformation(F(acgi{j}(k),:),cc,'quantile','quantile',10); % with 10 bins
%                             end
%                         otherwise
%                             disp('strange distance metric!!..........')
%                             keyboard
%                     end
%                     % reorder to have closest to centre first
%                     [sdd,ix] = sort(dd,'ascend');
%                     acgi{j} = acgi{j}(ix);
                end
            end
            
            % reorder by decreasing cluster size
            [~,ix] = sort(gil,'descend');
            ackwgs = ackwgs(ix);
            acgi = acgi(ix);
            
        else % don't do agglomerative clustering, just return the dendrogram ordering
            figure('color','w');
            if ~showdend, set(gcf,'Visible','off'); end % suppress figure output
            if size(TS_DataMat,1) < 1000 % small enough to try optimalleaforder
                try
%                     ord = bensoptimalleaforder(links,R); % NEW!
                    ord = optimalleaforder(links,R); % NEW!
                    [~,~,ord] = dendrogram(links,0,'r',ord);
                    fprintf(1,'Used optimalleaforder!\n')
                catch
                    beep
                    fprintf(1,'optimalleaforder was not used :(\n')
                    [~,~,ord] = dendrogram(links,0);
                end
            else
                fprintf(1,'Too big for optimalleaforder\n')
                [~,~,ord] = dendrogram(links,0);
            end
            ackwgs = {[lmth '_' dmth '_linkage']};
            acgi = ord; % outputs one cluster with an ordering given by the linkage clustering
            if ~showdend, close; end
        end
        
        
    case 'kmeans_spider'
        %% Check the inputs
        disp('Using the spider package''s kmeans clustering')
        % ClusterParams specifies {k,distancemeasure,maxiterations}
        % ** k
        if ~isempty(ClusterParams) && ~iscell(ClusterParams), ClusterParams = {ClusterParams}; end
        
        if length(ClusterParams)>=1
            k = ClusterParams{1};
        else
            k = 2;
            disp('forming 2 clusters using kmeans')
        end

        % ** distance measure
        if length(ClusterParams)>=2
            distancemeasure = ClusterParams{2};
        else
            distancemeasure = 'euclid';
            disp('using euclidean distance for kmeans')
        end
        
        % ** maxiterations
        % maximum number of iterations of training
        if length(ClusterParams)>=3
            maxiterations = ClusterParams{3};
        else
            maxiterations = 1000;
        end


        %% Specify the model
        a = kmeans; 
        a.k = k;
        a.child = distance(distancemeasure); % set the distance measure
        a.max_loops = maxiterations;
        
        [r,a] = train(a,data(TS_DataMat)); % do the clustering

        % get clusters
%         [rubbish ord_1] = sort(r.X);
        
        % secondary: order by distance to cluster centre
        cc = a.mu;
%         ord = 1:size(TS_DataMat,1);
        ackwgs = cell(k,1);
        acgi = cell(k,1);
        
        for i=1:k
            ackwgs{i} = ['KMEANS_C' num2str(i)];
            
            ii = find(r.X==i);
            % in this subrange, order by distance to cluster centre
            dd = zeros(length(ii),1);
            for j=1:length(ii)
                dd(j) = calc(distance(distancemeasure),data(TS_DataMat(ii(j),:)),data(cc(i,:)));
                % evaluates the distance between each point and its
                % assigned cluster centre -- stores in vector dd
            end
            [~,ord_2] = sort(dd);
            acgi{i} = ii(ord_2);
        end
        
	case 'kmeans_matlab'
        %% Check the inputs
        disp('Using matlab''s statistics toolbox kmeans clustering')
        % ClusterParams specifies {k,distancemeasure,nrep,starts}
        % ** k
        if ~isempty(ClusterParams) && ~iscell(ClusterParams), ClusterParams = {ClusterParams}; end

        if length(ClusterParams)>=1
            k = ClusterParams{1};
        else
            k = 2;
            disp('forming 2 clusters using kmeans')
        end

        % ** distance measure
        if length(ClusterParams)>=2
            distancemeasure = ClusterParams{2};
            if strcmp(distancemeasure,'Euclidean')
                distancemeasure = 'sqEuclidean';
            end
        else
            distancemeasure = 'sqEuclidean';
            disp('using euclidean distance for kmeans')
        end

        % ** nrep
        % number of replicates
        if length(ClusterParams)>=3
            nrep = ClusterParams{3};
        else
            nrep = 1;
        end
		
		% ** starts
		% how to initialize the algorithm
		if length(ClusterParams)>=4
			starts = ClusterParams{4};
		else
			starts = 'sample'; % samples from the data matrix
        end

        
        %% Specify the model
        [idx,~,~,D] = kmeans(TS_DataMat, k, 'dist',distancemeasure, 'replicates',nrep,...
        							'start',starts, 'emptyaction','singleton', 'display','off');

        ackwgs = cell(k,1); % keywords
		acgi = cell(k,1); % indicies
        for i=1:k
            ackwgs{i} = ['KMEANS_C' num2str(i)];
            acgi{i} = find(idx==i);
		    d = D(acgi{i},i); % distances of points in this cluster to this cluster's centroid
		    [~,ix] = sort(d,'ascend');
		    acgi{i} = acgi{i}(ix); % those that are closest to the cluster centroid are listed first
        end
        
    case 'kmedoids'
        %% Check the inputs
        disp('Using Ben''s cute little implementation of kmedoids')
        % ClusterParams specifies k, distancemeasure, nrep
        % ** k
        if isfield(ClusterParams,'k')
            k = ClusterParams.k;
        else
            k = 2;
            disp('Forming 2 clusters using kmediods')
        end
        if isfield(ClusterParams,'dmth')
            dmth = ClusterParams.dmth;
        else
            dmth = 'Euclidean';
        end
        if isfield(ClusterParams,'maxIter')
            maxIter = ClusterParams.maxIter;
        else
            maxIter = 50;
        end
        if isfield(ClusterParams,'nrep')
            nrep = ClusterParams.nrep;
        else
            nrep = 20;
        end
        if isfield(ClusterParams,'file')
            whatwithfile = ClusterParams.file; % filename to retrieve, or integer to specify
        else
            whatwithfile = 0; % calculate distance matrix now, don't save to file
        end
        if isfield(ClusterParams,'errmeas')
            errmeas = ClusterParams.errmeas;
        else
            errmeas = 'sum';
        end
        
        % retrieve distances if necessary
        if ischar(whatwithfile) % load from custom filename
            fn = whatwithfile;
            tic
            load(fn,'R'); % load custom distance ('links' not needed)
            disp(['loaded R from ' fn ' took ' BF_thetime(toc)])
        elseif (whatwithfile == 2) % load from TS_guide_clinks
            if strcmp(metorts,'ts')
                fn = 'TS_guide_clinksr.mat';
            else
                fn = 'TS_guide_clinksc.mat';
            end
            load(fn,'R'); % don't need 'links'
        elseif ndims(whatwithfile)==2 && length(whatwithfile)>1 % you've supplied R in file field!
            R = whatwithfile; clear whatwithfile
        else
            % calculate pairwise distances
            if strcmp(dmth,'abscorr') % special distance function
                R = pdist(TS_DataMat,'correlation');
                R = 1-abs(1-R);
                R(R<0) = 0;% sometimes get numerical error
                disp(['R between ' num2str(min(R)) ' (0) - ' num2str(max(R)) ' (1)'])
            else
                R = pdist(TS_DataMat,dmth);
            end
        end

        %% Run the algorithm
        if size(R,1)==1
            R = squareform(R); % we want a full matrix for benkmedoids
        end
        [~,~,errs,acgi] = benkmedoids(R,k,maxIter,nrep,errmeas);
        disp(['k-Medoids successful, with ' num2str(sum(errs)) ' ''error'''])
        % output acgi is already ordered by sum of distances to cluster
        % centre
        
        ackwgs = cell(k,1); % keywords
        for i=1:k
            ackwgs{i} = ['KMEDOIDS_C' num2str(i)];
        end

    case 'gmm'
        %% Gaussian Mixture Modeling
        % use Gaussian Mixture modeling from the Statistics Toolbox
        % Ben Fulcher 6/7/2010
        
        if ~isempty(ClusterParams) && ~iscell(ClusterParams), ClusterParams = {ClusterParams}; end

        if length(ClusterParams)>=1
            k = ClusterParams{1};
        else
            k = 2;
            disp('forming 2 clusters using a mixture of Gaussians')
        end
        
        options = statset('Display','final');
        gm = gmdistribution.fit(TS_DataMat, k, 'Options', options);
        % now assign clusters
        idx = cluster(gm,TS_DataMat);
        
%         for i=1:k
%             ackwgs{i} = ['KMEANS_C' num2str(i)];
%             acgi{i} = find(idx==i);
% 		    d = D(acgi{i},i); % distances of points in this cluster to this cluster's centroid
% 		    [d_s ix] = sort(d,'ascend');
% 		    acgi{i} = acgi{i}(ix); % those that are closest to the cluster centroid are listed first
%         end
        ackwgs = cell(k,1); % keywords
		acgi = cell(k,1); % indicies
        P = posterior(gm,TS_DataMat); % posterior under each mixture component
        for i = 1:k
            ackwgs{i} = ['GMM_C' num2str(i)];
            acgi{i} = find(idx==i);
            [~,ix] = sort(P(acgi{i},i),'ascend');
            acgi{i} = acgi{i}(ix);
            % now reorder based on distance to cluster centre (probably
            % better to do by posterior...?
%             cc = gm.mu(1,:); % the mean of this gaussian mixture
%             component
%             dd = zeros(length(acgi{i}),1);
%             for j = 1:length(acgi{i})
%                 dd(k) = sqrt(sum((F(acgi{i}(j),:)-cc).^2)); % euclidean distances
%             end
            
        end
        
        
    case 'spectral'
        %% Spectral Clustering: check the inputs
        disp('Using the spider package''s spectral clustering')
        % doesn't work so well on large numbers of features
        % ClusterParams specifies {k,sigma}
        % ** k, number of clusters
        if length(ClusterParams)>=1
            k = ClusterParams{1};
        else
            k = 2; % 2 clusters
        end
        
        % ** sigma, scale of exponential
        if length(ClusterParams)>=2
            sigma = ClusterParams{2};
        else
            sigma = 0.05;
        end
        
        %% Specify and train the model
        a = spectral;
        a.k = k;
        a.sigma = sigma;
        
        d = data(TS_DataMat);
        d.Y = []; % unsupervised
        
        [r,a] = train(a,d); % do the clustering
        
        %% Package Output
        ackwgs = cell(k,1);
        acgi = cell(k,1);
        
        for i=1:k
            ackwgs{i} = ['SPECTRAL_C' num2str(i)];
            acgi{i} = find(r.X==i); % unordered within each cluster
        end
	otherwise
		disp([ClusterMethod ' -- an invalid clustering option'])
		return
end


% Also output the clustered input matrix
if nargout > 2
	if iscell(acgi)
		TS_DataMat_cl = TS_DataMat(vertcat(acgi{:}),:);
	else
		TS_DataMat_cl = TS_DataMat(acgi,:);
	end
end



end