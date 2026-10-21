function out = Vivaldi_HFSS_Simulation(action, input, settings)
% SPDX-License-Identifier: GPL-2.0-or-later
% VIVALDI_HFSS_SIMULATION Solver tách biệt Builder; chỉ đọc kết quả CSV thật.
% s = ...('validate',struct(...)); ...('writeSetup',struct('fid',fid,'settings',s))
% run = ...('run',build,s); data = ...('read',run.folder); ...('plot',data,axes)
if nargin<2, input=struct(); end
switch action
    case 'validate', out=validateSettings(input);
    case 'writeSetup'
        s=validateSettings(input.settings); fid=input.fid;
        replace=isfield(input,'replace') && input.replace;
        writeSetup(fid,s,replace); out=s;
    case 'run'
        if nargin<3, settings=struct(); end
        out=runSimulation(input,validateSettings(settings));
    case 'generate'
        if nargin<3, settings=struct(); end
        out=generateSimulation(input,validateSettings(settings));
    case 'read', out=readResults(input);
    case 'plot', plotResults(input,settings); out=[];
    otherwise, error('Vivaldi:SimulationAction','Lệnh mô phỏng không hợp lệ: %s',action);
end
end

function s=validateSettings(s)
def=struct('StartGHz',5,'StopGHz',20,'StepGHz',0.25,'AdaptiveGHz',5, ...
    'DeltaS',0.02,'MinimumPasses',5,'MaximumPasses',50, ...
    'Power1',1,'Phase1',0,'Power2',0,'Phase2',0, ...
    'SaveFields',true,'SaveRadiation',true,'PatternGHz',[]);
names=fieldnames(s);
assert(all(isfield(def,names)),'Vivaldi:Simulation','Có tùy chọn mô phỏng không được hỗ trợ.');
names=fieldnames(def);
for k=1:numel(names)
    if ~isfield(s,names{k}), s.(names{k})=def.(names{k}); end
end
if isempty(s.PatternGHz), s.PatternGHz=s.StartGHz; end
for k=1:numel(names)
    validateattributes(s.(names{k}),{'numeric','logical'}, ...
        {'real','finite','scalar'},mfilename,names{k});
end
assert(s.StartGHz>0 && s.StopGHz>s.StartGHz && s.StepGHz>0 && s.AdaptiveGHz>0, ...
    'Vivaldi:Simulation','Cần 0 < Start < Stop, Step > 0, Adaptive > 0.');
n=(s.StopGHz-s.StartGHz)/s.StepGHz;
assert(abs(n-round(n))<1e-8 && n>=1 && n<=10000, ...
    'Vivaldi:Simulation','Sweep cần số khoảng nguyên, tối đa 10001 điểm.');
assert(s.DeltaS>0 && s.DeltaS<1 && s.MinimumPasses>=1 && ...
    s.MaximumPasses>=s.MinimumPasses && ...
    all(mod([s.MinimumPasses s.MaximumPasses],1)==0), ...
    'Vivaldi:Simulation','Delta S hoặc số adaptive passes không hợp lệ.');
assert(s.Power1>=0 && s.Power2>=0 && s.Power1+s.Power2>0, ...
    'Vivaldi:Excitation','Công suất không âm và ít nhất một port được kích thích.');
assert(all(ismember([s.SaveFields s.SaveRadiation],[0 1])) && ...
    (~s.SaveRadiation || s.SaveFields),'Vivaldi:Simulation', ...
    'SaveRadiation yêu cầu SaveFields; tùy chọn phải là true/false.');
assert(s.PatternGHz>=s.StartGHz && s.PatternGHz<=s.StopGHz && ...
    abs((s.PatternGHz-s.StartGHz)/s.StepGHz-round((s.PatternGHz-s.StartGHz)/s.StepGHz))<1e-8, ...
    'Vivaldi:Simulation','Tần số pattern phải trùng một điểm trong sweep.');
end

function writeSetup(fid,s,replace)
% API gốc dùng đúng chữ ký 8 tham số. Không gọi Analyze tại đây.
fprintf(fid,'Set oModule = oDesign.GetModule("AnalysisSetup")\n');
if replace, fprintf(fid,'oModule.DeleteSetups Array("Setup1")\n'); end
file=tempname; f=fopen(file,'wt'); cleanup=onCleanup(@() removeTemp(f,file));
hfssInsertSolution(f,'Setup1',s.AdaptiveGHz,s.DeltaS,s.MaximumPasses,s.MinimumPasses,min(2,s.MinimumPasses),30);
fclose(f); text=fileread(file);
text=regexprep(text,'("Frequency:=",\s*)"[^"]*"',sprintf('$1"%.17gGHz"',s.AdaptiveGHz));
text=regexprep(text,'"maxDeltaS:=",\s*[0-9.]+',sprintf('"maxDeltaS:=", %.17g',s.DeltaS));
fprintf(fid,'%s',text); clear cleanup;
fprintf(fid,['oModule.InsertFrequencySweep "Setup1", Array("NAME:Sweep1", "IsEnabled:=", True, ' ...
    '"RangeType:=", "LinearStep", "RangeStart:=", "%.17gGHz", "RangeEnd:=", "%.17gGHz", ' ...
    '"RangeStep:=", "%.17gGHz", "Type:=", "Discrete", "SaveFields:=", %s, ' ...
    '"SaveRadFields:=", %s, "ExtrapToDC:=", False)\n'], ...
    s.StartGHz,s.StopGHz,s.StepGHz,vbBool(s.SaveFields),vbBool(s.SaveRadiation));
if ~replace
    hfssInsertFarFieldSphereSetup(fid,'3D',[0 180 2],[-180 180 2],'');
    hfssInsertFarFieldSphereSetup(fid,'Elevation',[-180 180 1],[0 90 90],'');
    % Dải theta cố định dùng step dương; không chia cho khoảng theta bằng 0.
    hfssInsertFarFieldSphereSetup(fid,'Azimuth',[90 90 1],[-180 180 1],'');
end
fprintf(fid,'Set oModule = oDesign.GetModule("Solutions")\n');
fprintf(fid,['oModule.EditSources Array(Array("IncludePortPostProcessing:=", True, ' ...
    '"SpecifySystemPower:=", False), Array("Name:=", "1:1", "Magnitude:=", "%.17gW", "Phase:=", "%.17gdeg"), ' ...
    'Array("Name:=", "2:1", "Magnitude:=", "%.17gW", "Phase:=", "%.17gdeg"))\n'], ...
    s.Power1,s.Phase1,s.Power2,s.Phase2);
end

function r=generateSimulation(build,s)
Vivaldi_HFSS_Builder('library');
assert(isfile(build.project),'Vivaldi:Project','Chưa có AEDT đã dựng thành công.');
assert(strcmp(build.status,'BUILD_COMPLETE'),'Vivaldi:Project','Chỉ mô phỏng project đã Validate và Save thành công.');
% Save Fields cần thiết cho pattern; S/VSWR/Z vẫn chạy khi người dùng tắt.
r=build; r.folder=tempname(build.folder); mkdir(r.folder);
[~,token]=fileparts(r.folder);
r.project=fullfile(r.folder,['Vivaldi_Simulation_' token '.aedt']);
assert(~isfile(r.project),'Vivaldi:Overwrite','File mô phỏng đã tồn tại.');
[ok,msg]=copyfile(build.project,r.project); assert(logical(ok),'Vivaldi:Copy','%s',msg);
r.script=fullfile(r.folder,'simulate.vbs'); r.log=fullfile(r.folder,'simulation.log');
r.expected='SIMULATION_COMPLETE'; r.status='SCRIPT_GENERATED'; r.simulation=s;
fid=fopen(r.script,'wt'); assert(fid>=0,'Vivaldi:File','Không tạo được simulate.vbs.');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'Sub Main()\nOn Error Resume Next\n');
fprintf(fid,'Dim fs, logFile, stepName, validationResult\n');
fprintf(fid,'Set fs = CreateObject("Scripting.FileSystemObject")\n');
fprintf(fid,'Set logFile = fs.CreateTextFile(%s, False, True)\n',quote(r.log));
fprintf(fid,'If Err.Number <> 0 Then Exit Sub\n');
fprintf(fid,'stepName = "SIM_01_OPEN"\n');
hfssOpenProject(fid,r.project); check(fid);
hfssSetDesign(fid,'dual_pol_vivaldi_patch_Wflare_20'); check(fid);
fprintf(fid,'logFile.WriteLine stepName & " API_COMPLETED"\nstepName = "SIM_02_SETUP"\n');
writeSetup(fid,s,true); check(fid);
fprintf(fid,'validationResult = oDesign.ValidateDesign(%s)\n',quote(fullfile(r.folder,'validation.log'))); check(fid);
fprintf(fid,'If validationResult <> 1 Then Err.Raise 518, "Validate", "Invalid design"\n'); check(fid);
fprintf(fid,'logFile.WriteLine stepName & " API_COMPLETED"\nstepName = "SIM_03_SOLVE"\n');
hfssSolveSetup(fid,'Setup1'); check(fid);
fprintf(fid,'logFile.WriteLine stepName & " API_COMPLETED"\nstepName = "SIM_04_EXPORT"\n');
report(fid,'S_parameters',1,1,'',{'Freq'}, ...
    {'Freq','dB(S(1,1))','dB(S(2,2))','dB(S(2,1))','dB(S(1,2))'},r.folder,{}); check(fid);
report(fid,'VSWR',1,1,'',{'Freq'},{'Freq','VSWR(1)','VSWR(2)'},r.folder,{}); check(fid);
report(fid,'Impedance',1,1,'',{'Freq'}, ...
    {'Freq','re(Z(1,1))','im(Z(1,1))','re(Z(2,2))','im(Z(2,2))'},r.folder,{}); check(fid);
if s.SaveRadiation
    freq=sprintf('%.17gGHz',s.PatternGHz);
    % Gain-vs-frequency tại theta=90,phi=0; không gọi đây là peak gain.
    report(fid,'Gain_frequency',5,1,'3D',{'Freq','Theta','Phi'}, ...
        {'Freq','dB(RealizedGainTotal)'},r.folder,{'Theta','90deg';'Phi','0deg'}); check(fid);
    report(fid,'Elevation',5,1,'Elevation',{'Theta','Phi','Freq'}, ...
        {'Theta','dB(RealizedGainTotal)'},r.folder,{'Freq',freq}); check(fid);
    report(fid,'Azimuth',5,1,'Azimuth',{'Phi','Theta','Freq'}, ...
        {'Phi','dB(RealizedGainTotal)'},r.folder,{'Freq',freq}); check(fid);
    report(fid,'Pattern3D',5,7,'3D',{'Phi','Theta','Freq'}, ...
        {'Phi','Theta','dB(RealizedGainTotal)'},r.folder,{'Freq',freq}); check(fid);
    report(fid,'AxialRatio',5,1,'Azimuth',{'Phi','Theta','Freq'}, ...
        {'Phi','dB(AxialRatioValue)'},r.folder,{'Freq',freq});
    fprintf(fid,['If Err.Number <> 0 Then\nlogFile.WriteLine "OPTIONAL_UNAVAILABLE AxialRatio " & ' ...
        'CStr(Err.Number) & " " & Err.Description\nErr.Clear\nEnd If\n']);
end
fprintf(fid,'stepName = "SIM_05_SAVE"\noProject.Save\n'); check(fid);
fprintf(fid,'logFile.WriteLine "SIMULATION_COMPLETE"\nlogFile.Close\nEnd Sub\nMain\n');
clear cleanup;
text=Vivaldi_HFSS_Builder('encode',fileread(r.script));
fid=fopen(r.script,'wb'); fwrite(fid,text,'char'); fclose(fid);
settings=s; save(fullfile(r.folder,'simulation_inputs.mat'),'settings');
end

function r=runSimulation(build,s)
r=generateSimulation(build,s);
r=Vivaldi_HFSS_Builder('run',r);
% Thành công solver/export phải đi kèm CSV số thật, không chỉ marker.
r.results=readResults(r.folder);
end

function report(fid,name,type,display,context,families,curves,folder,fixed)
% Tái dùng reporter gốc, bổ sung fixed family mà API cũ chỉ cho Array("All").
file=tempname; f=fopen(file,'wt'); assert(f>=0,'Vivaldi:File','Không tạo được report tạm.');
cleanup=onCleanup(@() removeTemp(f,file));
hfssCreateReport(f,name,type,display,'Setup1','Sweep1',context,'',families,curves);
hfssExportToFile(f,name,fullfile(folder,name),'csv'); fclose(f);
text=strrep(fileread(file),'"Modal S Parameter"','"Modal Solution Data"');
for k=1:size(fixed,1)
    text=strrep(text,['"' fixed{k,1} ':=", Array("All")'], ...
        ['"' fixed{k,1} ':=", Array("' fixed{k,2} '")']);
end
fprintf(fid,'%s',text);
end

function out=readResults(folder)
% Chỉ đọc file do một lượt solver/export hoàn tất trong thư mục riêng.
log=fullfile(folder,'simulation.log');
assert(isfile(log),'Vivaldi:Results','Thiếu log nguồn gốc của lượt mô phỏng.');
fid=fopen(log,'rb'); bytes=fread(fid,Inf,'*uint8')'; fclose(fid);
if numel(bytes)>2 && isequal(bytes(1:2),uint8([255 254]))
    text=native2unicode(bytes(3:end),'UTF-16LE');
else, text=native2unicode(bytes,'UTF-8'); end
assert(~isempty(strfind(text,'SIMULATION_COMPLETE')) && isempty(strfind(text,'FAILED')), ...
    'Vivaldi:Results','Lượt mô phỏng chưa hoàn tất; không dùng CSV thiếu/cached.');
required={'S_parameters','VSWR','Impedance'};
optional={'Gain_frequency','Elevation','Azimuth','Pattern3D','AxialRatio'};
metadata=fullfile(folder,'simulation_inputs.mat');
assert(isfile(metadata),'Vivaldi:Results','Thiếu metadata của lượt mô phỏng.');
source=load(metadata,'settings'); s=validateSettings(source.settings);
if s.SaveRadiation
    required=[required optional(1:4)]; optional=optional(5);
end
out=struct('folder',folder,'tables',struct());
for name=[required optional]
    if ~isempty(strfind(text,['OPTIONAL_UNAVAILABLE ' name{1}])), continue; end
    path=fullfile(folder,[name{1} '.csv']);
    if ~isfile(path)
        assert(~any(strcmp(name{1},required)),'Vivaldi:Results','Thiếu %s.',path);
        continue;
    end
    table=readtable(path,'VariableNamingRule','preserve');
    assert(height(table)>0 && width(table)>=2,'Vivaldi:Results','CSV rỗng: %s',path);
    numbers=table{:,:};
    assert(isnumeric(numbers) && isreal(numbers) && ~any(isnan(numbers(:))), ...
        'Vivaldi:Results','CSV không có dữ liệu số hợp lệ: %s',path);
    if any(strcmp(name{1},{'S_parameters','VSWR','Impedance','Gain_frequency'}))
        headers=table.Properties.VariableNames;
        f=findColumn(headers,'Freq');
        token=regexpi(headers{f},'\[(GHz|MHz|kHz|Hz)\]','tokens','once');
        assert(~isempty(token),'Vivaldi:CSVUnits','CSV thiếu đơn vị tần số: %s',path);
        units={'ghz','mhz','khz','hz'}; scale=[1 1e-3 1e-6 1e-9];
        frequency=numbers(:,f)*scale(strcmpi(token{1},units));
        expected=(s.StartGHz:s.StepGHz:s.StopGHz)';
        assert(numel(frequency)==numel(expected) && ...
            max(abs(sort(frequency)-expected))<1e-7*max(1,s.StopGHz), ...
            'Vivaldi:CSVFrequency','CSV thiếu/sai điểm sweep: %s',path);
    end
    switch name{1}
        case 'S_parameters', requiredColumns={'S(1,1)','S(2,2)','S(2,1)','S(1,2)'};
        case 'VSWR', requiredColumns={'VSWR(1)','VSWR(2)'};
        case 'Impedance', requiredColumns={'re(Z(1,1))','im(Z(1,1))','re(Z(2,2))','im(Z(2,2))'};
        otherwise, requiredColumns={};
    end
    for col=requiredColumns, findColumn(table.Properties.VariableNames,col{1}); end
    out.tables.(name{1})=table;
end
end

function plotResults(data,ax)
% ax là UIAxes thật; loại đồ thị được chọn bằng ax.UserData.
name=ax.UserData;
assert(isfield(data.tables,name),'Vivaldi:Results','Không có dữ liệu thật cho %s.',name);
t=data.tables.(name); headers=t.Properties.VariableNames; v=t{:,:};
cla(ax);
if strcmp(name,'Pattern3D')
    phi=findColumn(headers,'Phi'); theta=findColumn(headers,'Theta');
    gain=findColumn(headers,'RealizedGain');
    r=10.^(v(:,gain)/20); % Bán kính tuyến tính, màu biểu diễn gain dB thực.
    xyz=[r.*sind(v(:,theta)).*cosd(v(:,phi)), ...
         r.*sind(v(:,theta)).*sind(v(:,phi)),r.*cosd(v(:,theta))];
    scatter3(ax,xyz(:,1),xyz(:,2),xyz(:,3),12,v(:,gain),'filled');
    axis(ax,'equal'); view(ax,3); colorbar(ax); title(ax,'Realized gain 3D (màu: dB)');
    xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z');
else
    if strcmp(name,'Elevation'), x=findColumn(headers,'Theta');
    elseif strcmp(name,'AxialRatio'), x=findColumn(headers,'Phi');
    elseif strcmp(name,'Azimuth'), x=findColumn(headers,'Phi');
    else, x=findColumn(headers,'Freq'); end
    % Các cột family cố định (Freq/Phi/Theta) không phải đại lượng kết quả.
    y=find(~cellfun(@(h) ~isempty(regexpi(h,'^(Freq|Phi|Theta)(\s|\[|$)','once')),headers));
    assert(~isempty(y),'Vivaldi:Results','Không tìm thấy cột kết quả.');
    hold(ax,'on'); labels={};
    family=setdiff(1:width(t),[x y]);
    if isempty(family), groups=ones(height(t),1); else, [~,~,groups]=unique(v(:,family),'rows'); end
    for group=unique(groups)'
        rows=groups==group; [xvalues,order]=sort(v(rows,x));
        for col=y
            values=v(rows,col); plot(ax,xvalues,values(order),'LineWidth',1.3);
            suffix='';
            for f=family, suffix=[suffix sprintf(' %s=%.4g',headers{f},v(find(rows,1),f))]; end %#ok<AGROW>
            labels{end+1}=[headers{col} suffix]; %#ok<AGROW>
        end
    end
    hold(ax,'off'); legend(ax,labels,'Interpreter','none','Location','best');
    xlabel(ax,headers{x},'Interpreter','none'); ylabel(ax,name,'Interpreter','none');
    title(ax,strrep(name,'_',' ')); view(ax,2);
end
grid(ax,'on');
end

function k=findColumn(headers,token)
k=find(cellfun(@(h) ~isempty(strfind(h,token)),headers),1);
assert(~isempty(k),'Vivaldi:CSVHeader','CSV thiếu cột %s.',token);
end

function check(fid)
fprintf(fid,['If Err.Number <> 0 Then\nlogFile.WriteLine stepName & " FAILED " & ' ...
    'CStr(Err.Number) & " " & Err.Description\nlogFile.Close\nExit Sub\nEnd If\n']);
end

function out=quote(text)
out=['"' strrep(text,'"','""') '"'];
end

function s=vbBool(value)
if value, s='True'; else, s='False'; end
end

function removeTemp(fid,path)
if any(fopen('all')==fid), fclose(fid); end
if isfile(path), delete(path); end
end
