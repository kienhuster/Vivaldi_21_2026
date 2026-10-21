function varargout=Vivaldi_GUI(action,varargin)
% Giao diện tiếng Việt: một phần tử dual-pol, MATLAB R2021a trở lên.
% Các action vật liệu dùng chung cho GUI và kiểm thử không đồ họa.
if nargin>0
    switch lower(action)
        case 'materials', varargout{1}=materials();
        case 'validatematerial', validateMaterial(varargin{1});
        case 'filtermaterials'
            db=varargin{1};varargout{1}=db(contains(lower(string({db.name})),lower(string(varargin{2}))));
        case 'savematerials'
            custom=varargin{1};path=varargin{2};
            for k=1:numel(custom),validateMaterial(custom(k));end
            assert(numel(unique(lower(string({custom.name}))))==numel(custom),'Vivaldi:Material','Trùng tên vật liệu.');
            save(path,'custom');
        case 'loadmaterials'
            varargout{1}=loadCustom(varargin{1});
        otherwise, error('Vivaldi:GUI','Action không hợp lệ.');
    end
    return
end
Vivaldi_HFSS_Builder('library');g=Vivaldi_Calculation();
db=materials();customFile=fullfile(prefdir,'Vivaldi_DualPol_custom_materials.mat');
startupWarning='';
try
    custom=loadCustom(customFile);db=mergeMaterials(db,custom);
catch ex
    custom=db([]);startupWarning=ex.message;
end
current=db(1);job=[];sim=[];results=struct;busy=false;logLines={};
root=fileparts(mfilename('fullpath'));
fig=uifigure('Name','Vivaldi Dual-Pol — HFSS 2021 R2','Position',[60 50 1220 850]);
tabs=uitabgroup(fig,'Position',[10 10 1200 830]);
t1=uitab(tabs,'Title','Thông số anten');t2=uitab(tabs,'Title','Xem trước 3D');
t3=uitab(tabs,'Title','Tạo anten HFSS');t4=uitab(tabs,'Title','Mô phỏng');t5=uitab(tabs,'Title','Nhật ký');
logBox=uitextarea(t5,'Position',[10 10 1170 770],'Editable','off');
fields=struct;names=fieldnames(g.parameters);
for k=1:numel(names)
    col=floor((k-1)/10);row=mod(k-1,10);x=20+col*390;y=735-row*53;
    unit='mm';if any(strcmp(names{k},{'deg_slot_t','scan_phi','scan_theta'})),unit='độ';end
    uilabel(t1,'Text',sprintf('%s (%s)',names{k},unit),'Position',[x y 205 24],'Interpreter','none');
    fields.(names{k})=uieditfield(t1,'numeric','Value',g.(names{k}), ...
        'ValueDisplayFormat','%.12g','Position',[x+205 y 155 26]);
end
matName=uieditfield(t1,'text','Value',current.name,'Editable','off','Position',[20 170 230 28]);
uibutton(t1,'Text','Thư viện','Position',[265 170 110 28],'ButtonPushedFcn',@(~,~)openLibrary());
uibutton(t1,'Text','Khôi phục mặc định','Position',[20 110 180 35],'ButtonPushedFcn',@(~,~)reset());
uibutton(t1,'Text','Tính toán / Xem trước','Position',[215 110 210 35],'ButtonPushedFcn',@(~,~)calculate());
uilabel(t1,'Text','lamda, scan_phi, scan_theta, c2 được giữ theo nguồn; không tạo mảng.','Position',[20 50 760 40],'WordWrap','on');
derived=uitable(t1,'Position',[815 170 355 590],'ColumnName',{'Biến phụ thuộc','Giá trị'},'ColumnWidth',{160 165},'RowName',[]);
ax=uiaxes(t2,'Position',[15 65 1150 705]);
axtoolbar(ax,{'rotate','zoomin','zoomout','pan','restoreview'});
uilabel(t2,'Text','Xem trước MATLAB — chưa phải CAD HFSS đã kiểm chứng.','Position',[20 15 1100 35],'FontColor',[.75 .2 .05]);
uilabel(t3,'Text','ANSYS Electronics Desktop 2021 R2 (Windows):','Position',[25 715 600 30]);
exe=uieditfield(t3,'text','Position',[25 675 950 30],'Value','');
uibutton(t3,'Text','Chọn ansysedt.exe','Position',[990 675 175 30],'ButtonPushedFcn',@(~,~)chooseExe());
uilabel(t3,'Text','Thư mục xuất (mỗi lần dựng tạo thư mục mới):','Position',[25 610 700 28]);
out=uieditfield(t3,'text','Position',[25 570 950 30],'Value',fullfile(root,'outputs'));
uibutton(t3,'Text','Chọn thư mục','Position',[990 570 175 30],'ButtonPushedFcn',@(~,~)chooseOut());
nextName=uilabel(t3,'Text','AEDT mới: Vivaldi_DualPol_<ID duy nhất>.aedt','Position',[25 505 1120 35],'Interpreter','none');
debug=uicheckbox(t3,'Text','Lưu AEDT debug riêng nếu lỗi','Value',true,'Position',[25 445 500 30]);
generateOnly=uicheckbox(t3,'Text','Chỉ sinh VBScript (chưa dựng CAD trong HFSS)','Value',false,'Position',[25 395 700 30]);
buildButton=uibutton(t3,'Text','Tạo anten HFSS','Position',[25 310 245 50],'ButtonPushedFcn',@(~,~)build());
uibutton(t3,'Text','Mở AEDT','Position',[295 310 180 50],'ButtonPushedFcn',@(~,~)openAEDT());
uilabel(t3,'Text','Dựng CAD không chạy solver. HFSS được gọi bằng /RunScriptAndExit; dùng Mở AEDT để xem project đã lưu.','Position',[25 200 1100 65],'WordWrap','on');
uilabel(t4,'Text','Solver áp dụng cho AEDT vừa dựng; thay hình học/vật liệu thì phải dựng lại.','Position',[20 745 1120 28]);
cfgDefaults=Vivaldi_HFSS_Simulation('defaults');cfgFields=struct;
configNames={'start','stop','step','adaptive','deltaS','minPass','maxPass'};
labels={'Bắt đầu (GHz)','Kết thúc (GHz)','Bước (GHz)','Adaptive (GHz)','Delta S','Min passes','Max passes'};
for k=1:numel(configNames)
    x=20+mod(k-1,4)*290;y=690-floor((k-1)/4)*65;
    uilabel(t4,'Text',labels{k},'Position',[x y 145 25]);
    cfgFields.(configNames{k})=uieditfield(t4,'numeric','Position',[x+145 y 125 27], ...
        'Value',cfgDefaults.(configNames{k}),'ValueDisplayFormat','%.10g');
end
mode=uidropdown(t4,'Items',{'Chỉ Port 1','Chỉ Port 2','Hai port'},'Position',[20 550 220 30]);
power1=uieditfield(t4,'numeric','Value',1,'Position',[400 550 120 28]);
phase1=uieditfield(t4,'numeric','Value',0,'Position',[650 550 120 28]);
power2=uieditfield(t4,'numeric','Value',1,'Position',[400 505 120 28]);
phase2=uieditfield(t4,'numeric','Value',0,'Position',[650 505 120 28]);
uilabel(t4,'Text','Port 1: W','Position',[290 550 100 26]);uilabel(t4,'Text','Pha (độ)','Position',[550 550 95 26]);
uilabel(t4,'Text','Port 2: W','Position',[290 505 100 26]);uilabel(t4,'Text','Pha (độ)','Position',[550 505 95 26]);
solveButton=uibutton(t4,'Text','Chạy mô phỏng','Position',[20 445 200 38],'ButtonPushedFcn',@(~,~)solve());
uibutton(t4,'Text','Đọc thư mục CSV','Position',[235 445 170 38],'ButtonPushedFcn',@(~,~)importCSV());
resultName=uidropdown(t4,'Items',{'SParameters','VSWR','Impedance','GainFrequency','Elevation','Azimuth','Pattern3D','AxialRatio'}, ...
    'Position',[425 445 250 38],'ValueChangedFcn',@(~,~)plotResult());
resultAx=uiaxes(t4,'Position',[20 20 1140 400]);grid(resultAx,'on');
calculate();logMessage('GUI sẵn sàng; chưa khởi chạy HFSS hay tạo project.');
if ~isempty(startupWarning),logMessage(['Không nạp được vật liệu tùy chỉnh: ' startupWarning]);end
if nargout,varargout{1}=fig;end

    function p=parameters()
        p=struct;for i=1:numel(names),p.(names{i})=fields.(names{i}).Value;end
    end
    function c=config()
        c=cfgDefaults;for i=1:numel(configNames),c.(configNames{i})=cfgFields.(configNames{i}).Value;end
        c.power=[power1.Value power2.Value];c.phase=[phase1.Value phase2.Value];
        if strcmp(mode.Value,'Chỉ Port 1'),c.power(2)=0;elseif strcmp(mode.Value,'Chỉ Port 2'),c.power(1)=0;end
        Vivaldi_HFSS_Simulation('validate',c);
    end
    function calculate()
        try
            geom=Vivaldi_Calculation(parameters());
            dn={'slot_t_L','L_flare','r_flare','x_feed','z_feed','L_patch','z_base','de_L','de_W','h_box','h_cabin','h_cabout','h_cabmid'};
            data=cell(numel(dn),2);for i=1:numel(dn),data(i,:)={dn{i},sprintf('%.12g',geom.(dn{i}))};end
            derived.Data=data;preview(ax,geom);logMessage('Đã tính công thức và cập nhật preview; CAD HFSS chưa được xác minh.');
        catch ex,showError(ex);end
    end
    function reset()
        d=Vivaldi_Calculation();for i=1:numel(names),fields.(names{i}).Value=d.(names{i});end
        current=db(1);matName.Value=current.name;calculate();
    end
    function chooseExe()
        [f,p]=uigetfile('*.exe','Chọn ansysedt.exe');if ~isequal(f,0),exe.Value=fullfile(p,f);end
    end
    function chooseOut()
        p=uigetdir(out.Value,'Chọn thư mục xuất');if ~isequal(p,0),out.Value=p;end
    end
    function build()
        if busy,return;end
        busy=true;buildButton.Enable='off';solveButton.Enable='off';unlocker=onCleanup(@unlock);
        try
            p=parameters();c=config();
            logMessage('Đang sinh VBScript từ tham số và vật liệu hiện tại...');
            job=Vivaldi_HFSS_Builder('generate',p,current,out.Value,c,debug.Value);
            nextName.Text=['AEDT: ' job.project];logMessage(['Script: ' job.script]);
            if generateOnly.Value
                logMessage('GENERATED — chưa thực thi trong HFSS; chưa có AEDT hoàn chỉnh.');return
            end
            logMessage('Đang chạy HFSS; chờ hoàn tất. Nhật ký chi tiết được ghi vào build.log.');drawnow;
            job=Vivaldi_HFSS_Builder('execute',job,exe.Value);appendLog(job.log);
            logMessage(['HFSS đã lưu AEDT sau ValidateDesign: ' job.project]);
            logMessage('Cần kiểm tra topology, vùng khoét và hướng integration lines trực tiếp trước nghiệm thu CAD.');
        catch ex
            if ~isempty(job) && isfile(job.log),appendLog(job.log);end
            showError(ex);
        end
    end
    function solve()
        if busy,return;end
        busy=true;buildButton.Enable='off';solveButton.Enable='off';unlocker=onCleanup(@unlock);
        try
            assert(~isempty(job) && isfile(job.done),'Vivaldi:BuildRequired','Hãy dựng anten HFSS thành công trước.');
            assert(isequaln(job.geometry.parameters,parameters()) && isequaln(job.material,current), ...
                'Vivaldi:StaleGeometry','Hình học hoặc vật liệu đã đổi. Hãy dựng lại trước khi mô phỏng.');
            sim=Vivaldi_HFSS_Simulation('generate',job,config());
            logMessage(['Đang chạy solver; nhật ký: ' sim.log]);drawnow;
            sim=Vivaldi_HFSS_Builder('execute',sim,exe.Value);appendLog(sim.log);
            results=Vivaldi_HFSS_Simulation('read',sim.folder);plotResult();
            logMessage(['Đã đọc CSV từ nghiệm thực: ' sim.folder]);
        catch ex
            if ~isempty(sim) && isfile(sim.log),appendLog(sim.log);end
            showError(ex);
        end
    end
    function unlock()
        busy=false;if isvalid(fig),buildButton.Enable='on';solveButton.Enable='on';end
    end
    function openAEDT()
        try
            assert(~isempty(job) && isfile(job.done),'Vivaldi:BuildRequired','Chưa có AEDT hoàn chỉnh.');
            Vivaldi_HFSS_Builder('open',exe.Value,job.project);
        catch ex,showError(ex);end
    end
    function importCSV()
        p=uigetdir(out.Value,'Chọn thư mục CSV HFSS');if isequal(p,0),return;end
        try,results=Vivaldi_HFSS_Simulation('read',p);plotResult();logMessage(['CSV được đọc từ: ' p]);catch ex,showError(ex);end
    end
    function plotResult()
        try,Vivaldi_HFSS_Simulation('plot',resultAx,results,resultName.Value);catch ex,showError(ex);end
    end
    function appendLog(path)
        lines=splitlines(string(fileread(path)));for i=1:numel(lines),if strlength(lines(i))>0,logMessage(char(lines(i)));end,end
    end
    function logMessage(message)
        logLines{end+1}=sprintf('%s %s',datestr(now,'HH:MM:SS'),message);logBox.Value=logLines;drawnow limitrate
    end
    function showError(ex)
        logMessage(getReport(ex,'extended','hyperlinks','off'));uialert(fig,ex.message,'Lỗi — xem tab Nhật ký');
    end
    function openLibrary()
        dlg=uifigure('Name','Select Definition - Vật liệu','Position',[200 180 1020 480],'WindowStyle','modal');
        search=uieditfield(dlg,'text','Position',[20 425 360 28],'ValueChangedFcn',@(~,~)filter());
        uilabel(dlg,'Text','Tìm kiếm theo tên','Position',[20 450 300 22]);
        uibutton(dlg,'Text','Tìm kiếm','Position',[400 425 120 28],'ButtonPushedFcn',@(~,~)filter());
        visible=db;selected=[];
        table=uitable(dlg,'Position',[20 80 980 325],'ColumnName',{'Tên','Loại','εr','μr','σ (S/m)','tanδ'}, ...
            'ColumnWidth',{260 100 130 130 160 120},'RowName',[],'CellSelectionCallback',@selectRow);
        uibutton(dlg,'Text','Add Material...','Position',[20 20 170 35],'ButtonPushedFcn',@(~,~)addMaterial());
        uibutton(dlg,'Text','OK','Position',[750 20 110 35],'ButtonPushedFcn',@(~,~)accept());
        uibutton(dlg,'Text','Cancel','Position',[880 20 110 35],'ButtonPushedFcn',@(~,~)delete(dlg));filter();
        function selectRow(~,event)
            if isempty(event.Indices),selected=[];else,selected=event.Indices(1,1);end
        end
        function filter()
            visible=Vivaldi_GUI('filtermaterials',db,search.Value);selected=[];
            table.Data=[{visible.name}' {visible.type}' num2cell([visible.permittivity]') ...
                num2cell([visible.permeability]') num2cell([visible.conductivity]') num2cell([visible.lossTangent]')];
        end
        function accept()
            if isempty(selected),uialert(dlg,'Hãy chọn một dòng vật liệu.','Chọn vật liệu');return;end
            candidate=visible(selected);
            if strcmp(candidate.type,'dielectric'),uialert(dlg,'Thân anten cần kim loại/PEC; không thêm substrate.','Vật liệu không tương thích');return;end
            current=candidate;matName.Value=current.name;logMessage(['Đã chọn vật liệu: ' current.name]);delete(dlg);
        end
        function addMaterial()
            form=uifigure('Name','Add Material','Position',[350 250 560 430],'WindowStyle','modal');
            uilabel(form,'Text','Tên','Position',[20 370 180 24]);nm=uieditfield(form,'text','Position',[210 370 320 26]);
            uilabel(form,'Text','Loại','Position',[20 320 180 24]);ty=uidropdown(form,'Items',{'metal','dielectric','pec'},'Position',[210 320 320 26],'ValueChangedFcn',@(~,~)typeChanged());
            labels2={'Permittivity εr','Permeability μr','Conductivity S/m','Loss tangent'};
            props={'permittivity','permeability','conductivity','lossTangent'};ed=struct;
            vals=[1 1 3.8e7 0];for ii=1:4
                y=270-(ii-1)*45;uilabel(form,'Text',labels2{ii},'Position',[20 y 180 26]);
                ed.(props{ii})=uieditfield(form,'numeric','Position',[210 y 320 26],'Value',vals(ii),'ValueDisplayFormat','%.12g');
            end
            uibutton(form,'Text','Lưu vật liệu','Position',[210 35 160 35],'ButtonPushedFcn',@(~,~)store());typeChanged();
            function typeChanged()
                ed.conductivity.Enable=onOff(strcmp(ty.Value,'metal'));
                ed.lossTangent.Enable=onOff(strcmp(ty.Value,'dielectric'));
                ed.permittivity.Enable=onOff(strcmp(ty.Value,'dielectric'));
            end
            function store()
                try
                    m=struct('name',strtrim(nm.Value),'type',ty.Value);
                    for jj=1:4,m.(props{jj})=ed.(props{jj}).Value;end
                    if strcmp(m.type,'metal'),m.permittivity=1;m.lossTangent=0;
                    elseif strcmp(m.type,'dielectric'),m.conductivity=0;
                    else,m.permittivity=1;m.conductivity=0;m.lossTangent=0;end
                    validateMaterial(m);
                    assert(~any(strcmpi(m.name,{db.name})),'Vivaldi:Material','Tên vật liệu đã tồn tại.');
                    nextCustom=[custom m];Vivaldi_GUI('savematerials',nextCustom,customFile);
                    custom=nextCustom;db(end+1)=m;search.Value='';filter();delete(form);
                    logMessage(['Đã lưu vật liệu tùy chỉnh: ' m.name]);
                catch ex,uialert(form,ex.message,'Lỗi vật liệu');end
            end
        end
    end
end
function value=onOff(flag)
if flag,value='on';else,value='off';end
end
function db=materials()
names={'Aluminum','Copper','PEC','FR4_epoxy','Rogers RO4350 (tm)', ...
    'Rogers RT/duroid 5880 (tm)','Arlon AD250','Taconic TLC-30','Teflon (PTFE)','Glass','Vacuum'};
er=[1 1 1 4.4 3.48 2.2 2.5 3 2.1 5.5 1];loss=[0 0 0 .02 .0037 .0009 .0018 .003 .0002 0 0];
mu=[1.000021 .999991 ones(1,9)];sigma=[3.8e7 5.8e7 zeros(1,9)];
for k=1:numel(names)
    type='dielectric';if k<3,type='metal';elseif k==3,type='pec';end
    db(k)=struct('name',names{k},'type',type,'permittivity',er(k), ...
        'permeability',mu(k),'conductivity',sigma(k),'lossTangent',loss(k)); %#ok<AGROW>
end
end
function validateMaterial(m)
assert(isstruct(m) && isscalar(m) && all(isfield(m,{'name','type','permittivity','permeability','conductivity','lossTangent'})), ...
    'Vivaldi:Material','Thiếu thuộc tính vật liệu.');
assert(ischar(m.name) && ~isempty(strtrim(m.name)) && ~any(double(m.name)<32), ...
    'Vivaldi:Material','Tên vật liệu rỗng hoặc chứa ký tự điều khiển.');
assert(any(strcmp(m.type,{'metal','dielectric','pec'})),'Vivaldi:Material','Loại vật liệu không hợp lệ.');
for n={'permittivity','permeability','conductivity','lossTangent'}
    validateattributes(m.(n{1}),{'numeric'},{'real','finite','scalar','nonnegative'});
end
assert(m.permittivity>0 && m.permeability>0 && (~strcmp(m.type,'metal') || m.conductivity>0), ...
    'Vivaldi:Material','εr, μr và độ dẫn kim loại phải dương.');
end
function custom=loadCustom(path)
db=materials();custom=db([]);
if ~isfile(path),return;end
s=load(path,'custom');assert(isfield(s,'custom') && isstruct(s.custom),'Vivaldi:Material','Tệp vật liệu không hợp lệ.');
custom=s.custom;
for k=1:numel(custom),validateMaterial(custom(k));end
mergeMaterials(db,custom); % Kiểm tra trùng tên trước khi sử dụng.
end
function db=mergeMaterials(db,custom)
allNames=lower(string([{db.name} {custom.name}]));
assert(numel(unique(allNames))==numel(allNames),'Vivaldi:Material','Tên vật liệu tùy chỉnh bị trùng.');
db=[db custom];
end
function preview(ax,g)
% Preview lấy mẫu polyshape; CAD sử dụng EquationBasedSurface liên tục.
cla(ax);hold(ax,'on');
plate=polyshape([-g.aperture_w/2 g.aperture_w/2 g.aperture_w/2 -g.aperture_w/2], ...
    [g.z_base g.z_base g.L_flare g.L_flare]);
cut=polyshape(g.flare(:,1),g.flare(:,2));cut=union(cut,polyshape(g.transition(:,1),g.transition(:,2)));
for k=1:3,q=g.rectangles{k};cut=union(cut,polyshape(q(:,1),q(:,2)));end
metal=subtract(plate,cut);[tri,v]=triangulation(metal);
for arm=1:2
    for side=[-1 1]
        q=[v(:,1) side*g.thickness/2*ones(size(v,1),1) v(:,2)];
        if arm==2,q=(g.secondRotation*q'+g.secondTranslation)';end
        patch(ax,'Faces',tri,'Vertices',q,'FaceColor',[.65 .7 .78],'EdgeColor','none','FaceAlpha',.85);
    end
    [bx,bz]=boundary(metal);starts=[0;find(isnan(bx));numel(bx)+1];
    for k=1:numel(starts)-1
        ids=starts(k)+1:starts(k+1)-1;if numel(ids)<2,continue;end
        for j=1:numel(ids)-1
            ii=ids(j:j+1);q=[bx(ii) repmat(-g.thickness/2,2,1) bz(ii);flipud(bx(ii)) repmat(g.thickness/2,2,1) flipud(bz(ii))];
            if arm==2,q=(g.secondRotation*q'+g.secondTranslation)';end
            patch(ax,q(:,1),q(:,2),q(:,3),[.55 .6 .7],'EdgeColor','none','FaceAlpha',.85);
        end
    end
end
box(ax,[g.aperture_w/2 -g.thickness/2 g.z_base],[g.thickness g.thickness g.L_patch]);
box(ax,[g.bounds(1,1) g.bounds(1,2) g.z_base],[g.de_L g.de_W g.h_de]);
for arm=1:2
    if arm==1,c=g.port1;else,c=g.port2;end
    for r=[g.r_cabin g.r_cabout g.r_cabmid]
        [x,y,z]=cylinder(r,48);h=g.h_cabout;if r==g.r_cabin,h=g.h_cabin;end
        surf(ax,x+c(1),y+c(2),z*h+c(3),'FaceColor',[.8 .4 .15],'EdgeColor','none','FaceAlpha',.8);
    end
    plot3(ax,c(1),c(2),c(3),'bo','MarkerFaceColor','b');
    text(ax,c(1),c(2),c(3),sprintf(' port%d',arm),'Color','b');
end
axis(ax,'equal');grid(ax,'on');view(ax,35,25);xlabel(ax,'X (mm)');ylabel(ax,'Y (mm)');zlabel(ax,'Z (mm)');
title(ax,'Hai phân cực trực giao — preview dựa trên công thức');hold(ax,'off');
end
function box(ax,origin,sz)
v=[0 0 0;1 0 0;1 1 0;0 1 0;0 0 1;1 0 1;1 1 1;0 1 1].*sz+origin;
f=[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
patch(ax,'Faces',f,'Vertices',v,'FaceColor',[.6 .65 .7],'EdgeColor',[.3 .3 .3],'FaceAlpha',.8);
end
