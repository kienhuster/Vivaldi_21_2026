function report = test_vivaldi()
% Kiểm thử ngoại tuyến: không xác nhận MATLAB GUI hoặc CAD/solver HFSS PASS.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); addpath(fullfile(root,'tests'));
suite={@defaultValues,@decimalGeometry,@invalidGeometry,@materialPersistence, ...
    @invalidMaterials,@libraryResolution,@scriptGeneration,@unicodePaths, ...
    @simulationSettings,@simulationGeneration,@missingRuntime};
report=struct('passed',0,'failed',0,'pending',{{'MATLAB GUI','HFSS CAD/topology/ports','HFSS solver/CSV/plots'}});
for k=1:numel(suite)
    name=func2str(suite{k});
    try
        suite{k}(); report.passed=report.passed+1; fprintf('OFFLINE PASS %s\n',name);
    catch err
        report.failed=report.failed+1; fprintf(2,'OFFLINE FAIL %s: %s\n',name,err.message);
        for j=1:numel(err.stack), fprintf(2,'  %s:%d\n',err.stack(j).name,err.stack(j).line); end
    end
end
fprintf('Offline: %d passed, %d failed. MATLAB GUI/HFSS checks: PENDING.\n',report.passed,report.failed);
assert(report.failed==0,'Vivaldi:TestFailure','Có kiểm thử ngoại tuyến thất bại.');
end

function defaultValues()
[g,p]=Vivaldi_Calculation();
assert(numel(fieldnames(p))==19);
expected=[6.4 46.4 0.0795017124 2.499330861 0.663696710 49.236303290 22 22 2.5 2 2];
actual=[g.slot_t_L g.L_flare g.r_flare g.x_feed g.z_feed g.L_patch g.de_L g.de_W g.h_cabin g.h_cabout g.h_cabmid];
assert(max(abs(actual-expected))<1e-9);
assert(max(abs(g.coax1-[0.450669139 0 -2.836303290]))<1e-9);
assert(max(abs(g.coax2-[11 10.549330861 -2.836303290]))<1e-9);
assert(max(abs(g.cs.RelativeCS1-[10 -1 46.4]))<1e-12);
assert(max(abs(diff(g.bounds)-[22 22 g.L_patch]))<1e-12);
assert(abs(p.slot_feed_w*exp(g.r_flare*g.L_flare)-p.aperture_w)<1e-12);
% Chiều radial của port2 là ảnh quay -90 độ của port1; đầu ngoài -> đầu trong.
assert(max(abs(diff(g.port2Line)-diff(g.port1Line)*g.rotationZ'))<1e-12);
% Mép transition u=0 phải đi qua gốc slot_feed_td.
assert(norm(g.transition(end,:)-[-g.x_feed g.z_feed])<1e-12);
end

function decimalGeometry()
base=Vivaldi_Calculation();
for p={struct('L_flare_1',42.125,'aperture_w',22.75,'them',0.375), ...
       struct('h2',2.775,'cavity_L',4.125,'deg_slot_t',17.25,'thickness',2.25), ...
       struct('slot_feed_w',0.575,'h_de',2.125,'positionx',0.125)}
    [g,q]=Vivaldi_Calculation(p{1});
    assert(abs(g.L_patch-(g.L_flare-g.z_feed+q.h3_slot_feed+q.slot_feed_w+q.h_de))<1e-12);
    assert(norm(g.coax2-((g.coax1-g.cs.RelativeCS1)*g.rotationZ'+g.cs.RelativeCS1+g.translation))<1e-12);
    assert(~isequal(g.parameters,base.parameters));
end
end

function invalidGeometry()
sets={struct('slot_feed_w',0),struct('r_cabin',0.4),struct('them',-6.4), ...
    struct('aperture_w',0.5),struct('L_flare_1',NaN),struct('thickness',0), ...
    struct('deg_slot_t',90),struct('cavity_L',100),struct('positionx',-1), ...
    struct('r_cabout',1),struct('unknown',1)};
for k=1:numel(sets), fails(@() Vivaldi_Calculation(sets{k})); end
end

function materialPersistence()
dir=tempname; mkdir(dir); cleanup=onCleanup(@() rmdir(dir,'s'));
m=struct('name','Nhôm tùy chỉnh','type','metal','permittivity',1, ...
    'permeability',1.02,'conductivity',3.1e7,'lossTangent',0);
materials=Vivaldi_GUI('addMaterial',m,dir); assert(numel(materials)==12);
loaded=Vivaldi_GUI('materials',[],dir); assert(isequal(loaded(end),m));
fails(@() Vivaldi_GUI('addMaterial',m,dir));
m.name='aluminum'; fails(@() Vivaldi_GUI('addMaterial',m,dir));
assert(isequal(Vivaldi_GUI('materials',[],dir),loaded));
end

function invalidMaterials()
dir=tempname; mkdir(dir); cleanup=onCleanup(@() rmdir(dir,'s'));
m=struct('name','bad','type','metal','permittivity',1,'permeability',1,'conductivity',0,'lossTangent',0);
fails(@() Vivaldi_GUI('addMaterial',m,dir)); m.type='dielectric';m.permittivity=Inf;
fails(@() Vivaldi_GUI('addMaterial',m,dir));
end

function libraryResolution()
old=pwd; cleanup=onCleanup(@() cd(old)); cd(tempdir);
paths=Vivaldi_HFSS_Builder('library');
assert(all(cellfun(@(p) ~isempty(strfind(p,fullfile('third_party','hfss-api'))),paths)));
end

function scriptGeneration()
dir=tempname; mkdir(dir); cleanup=onCleanup(@() rmdir(dir,'s'));
a=Vivaldi_HFSS_Builder(struct(),struct('OutputDir',dir));
b=Vivaldi_HFSS_Builder(struct('L_flare_1',42.125),struct('OutputDir',dir));
assert(~strcmp(a.project,b.project)); assert(~isfile(a.project)); assert(~isfile(a.log));
assert(strcmp(a.status,'SCRIPT_GENERATED'));
text=fileread(a.script); assert(all(double(text)<128));
assert(isempty(strfind(text,'Analyze')) && isempty(strfind(text,'OpenProject')));
assert(~isempty(strfind(text,'"BothSides:=", True')));
assert(~isempty(strfind(text,'"PartCoordinateSystem:=", "RelativeCS1"')));
assert(~isempty(strfind(text,'"OriginY:=", "-thickness/2"')));
assert(~isempty(strfind(text,'"Thickness:=", "thickness"')));
assert(~isempty(strfind(text,'"RangeStep:=", "0.25GHz"')));
assert(~isempty(strfind(text,'"Type:=", "Discrete"')));
assert(~isempty(strfind(text,'"RenormImp')) || ~isempty(strfind(text,'"Resistance:=", "50.000000Ohm"')));
assert(~isempty(strfind(text,'"KeepOriginals:=", true')));
assert(~isempty(strfind(text,'If validationResult <> 1 Then Err.Raise')));
assert(~isempty(strfind(text,'ObjectNames(oEditor)')));
assert(~isempty(strfind(text,'AddedObjectName(oEditor, beforeNames)')));
for k=1:18, assert(~isempty(strfind(text,sprintf('BUILD_%02d',k)))); end
% Khác kích thước phải thay biến thật dùng bởi CAD, không chỉ GUI.
assert(~isempty(strfind(fileread(b.script),'42.125 mm')));
% Điện môi bị từ chối trước khi dựng.
m=struct('name','FR4','type','dielectric','permittivity',4.4,'permeability',1,'conductivity',0,'lossTangent',0.02);
fails(@() Vivaldi_HFSS_Builder(struct(),struct('OutputDir',dir,'Material',m)));
end

function unicodePaths()
dir=[tempname '_Kiên_測試']; mkdir(dir); cleanup=onCleanup(@() rmdir(dir,'s'));
r=Vivaldi_HFSS_Builder(struct(),struct('OutputDir',dir));
f=fopen(r.script,'rb'); raw=fread(f,Inf,'*uint8'); fclose(f);
assert(all(raw<128)); text=char(raw'); assert(~isempty(strfind(text,'ChrW(')));
assert(isempty(strfind(text,'?'))); % không thay ký tự đường dẫn bằng dấu hỏi
end

function simulationSettings()
s=Vivaldi_HFSS_Simulation('validate',struct()); assert((s.StopGHz-s.StartGHz)/s.StepGHz+1==61);
sets={struct('StepGHz',0),struct('Power1',0),struct('Power2',-1), ...
    struct('MinimumPasses',1.5),struct('DeltaS',0),struct('StopGHz',5), ...
    struct('PatternGHz',5.1),struct('SaveFields',false)};
for k=1:numel(sets), fails(@() Vivaldi_HFSS_Simulation('validate',sets{k})); end
end

function simulationGeneration()
% Fixture giả lập FILE chỉ để kiểm tra sinh script, KHÔNG phải kết quả HFSS.
dir=tempname; mkdir(dir); cleanup=onCleanup(@() rmdir(dir,'s'));
b=Vivaldi_HFSS_Builder(struct(),struct('OutputDir',dir));
f=fopen(b.project,'wt'); fprintf(f,'TEST FIXTURE - NOT AN AEDT'); fclose(f);
b.status='BUILD_COMPLETE';
r=Vivaldi_HFSS_Simulation('generate',b,struct()); text=fileread(r.script);
assert(~strcmp(r.project,b.project)); assert(isfile(b.project));
assert(~isempty(strfind(text,'oDesign.Solve _')) && ~isempty(strfind(text,'Array("Setup1")')));
assert(~isempty(strfind(text,'S_parameters.csv')));
assert(~isempty(strfind(text,'"Modal Solution Data"')));
assert(~isempty(strfind(text,'"Phi:=", Array("0deg")')));
assert(~isempty(strfind(text,'"Freq:=", Array("5GHz")')));
assert(isempty(strfind(text,'NewProject')));
assert(~isfile(r.log)); fails(@() Vivaldi_HFSS_Simulation('read',r.folder));
end

function missingRuntime()
if ~ispc
    fails(@() Vivaldi_HFSS_Builder('run',struct()),'Vivaldi:Platform');
end
end

function fails(fun,id)
failed=false;
try, fun(); catch err
    failed=true;
    if nargin>1, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); end
end
assert(failed,'Expected failure did not occur.');
end
