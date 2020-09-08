function varargout = clean_out_dir(varargin)
% arguments
% 1: path to out files (default: pwd)
% 2: save individual files? (default: false)
% 3: name to give to savefile (default: none)
switch length(varargin)
    case 0
        path = pwd;
        save_cells = 0;
        name = '';
    case 1
        path = varargin{1};
        save_cells = 0;
        name = '';
    case 2
        path = varargin{1};
        if ischar(varargin{2})
            name = varargin{2};
            save_cells = 0;
        else
            name = '';
            save_cells = varargin{2};
        end
    case 3
        path = varargin{1};
        save_cells = varargin{2};
        name = varargin{3};
end

% get out files
if path(end)~= filesep
    path = [path, filesep];
end

search_path = [path, 'outPSTH*.mat'];
out_dir = dir(search_path);

% loop thru
dir_table = table();
for i = 1:size(out_dir,1)
    out_fn = fullfile(out_dir(i).folder, out_dir(i).name);
    cell_table = clean_out_psth(out_fn, save_cells, save_cells);
    dir_table = concat_tables(dir_table, cell_table);
end

% save it
if length(name)>0
    save_name = ['out_combined_' name '.csv'];
else
    save_name = 'out_combined.csv';
end
save_fn = fullfile(path, save_name);

writetable(dir_table,save_fn);
fprintf('\nsaved spikes table to: %s\n',save_fn)

if nargout>0
    varargout{1} = dir_table;
end
