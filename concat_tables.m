function new_table = concat_tables(table1,table2)

    % account for stims that have differing parameters - expand both tables
    % super slow but matlab just CANT FUCKING HANDLE JOINS
    t1colmissing = setdiff(table2.Properties.VariableNames, table1.Properties.VariableNames);
    t2colmissing = setdiff(table1.Properties.VariableNames, table2.Properties.VariableNames);
    
    table1 = [table1 array2table(nan(height(table1), numel(t1colmissing)), 'VariableNames', t1colmissing)];
    table2 = [table2 array2table(nan(height(table2), numel(t2colmissing)), 'VariableNames', t2colmissing)];
    
    new_table = [table1;table2];
    
end