function result = Vivaldi_HFSS_Builder(parameters, options)
% SPDX-License-Identifier: GPL-2.0-or-later
% VIVALDI_HFSS_BUILDER Sinh VBScript từ đầu, không mở/sửa project tham chiếu.
% r = Vivaldi_HFSS_Builder(p,struct('OutputDir',folder,'Execute',false))
% Vivaldi_HFSS_Builder('library') chỉ nạp/kiểm tra thư viện đi kèm.
% Vivaldi_HFSS_Builder('run',r) thực thi script đã sinh và kiểm tra log runtime.
root = fileparts(mfilename('fullpath'));
if nargin >= 1 && ischar(parameters)
    switch parameters
        case 'library', result = loadLibrary(root); return;
        case 'run', result = runScript(options); return;
        case 'encode', result = encodeUnicode(options); return;
        otherwise, error('Vivaldi:Action','Lệnh Builder không hợp lệ.');
    end
end
loadLibrary(root);
if nargin < 1, parameters = struct(); end
if nargin < 2, options = struct(); end
[g,p] = Vivaldi_Calculation(parameters);
options = defaults(options,struct('OutputDir',fullfile(root,'outputs'), ...
    'Executable','','Execute',false,'Debug',true,'Simulation',struct(), ...
    'Material',struct('name','Aluminum','type','metal','permittivity',1, ...
        'permeability',1.000021,'conductivity',3.8e7,'lossTangent',0)));
validateMaterial(options.Material);
assert(ischar(options.OutputDir) && isempty(regexp(options.OutputDir,'["\r\n]','once')), ...
    'Vivaldi:Output','Thư mục xuất không được chứa dấu nháy hoặc ký tự xuống dòng.');
% Mỗi project có thư mục riêng; không ghi đè kể cả khi bấm nhiều lần.
if ~isfolder(options.OutputDir), mkdir(options.OutputDir); end
[ok,info] = fileattrib(options.OutputDir); assert(logical(ok),'Vivaldi:Output','Không đọc được thư mục xuất.');
folder = tempname(info.Name); [ok,msg] = mkdir(folder); assert(logical(ok),'Vivaldi:Output','%s',msg);
[~,token] = fileparts(folder);
name = ['Vivaldi_DualPol_' datestr(now,'yyyymmdd_HHMMSS') '_' token];
result = struct('folder',folder,'project',fullfile(folder,[name '.aedt']), ...
    'script',fullfile(folder,[name '.vbs']),'log',fullfile(folder,'build.log'), ...
    'debug',fullfile(folder,['Vivaldi_DEBUG_INCOMPLETE_' token '.aedt']), ...
    'validation',fullfile(folder,'validation.log'),'executable',options.Executable, ...
    'geometry',g,'parameters',p,'material',options.Material,'status','SCRIPT_GENERATED');
result.expected = 'BUILD_COMPLETE';
result.simulation = Vivaldi_HFSS_Simulation('validate',options.Simulation);
[fid,msg] = fopen(result.script,'wt'); assert(fid>=0,'Vivaldi:File','%s',msg);
cleanup = onCleanup(@() safeClose(fid));
% Main có error handler cục bộ; lỗi thật kết thúc Main và không ghi marker thành công.
fprintf(fid,'Sub Main()\nOn Error Resume Next\n');
fprintf(fid,'Dim fs, logFile, stepName, errNum, errText, validationResult, beforeNames, addedName\n');
fprintf(fid,'Set fs = CreateObject("Scripting.FileSystemObject")\n');
fprintf(fid,'Set logFile = fs.CreateTextFile(%s, False, True)\n',vbString(result.log));
fprintf(fid,'If Err.Number <> 0 Then Exit Sub\n');
fprintf(fid,'If fs.FileExists(%s) Then\nlogFile.WriteLine "REFUSED_EXISTING_PROJECT"\nlogFile.Close\nExit Sub\nEnd If\n',vbString(result.project));
begin(fid,'BUILD_01','New project / DrivenModal');
hfssNewProject(fid); guard(fid,result,options);
hfssInsertDesign(fid,'dual_pol_vivaldi_patch_Wflare_20','driven modal'); guard(fid,result,options);
fprintf(fid,'oEditor.SetModelUnits Array("NAME:Units Parameter", "Units:=", "mm", "Rescale:=", False)\n');
finish(fid,result,options);
begin(fid,'BUILD_02','Independent and dependent variables');
names = fieldnames(p);
for k = 1:numel(names)
    unit = 'mm';
    if any(strcmp(names{k},{'deg_slot_t','scan_phi','scan_theta'})), unit='deg'; end
    hfssSetVariable(fid,names{k},sprintf('%.17g',p.(names{k})),unit);
    guard(fid,result,options);
end
expr = {'slot_t_L','6.4mm+them';'L_flare','L_flare_1+slot_t_L'; ...
    'r_flare','ln(aperture_w/slot_feed_w)/L_flare'; ...
    'x_feed','((slot_feed_w/2)*exp(slot_t_L*r_flare)+slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*sin(deg_slot_t)-(slot_feed_w/2)*exp(slot_t_L*r_flare)'; ...
    'z_feed','((slot_feed_w/2)*exp(slot_t_L*r_flare)+slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t))'; ...
    'L_patch','L_flare-z_feed+h3_slot_feed+slot_feed_w+h_de'; ...
    'de_L','aperture_w+thickness';'de_W','aperture_w+thickness'; ...
    'h_box','lamda/2+L_patch';'h_cabin','h_de+slot_feed_w'; ...
    'h_cabout','h_cabin-slot_feed_w';'h_cabmid','h_cabin-slot_feed_w'};
for k=1:size(expr,1)
    hfssSetVariable(fid,expr{k,1},expr{k,2},''); guard(fid,result,options);
end
% Tên ASCII nội bộ ổn định; tên hiển thị vật liệu có thể là Unicode.
mat = options.Material;
if strcmp(mat.type,'pec')
    materialName='pec';
else
    materialName='VivaldiBodyMaterial';
    fprintf(fid,'Dim definitions\nSet definitions = oProject.GetDefinitionManager()\n');
    fprintf(fid,['definitions.AddMaterial Array("NAME:%s", "CoordinateSystemType:=", "Cartesian", ' ...
        '"BulkOrSurfaceType:=", 1, "permittivity:=", "%.17g", "permeability:=", "%.17g", ' ...
        '"conductivity:=", "%.17g", "dielectric_loss_tangent:=", "%.17g")\n'], ...
        materialName,mat.permittivity,mat.permeability,mat.conductivity,mat.lossTangent);
end
finish(fid,result,options);
begin(fid,'BUILD_03','Coordinate systems and parent patch_td');
cs(fid,'slot_t_td','Global',{'(slot_feed_w/2)*exp(slot_t_L*r_flare)','0mm','slot_t_L'}); guard(fid,result,options);
cs(fid,'slot_feed_td','Global',{'-x_feed','0mm','z_feed'}); guard(fid,result,options);
cs(fid,'patch_td','Global',{'aperture_w/2','0mm','L_flare'}); guard(fid,result,options);
cs(fid,'RelativeCS1','patch_td',{'0mm','-thickness/2','0mm'}); finish(fid,result,options);
begin(fid,'BUILD_04','Exact equation surfaces and pre-rotation clone');
hfssSetWCS(fid,'Global');
equation(fid,'EquationSurface1','L_flare'); guard(fid,result,options);
equation(fid,'EquationSurface2','slot_t_L'); guard(fid,result,options);
% Copy/Paste giữ nguyên vị trí; fresh project quyết định tên bản sao.
copyObject(fid,'EquationSurface2','EquationSurface2_1',result,options); guard(fid,result,options);
hfssSubtract(fid,'EquationSurface1','EquationSurface2_1','true'); guard(fid,result,options);
deleteObjects(fid,'EquationSurface2_1'); finish(fid,result,options);
begin(fid,'BUILD_05','Rotate transition / three rectangles / unite cutter');
hfssSetWCS(fid,'slot_t_td');
api(fid,@hfssRotate,{{'EquationSurface2'},'Y',p.deg_slot_t}, ...
    {'RotateAngle','deg_slot_t'}); guard(fid,result,options);
rectangle(fid,'Rectangle1','slot_feed_td',{'0mm','0mm','0mm'},'-h3_slot_feed','slot_feed_w'); guard(fid,result,options);
rectangle(fid,'Rectangle2','slot_feed_td',{'0mm','0mm','-h3_slot_feed'},'-slot_feed_w','slot_feed_w+h2+cavity_w'); guard(fid,result,options);
rectangle(fid,'Rectangle3','slot_feed_td',{'slot_feed_w+h2','0mm','-h3_slot_feed-slot_feed_w'},'cavity_L','cavity_w'); guard(fid,result,options);
hfssUnite(fid,{'EquationSurface1','EquationSurface2','Rectangle1','Rectangle2','Rectangle3'}); finish(fid,result,options);
begin(fid,'BUILD_06','Subtract composite cutter from Vivaldi_1');
rectangle(fid,'Vivaldi_1','patch_td',{'0mm','0mm','0mm'},'-L_patch','-aperture_w'); guard(fid,result,options);
hfssSubtract(fid,'Vivaldi_1','EquationSurface1','false'); guard(fid,result,options);
% Điểm trong khe phải rỗng, hai mép tấm phải còn kim loại.
zm=g.slot_t_L+p.L_flare_1/2;
xm=(p.aperture_w/2+p.slot_feed_w/2*exp(g.r_flare*zm))/2;
checkPoint(fid,'Vivaldi_1',[0 0 zm],false,result,options);
checkPoint(fid,'Vivaldi_1',[xm 0 zm],true,result,options);
checkPoint(fid,'Vivaldi_1',[-xm 0 zm],true,result,options);
finish(fid,result,options);
begin(fid,'BUILD_07','BothSides sheet thickening');
% API gốc không hỗ trợ BothSides=true: chỉ xuất lệnh thiếu tùy chọn này.
fprintf(fid,['oEditor.ThickenSheet Array("NAME:Selections", "Selections:=", "Vivaldi_1", ' ...
    '"NewPartsModelFlag:=", "Model"), Array("NAME:SheetThickenParameters", ' ...
    '"Thickness:=", "thickness", "BothSides:=", True)\n']); guard(fid,result,options);
checkPoint(fid,'Vivaldi_1',[0 0 zm],false,result,options);
checkPoint(fid,'Vivaldi_1',[xm 0.49*p.thickness zm],true,result,options);
checkPoint(fid,'Vivaldi_1',[xm -0.49*p.thickness zm],true,result,options);
checkPoint(fid,'Vivaldi_1',[xm 0.75*p.thickness zm],false,result,options);
finish(fid,result,options);
begin(fid,'BUILD_08','Duplicate -90 degrees / move +thickness');
duplicate(fid,'Vivaldi_1','Vivaldi_2',result,options);
secondPoint=([xm 0 zm]-g.cs.RelativeCS1)*g.rotationZ'+g.cs.RelativeCS1+g.translation;
checkPoint(fid,'Vivaldi_2',secondPoint,true,result,options);
checkPoint(fid,'Vivaldi_2',[xm 0 zm],false,result,options);
finish(fid,result,options);
begin(fid,'BUILD_09','Box1 and metal base');
box(fid,'Box1','RelativeCS1',{'0mm','0mm','0mm'},{'thickness','thickness','-L_patch'},materialName); guard(fid,result,options);
box(fid,'De','Global',{'(de_L+thickness)/2','-(de_W-aperture_w)/2','z_feed-h3_slot_feed-slot_feed_w'}, ...
    {'-de_L','de_W','-h_de'},materialName); finish(fid,result,options);
begin(fid,'BUILD_10','Unite two arms, Box1 and De');
hfssUnite(fid,{'Vivaldi_1','Vivaldi_2','Box1','De'}); guard(fid,result,options);
hfssAssignMaterial(fid,'Vivaldi_1',materialName,false);
hfssSetSolveInside(fid,'Vivaldi_1',false); guard(fid,result,options);
checkPoint(fid,'Vivaldi_1',secondPoint,true,result,options);
checkPoint(fid,'Vivaldi_1',[xm 0 zm],true,result,options);
finish(fid,result,options);
begin(fid,'BUILD_11','Coax 1 conductors / hollow outer / circle port');
cylinder(fid,'cable_in','slot_feed_td',{'-positionx+slot_feed_w+h2','0mm','-h3_slot_feed'},'r_cabin','-h_cabin'); guard(fid,result,options);
cylinder(fid,'cable_out','slot_feed_td',{'-positionx+slot_feed_w+h2','0mm','-h3_slot_feed-slot_feed_w'},'r_cabout','-h_cabout'); guard(fid,result,options);
cylinder(fid,'cable_mid','slot_feed_td',{'-positionx+slot_feed_w+h2','0mm','-h3_slot_feed-slot_feed_w'},'r_cabmid','-h_cabmid'); guard(fid,result,options);
hfssSubtract(fid,'cable_out','cable_mid','true'); guard(fid,result,options);
api(fid,@hfssCircle,{'port1','Z',[0 0 0],1,'mm',true}, ...
    {'XCenter','-positionx+slot_feed_w+h2';'YCenter','0mm'; ...
    'ZCenter','-h3_slot_feed-h_cabin';'Radius','r_cabmid';'PartCoordinateSystem','slot_feed_td'}); finish(fid,result,options);
begin(fid,'BUILD_12','Coax 2 / same rigid transform as arm 2');
for item = {'cable_in','cable_out','cable_mid','port1'}
    old = item{1}; new=[old '_1']; if strcmp(old,'port1'), new='port2'; end
    duplicate(fid,old,new,result,options);
end
finish(fid,result,options);
begin(fid,'BUILD_13','Six preserved coax cutters / final body subtract');
originals = {'cable_in','cable_in_1','cable_mid','cable_mid_1','cable_out','cable_out_1'};
cutters = cell(1,6);
for k=1:6
    cutters{k} = ['CoaxCut' num2str(k)];
    copyObject(fid,originals{k},cutters{k},result,options); guard(fid,result,options);
end
hfssSubtract(fid,'Vivaldi_1',cutters,'true'); guard(fid,result,options);
deleteObjects(fid,strjoin([cutters {'cable_mid','cable_mid_1'}],',')); guard(fid,result,options);
for item = {'cable_in','cable_in_1','cable_out','cable_out_1'}
    hfssAssignMaterial(fid,item{1},'copper',false); guard(fid,result,options);
end
for center=[g.coax1;g.coax2]'
    point=center'; point(3)=g.z_base+p.h_de/2;
    checkPoint(fid,'Vivaldi_1',point,false,result,options);
end
checkPoint(fid,'cable_in',g.coax1+[0 0 p.h_de/2],true,result,options);
checkPoint(fid,'cable_out',g.coax1+[0 0 p.h_de/2],false,result,options);
checkPoint(fid,'cable_out',g.coax1+[(p.r_cabout+p.r_cabmid)/2 0 p.h_de/2],true,result,options);
checkPoint(fid,'cable_in_1',g.coax2+[0 0 p.h_de/2],true,result,options);
checkPoint(fid,'cable_out_1',g.coax2+[0 0 p.h_de/2],false,result,options);
finish(fid,result,options);
begin(fid,'BUILD_14','Two 50-ohm lumped ports / outer-to-inner lines');
hfssSetWCS(fid,'Global');
api(fid,@hfssAssignLumpedPort,{'1','port1',g.port1Line(1,:),g.port1Line(2,:),'mm',50,0},{}); guard(fid,result,options);
api(fid,@hfssAssignLumpedPort,{'2','port2',g.port2Line(1,:),g.port2Line(2,:),'mm',50,0},{}); finish(fid,result,options);
begin(fid,'BUILD_15','RadiatingSurface / absolute 20mm offsets / Open1');
padding={};
for axis={'X','Y','Z'}
    for sign={'+','-'}
        key=[sign{1} axis{1}];
        padding{end+1}=sprintf('"%sPaddingType:=", "Absolute Offset", "%sPadding:=", "20mm"',key,key); %#ok<AGROW>
    end
end
fprintf(fid,['oEditor.CreateRegion Array("NAME:RegionParameters", %s), ' ...
    'Array("NAME:Attributes", "Name:=", "RadiatingSurface", "Flags:=", "Wireframe#", ' ...
    '"PartCoordinateSystem:=", "Global", "MaterialValue:=", """vacuum""", "SolveInside:=", True)\n'],strjoin(padding,', '));
guard(fid,result,options);
hfssAssignRadiation(fid,'Open1','RadiatingSurface',false); finish(fid,result,options);
begin(fid,'BUILD_16','Setup1 / discrete sweep / far fields / sources');
Vivaldi_HFSS_Simulation('writeSetup',struct('fid',fid,'settings',result.simulation)); finish(fid,result,options);
begin(fid,'BUILD_17','ValidateDesign and runtime object inventory');
% 2021 R2 trả SAFEARRAY theo kiểu giá trị. Không dùng Set để nhận mảng.
fprintf(fid,'Dim solids, sheets, item, objectNames\nobjectNames = "|"\n');
fprintf(fid,'solids = oEditor.GetObjectsInGroup("Solids")\n'); guard(fid,result,options);
fprintf(fid,'If IsArray(solids) Then\nFor Each item In solids\nobjectNames = objectNames & CStr(item) & "|"\nNext\nEnd If\n');
fprintf(fid,'sheets = oEditor.GetObjectsInGroup("Sheets")\n'); guard(fid,result,options);
fprintf(fid,'If IsArray(sheets) Then\nFor Each item In sheets\nobjectNames = objectNames & CStr(item) & "|"\nNext\nEnd If\n');
expected={'Vivaldi_1','cable_in','cable_out','cable_in_1','cable_out_1','port1','port2','RadiatingSurface'};
for k=1:numel(expected)
    fprintf(fid,'If InStr(objectNames, "|%s|") = 0 Then Err.Raise 513, "Inventory", "Missing %s"\n',expected{k},expected{k}); guard(fid,result,options);
end
fprintf(fid,'If UBound(Split(objectNames, "|")) <> 9 Then Err.Raise 519, "Inventory", "Expected exactly 8 final objects"\n'); guard(fid,result,options);
fprintf(fid,'logFile.WriteLine "OBJECTS " & objectNames\n');
fprintf(fid,'validationResult = oDesign.ValidateDesign(%s)\n',vbString(result.validation)); guard(fid,result,options);
fprintf(fid,'If validationResult <> 1 Then Err.Raise 514, "ValidateDesign", "HFSS validation failed; see validation.log"\n'); finish(fid,result,options);
begin(fid,'BUILD_18','Save new AEDT without overwrite');
hfssSaveProject(fid,result.project,false); guard(fid,result,options);
fprintf(fid,'If Not fs.FileExists(%s) Then Err.Raise 515, "Save", "AEDT was not written"\n',vbString(result.project)); finish(fid,result,options);
fprintf(fid,'logFile.WriteLine "BUILD_COMPLETE"\nlogFile.Close\nEnd Sub\n');
writeInventoryFunctions(fid);
fprintf(fid,'Main\n');
clear cleanup;
% Sửa các thiếu sót định dạng của API gốc, không sửa file thư viện.
text = fileread(result.script);
text = encodeUnicode(text);
assert(all(double(text)<128),'Vivaldi:Encoding','VBScript phải là ASCII không BOM.');
[fid,msg]=fopen(result.script,'wb'); assert(fid>=0,'Vivaldi:File','%s',msg);
fwrite(fid,text,'char'); fclose(fid);
save(fullfile(folder,'build_inputs.mat'),'p','g','options');
if options.Execute, result = runScript(result); end
end

function paths = loadLibrary(root)
% Từng addpath trực tiếp, không reset hoặc lưu toàn bộ MATLAB Path.
folders={'boundary','3dmodeler','analysis','general','radiation','reporter','mesh','fieldsCalculator'};
for k=1:numel(folders)
    assert(isfolder(fullfile(root,'third_party','hfss-api',folders{k})), ...
        'Vivaldi:Library','Thiếu thư mục HFSS API: %s',folders{k});
end
addpath(fullfile(root,'third_party','hfss-api','boundary'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','3dmodeler'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','analysis'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','general'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','radiation'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','reporter'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','mesh'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','fieldsCalculator'),'-begin');
functions={'hfssNewProject','hfssRectangle','hfssSubtract','hfssUnite','hfssExecuteScript', ...
    'hfssBox','hfssCylinder','hfssCircle','hfssRotate','hfssMove','hfssCreateRelativeCS', ...
    'hfssAssignLumpedPort','hfssAssignRadiation','hfssSaveProject','hfssInsertSolution', ...
    'hfssSetVariable','hfssSetWCS','hfssInsertDesign','hfssAssignMaterial','hfssSetSolveInside', ...
    'hfssRename','hfssInsertFarFieldSphereSetup','hfssCreateReport','hfssExportToFile', ...
    'hfssOpenProject','hfssSetDesign','hfssSolveSetup'};
paths=cell(size(functions));
for k=1:numel(functions)
    paths{k}=which(functions{k});
    prefix=fullfile(root,'third_party','hfss-api');
    assert(strncmpi(paths{k},[prefix filesep],numel(prefix)+1), ...
        'Vivaldi:LibraryConflict','Hàm %s đang trỏ tới %s. Hãy bỏ bản cũ/clear hàm rồi thử lại.',functions{k},paths{k});
end
end

function out = defaults(out, fallback)
names=fieldnames(fallback);
for k=1:numel(names)
    if ~isfield(out,names{k}), out.(names{k})=fallback.(names{k}); end
end
end

function validateMaterial(m)
required={'name','type','permittivity','permeability','conductivity','lossTangent'};
assert(isstruct(m)&&all(isfield(m,required)),'Vivaldi:Material','Vật liệu thiếu thuộc tính.');
assert(ischar(m.name)&&~isempty(strtrim(m.name)),'Vivaldi:Material','Tên vật liệu rỗng.');
assert(any(strcmp(m.type,{'metal','pec'})),'Vivaldi:Material', ...
    'Thân anten phải là kim loại hoặc PEC. Không thêm substrate điện môi.');
v=[m.permittivity m.permeability m.conductivity m.lossTangent];
assert(numel(v)==4 && isreal(v) && all(isfinite(v)) && ...
    all(v(1:2)>0) && all(v(3:4)>=0),'Vivaldi:Material','Thông số vật liệu không hợp lệ.');
if strcmp(m.type,'metal'), assert(m.conductivity>0,'Vivaldi:Material','Kim loại cần conductivity > 0.'); end
end

function begin(fid,id,description)
fprintf(fid,'stepName = "%s"\nlogFile.WriteLine stepName & " BEGIN %s"\nErr.Clear\n',id,description);
end

function finish(fid,r,o)
guard(fid,r,o);
fprintf(fid,'logFile.WriteLine stepName & " API_COMPLETED"\n');
end

function guard(fid,r,o)
% Kiểm tra ngay sau lời gọi; không tiếp tục CAD sau lỗi.
fprintf(fid,['If Err.Number <> 0 Then\nerrNum = Err.Number\nerrText = Err.Description\n' ...
    'Err.Clear\nlogFile.WriteLine stepName & " FAILED " & CStr(errNum) & " " & errText\n']);
if o.Debug
    fprintf(fid,'If Not fs.FileExists(%s) Then oProject.SaveAs %s, False\n',vbString(r.debug),vbString(r.debug));
    fprintf(fid,'If Err.Number <> 0 Then logFile.WriteLine "DEBUG_SAVE_FAILED " & Err.Description\n');
end
fprintf(fid,'logFile.Close\nExit Sub\nEnd If\n');
end

function api(fid,fun,args,replacements)
% Tái dùng hàm gốc. Chỉ thay literal bị làm tròn/CS bị ép Global bằng biểu thức.
file=tempname; [f,msg]=fopen(file,'wt'); assert(f>=0,'Vivaldi:File','%s',msg);
cleanup=onCleanup(@() removeTemp(f,file));
fun(f,args{:}); fclose(f); text=fileread(file);
if strcmp(func2str(fun),'hfssAssignLumpedPort')
    for line=1:2
        key='Start'; if line==2, key='End'; end
        xyz=args{line+2};
        val=sprintf('Array("%.17gmm", "%.17gmm", "%.17gmm")',xyz);
        text=regexprep(text,['("' key ':=",\s*)Array\([^)]*\)'],['$1' val]);
    end
end
for k=1:size(replacements,1)
    key=replacements{k,1}; value=replacements{k,2};
    pattern=['("' key ':=",\s*)"[^"]*"'];
    assert(~isempty(regexp(text,pattern,'once')),'Vivaldi:APIFormat','Không tìm thấy %s trong %s.',key,func2str(fun));
    text=regexprep(text,pattern,['$1"' value '"']);
end
% API riêng Rectangle dùng PartCoordinateSystem, các hàm khác cũng vậy.
fprintf(fid,'%s',text);
end

function removeTemp(fid,file)
safeClose(fid); if isfile(file), delete(file); end
end

function safeClose(fid)
if any(fopen('all')==fid), fclose(fid); end
end

function cs(fid,name,parent,xyz)
hfssSetWCS(fid,parent);
api(fid,@hfssCreateRelativeCS,{name,[0 0 0],'mm'}, ...
    {'OriginX',xyz{1};'OriginY',xyz{2};'OriginZ',xyz{3}});
end

function rectangle(fid,name,coord,xyz,w,h)
api(fid,@hfssRectangle,{name,'Y',[0 0 0],1,1,'mm'}, ...
    {'XStart',xyz{1};'YStart',xyz{2};'ZStart',xyz{3}; ...
    'Width',w;'Height',h;'PartCoordinateSystem',coord});
end

function box(fid,name,coord,xyz,sz,mat)
api(fid,@hfssBox,{name,[0 0 0],[1 1 1],'mm',mat,false}, ...
    {'XPosition',xyz{1};'YPosition',xyz{2};'ZPosition',xyz{3}; ...
    'XSize',sz{1};'YSize',sz{2};'ZSize',sz{3};'PartCoordinateSystem',coord});
end

function cylinder(fid,name,coord,xyz,r,h)
api(fid,@hfssCylinder,{name,'Z',[0 0 0],1,1,'mm'}, ...
    {'XCenter',xyz{1};'YCenter',xyz{2};'ZCenter',xyz{3}; ...
    'Radius',r;'Height',h;'PartCoordinateSystem',coord});
end

function equation(fid,name,uEnd)
fprintf(fid,['oEditor.CreateEquationSurface Array("NAME:EquationBasedSurfaceParameters", ' ...
    '"XuvFunction:=", "_v*(slot_feed_w/2)*exp(_u*r_flare)", "YuvFunction:=", "0", ' ...
    '"ZuvFunction:=", "_u", "uStart:=", "0", "uEnd:=", "%s", ' ...
    '"vStart:=", "-1", "vEnd:=", "1"), Array("NAME:Attributes", ' ...
    '"Name:=", "%s", "PartCoordinateSystem:=", "Global", "MaterialValue:=", """vacuum""", "SolveInside:=", True)\n'],uEnd,name);
end

function duplicate(fid,old,new,r,o)
hfssSetWCS(fid,'RelativeCS1');
fprintf(fid,'beforeNames = ObjectNames(oEditor)\n'); guard(fid,r,o);
% NumClones=2 gồm gốc và một bản sao; tên thực được lấy từ inventory delta.
fprintf(fid,['oEditor.DuplicateAroundAxis Array("NAME:Selections", "Selections:=", "%s", ' ...
    '"NewPartsModelFlag:=", "Model"), Array("NAME:DuplicateAroundAxisParameters", ' ...
    '"CreateNewObjects:=", True, "WhichAxis:=", "Z", "AngleStr:=", "-90deg", "NumClones:=", "2"), ' ...
    'Array("NAME:Options", "DuplicateAssignments:=", False)\n'],old);
guard(fid,r,o);
renameAdded(fid,new,r,o);
api(fid,@hfssMove,{{new},[0 1 0],'mm'},{'TranslateVectorY','thickness'}); guard(fid,r,o);
end

function copyObject(fid,old,new,r,o)
fprintf(fid,'beforeNames = ObjectNames(oEditor)\n'); guard(fid,r,o);
fprintf(fid,'oEditor.Copy Array("NAME:Selections", "Selections:=", "%s")\n',old); guard(fid,r,o);
fprintf(fid,'oEditor.Paste\n'); guard(fid,r,o);
renameAdded(fid,new,r,o);
end

function renameAdded(fid,new,r,o)
fprintf(fid,'addedName = AddedObjectName(oEditor, beforeNames)\n'); guard(fid,r,o);
% Hàm gốc nhận literal; thay đúng literal sentinel bằng biến runtime.
file=tempname; f=fopen(file,'wt'); cleanup=onCleanup(@() removeTemp(f,file));
hfssRename(f,'__ADDED_OBJECT__',new); fclose(f);
text=strrep(fileread(file),'"__ADDED_OBJECT__"','addedName');
fprintf(fid,'%s',text); guard(fid,r,o);
end

function writeInventoryFunctions(fid)
% SAFEARRAY là giá trị Variant. Không dùng Set; Empty/Null được kiểm tra.
lines = {'Function ObjectNames(ByVal editor)', ...
    'Dim values, groupName, obj, names', 'names = "|"', ...
    'For Each groupName In Array("Solids", "Sheets")', ...
    'values = editor.GetObjectsInGroup(groupName)', ...
    'If IsArray(values) Then', 'For Each obj In values', ...
    'names = names & CStr(obj) & "|"', 'Next', 'ElseIf Not IsEmpty(values) Then', ...
    'If Not IsNull(values) Then', ...
    'If Len(CStr(values)) > 0 Then Err.Raise 516, "Inventory", "Unexpected non-array return"', ...
    'End If', 'End If', 'Next', 'ObjectNames = names', 'End Function', ...
    'Function AddedObjectName(ByVal editor, ByVal before)', ...
    'Dim names, obj, count, found', 'count = 0', 'names = Split(ObjectNames(editor), "|")', ...
    'For Each obj In names', 'If Len(obj) > 0 Then', ...
    'If InStr(before, "|" & obj & "|") = 0 Then', ...
    'count = count + 1', 'found = obj', 'End If', 'End If', 'Next', ...
    'If count <> 1 Then Err.Raise 517, "Clone", "Expected exactly one new object, got " & CStr(count)', ...
    'AddedObjectName = found', 'End Function', ...
    'Function ContainsBody(ByVal editor, ByVal body, ByVal x, ByVal y, ByVal z)', ...
    'Dim bodies, obj', 'ContainsBody = False', ...
    'bodies = editor.GetBodyNamesByPosition(Array("NAME:Parameters", "XPosition:=", x, "YPosition:=", y, "ZPosition:=", z))', ...
    'If IsArray(bodies) Then', 'For Each obj In bodies', ...
    'If CStr(obj) = body Then ContainsBody = True', 'Next', 'End If', 'End Function'};
for k=1:numel(lines), fprintf(fid,'%s\n',lines{k}); end
end

function checkPoint(fid,body,xyz,expected,r,o)
truth='False'; if expected, truth='True'; end
fprintf(fid,['If ContainsBody(oEditor, "%s", "%.17gmm", "%.17gmm", "%.17gmm") <> %s Then ' ...
    'Err.Raise 520, "GeometryPoint", "Unexpected body occupancy: %s"\n'],body,xyz,truth,body);
guard(fid,r,o);
end

function deleteObjects(fid,names)
fprintf(fid,'oEditor.Delete Array("NAME:Selections", "Selections:=", "%s")\n',names);
end

function s=vbString(text)
% Chuỗi VBScript ASCII; ChrW bảo toàn đường dẫn Unicode (UTF-16).
units=double(unicode2native(text,'UTF-16LE'));
units=units(1:2:end)+256*units(2:2:end);
parts={}; buffer='';
for k=1:numel(units)
    n=units(k);
    if n>=32 && n<=126
        if n==34, buffer=[buffer '""']; else, buffer=[buffer char(n)]; end %#ok<AGROW>
    else
        if ~isempty(buffer), parts{end+1}=['"' buffer '"']; buffer=''; end %#ok<AGROW>
        if n>32767, n=n-65536; end
        parts{end+1}=sprintf('ChrW(%d)',n); %#ok<AGROW>
    end
end
if ~isempty(buffer)||isempty(parts), parts{end+1}=['"' buffer '"']; end
s=strjoin(parts,' & ');
end

function text=encodeUnicode(text)
% Chuyển mọi literal có Unicode do hfssSaveProject/hfssExportToFile sinh ra.
[start,stop]=regexp(text,'"(?:""|[^"])*"');
for k=numel(start):-1:1
    literal=text(start(k)+1:stop(k)-1);
    if any(double(literal)>127)
        replacement=vbString(strrep(literal,'""','"'));
        text=[text(1:start(k)-1) replacement text(stop(k)+1:end)];
    end
end
end

function r=runScript(r)
assert(ispc,'Vivaldi:Platform','Thực thi VBScript yêu cầu Windows và HFSS 2021 R2.');
assert(isfile(r.executable),'Vivaldi:Executable','Hãy chọn ansysedt.exe có thật.');
assert(isfile(r.script),'Vivaldi:Script','Không tìm thấy VBScript.');
% hfssExecuteScript dùng cmd.exe: từ chối ký tự shell có thể bị diễn giải.
assert(isempty(regexp([r.executable r.script],'[%!&|<>^"\r\n]','once')), ...
    'Vivaldi:Path','Đường dẫn chạy không được chứa ký tự shell %% ! & | < > ^ hoặc dấu nháy.');
assert(~isfile(r.log),'Vivaldi:Run','Script đã được chạy; hãy tạo lần dựng/mô phỏng mới.');
loadLibrary(fileparts(mfilename('fullpath')));
console=evalc('status = hfssExecuteScript(r.executable,r.script,false,true);');
f=fopen(fullfile(r.folder,'launcher.log'),'wt'); if f>=0, fprintf(f,'%s',console); fclose(f); end
assert(status==0,'Vivaldi:Launch','HFSS trả mã %d; xem launcher.log và %s.',status,r.log);
assert(isfile(r.log),'Vivaldi:Runtime','HFSS chưa ghi log runtime: %s',r.log);
text=readRuntimeLog(r.log);
assert(~isempty(strfind(text,r.expected)) && isempty(strfind(text,'FAILED')), ...
    'Vivaldi:Runtime','HFSS chưa hoàn thành. Xem %s\n%s',r.log,text);
assert(isfile(r.project),'Vivaldi:Runtime','Không tìm thấy AEDT đầu ra.');
r.status=r.expected;
end

function text=readRuntimeLog(file)
fid=fopen(file,'rb'); cleanup=onCleanup(@() fclose(fid)); raw=fread(fid,Inf,'*uint8')';
if numel(raw)>=2 && isequal(raw(1:2),uint8([255 254]))
    text=native2unicode(raw(3:end),'UTF-16LE');
else
    text=native2unicode(raw,'UTF-8');
end
end
