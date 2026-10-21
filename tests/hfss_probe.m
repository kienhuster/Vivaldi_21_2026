function job=hfss_probe(exe,outdir)
% Thử riêng NewProject/Rectangle/Save/EquationSurface/SAFEARRAY trên Windows.
% Sinh script nếu exe rỗng; chỉ execute mới tạo AEDT, không chạy solver.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
Vivaldi_HFSS_Builder('library');
if nargin<1,exe='';end
if nargin<2,outdir=tempdir;end
[~,id]=fileparts(tempname(outdir));job.folder=fullfile(outdir,['HFSS_Probe_' id]);
[ok,msg]=mkdir(job.folder);assert(logical(ok),'Vivaldi:IO','%s',msg);
[ok,info]=fileattrib(job.folder);assert(logical(ok),'Vivaldi:IO','Không đọc được thư mục probe.');job.folder=info.Name;
job.script=fullfile(job.folder,'probe.vbs');job.project=fullfile(job.folder,'Probe.aedt');
job.log=fullfile(job.folder,'probe.log');job.done=fullfile(job.folder,'probe.complete');job.debug=fullfile(job.folder,'Probe_DEBUG.aedt');
fid=fopen(job.script,'wt','n','UTF-8');assert(fid>=0);closer=onCleanup(@()fclose(fid));
Vivaldi_HFSS_Builder('runtime',fid,job.log,job.done,job.debug,true);
hfssNewProject(fid);hfssInsertDesign(fid,'Probe','driven modal');
fprintf(fid,'Check "PROBE_01 Project"\n');
hfssRectangle(fid,'ProbeRectangle','Y',[0 0 0],10,10,'mm');
fprintf(fid,'Check "PROBE_02 Rectangle"\n');
hfssSaveProject(fid,fullfile(job.folder,'ProbeRectangle.aedt'),false);
fprintf(fid,'Check "PROBE_03 SaveRectangle"\n');
fprintf(fid,'oEditor.CreateEquationSurface Array("NAME:EquationBasedSurfaceParameters", "XuvFunction:=", "_v*0.25mm*exp(_u/10mm)", "YuvFunction:=", "0", "ZuvFunction:=", "_u", "uStart:=", "0mm", "uEnd:=", "10mm", "vStart:=", "-1", "vEnd:=", "1"), Array("NAME:Attributes", "Name:=", "ProbeEquation", "PartCoordinateSystem:=", "Global", "MaterialName:=", "vacuum")\nCheck "PROBE_04 EquationSurface"\n');
fprintf(fid,'Dim objects\nobjects = oEditor.GetObjectsInGroup("Sheets")\nCheck "PROBE_05 Sheets query"\n');
fprintf(fid,'If Not IsArray(objects) Then Err.Raise 513, "Probe", "Sheets did not return an array"\nCheck "PROBE_05 SAFEARRAY type"\n');
fprintf(fid,'Mark "Sheets array bounds: " & CStr(LBound(objects)) & " to " & CStr(UBound(objects))\nCheck "PROBE_05 SAFEARRAY bounds"\n');
hfssSaveProject(fid,job.project,false);fprintf(fid,'Check "PROBE_06 SaveEquation"\n');
q=Vivaldi_HFSS_Builder('quote',job.done);
fprintf(fid,'Set marker = fso.CreateTextFile(%s, false)\nmarker.WriteLine "COMPLETE"\nmarker.Close\nEnd Sub\nMain\n',q);
clear closer
Vivaldi_HFSS_Builder('ascii',job.script);
if ~isempty(exe),job=Vivaldi_HFSS_Builder('execute',job,exe);end
end
