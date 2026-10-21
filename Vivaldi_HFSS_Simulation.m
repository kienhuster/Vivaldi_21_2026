function varargout=Vivaldi_HFSS_Simulation(action,varargin)
% Cấu hình và chạy solver riêng; chỉ đọc CSV thực do HFSS xuất.
switch lower(action)
    case 'defaults'
        varargout{1}=struct('start',5,'stop',20,'step',.25,'adaptive',5, ...
            'deltaS',.02,'minPass',5,'maxPass',50,'power',[1 0],'phase',[0 0]);
    case 'validate'
        validate(varargin{1});
    case 'configure'
        configure(varargin{:});
    case 'generate'
        varargout{1}=generate(varargin{:});
    case 'read'
        varargout{1}=readResults(varargin{1});
    case 'plot'
        plotResults(varargin{:});
    otherwise
        error('Vivaldi:Simulation','Thao tác mô phỏng không hợp lệ.');
end
end
function validate(c)
n={'start','stop','step','adaptive','deltaS','minPass','maxPass'};
for k=1:numel(n)
    validateattributes(c.(n{k}),{'numeric'},{'real','finite','positive','scalar'},mfilename,n{k});
end
assert(c.stop>=c.start && c.deltaS<1,'Vivaldi:Sweep','Dải quét hoặc Delta S không hợp lệ.');
assert(c.minPass==fix(c.minPass) && c.maxPass==fix(c.maxPass) && c.maxPass>=c.minPass, ...
    'Vivaldi:Passes','Số lượt adaptive phải nguyên và max >= min.');
count=(c.stop-c.start)/c.step;
assert(abs(count-round(count))<1e-8 && count<100000, ...
    'Vivaldi:Sweep','Bước phải chia hết dải quét; tối đa 100000 điểm.');
validateattributes(c.power,{'numeric'},{'real','finite','nonnegative','size',[1 2]});
validateattributes(c.phase,{'numeric'},{'real','finite','size',[1 2]});
assert(any(c.power>0),'Vivaldi:Sources','Phải có ít nhất một port được cấp công suất.');
end
function configure(fid,c,g)
validate(c);
hfssSetWCS(fid,'Global');
Vivaldi_HFSS_Builder('api',fid,'Global',@hfssAssignLumpedPort,'1','port1',g.line1(1,:),g.line1(2,:),'mm',50,0);
Vivaldi_HFSS_Builder('api',fid,'Global',@hfssAssignLumpedPort,'2','port2',g.line2(1,:),g.line2(2,:),'mm',50,0);
fprintf(fid,'Check "BUILD_14 TwoLumpedPorts"\n');
% Region thật với absolute padding, không nhầm h_box với padding.
fprintf(fid,'oEditor.CreateRegion Array("NAME:RegionParameters", "+XPaddingType:=", "Absolute Offset", "+XPadding:=", "20mm", "-XPaddingType:=", "Absolute Offset", "-XPadding:=", "20mm", "+YPaddingType:=", "Absolute Offset", "+YPadding:=", "20mm", "-YPaddingType:=", "Absolute Offset", "-YPadding:=", "20mm", "+ZPaddingType:=", "Absolute Offset", "+ZPadding:=", "20mm", "-ZPaddingType:=", "Absolute Offset", "-ZPadding:=", "20mm"), Array("NAME:Attributes", "Name:=", "RadiatingSurface", "Flags:=", "Wireframe#", "PartCoordinateSystem:=", "Global", "MaterialName:=", "vacuum", "SolveInside:=", true)\n');
hfssAssignRadiation(fid,'Open1','RadiatingSurface',false);
fprintf(fid,'Check "BUILD_15 RadiationRegion"\n');
Vivaldi_HFSS_Builder('api',fid,'Global',@hfssInsertSolution,'Setup1',c.adaptive,c.deltaS,c.maxPass,c.minPass,1,20);
sweep(fid,c,false); sources(fid,c);
hfssInsertFarFieldSphereSetup(fid,'3D',[0 180 2],[-180 180 2]);
hfssInsertFarFieldSphereSetup(fid,'Elevation',[-180 180 1],[0 90 90]);
% Bước theta dương để tránh bước bằng 0 khi min=max ở API mới.
hfssInsertFarFieldSphereSetup(fid,'Azimuth',[90 90 1],[-180 180 1]);
fprintf(fid,'Check "BUILD_16 SetupSweepSourcesFarFields"\n');
end
function sweep(fid,c,edit)
fprintf(fid,'Set oModule = oDesign.GetModule("AnalysisSetup")\n');
if edit, method='EditFrequencySweep'; else, method='InsertFrequencySweep'; end
if edit
    fprintf(fid,'oModule.%s "Setup1", "Sweep1", ',method);
else
    fprintf(fid,'oModule.%s "Setup1", ',method);
end
fprintf(fid,'Array("NAME:Sweep1", "IsEnabled:=", true, "RangeType:=", "LinearStep", "RangeStart:=", "%.17gGHz", "RangeEnd:=", "%.17gGHz", "RangeStep:=", "%.17gGHz", "Type:=", "Discrete", "SaveFields:=", true, "SaveRadFields:=", true)\n',c.start,c.stop,c.step);
end
function sources(fid,c)
fprintf(fid,'Set oModule = oDesign.GetModule("Solutions")\n');
fprintf(fid,'oModule.EditSources Array(Array("IncludePortPostProcessing:=", false, "SpecifySystemPower:=", false), Array("Name:=", "1:1", "Magnitude:=", "%.17gW", "Phase:=", "%.17gdeg"), Array("Name:=", "2:1", "Magnitude:=", "%.17gW", "Phase:=", "%.17gdeg"))\n',c.power(1),c.phase(1),c.power(2),c.phase(2));
end
function job=generate(build,c)
% Sao lưu nghiệm vào project mới bằng SaveAs(false); không sửa AEDT dựng CAD.
validate(c); Vivaldi_HFSS_Builder('library');
assert(isfile(build.project) && isfile(build.done),'Vivaldi:BuildRequired','Cần dựng thành công trước khi chạy solver.');
[~,id]=fileparts(tempname(build.folder));job.folder=fullfile(build.folder,['Simulation_' id]);
[ok,msg]=mkdir(job.folder);assert(logical(ok),'Vivaldi:IO','%s',msg);
job.project=fullfile(job.folder,['Simulation_' id '.aedt']);job.script=fullfile(job.folder,'solve.vbs');
job.log=fullfile(job.folder,'solve.log');job.done=fullfile(job.folder,'solve.complete');
job.debug=fullfile(job.folder,'Simulation_DEBUG_INCOMPLETE.aedt');job.cfg=c;
job.status='GENERATED';
fid=fopen(job.script,'wt','n','UTF-8');assert(fid>=0,'Vivaldi:IO','Không mở được solve.vbs.');
closer=onCleanup(@()fclose(fid));
Vivaldi_HFSS_Builder('runtime',fid,job.log,job.done,job.debug,true);
hfssOpenProject(fid,build.project);hfssSetDesign(fid,build.design);
fprintf(fid,'Check "SIM_01 OpenBuiltProject"\n');
hfssSaveProject(fid,job.project,false);fprintf(fid,'Check "SIM_02 SaveSeparateProject"\n');
fprintf(fid,'Set oModule = oDesign.GetModule("AnalysisSetup")\n');
fprintf(fid,'oModule.EditSetup "Setup1", Array("NAME:Setup1", "Frequency:=", "%.17gGHz", "MaxDeltaS:=", %.17g, "MinimumPasses:=", %d, "MaximumPasses:=", %d)\n',c.adaptive,c.deltaS,c.minPass,c.maxPass);
sweep(fid,c,true);sources(fid,c);
fprintf(fid,'Check "SIM_03 UpdatedSettings"\nvalidation = oDesign.ValidateDesign()\nCheck "SIM_04 ValidateCall"\nIf validation <> 0 Then Err.Raise 514, "ValidateDesign", "Simulation validation failed"\nCheck "SIM_04 ValidateResult"\n');
fprintf(fid,'Mark "SIM_05 START SolveSetup"\n');
hfssSolveSetup(fid,'Setup1');fprintf(fid,'Check "SIM_05 SolveSetup"\noProject.Save\nCheck "SIM_06 SaveSolvedProject"\n');
% Tạo báo cáo từ nghiệm vừa chạy, không đọc plot cached của project gốc.
report(fid,job,'SParameters',1,{'Freq'},{'Freq','dB(S(1,1))','dB(S(2,2))','dB(S(2,1))','dB(S(1,2))'},'');
report(fid,job,'VSWR',1,{'Freq'},{'Freq','VSWR(1)','VSWR(2)'},'');
report(fid,job,'Impedance',1,{'Freq'},{'Freq','re(Z(1,1))','im(Z(1,1))','re(Z(2,2))','im(Z(2,2))'},'');
% Họ tần số/góc được chọn tường minh, tránh trộn các lát cắt khi vẽ.
farReport(fid,job,'GainFrequency','3D','Freq',{'dB(RealizedGainTotal)'},'0deg','0deg','All',c);
farReport(fid,job,'Elevation','Elevation','Theta',{'dB(RealizedGainTotal)'},'All','0deg','single',c);
farReport(fid,job,'Azimuth','Azimuth','Phi',{'dB(RealizedGainTotal)'},'90deg','All','single',c);
farReport(fid,job,'Pattern3D','3D','Theta',{'dB(RealizedGainTotal)'},'All','All','single',c);
farReport(fid,job,'AxialRatio','3D','Freq',{'dB(AxialRatioValue)'},'0deg','0deg','All',c,true);
fprintf(fid,'oProject.Save\nCheck "SIM_07 SaveReports"\nSet marker = fso.CreateTextFile(%s, false)\nmarker.WriteLine "COMPLETE"\nmarker.Close\nEnd Sub\nMain\n',q(job.done));
clear closer
Vivaldi_HFSS_Builder('ascii',job.script);
save(fullfile(job.folder,'simulation_manifest.mat'),'job');
end
function report(fid,job,name,type,vars,data,context)
% upstream hỗ trợ đầy đủ rectangular report; chỉ đổi tên loại report đời cũ.
Vivaldi_HFSS_Builder('api',fid,'Global',@hfssCreateReport,name,type,1,'Setup1','Sweep1',context,'Sweep',vars,data);
fprintf(fid,'Check "REPORT %s create"\n',name);
hfssExportToFile(fid,name,fullfile(job.folder,name),'csv');
fprintf(fid,'Check "REPORT %s export"\n',name);
end
function farReport(fid,job,name,context,x,ys,theta,phi,freq,c,optional)
if nargin<11,optional=false;end
% API upstream chỉ hỗ trợ All cho mọi family; helper ngắn cho lát cắt cố định.
if strcmp(freq,'single'), freq=sprintf('%.17gGHz',c.start); end
fprintf(fid,'Set oModule = oDesign.GetModule("ReportSetup")\n');
fprintf(fid,'oModule.CreateReport "%s", "Far Fields", "Rectangular Plot", "Setup1 : Sweep1", Array("Context:=", "%s"), Array("Freq:=", Array("%s"), "Theta:=", Array("%s"), "Phi:=", Array("%s")), Array("X Component:=", "%s", "Y Component:=", Array("%s")), Array()\n',name,context,freq,theta,phi,x,strjoin(ys,'","'));
if optional
    fprintf(fid,'If Err.Number <> 0 Then\n  Mark "OPTIONAL_FAILED %s create " & Err.Description\n  Err.Clear\nElse\n',name);
    hfssExportToFile(fid,name,fullfile(job.folder,name),'csv');
    fprintf(fid,'  If Err.Number <> 0 Then\n    Mark "OPTIONAL_FAILED %s export " & Err.Description\n    Err.Clear\n  Else\n    Mark "OPTIONAL_OK %s export"\n  End If\nEnd If\n',name,name);
else
    fprintf(fid,'Check "REPORT %s create"\n',name);
    hfssExportToFile(fid,name,fullfile(job.folder,name),'csv');
    fprintf(fid,'Check "REPORT %s export"\n',name);
end
end
function s=q(value)
s=Vivaldi_HFSS_Builder('quote',value);
end
function result=readResults(folder)
names={'SParameters','VSWR','Impedance','GainFrequency','Elevation','Azimuth','Pattern3D','AxialRatio'};
result=struct;
for k=1:numel(names)
    path=fullfile(folder,[names{k} '.csv']);
    if ~isfile(path), continue; end
    t=readtable(path,'VariableNamingRule','preserve');
    assert(height(t)>0 && width(t)>=2,'Vivaldi:CSV','CSV rỗng/thiếu cột: %s',path);
    for j=1:width(t)
        validateattributes(t{:,j},{'numeric'},{'real'},mfilename,path);
    end
    result.(names{k})=t;
end
assert(~isempty(fieldnames(result)),'Vivaldi:CSV','Không có CSV HFSS khả dụng trong %s.',folder);
end
function plotResults(ax,result,name)
assert(isfield(result,name),'Vivaldi:CSV','Chưa có dữ liệu thật: %s.',name);
t=result.(name); headers=t.Properties.VariableNames;
cla(ax);hold(ax,'on');
if strcmp(name,'Pattern3D')
    it=find(contains(headers,'Theta'),1);ip=find(contains(headers,'Phi'),1);
    ig=find(contains(headers,'RealizedGain'),1);
    assert(~isempty(it) && ~isempty(ip) && ~isempty(ig),'Vivaldi:CSV','Thiếu Theta/Phi/Gain.');
    theta=t{:,it};phi=t{:,ip};r=10.^(t{:,ig}/20);
    % HFSS CSV giữ lưới góc; scatter3 tránh nội suy sai qua seam/pole.
    scatter3(ax,r.*sind(theta).*cosd(phi),r.*sind(theta).*sind(phi),r.*cosd(theta),8,t{:,ig},'filled');
    view(ax,3);axis(ax,'equal');colorbar(ax);xlabel(ax,'X');ylabel(ax,'Y');zlabel(ax,'Z');
else
    if strcmp(name,'Elevation'), xname='Theta'; elseif strcmp(name,'Azimuth'), xname='Phi'; else, xname='Freq'; end
    ix=find(contains(headers,xname),1);assert(~isempty(ix),'Vivaldi:CSV','Thiếu cột trục %s.',xname);
    iy=find(~contains(headers,'Theta') & ~contains(headers,'Phi') & ~contains(headers,'Freq'));
    for j=iy, plot(ax,t{:,ix},t{:,j},'DisplayName',headers{j},'LineWidth',1.3); end
    xlabel(ax,headers{ix},'Interpreter','none');ylabel(ax,'Giá trị theo đơn vị CSV');
    view(ax,2);legend(ax,'show','Interpreter','none','Location','best');
end
title(ax,name,'Interpreter','none');grid(ax,'on');hold(ax,'off');
end
