function varargout = clean_out_psth(out_fn, varargin)
%varargs
%1: save cleaned out .mat file (detault true)
%2: save cleaned spikes table (default true)
% god i fkn hate matlab
switch length(varargin)
    case 0
        save_mat = 1;
        save_csv = 1;
    case 1
        save_mat = varargin{1};
        save_csv = 1;
    case 2
        save_mat = varargin{1};
        save_csv = varargin{2};
end

% read out file

% set desired fields and names depending on stim type
load(out_fn);
stimtype = out.stimlog(1).type;
% hack
for i = 1:length(out.stimlog)
    if strcmp(out.stimlog(i).type, 'soundfile')
        stimtype='soundfile';
    end
end
switch stimtype
    case 'clicktrain'
        field_list = {'cell','icis','durs','MtOFF','samprate','stimlog'};
        rename_list = {'cell','icis','durs','spiketimes','samprate','stimlog'};
        stim_idx = {'icis'};
    case 'tone'
        field_list  = {'cell','amps','freqs','durs','M1OFF','samprate','stimlog'};
        rename_list = {'cell','amps','freqs','durs','spiketimes','samprate','stimlog'};
        stim_idx = {'freqs','amps'};
    case 'silentsound'
        % aka PINPing
        field_list  = {'cell','MPulse','MTrain','pulsewidths','trainnumpulses','trainpulsewidths','trainisis','samprate','stimlog'};
        rename_list = {'cell','pulse_spikes','train_spikes','pulsewidths','trainnumpulses','trainpulsewidths','trainisis','samprate','stimlog'};
    case 'soundfile'
        field_list  = {'cell','LaserStart','LaserWidth','M1ON','M1OFF','amps','durs','sourcefiles','samprate','stimlog'};
        rename_list = {'cell','laser_start','laser_width','on_spikes','off_spikes','amps','durs','files','samprate','stimlog'};
        stim_idx = {'files','amps','durs'};
        
end

% get desired fields, renaming
clean_out = struct();
for field=1:length(field_list)
    clean_out.(rename_list{field}) = out.(field_list{field});
end

% unnest spiketimes
switch stimtype
    case 'silentsound'
        pulse_spikes = {};
        for i = 1:prod(size(clean_out.pulse_spikes))
            pulse_spikes(i) = {clean_out.pulse_spikes(i).spiketimes};
        end
        train_spikes = {};
        for i = 1:prod(size(clean_out.train_spikes))
            train_spikes(i) = {clean_out.train_spikes(i).spiketimes};
        end
        clean_out.pulse_spikes = pulse_spikes;
        clean_out.train_spikes = train_spikes;
    
    case 'soundfile'
        off_spikes = {};
        for i = 1:prod(size(clean_out.off_spikes))
            off_spikes(i) = {clean_out.off_spikes(i).spiketimes};
        end
        on_spikes = {};
        for i = 1:prod(size(clean_out.on_spikes))
            on_spikes(i) = {clean_out.on_spikes(i).spiketimes};
        end
        clean_out.off_spikes = reshape(off_spikes, size(clean_out.off_spikes));
        clean_out.on_spikes  = reshape(on_spikes, size(clean_out.on_spikes));
    
        
    
    otherwise
        spiketimes = {};
        n_cells = prod(size(clean_out.spiketimes));
        for i = 1:n_cells
            spiketimes(i) = {clean_out.spiketimes(i).spiketimes};
        end
        % reshape
        spiketimes = reshape(spiketimes,size(clean_out.spiketimes));
        clean_out.spiketimes = spiketimes;
end

if save_mat == 1
    % unnest stimlog params
    stim_params = struct2table(clean_out.stimlog(1).param);
    for i=2:length(clean_out.stimlog)
        param_row = struct2table(clean_out.stimlog(i).param);
        stim_params = concat_tables(stim_params, param_row);
    end
    clean_out.stimparams = stim_params;
end
% rename so when we load again it's consistent
out = clean_out;
% save
[save_dir,fn,~] = fileparts(out_fn);
if length(save_dir) <= 1
    save_dir = pwd;
end
split_fn = strsplit(fn, 'c');
save_fn = ['out_',split_fn{end},'_clean.mat'];
if save_mat == 1
    save(fullfile(save_dir,save_fn),'out');

    fprintf('\nsaved clean out file to: %s',fullfile(save_dir,save_fn))
end

%%%%%%%%%
% create long format spiketimes


spike_table = table();
switch stimtype
    case 'clicktrain'
        reps = size(out.spiketimes);
        reps = reps(end);
        [stim_reps,stim_idx1] = meshgrid(1:reps,out.(stim_idx{1}));
        for i=1:prod(size(out.spiketimes))
            spikes = out.spiketimes{i}';
            nspikes = length(spikes);
            idx1 = repmat(stim_idx1(i),nspikes,1);
            rep  = repmat(stim_reps(i),nspikes,1);
            spike_table = [spike_table;table(spikes,idx1,rep)];
        end
        spike_table.Properties.VariableNames{'idx1'} = stim_idx{1};
        expt = repmat('clicktrain', height(spike_table),1);
        spike_table = [spike_table, table(expt)];

    case 'tone'
        reps = size(out.spiketimes);
        reps = reps(end);
        [stim_idx1,stim_idx2, stim_reps] = ndgrid(out.(stim_idx{1}), out.(stim_idx{2}), 1:reps);
        for i = 1:prod(size(out.spiketimes))
            spikes = out.spiketimes{i}';
            nspikes = length(spikes);
            if nspikes==0
                continue
            end
            idx1 = repmat(stim_idx1(i),nspikes,1);
            idx2 = repmat(stim_idx2(i),nspikes,1);
            rep  = repmat(stim_reps(i),nspikes,1);
            spike_table = [spike_table;table(spikes,idx1,idx2,rep)];
        end
        
        % if we haven't gotten any spikes, dont try it
        table_size = size(spike_table);
        if table_size(1) ~= 0
            spike_table.Properties.VariableNames{'idx1'} = stim_idx{1};
            spike_table.Properties.VariableNames{'idx2'} = stim_idx{2};
            % add experiment type and duration (assuming we have only one
            % duration)
            dur  = repmat(out.durs,       height(spike_table),1);
            expt = repmat('tuning_curve', height(spike_table),1);
            spike_table = [spike_table, table(expt), table(dur)];
            
        end
        

    case 'silentsound'
        % aka pinping
        % first do pulses
        pulse_table = table();
        for i = 1:size(out.pulse_spikes,2)
            spikes = out.pulse_spikes{i}';
            nspikes = length(spikes);
            if nspikes==0
                continue
            end
            type = repmat(["pulse"], nspikes, 1);
            rep  = repmat([i],       nspikes, 1);
            pulse_width = repmat(out.pulsewidths, nspikes,1);
            pulse_table = [pulse_table;table(spikes,type,rep,pulse_width)];
        end
        
        % then trains
        train_table = table();
        for i = 1:size(out.train_spikes,2)
            spikes = out.train_spikes{i}';
            nspikes = length(spikes);
            if nspikes==0
                continue
            end
            type = repmat(["train"], nspikes, 1);
            rep  = repmat([i],       nspikes, 1);
            pulse_width = repmat(out.trainpulsewidths, nspikes,1);
            n_pulses = repmat(out.trainnumpulses, nspikes,1);
            isi = repmat(out.trainisis, nspikes,1);
            train_table = [train_table;table(spikes,type,rep,pulse_width, n_pulses, isi)];
        end
        spike_table = concat_tables(pulse_table,train_table); 
        expt = repmat("pinp", height(spike_table),1);
        spike_table = [spike_table, table(expt)];
        
    case 'soundfile'
        % rename files
        for i = 1:length(out.files)
            split_file = strsplit(out.files{i},'_'); 
            name_ind = find(cellfun(@(s) ~isempty(strfind(s, 'sourcefile')), split_file))+1;
            out.files{i} = split_file{name_ind};
        end
        
        reps = size(out.on_spikes);
        reps = reps(end);
        [stim_idx1,stim_idx2,stim_idx3, stim_reps] = ndgrid(out.(stim_idx{1}), out.(stim_idx{2}),out.(stim_idx{3}), 1:reps);
        for i = 1:prod(size(out.on_spikes))
            spikes = out.on_spikes{i}';
            nspikes = length(spikes);
            if nspikes==0
                continue
            end
            idx1 = repmat(stim_idx1(i),nspikes,1);
            idx2 = repmat(stim_idx2(i),nspikes,1);
            idx3 = repmat(stim_idx3(i),nspikes,1);
            rep  = repmat(stim_reps(i),nspikes,1);
            spike_table = [spike_table;table(spikes,idx1,idx2,idx3,rep)];
        end
        laser = repmat(1, height(spike_table),1);
        laser_start = repmat(out.laser_start(1), height(spike_table),1);
        laser_dur   = repmat(out.laser_width(1),  height(spike_table),1);
        spike_table = [spike_table, table(laser, laser_start, laser_dur)];
        
        % same for laser off
        off_table = table();
        for i = 1:prod(size(out.off_spikes))
            spikes = out.off_spikes{i}';
            nspikes = length(spikes);
            if nspikes==0
                continue
            end
            idx1 = repmat(stim_idx1(i),nspikes,1);
            idx2 = repmat(stim_idx2(i),nspikes,1);
            idx3 = repmat(stim_idx3(i),nspikes,1);
            rep  = repmat(stim_reps(i),nspikes,1);
            off_table = [off_table;table(spikes,idx1,idx2,idx3,rep)];
        end
        laser = repmat(0, height(off_table),1);
        off_table = [off_table, table(laser)];
        
        spike_table = concat_tables(spike_table, off_table);
        
        spike_table.Properties.VariableNames{'idx1'} = stim_idx{1};
        spike_table.Properties.VariableNames{'idx2'} = stim_idx{2};
        spike_table.Properties.VariableNames{'idx3'} = stim_idx{3};
        % add experiment type and duration (assuming we have only one
        % duration)
        expt = repmat('soundfile', height(spike_table),1);
        spike_table = [spike_table, table(expt)];

        
end

% add some final universals
cell = repmat(out.cell, height(spike_table),1);
spike_table = [spike_table, table(cell)];

% save
if save_csv == 1
    save_fn = ['out_',split_fn{end},'_spikes.csv'];
    writetable(spike_table,fullfile(save_dir,save_fn));

    fprintf('\nsaved spikes table to: %s',fullfile(save_dir,save_fn))
end

% if asked to return, return
if nargout == 1
    varargout{1} = spike_table;
end
end

