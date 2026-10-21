function varargout = Vivaldi_HFSS_Builder(action,varargin)
% Sinh VBScript bằng thư viện gốc; không mở/sửa project tham chiếu.
switch lower(action)
    case 'library'
        library();
    case 'generate'
        varargout{1}=generate(varargin{:});
    case 'execute'
        varargout{1}=execute(varargin{:});
    case 'api'
        api(varargin{:});
    case 'quote'
        varargout{1}=quote(varargin{1});
    case 'runtime'
        runtime(varargin{:});
    case 'ascii'
        asciiScript(varargin{1});
    case 'open'
        openProject(varargin{:});
    otherwise
        error('Vivaldi:Action','Thao tác Builder không hợp lệ: %s',action);
end
end

function library()
% Khai báo trực tiếp từng addpath, không phụ thuộc Current Folder.
root=fileparts(mfilename('fullpath'));
folders={'boundary','3dmodeler','analysis','general','radiation','reporter','mesh','fieldsCalculator'};
for k=1:numel(folders)
    assert(isfolder(fullfile(root,'third_party','hfss-api',folders{k})), ...
        'Vivaldi:Library','Thiếu thư mục hfss-api: %s',folders{k});
end
addpath(fullfile(root,'third_party','hfss-api','boundary'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','3dmodeler'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','analysis'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','general'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','radiation'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','reporter'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','mesh'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','fieldsCalculator'),'-begin');
names={'hfssNewProject','hfssInsertDesign','hfssSaveProject','hfssExecuteScript', ...
    'hfssRectangle','hfssBox','hfssCircle','hfssCylinder','hfssSubtract','hfssUnite', ...
    'hfssRotate','hfssMove','hfssSetWCS','hfssAssignMaterial','hfssAssignLumpedPort', ...
    'hfssAssignRadiation','hfssInsertSolution','hfssSolveSetup','hfssInsertFarFieldSphereSetup', ...
    'hfssCreateReport','hfssExportToFile','hfssSetVariable','hfssOpenProject','hfssSetDesign', ...
    'hfssRename','hfssSetSolveInside'};
for k=1:numel(names)
    path=which(names{k});
    assert(startsWith(path,[fullfile(root,'third_party','hfss-api') filesep]), ...
        'Vivaldi:PathConflict','Xung đột MATLAB Path: %s -> %s',names{k},path);
end
end

function job=generate(p,material,outdir,cfg,debug)
% Mỗi lần sinh script giữ riêng một thư mục mới, không ghi đè AEDT.
if nargin<4 || isempty(cfg), cfg=Vivaldi_HFSS_Simulation('defaults'); end
if nargin<5, debug=true; end
library(); g=Vivaldi_Calculation(p);
Vivaldi_HFSS_Simulation('validate',cfg);
validateMaterial(material);
if ~isfolder(outdir), [ok,msg]=mkdir(outdir); assert(logical(ok),'Vivaldi:IO','%s',msg); end
[ok,info]=fileattrib(outdir); assert(logical(ok),'Vivaldi:IO','Không đọc được thư mục xuất.');
outdir=info.Name;
[~,id]=fileparts(tempname(outdir));
job.folder=fullfile(outdir,['Vivaldi_DualPol_' id]);
[ok,msg]=mkdir(job.folder); assert(logical(ok),'Vivaldi:IO','%s',msg);
job.project=fullfile(job.folder,['Vivaldi_DualPol_' id '.aedt']);
job.script=fullfile(job.folder,'build.vbs');
job.log=fullfile(job.folder,'build.log');
job.done=fullfile(job.folder,'build.complete');
job.debug=fullfile(job.folder,['Vivaldi_DEBUG_INCOMPLETE_' id '.aedt']);
job.design='dual_pol_vivaldi_patch_Wflare_20'; job.geometry=g;
job.cfg=cfg; job.material=material; job.status='GENERATED';
fid=fopen(job.script,'wt','n','UTF-8'); assert(fid>=0,'Vivaldi:IO','Không mở được script.');
closer=onCleanup(@()fclose(fid));
runtime(fid,job.log,job.done,job.debug,debug);
fprintf(fid,'Mark "BUILD_01 START Project"\n');
hfssNewProject(fid);
% ProgID đời cũ trong upstream không chắc đăng ký ở AEDT 2021 R2.
% Chỉ đổi ProgID ở bước chuẩn hóa cuối; các lệnh API vẫn giữ nguyên.
hfssInsertDesign(fid,job.design,'driven modal');
fprintf(fid,'Check "BUILD_01 Project"\n');
fprintf(fid,'oEditor.SetModelUnits Array("NAME:Units Parameter", "Units:=", "mm", "Rescale:=", false)\n');
writeVariables(fid,g);
fprintf(fid,'Check "BUILD_02 Variables"\n');
createCS(fid,'slot_t_td','Global',{'(slot_feed_w/2)*exp(slot_t_L*r_flare)','0','slot_t_L'});
createCS(fid,'slot_feed_td','Global',{'-x_feed','0','z_feed'});
createCS(fid,'patch_td','Global',{'aperture_w/2','0','L_flare'});
createCS(fid,'RelativeCS1','patch_td',{'0','-thickness/2','0'});
fprintf(fid,'Check "BUILD_03 CoordinateSystems"\n');
hfssSetWCS(fid,'Global');
equation(fid,'EquationSurface1','L_flare'); equation(fid,'EquationSurface2','slot_t_L');
clone(fid,'EquationSurface2','EquationSurface2_1');
hfssSubtract(fid,'EquationSurface1','EquationSurface2_1','true');
remove(fid,'EquationSurface2_1');
fprintf(fid,'Check "BUILD_04 EquationSurfaces"\n');
hfssSetWCS(fid,'slot_t_td'); api(fid,'slot_t_td',@hfssRotate,'EquationSurface2','Y',g.deg_slot_t);
hfssSetWCS(fid,'slot_feed_td');
api(fid,'slot_feed_td',@hfssRectangle,'Rectangle1','Y',[0 0 0],-g.h3_slot_feed,g.slot_feed_w,'mm');
api(fid,'slot_feed_td',@hfssRectangle,'Rectangle2','Y',[0 0 -g.h3_slot_feed],-g.slot_feed_w,g.slot_feed_w+g.h2+g.cavity_w,'mm');
api(fid,'slot_feed_td',@hfssRectangle,'Rectangle3','Y',[g.slot_feed_w+g.h2 0 -g.h3_slot_feed-g.slot_feed_w],g.cavity_L,g.cavity_w,'mm');
hfssUnite(fid,{'EquationSurface1','EquationSurface2','Rectangle1','Rectangle2','Rectangle3'});
fprintf(fid,'Check "BUILD_05 TransitionCavity"\n');
hfssSetWCS(fid,'patch_td');
api(fid,'patch_td',@hfssRectangle,'Vivaldi_1','Y',[0 0 0],-g.L_patch,-g.aperture_w,'mm');
hfssSubtract(fid,'Vivaldi_1','EquationSurface1','false');
fprintf(fid,'Check "BUILD_06 SubtractFlare"\n');
% Upstream hfssThickenSheet chỉ hỗ trợ BothSides=false: phát lệnh bổ sung.
fprintf(fid,'oEditor.ThickenSheet Array("NAME:Selections", "Selections:=", "Vivaldi_1", "NewPartsModelFlag:=", "Model"), Array("NAME:SheetThickenParameters", "Thickness:=", "thickness", "BothSides:=", true)\n');
fprintf(fid,'Check "BUILD_07 BothSidesThicken"\n');
hfssSetWCS(fid,'RelativeCS1'); duplicate(fid,'Vivaldi_1','Vivaldi_2');
api(fid,'RelativeCS1',@hfssMove,'Vivaldi_2',[0 g.thickness 0],'mm');
fprintf(fid,'Check "BUILD_08 SecondPolarization"\n');
api(fid,'RelativeCS1',@hfssBox,'Box1',[0 0 0],[g.thickness g.thickness -g.L_patch],'mm','vacuum',true);
hfssSetWCS(fid,'Global');
api(fid,'Global',@hfssBox,'De',[(g.de_L+g.thickness)/2 -(g.de_W-g.aperture_w)/2 g.z_feed-g.h3_slot_feed-g.slot_feed_w],[-g.de_L g.de_W -g.h_de],'mm','vacuum',true);
fprintf(fid,'Check "BUILD_09 BaseAndBox"\n');
hfssUnite(fid,{'Vivaldi_1','Vivaldi_2','Box1','De'});
assignBody(fid,material);
fprintf(fid,'Check "BUILD_10 UniteBody"\n');
hfssSetWCS(fid,'slot_feed_td');
x=-g.positionx+g.slot_feed_w+g.h2;
api(fid,'slot_feed_td',@hfssCylinder,'cable_in','Z',[x 0 -g.h3_slot_feed],g.r_cabin,-g.h_cabin,'mm');
api(fid,'slot_feed_td',@hfssCylinder,'cable_out','Z',[x 0 -g.h3_slot_feed-g.slot_feed_w],g.r_cabout,-g.h_cabout,'mm');
api(fid,'slot_feed_td',@hfssCylinder,'cable_mid','Z',[x 0 -g.h3_slot_feed-g.slot_feed_w],g.r_cabmid,-g.h_cabmid,'mm');
hfssSubtract(fid,'cable_out','cable_mid','true');
api(fid,'slot_feed_td',@hfssCircle,'port1','Z',[x 0 -g.h3_slot_feed-g.h_cabin],g.r_cabmid,'mm',true);
for n={'cable_in','cable_out'}, hfssAssignMaterial(fid,n{1},'copper',false); end
fprintf(fid,'Check "BUILD_11 FirstCoax"\n');
hfssSetWCS(fid,'RelativeCS1');
old={'cable_in','cable_out','cable_mid','port1'};
new={'cable_in_1','cable_out_1','cable_mid_1','port2'};
for k=1:4
    duplicate(fid,old{k},new{k});
    api(fid,'RelativeCS1',@hfssMove,new{k},[0 g.thickness 0],'mm');
end
fprintf(fid,'Check "BUILD_12 SecondCoax"\n');
hfssSetWCS(fid,'Global');
conductors={'cable_in','cable_in_1','cable_mid','cable_mid_1','cable_out','cable_out_1'};
cutters=cellfun(@(n)[n '_cut'],conductors,'UniformOutput',false);
for k=1:6, clone(fid,conductors{k},cutters{k}); end
hfssSubtract(fid,'Vivaldi_1',cutters,'true');
remove(fid,strjoin([cutters {'cable_mid','cable_mid_1'}],','));
fprintf(fid,'Check "BUILD_13 CoaxCutouts"\n');
Vivaldi_HFSS_Simulation('configure',fid,cfg,g);
% Xác minh object IDs bằng lệnh trả về scalar, tránh SAFEARRAY/Set sai.
for n={'Vivaldi_1','cable_in','cable_out','cable_in_1','cable_out_1','port1','port2','RadiatingSurface'}
    fprintf(fid,'objectId = oEditor.GetObjectIDByName("%s")\nCheck "Object %s"\n',n{1},n{1});
    fprintf(fid,'If objectId <= 0 Then Err.Raise 513, "ObjectCheck", "Missing %s"\nCheck "Object %s exists"\n',n{1},n{1});
end
fprintf(fid,'validation = oDesign.ValidateDesign()\nCheck "BUILD_17 ValidateDesign call"\n');
fprintf(fid,'If validation <> 0 Then Err.Raise 514, "ValidateDesign", "Validation reported errors: " & CStr(validation)\nCheck "BUILD_17 ValidateDesign result"\n');
fprintf(fid,'If fso.FileExists(%s) Then Err.Raise 515, "Save", "Refusing overwrite"\nCheck "BUILD_18 NoOverwrite"\n',quote(job.project));
hfssSaveProject(fid,job.project,false);
fprintf(fid,'Check "BUILD_18 SaveAEDT"\n');
fprintf(fid,'If Not fso.FileExists(%s) Then Err.Raise 516, "Save", "AEDT file missing"\nCheck "BUILD_18 FileExists"\n',quote(job.project));
fprintf(fid,'Mark "COMPLETE: API commands and ValidateDesign succeeded; physical CAD acceptance still required"\n');
fprintf(fid,'Set marker = fso.CreateTextFile(%s, false)\nmarker.WriteLine "COMPLETE"\nmarker.Close\nEnd Sub\nMain\n',quote(job.done));
clear closer
asciiScript(job.script);
save(fullfile(job.folder,'build_manifest.mat'),'job');
end

function writeVariables(fid,g)
names=fieldnames(g.parameters);
for k=1:numel(names)
    n=names{k}; unit='mm';
    if any(strcmp(n,{'deg_slot_t','scan_phi','scan_theta'})), unit='deg'; end
    hfssSetVariable(fid,n,sprintf('%.17g',g.(n)),unit);
end
v={'slot_t_L','6.4mm+them';'L_flare','L_flare_1+slot_t_L'; ...
    'r_flare','ln(aperture_w/slot_feed_w)/L_flare'; ...
    'z_feed','((slot_feed_w/2)*exp(slot_t_L*r_flare)+slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t))'; ...
    'x_feed','((slot_feed_w/2)*exp(slot_t_L*r_flare)+slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*sin(deg_slot_t)-(slot_feed_w/2)*exp(slot_t_L*r_flare)'; ...
    'L_patch','L_flare-z_feed+h3_slot_feed+slot_feed_w+h_de'; ...
    'de_L','aperture_w+thickness';'de_W','aperture_w+thickness'; ...
    'h_cabin','h_de+slot_feed_w';'h_cabout','h_cabin-slot_feed_w'; ...
    'h_cabmid','h_cabin-slot_feed_w';'h_box','lamda/2+L_patch'};
for k=1:size(v,1), hfssSetVariable(fid,v{k,1},v{k,2},''); end
end

function createCS(fid,name,parent,origin)
hfssSetWCS(fid,parent);
fprintf(fid,'oEditor.CreateRelativeCS Array("NAME:RelativeCSParameters", "Mode:=", "Axis/Position", "OriginX:=", "%s", "OriginY:=", "%s", "OriginZ:=", "%s", "XAxisXvec:=", "1mm", "XAxisYvec:=", "0mm", "XAxisZvec:=", "0mm", "YAxisXvec:=", "0mm", "YAxisYvec:=", "1mm", "YAxisZvec:=", "0mm"), Array("NAME:Attributes", "Name:=", "%s")\n',origin{:},name);
end
function equation(fid,name,limit)
fprintf(fid,'oEditor.CreateEquationSurface Array("NAME:EquationBasedSurfaceParameters", "XuvFunction:=", "_v*(slot_feed_w/2)*exp(_u*r_flare)", "YuvFunction:=", "0", "ZuvFunction:=", "_u", "uStart:=", "0", "uEnd:=", "%s", "vStart:=", "-1", "vEnd:=", "1"), Array("NAME:Attributes", "Name:=", "%s", "PartCoordinateSystem:=", "Global", "MaterialName:=", "vacuum", "SolveInside:=", true)\n',limit,name);
end
function clone(fid,old,new)
hfssRename(fid,old,'VD_CopySource');
fprintf(fid,'oEditor.Copy Array("NAME:Selections", "Selections:=", "VD_CopySource")\noEditor.Paste\n');
hfssRename(fid,'VD_CopySource',old);
hfssRename(fid,'VD_CopySource_1',new);
end
function duplicate(fid,old,new)
% Tên nguồn tạm không có hậu tố số: tránh quy tắc tăng số của AEDT.
hfssRename(fid,old,'VD_RotateSource');
fprintf(fid,'oEditor.DuplicateAroundAxis Array("NAME:Selections", "Selections:=", "VD_RotateSource", "NewPartsModelFlag:=", "Model"), Array("NAME:DuplicateAroundAxisParameters", "CreateNewObjects:=", true, "WhichAxis:=", "Z", "AngleStr:=", "-90deg", "NumClones:=", "2"), Array("NAME:Options", "DuplicateAssignments:=", false)\n');
hfssRename(fid,'VD_RotateSource',old);
hfssRename(fid,'VD_RotateSource_1',new);
end
function remove(fid,names)
fprintf(fid,'oEditor.Delete Array("NAME:Selections", "Selections:=", "%s")\n',names);
end
function validateMaterial(m)
Vivaldi_GUI('validatematerial',m);
assert(isstruct(m) && all(isfield(m,{'name','type','permittivity','permeability','conductivity','lossTangent'})), ...
    'Vivaldi:Material','Thiếu thuộc tính vật liệu.');
assert(~isempty(strtrim(m.name)) && any(strcmp(m.type,{'metal','pec'})), ...
    'Vivaldi:Material','Thân anten cần kim loại hoặc PEC; không thể dùng điện môi.');
validateattributes([m.permittivity m.permeability m.conductivity m.lossTangent],{'numeric'},{'real','finite','nonnegative'});
assert(m.permittivity>0 && m.permeability>0 && (strcmp(m.type,'pec') || m.conductivity>0), ...
    'Vivaldi:Material','Thuộc tính kim loại không hợp lệ.');
end
function assignBody(fid,m)
if strcmp(m.type,'pec')
    hfssAssignMaterial(fid,'Vivaldi_1','pec',false);
else
    fprintf(fid,'Set definitions = oProject.GetDefinitionManager()\n');
    fprintf(fid,'definitions.AddMaterial Array("NAME:VD_Body", "CoordinateSystemType:=", "Cartesian", "permittivity:=", "%.17g", "permeability:=", "%.17g", "conductivity:=", "%.17g", "dielectric_loss_tangent:=", "%.17g")\n',m.permittivity,m.permeability,m.conductivity,m.lossTangent);
    hfssAssignMaterial(fid,'Vivaldi_1','VD_Body',false);
end
hfssSetSolveInside(fid,'Vivaldi_1',false);
end

function api(fid,cs,fun,varargin)
% Giữ hàm upstream nguyên bản. Chuẩn hóa CS và độ chính xác đầu ra của API
% cũ (%f/%.4f), tránh làm tròn tọa độ trước khi gửi HFSS.
path=tempname; f=fopen(path,'wt'); assert(f>=0,'Vivaldi:IO','Không mở được tệp API tạm.');
try
    fun(f,varargin{:}); fclose(f);
catch ex
    fclose(f); if isfile(path), delete(path); end; rethrow(ex);
end
text=fileread(path); delete(path);
text=strrep(text,'"Modal S Parameter"','"Modal Solution Data"');
text=strrep(text,'"PartCoordinateSystem:=", "Global"',['"PartCoordinateSystem:=", "' cs '"']);
nums=[];
for k=1:numel(varargin)
    if isnumeric(varargin{k}), nums=[nums varargin{k}(:)']; end %#ok<AGROW>
end
[starts,stops,tokens]=regexp(text,'"(-?\d+\.\d+)(mm|deg|GHz|Ohm)"','start','end','tokens');
for k=numel(starts):-1:1
    token=tokens{k}; candidates=nums(arrayfun(@(v)strcmp(sprintf('%.6f',v),token{1}) || strcmp(sprintf('%.4f',v),token{1}),nums));
    candidates=unique(candidates);
    assert(numel(candidates)<=1,'Vivaldi:Precision','Hai giá trị bị API cũ làm tròn trùng nhau; không thể khôi phục an toàn.');
    if ~isempty(candidates)
        text=[text(1:starts(k)-1) '"' sprintf('%.17g',candidates(1)) token{2} '"' text(stops(k)+1:end)];
    end
end
[a,b,t]=regexp(text,'(?<=, )(-?\d+\.\d+)(?=[, )\r\n])','start','end','tokens');
for k=numel(a):-1:1
    values=unique(nums(arrayfun(@(v)strcmp(sprintf('%.6f',v),t{k}{1}),nums)));
    assert(numel(values)<=1,'Vivaldi:Precision','Giá trị API bị làm tròn trùng nhau.');
    if ~isempty(values),text=[text(1:a(k)-1) sprintf('%.17g',values(1)) text(b(k)+1:end)];end
end
fprintf(fid,'%s',text);
end

function s=quote(value)
% Chuỗi VBS ASCII, hỗ trợ đường dẫn Unicode qua UTF-16 ChrW.
value=char(value);parts={};run='';
for k=1:numel(value)
    code=double(value(k));
    if code>=32 && code<=126
        run=[run value(k)]; %#ok<AGROW>
    else
        if ~isempty(run),parts{end+1}=['"' strrep(run,'"','""') '"'];run='';end %#ok<AGROW>
        if code>32767,code=code-65536;end
        parts{end+1}=sprintf('ChrW(%d)',code); %#ok<AGROW>
    end
end
if ~isempty(run),parts{end+1}=['"' strrep(run,'"','""') '"'];end
if isempty(parts),s='""';else,s=strjoin(parts,' & ');end
end
function asciiScript(path)
s=fileread(path);
s=strrep(s,sprintf('\r\n'),sprintf('\n'));
s=strrep(s,'AnsoftHfss.HfssScriptInterface','Ansoft.ElectronicsDesktop.2021.2');
s=regexprep(s,'(?m)^Dim oProject\r?\n','');
s=regexprep(s,'(?m)^Check ([^\r\n]+)$','If Not Check($1) Then Exit Sub');
[a,b]=regexp(s,'"(?:[^"\r\n]|"")*"');
for k=numel(a):-1:1
    literal=s(a(k)+1:b(k)-1);
    if any(double(literal)>127)
        s=[s(1:a(k)-1) '(' quote(strrep(literal,'""','"')) ')' s(b(k)+1:end)];
    end
end
assert(all(double(s)<128),'Vivaldi:Encoding','Script còn ký tự ngoài ASCII.');
f=fopen(path,'wb'); assert(f>=0,'Vivaldi:IO','Không ghi được script ASCII.');
c=onCleanup(@()fclose(f)); fwrite(f,uint8(s),'uint8');
end
function runtime(fid,logpath,donepath,debugpath,debug)
% Check trả Boolean, Main thoát ngay khi lỗi; không nuốt Err.Raise ở caller.
fprintf(fid,'Dim fso, stream, marker, objectId, validation, definitions, oProject\n');
fprintf(fid,'Set fso = CreateObject("Scripting.FileSystemObject")\n');
fprintf(fid,'Sub Mark(message)\n  Set stream = fso.OpenTextFile(%s, 8, true)\n  stream.WriteLine CStr(Now) & " " & message\n  stream.Close\nEnd Sub\n',quote(logpath));
fprintf(fid,'Function Check(stage)\n  Dim code, message\n  code = Err.Number\n  message = Err.Description\n  Check = false\n  If code <> 0 Then\n    Err.Clear\n    Mark stage & " ERROR " & CStr(code) & " " & message\n');
if debug
    fprintf(fid,'    On Error Resume Next\n    oProject.SaveAs %s, false\n    Err.Clear\n',quote(debugpath));
end
fprintf(fid,'    Exit Function\n  End If\n  Mark stage & " OK_COMMAND"\n  Check = true\nEnd Function\n');
fprintf(fid,'Sub Main()\nOn Error Resume Next\n');
fprintf(fid,'If fso.FileExists(%s) Then Err.Raise 517, "Run", "Completion marker already exists"\nCheck "Fresh run"\n',quote(donepath));
end
function job=execute(job,exe)
assert(ispc,'Vivaldi:Platform','Khởi chạy HFSS cần Windows và ANSYS 2021 R2 có giấy phép.');
assert(isfile(exe),'Vivaldi:Executable','Không tìm thấy ansysedt.exe.');
assert(~any(ismember([char(exe) char(job.script)],['"' char(10) char(13) '%' '!'])), ...
    'Vivaldi:Path','Đường dẫn chứa ký tự không an toàn cho Windows shell.');
assert(~isfile(job.done),'Vivaldi:Run','Job đã chạy; hãy sinh job mới.');
library(); status=hfssExecuteScript(exe,job.script,false,true);
if status~=0 || ~isfile(job.done) || ~isfile(job.project)
    detail='Không có nhật ký HFSS.';
    if isfile(job.log), detail=fileread(job.log); end
    error('Vivaldi:HFSS','HFSS chưa hoàn tất (exit=%d). Nhật ký: %s\n%s',status,job.log,detail);
end
assert(strcmp(strtrim(fileread(job.done)),'COMPLETE'),'Vivaldi:HFSS','Marker không hợp lệ.');
job.status='API_COMPLETE_PHYSICAL_ACCEPTANCE_PENDING';
end
function openProject(exe,project)
assert(ispc && isfile(exe) && isfile(project),'Vivaldi:Open','Cần Windows, ansysedt.exe và AEDT có thật.');
assert(~any(ismember([char(exe) char(project)],['"' char(10) char(13) '%' '!'])), ...
    'Vivaldi:Path','Đường dẫn không an toàn cho Windows shell.');
[status,msg]=system(sprintf('start "" "%s" "%s"',exe,project));
assert(status==0,'Vivaldi:Open','%s',msg);
end
