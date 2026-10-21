function r = hfss_probe(executable, folder, execute)
% HFSS_PROBE Kiểm tra riêng COM SAFEARRAY từ VBScript chạy bởi HFSS 2021 R2.
% r=hfss_probe('',folder,false) chỉ sinh script. Không được gọi đó là CAD PASS.
% hfss_probe(exe,folder,true) tạo project mới, Rectangle và EquationSurface,
% truy vấn Sheets bằng Variant (không Set), kiểm tra vị trí và SaveAs không ghi đè.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
Vivaldi_HFSS_Builder('library');
if nargin<3, execute=false; end
if nargin<2, folder=fullfile(root,'outputs'); end
if nargin<1, executable=''; end
if ~isfolder(folder), mkdir(folder); end
folder=tempname(folder); mkdir(folder);
r=struct('folder',folder,'executable',executable,'project',fullfile(folder,'Probe.aedt'), ...
    'script',fullfile(folder,'probe.vbs'),'log',fullfile(folder,'probe.log'), ...
    'expected','PROBE_COMPLETE','status','SCRIPT_GENERATED');
fid=fopen(r.script,'wt'); assert(fid>=0,'Cannot create probe script');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'Sub Main()\nOn Error Resume Next\nDim fs, logFile, values, obj, found, bodies\n');
fprintf(fid,'Set fs = CreateObject("Scripting.FileSystemObject")\n');
fprintf(fid,'Set logFile = fs.CreateTextFile("%s", False, True)\n',r.log);
fprintf(fid,'If Err.Number <> 0 Then Exit Sub\n');
hfssNewProject(fid); check(fid,'PROJECT');
hfssInsertDesign(fid,'Probe','driven modal'); check(fid,'DESIGN');
hfssRectangle(fid,'ProbeRectangle','Y',[0 0 0],10,10,'mm'); check(fid,'RECTANGLE');
fprintf(fid,['oEditor.CreateEquationSurface Array("NAME:EquationBasedSurfaceParameters", ' ...
    '"XuvFunction:=", "_v*1mm*exp(_u/10mm)", "YuvFunction:=", "0", ' ...
    '"ZuvFunction:=", "_u", "uStart:=", "0mm", "uEnd:=", "5mm", ' ...
    '"vStart:=", "-1", "vEnd:=", "1"), Array("NAME:Attributes", ' ...
    '"Name:=", "ProbeEquation", "PartCoordinateSystem:=", "Global")\n']); check(fid,'EQUATION');
fprintf(fid,'values = oEditor.GetObjectsInGroup("Sheets")\n'); check(fid,'SHEETS_QUERY');
fprintf(fid,'found = False\nlogFile.WriteLine "Sheets typename: " & TypeName(values)\n');
fprintf(fid,'If IsArray(values) Then\nFor Each obj In values\nlogFile.WriteLine CStr(obj)\nIf CStr(obj) = "ProbeEquation" Then found = True\nNext\nEnd If\n');
fprintf(fid,'If Not found Then Err.Raise 521, "Probe", "Equation missing from Sheets SAFEARRAY"\n'); check(fid,'SHEETS_VALUE');
fprintf(fid,'bodies = oEditor.GetBodyNamesByPosition(Array("NAME:Parameters", "XPosition:=", "5mm", "YPosition:=", "0mm", "ZPosition:=", "5mm"))\n'); check(fid,'POINT_QUERY');
fprintf(fid,'found = False\nIf IsArray(bodies) Then\nFor Each obj In bodies\nIf CStr(obj) = "ProbeRectangle" Then found = True\nNext\nEnd If\n');
fprintf(fid,'If Not found Then Err.Raise 522, "Probe", "Rectangle point query failed"\n'); check(fid,'POINT_RESULT');
hfssSaveProject(fid,r.project,false); check(fid,'SAVE');
fprintf(fid,'logFile.WriteLine "PROBE_COMPLETE"\nlogFile.Close\nEnd Sub\nMain\n');
clear cleanup;
text=Vivaldi_HFSS_Builder('encode',fileread(r.script));
fid=fopen(r.script,'wb'); fwrite(fid,text,'char'); fclose(fid);
if execute, r=Vivaldi_HFSS_Builder('run',r); end
end

function check(fid,name)
fprintf(fid,['If Err.Number <> 0 Then\nlogFile.WriteLine "%s FAILED " & ' ...
    'CStr(Err.Number) & " " & Err.Description\nlogFile.Close\nExit Sub\nEnd If\n'],name);
fprintf(fid,'logFile.WriteLine "%s API_COMPLETED"\n',name);
end
