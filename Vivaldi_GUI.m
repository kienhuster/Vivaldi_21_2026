function fig = Vivaldi_GUI(action, input, configFolder)
% SPDX-License-Identifier: GPL-2.0-or-later
% VIVALDI_GUI Giao diện tiếng Việt, MATLAB R2021a+, không COM từ MATLAB.
% Chạy Vivaldi_GUI. API vật liệu phục vụ kiểm thử: ('materials',[],folder),
% ('addMaterial',material,folder). Không tạo project khi mở giao diện.
if nargin<3, configFolder=fullfile(prefdir,'Vivaldi_DualPol'); end
if nargin>0
    switch action
        case 'materials', fig=loadMaterials(configFolder); return;
        case 'addMaterial', fig=addMaterial(input,configFolder); return;
        otherwise, error('Vivaldi:GUIAction','Lệnh GUI không hợp lệ.');
    end
end
Vivaldi_HFSS_Builder('library');
[g,p]=Vivaldi_Calculation(); materials=loadMaterials(configFolder); selected=materials(1);
lastBuild=[]; lastResults=[]; busy=false;
if ~isfolder(configFolder), mkdir(configFolder); end
sessionLog=[tempname(configFolder) '.log'];
fig=uifigure('Name','Thiết kế Vivaldi hai phân cực — HFSS 2021 R2', ...
    'Position',[70 60 1180 850]);
main=uigridlayout(fig,[2 1]); main.RowHeight={'1x',32};
tabs=uitabgroup(main); tabs.Layout.Row=1;
tab1=uitab(tabs,'Title','Thông số anten'); tab2=uitab(tabs,'Title','Xem trước 3D');
tab3=uitab(tabs,'Title','Tạo anten HFSS'); tab4=uitab(tabs,'Title','Mô phỏng');
tab5=uitab(tabs,'Title','Nhật ký');
status=uilabel(main,'Text','Sẵn sàng tính toán.'); status.Layout.Row=2;
logs=uitextarea(tab5,'Editable','off','Value',{'Nhật ký phiên làm việc'});
logs.Position=[10 10 1100 710];
logGrid=uigridlayout(tab5,[1 1]); logs.Parent=logGrid;
% Tab 1: 19 biến, giá trị dẫn xuất và chọn vật liệu riêng.
layout=uigridlayout(tab1,[3 1]); layout.RowHeight={40,'1x',190};
materialGrid=uigridlayout(layout,[1 4]); materialGrid.ColumnWidth={90,'1x',130,180};
uilabel(materialGrid,'Text','Vật liệu:'); materialLabel=uilabel(materialGrid,'Text',selected.name);
uibutton(materialGrid,'Text','Thư viện','ButtonPushedFcn',@(~,~) materialDialog());
uibutton(materialGrid,'Text','Khôi phục mặc định','ButtonPushedFcn',@(~,~) resetDefaults());
paramGrid=uigridlayout(layout,[10 6]); paramGrid.ColumnWidth={'1x',110,40,'1x',110,40};
names=fieldnames(p); edits=struct();
for k=1:numel(names)
    row=mod(k-1,10)+1; col=3*floor((k-1)/10)+1;
    label=uilabel(paramGrid,'Text',names{k},'Interpreter','none'); label.Layout.Row=row; label.Layout.Column=col;
    e=uieditfield(paramGrid,'numeric','Value',p.(names{k}),'ValueDisplayFormat','%.12g', ...
        'ValueChangedFcn',@(~,~) parametersChanged());
    e.Layout.Row=row; e.Layout.Column=col+1; edits.(names{k})=e;
    unit='mm'; if any(strcmp(names{k},{'deg_slot_t','scan_phi','scan_theta'})), unit='độ'; end
    label=uilabel(paramGrid,'Text',unit); label.Layout.Row=row; label.Layout.Column=col+2;
end
derived=uitable(layout,'ColumnName',{'Biến phụ thuộc','Giá trị','Đơn vị'},'ColumnEditable',[false false false]);
% Tab 2: preview tính từ tham số, không dùng ảnh và không thay thế Validate CAD.
l=uigridlayout(tab2,[2 1]); l.RowHeight={30,'1x'};
uilabel(l,'Text','Xem trước MATLAB — chưa phải CAD HFSS đã kiểm chứng.');
preview=uiaxes(l); axtoolbar(preview,{'rotate','zoomin','zoomout','pan','restoreview'});
% Tab 3: sinh script độc lập hoặc dựng và kiểm tra runtime.
l=uigridlayout(tab3,[9 3]); l.ColumnWidth={160,'1x',180};
l.RowHeight={32,32,55,32,40,40,40,80,'1x'};
uilabel(l,'Text','Ansys executable:');
exe=uieditfield(l,'text','Value',getpref('VivaldiDualPol','Executable',''));
uibutton(l,'Text','Chọn ansysedt.exe','ButtonPushedFcn',@(~,~) selectExe());
uilabel(l,'Text','Thư mục xuất:'); output=uieditfield(l,'text','Value',fullfile(configFolder,'outputs'));
uibutton(l,'Text','Chọn thư mục','ButtonPushedFcn',@(~,~) selectOutput());
uilabel(l,'Text','Tên AEDT:'); projectLabel=uilabel(l,'Text','Vivaldi_DualPol_<thời gian>_<mã duy nhất>.aedt','WordWrap','on');
projectLabel.Layout.Column=[2 3];
debug=uicheckbox(l,'Text','Lưu CAD debug khi lỗi','Value',true); debug.Layout.Column=[1 3];
generateButton=uibutton(l,'Text','Chỉ sinh VBScript (không chạy HFSS)', ...
    'ButtonPushedFcn',@(~,~) buildAntenna(false)); generateButton.Layout.Column=[1 3];
buildButton=uibutton(l,'Text','TẠO ANTEN HFSS','ButtonPushedFcn',@(~,~) buildAntenna(true));
buildButton.Layout.Column=[1 3];
openButton=uibutton(l,'Text','Mở AEDT đã dựng','ButtonPushedFcn',@(~,~) openProject()); openButton.Layout.Column=[1 3];
help=uilabel(l,'Text',['Mỗi lần bấm tạo một project mới. Dựng CAD không chạy solver. ' ...
    'API_COMPLETED chỉ xác nhận lời gọi thực thi; xem validation.log và kiểm tra CAD trong HFSS.'], ...
    'WordWrap','on'); help.Layout.Column=[1 3];
% Tab 4: cấu hình solver và chọn dữ liệu thật để vẽ.
l=uigridlayout(tab4,[4 1]); l.RowHeight={155,36,35,'1x'};
sg=uigridlayout(l,[4 6]); sg.ColumnWidth={'1x',85,'1x',85,'1x',85};
spec={'StartGHz','Bắt đầu (GHz)',5;'StopGHz','Kết thúc (GHz)',20; ...
    'StepGHz','Bước (GHz)',0.25;'AdaptiveGHz','Adaptive (GHz)',5; ...
    'DeltaS','Delta S',0.02;'MinimumPasses','Pass tối thiểu',5; ...
    'MaximumPasses','Pass tối đa',50;'Power1','Port 1 (W)',1; ...
    'Phase1','Pha 1 (độ)',0;'Power2','Port 2 (W)',0; ...
    'Phase2','Pha 2 (độ)',0;'PatternGHz','Pattern (GHz)',5};
simEdits=struct();
for k=1:size(spec,1)
    row=floor((k-1)/3)+1; col=2*mod(k-1,3)+1;
    label=uilabel(sg,'Text',spec{k,2}); label.Layout.Row=row; label.Layout.Column=col;
    e=uieditfield(sg,'numeric','Value',spec{k,3},'ValueDisplayFormat','%.10g');
    e.Layout.Row=row; e.Layout.Column=col+1; simEdits.(spec{k,1})=e;
end
buttons=uigridlayout(l,[1 4]); buttons.ColumnWidth={180,180,180,'1x'};
simButton=uibutton(buttons,'Text','Chạy mô phỏng','ButtonPushedFcn',@(~,~) simulate());
uibutton(buttons,'Text','Chỉ kích Port 1','ButtonPushedFcn',@(~,~) sources(1));
uibutton(buttons,'Text','Chỉ kích Port 2','ButtonPushedFcn',@(~,~) sources(2));
uibutton(buttons,'Text','Hai port: nhập W/pha độc lập','ButtonPushedFcn',@(~,~) sources(3));
chooser=uigridlayout(l,[1 2]); chooser.ColumnWidth={180,'1x'};
uilabel(chooser,'Text','Đồ thị từ CSV thực:');
plotChoice=uidropdown(chooser,'Items',{'S_parameters','VSWR','Impedance', ...
    'Gain_frequency','Elevation','Azimuth','Pattern3D','AxialRatio'}, ...
    'ValueChangedFcn',@(~,~) showResult());
resultAxes=uiaxes(l); title(resultAxes,'Chưa có dữ liệu solver');
appendLog(['Log MATLAB: ' sessionLog]);
appendLog('Đã nạp đúng thư viện HFSS API trong repository. Không tạo project khi mở GUI.');
refresh();

    function current=readParameters()
        current=struct();
        for i=1:numel(names), current.(names{i})=edits.(names{i}).Value; end
    end

    function s=readSimulation()
        s=struct(); keys=fieldnames(simEdits);
        for i=1:numel(keys), s.(keys{i})=simEdits.(keys{i}).Value; end
        s=Vivaldi_HFSS_Simulation('validate',s);
    end

    function parametersChanged()
        if busy, return; end
        lastBuild=[]; lastResults=[];
        projectLabel.Text='Thông số đã đổi — cần tạo project mới.';
        refresh();
    end

    function refresh()
        try
            [g,p]=Vivaldi_Calculation(readParameters());
            keys={'slot_t_L','L_flare','r_flare','x_feed','z_feed','L_patch', ...
                'z_base','de_L','de_W','h_box','h_cabin','h_cabout','h_cabmid'};
            data=cell(numel(keys),3);
            for i=1:numel(keys)
                unit='mm'; if strcmp(keys{i},'r_flare'), unit='mm^-1'; end
                data(i,:)={keys{i},g.(keys{i}),unit};
            end
            derived.Data=data; drawPreview(preview,g,p);
            status.Text='Thông số hợp lệ ở mức giải tích; CAD cần HFSS Validate.';
        catch err, reportError(err); end
    end

    function resetDefaults()
        if busy, return; end
        [~,d]=Vivaldi_Calculation();
        for i=1:numel(names), edits.(names{i}).Value=d.(names{i}); end
        selected=materials(1); materialLabel.Text=selected.name; parametersChanged();
    end

    function selectExe()
        [file,path]=uigetfile('ansysedt.exe','Chọn Ansys Electronics Desktop 2021 R2');
        if isequal(file,0), return; end
        exe.Value=fullfile(path,file); setpref('VivaldiDualPol','Executable',exe.Value);
    end

    function selectOutput()
        folder=uigetdir(output.Value,'Chọn thư mục xuất');
        if ~isequal(folder,0), output.Value=folder; end
    end

    function buildAntenna(execute)
        if busy, return; end
        setBusy(true); cleanup=onCleanup(@() setBusy(false));
        try
            opts=struct('OutputDir',output.Value,'Executable',exe.Value, ...
                'Execute',false,'Debug',debug.Value,'Material',selected,'Simulation',readSimulation());
            lastBuild=[]; lastResults=[]; cla(resultAxes);
            appendLog('Bắt đầu tính hình học và sinh VBScript mới.');
            candidate=Vivaldi_HFSS_Builder(readParameters(),opts);
            projectLabel.Text=candidate.project;
            appendLog(['Đã sinh: ' candidate.script]);
            if ~execute
                appendLog('SCRIPT_GENERATED — chưa chạy HFSS, chưa xác minh CAD.'); return;
            end
            appendLog(['Khởi chạy HFSS; nhật ký thực: ' candidate.log]); drawnow;
            try
                candidate=Vivaldi_HFSS_Builder('run',candidate);
            catch err
                if isfile(candidate.log), appendLog(readLog(candidate.log)); end
                rethrow(err);
            end
            lastBuild=candidate; appendLog(readLog(candidate.log));
            appendLog(['Đã Validate và lưu AEDT: ' candidate.project]);
            status.Text='BUILD_COMPLETE — cần kiểm tra trực quan topology và hướng integration line trong HFSS.';
        catch err, reportError(err); end
    end

    function openProject()
        try
            assert(~isempty(lastBuild) && isfile(lastBuild.project), ...
                'Vivaldi:Project','Chưa có project dựng thành công.');
            assert(ispc,'Vivaldi:Platform','Mở AEDT yêu cầu Windows/HFSS.');
            winopen(lastBuild.project);
        catch err, reportError(err); end
    end

    function sources(mode)
        if mode==1, simEdits.Power1.Value=1; simEdits.Power2.Value=0;
        elseif mode==2, simEdits.Power1.Value=0; simEdits.Power2.Value=1;
        else, simEdits.Power1.Value=1; simEdits.Power2.Value=1; end
        appendLog('Đã đổi công suất nguồn. Pha độc lập; không suy diễn phân cực tròn từ pha nguồn.');
    end

    function simulate()
        if busy, return; end
        setBusy(true); cleanup=onCleanup(@() setBusy(false));
        try
            assert(~isempty(lastBuild),'Vivaldi:Simulation','Hãy dựng và Validate anten trước.');
            lastResults=[]; cla(resultAxes);
            appendLog(['Bắt đầu solver trên bản sao riêng của: ' lastBuild.project]); drawnow;
            run=Vivaldi_HFSS_Simulation('generate',lastBuild,readSimulation());
            appendLog(['Log solver: ' run.log]);
            try, run=Vivaldi_HFSS_Builder('run',run);
            catch err
                if isfile(run.log), appendLog(readLog(run.log)); end
                rethrow(err);
            end
            lastResults=Vivaldi_HFSS_Simulation('read',run.folder);
            appendLog(readLog(run.log)); showResult();
            status.Text=['Đã đọc CSV thực từ ' run.folder];
        catch err, reportError(err); end
    end

    function showResult()
        try
            assert(~isempty(lastResults),'Vivaldi:Results','Chưa có CSV từ lượt solver hoàn tất.');
            resultAxes.UserData=plotChoice.Value;
            Vivaldi_HFSS_Simulation('plot',lastResults,resultAxes);
        catch err, cla(resultAxes); title(resultAxes,'Chưa có dữ liệu phù hợp'); reportError(err); end
    end

    function materialDialog()
        if busy, return; end
        dlg=uifigure('Name','Select Definition - Vật liệu','Position',[180 180 870 480], ...
            'WindowStyle','modal');
        ml=uigridlayout(dlg,[3 1]); ml.RowHeight={35,'1x',40};
        searchGrid=uigridlayout(ml,[1 3]); searchGrid.ColumnWidth={170,'1x',110};
        uilabel(searchGrid,'Text','Tìm kiếm theo Tên:');
        search=uieditfield(searchGrid,'text','ValueChangedFcn',@(~,~) filter());
        uibutton(searchGrid,'Text','Tìm kiếm','ButtonPushedFcn',@(~,~) filter());
        table=uitable(ml,'ColumnName',{'Tên','Loại','εr','μr','σ (S/m)','tanδ'}, ...
            'ColumnEditable',false(1,6),'CellSelectionCallback',@selectRow);
        b=uigridlayout(ml,[1 4]); b.ColumnWidth={150,'1x',100,100};
        uibutton(b,'Text','Add Material...','ButtonPushedFcn',@(~,~) addDialog());
        uilabel(b,'Text','Thân anten chỉ nhận kim loại/PEC.');
        uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~) apply());
        uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~) delete(dlg));
        visible=1:numel(materials); chosen=[]; filter();

        function filter()
            chosen=[]; visible=find(contains(lower({materials.name}),lower(search.Value)));
            rows=cell(numel(visible),6);
            for j=1:numel(visible)
                m=materials(visible(j));
                rows(j,:)={m.name,m.type,m.permittivity,m.permeability,m.conductivity,m.lossTangent};
            end
            table.Data=rows;
        end
        function selectRow(~,event)
            if isempty(event.Indices), chosen=[]; else, chosen=visible(event.Indices(1,1)); end
        end
        function apply()
            if isempty(chosen), uialert(dlg,'Vui lòng chọn một dòng vật liệu.','Chọn vật liệu'); return; end
            if strcmp(materials(chosen).type,'dielectric')
                uialert(dlg,'Điện môi không tương thích với thân kim loại; không tự thêm substrate.','Vật liệu không phù hợp'); return;
            end
            selected=materials(chosen); materialLabel.Text=selected.name;
            delete(dlg); parametersChanged(); appendLog(['Đã chọn vật liệu: ' selected.name]);
        end
        function addDialog()
            d=uifigure('Name','Thêm vật liệu','Position',[250 220 470 400],'WindowStyle','modal');
            grid=uigridlayout(d,[8 2]); grid.ColumnWidth={210,'1x'};
            uilabel(grid,'Text','Tên:'); n=uieditfield(grid,'text');
            uilabel(grid,'Text','Loại:'); type=uidropdown(grid,'Items',{'metal','dielectric','pec'});
            uilabel(grid,'Text','Epsilon tương đối:'); er=uieditfield(grid,'numeric','Value',1);
            uilabel(grid,'Text','Permeability tương đối:'); mur=uieditfield(grid,'numeric','Value',1);
            uilabel(grid,'Text','Conductivity (S/m):'); sigma=uieditfield(grid,'numeric','Value',3.8e7);
            uilabel(grid,'Text','Loss tangent:'); loss=uieditfield(grid,'numeric','Value',0);
            note=uilabel(grid,'Text','PEC bỏ qua conductivity. Điện môi dùng σ = 0.','WordWrap','on'); note.Layout.Column=[1 2];
            uibutton(grid,'Text','Lưu','ButtonPushedFcn',@(~,~) saveNew());
            uibutton(grid,'Text','Hủy','ButtonPushedFcn',@(~,~) delete(d));
            function saveNew()
                try
                    m=struct('name',strtrim(n.Value),'type',type.Value,'permittivity',er.Value, ...
                        'permeability',mur.Value,'conductivity',sigma.Value,'lossTangent',loss.Value);
                    if strcmp(m.type,'pec'), m.conductivity=0; end
                    materials=addMaterial(m,configFolder); delete(d); filter();
                    appendLog(['Đã lưu vật liệu mới: ' m.name]);
                catch err, uialert(d,err.message,'Không lưu được vật liệu'); end
            end
        end
    end

    function setBusy(value)
        busy=value; state='on'; if value, state='off'; end
        buildButton.Enable=state; generateButton.Enable=state; simButton.Enable=state;
        for key=fieldnames(edits)'
            edits.(key{1}).Enable=state;
        end
        for key=fieldnames(simEdits)'
            simEdits.(key{1}).Enable=state;
        end
        exe.Enable=state; output.Enable=state; debug.Enable=state;
        drawnow;
    end

    function appendLog(message)
        lines=cellstr(splitlines(string(message))); old=cellstr(logs.Value);
        lines=[{['[' datestr(now,'HH:MM:SS') ']']} ; lines];
        all=[old(:);lines(:)]; logs.Value=all(max(1,numel(all)-1500):end);
        f=fopen(sessionLog,'at','n','UTF-8');
        if f>=0, for j=1:numel(lines), fprintf(f,'%s\n',lines{j}); end; fclose(f); end
        drawnow limitrate;
    end

    function reportError(err)
        status.Text=['Lỗi: ' err.message]; appendLog(getReport(err,'extended','hyperlinks','off'));
    end
end

function materials=loadMaterials(folder)
% Database nhỏ, chỉ dữ liệu; không chạy mã nạp từ file tùy chỉnh.
materials=[material('Aluminum','metal',1,1.000021,3.8e7,0), ...
    material('Copper','metal',1,0.999991,5.8e7,0),material('PEC','pec',1,1,0,0)];
names={'FR4_epoxy','Rogers RO4350 (tm)','Rogers RT/duroid 5880 (tm)', ...
    'Arlon AD250','Taconic TLC-30','Teflon (PTFE)','Glass','Vacuum'};
er=[4.4 3.48 2.2 2.5 3 2.1 5.5 1]; loss=[0.02 0.0037 0.0009 0.0018 0.003 0.0002 0 0];
for k=1:numel(names), materials(end+1)=material(names{k},'dielectric',er(k),1,0,loss(k)); end
file=fullfile(folder,'custom_materials.mat');
if isfile(file)
    saved=load(file,'customMaterials');
    assert(isfield(saved,'customMaterials')&&isstruct(saved.customMaterials), ...
        'Vivaldi:MaterialFile','File vật liệu không hợp lệ: %s',file);
    for k=1:numel(saved.customMaterials)
        m=saved.customMaterials(k); validateMaterial(m);
        assert(~any(strcmpi(m.name,{materials.name})),'Vivaldi:MaterialDuplicate','Tên vật liệu bị trùng: %s',m.name);
        materials(end+1)=m;
    end
end
end

function materials=addMaterial(m,folder)
validateMaterial(m); materials=loadMaterials(folder);
assert(~any(strcmpi(strtrim(m.name),{materials.name})), ...
    'Vivaldi:MaterialDuplicate','Tên vật liệu đã có: %s',m.name);
m.name=strtrim(m.name); materials(end+1)=m; customMaterials=materials(12:end);
if ~isfolder(folder), mkdir(folder); end
file=fullfile(folder,'custom_materials.mat'); tmp=[tempname(folder) '.mat'];
cleanup=onCleanup(@() deleteIfExists(tmp));
save(tmp,'customMaterials','-v7');
[ok,msg]=movefile(tmp,file,'f'); assert(logical(ok),'Vivaldi:MaterialSave','%s',msg);
end

function m=material(name,type,er,mur,sigma,loss)
m=struct('name',name,'type',type,'permittivity',er,'permeability',mur, ...
    'conductivity',sigma,'lossTangent',loss);
end

function validateMaterial(m)
assert(isstruct(m)&&isscalar(m)&&all(isfield(m, ...
    {'name','type','permittivity','permeability','conductivity','lossTangent'})), ...
    'Vivaldi:Material','Vật liệu thiếu trường dữ liệu.');
assert(ischar(m.name)&&isrow(m.name)&&~isempty(strtrim(m.name)), ...
    'Vivaldi:Material','Tên vật liệu không được rỗng.');
assert(any(strcmp(m.type,{'metal','dielectric','pec'})),'Vivaldi:Material','Loại vật liệu không hợp lệ.');
for key={'permittivity','permeability','conductivity','lossTangent'}
    validateattributes(m.(key{1}),{'numeric'},{'real','finite','scalar'});
end
assert(m.permittivity>0&&m.permeability>0&&m.conductivity>=0&&m.lossTangent>=0, ...
    'Vivaldi:Material','εr/μr phải dương, conductivity/tanδ không âm.');
if strcmp(m.type,'metal'), assert(m.conductivity>0,'Vivaldi:Material','Kim loại cần conductivity > 0.'); end
if strcmp(m.type,'dielectric'), assert(m.conductivity==0,'Vivaldi:Material','Điện môi trong thư viện này dùng conductivity = 0.'); end
end

function deleteIfExists(file)
if isfile(file), delete(file); end
end

function text=readLog(file)
f=fopen(file,'rb'); raw=fread(f,Inf,'*uint8')'; fclose(f);
if numel(raw)>2 && isequal(raw(1:2),uint8([255 254])), text=native2unicode(raw(3:end),'UTF-16LE');
else, text=native2unicode(raw,'UTF-8'); end
end

function drawPreview(ax,g,p)
% Polyshape chỉ dùng preview MATLAB, CAD thật không dùng đa giác thay flare.
cla(ax); hold(ax,'on');
metal=polyshape([-p.aperture_w/2 p.aperture_w/2 p.aperture_w/2 -p.aperture_w/2], ...
    [g.z_base g.z_base g.L_flare g.L_flare]);
cut=union(polyshape(g.flare),polyshape(g.transition));
for k=1:3, cut=union(cut,polyshape(g.rectangles{k})); end
metal=subtract(metal,cut);
drawExtrusion(ax,metal,[-p.thickness/2 p.thickness/2],'arm',[0.72 0.75 0.8],g,false);
drawExtrusion(ax,metal,[-p.thickness/2 p.thickness/2],'arm',[0.6 0.7 0.82],g,true);
origin=g.cs.RelativeCS1;
drawBox(ax,[origin(1) origin(2) g.z_base],[p.thickness p.thickness g.L_patch],[0.6 0.65 0.7]);
base=polyshape([g.bounds(1,1) g.bounds(2,1) g.bounds(2,1) g.bounds(1,1)], ...
    [g.bounds(1,2) g.bounds(1,2) g.bounds(2,2) g.bounds(2,2)]);
t=linspace(0,2*pi,97)';
for center=[g.coax1;g.coax2]'
    base=subtract(base,polyshape(center(1)+p.r_cabout*cos(t),center(2)+p.r_cabout*sin(t)));
end
drawExtrusion(ax,base,[g.z_base g.z_base+p.h_de],'base',[0.65 0.68 0.72],g,false);
for second=[false true]
    c=g.coax1;
    for spec=[p.r_cabin g.h_cabin]'
        r=spec(1); h=spec(2); ztop=g.z_base+h;
        xyz=[c(1)+r*cos(t),c(2)+r*sin(t),g.z_base+zeros(size(t))];
        top=xyz; top(:,3)=ztop;
        if second, xyz=rigid(xyz,g); top=rigid(top,g); end
        surf(ax,[xyz(:,1) top(:,1)],[xyz(:,2) top(:,2)], ...
            [xyz(:,3) top(:,3)],'FaceColor',[0.8 0.43 0.18],'EdgeColor','none');
    end
    annulus=polyshape(c(1)+p.r_cabout*cos(t),c(2)+p.r_cabout*sin(t));
    annulus=subtract(annulus,polyshape(c(1)+p.r_cabmid*cos(t),c(2)+p.r_cabmid*sin(t)));
    drawExtrusion(ax,annulus,[g.z_base g.z_base+g.h_cabout],'base',[0.8 0.43 0.18],g,second);
    xyz=[c(1)+p.r_cabmid*cos(t),c(2)+p.r_cabmid*sin(t),c(3)+zeros(size(t))];
    line=g.port1Line;
    if second, xyz=rigid(xyz,g); line=g.port2Line; end
    patch(ax,xyz(:,1),xyz(:,2),xyz(:,3),[0 0.7 0.7],'FaceAlpha',0.5,'EdgeColor','none');
    plot3(ax,line(:,1),line(:,2),line(:,3),'r-','LineWidth',2);
end
hold(ax,'off'); axis(ax,'equal'); grid(ax,'on'); view(ax,35,25);
xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)'); zlabel(ax,'Z (mm)');
title(ax,sprintf('Dual-pol: %.4g × %.4g × %.6g mm',g.de_L,g.de_W,g.L_patch));
end

function drawExtrusion(ax,shape,levels,mode,color,g,second)
tri=triangulation(shape); vertices=tri.Points; faces=tri.ConnectivityList;
for level=levels
    xyz=lift(vertices,level,mode); if second, xyz=rigid(xyz,g); end
    patch(ax,'Faces',faces,'Vertices',xyz,'FaceColor',color,'EdgeColor','none');
end
[x,y]=boundary(shape);
for k=1:numel(x)-1
    if any(isnan([x(k:k+1);y(k:k+1)])), continue; end
    a=lift([x(k) y(k);x(k+1) y(k+1)],levels(1),mode);
    b=lift([x(k+1) y(k+1);x(k) y(k)],levels(2),mode); xyz=[a;b];
    if second, xyz=rigid(xyz,g); end
    patch(ax,'Faces',[1 2 3 4],'Vertices',xyz,'FaceColor',color,'EdgeColor','none');
end
end

function xyz=lift(v,level,mode)
if strcmp(mode,'arm'), xyz=[v(:,1) level+zeros(size(v,1),1) v(:,2)];
else, xyz=[v level+zeros(size(v,1),1)]; end
end

function q=rigid(q,g)
q=(q-g.cs.RelativeCS1)*g.rotationZ'+g.cs.RelativeCS1+g.translation;
end

function drawBox(ax,origin,size,color)
v=[0 0 0;1 0 0;1 1 0;0 1 0;0 0 1;1 0 1;1 1 1;0 1 1].*size+origin;
f=[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
patch(ax,'Faces',f,'Vertices',v,'FaceColor',color,'EdgeColor',[0.4 0.4 0.4]);
end
