% Smoke chạy được trong MATLAB/Octave; không xác nhận CAD hoặc GUI.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
g=Vivaldi_Calculation();checks=0;has=@(text,pattern)~isempty(strfind(text,pattern));
assert(numel(fieldnames(g.parameters))==19);checks=checks+1;
assert(norm([g.r_flare g.x_feed g.z_feed g.L_patch]-[.0795017124 2.499330861 .663696710 49.236303290],Inf)<1e-9);checks=checks+1;
assert(norm(g.transition(end,:)-[-g.x_feed g.z_feed],Inf)<1e-12);checks=checks+1;
assert(norm(g.port2-[11 10.549330861 -2.836303290],Inf)<1e-9);checks=checks+1;
assert(abs(g.slot_feed_w*exp(g.r_flare*g.L_flare)-g.aperture_w)<1e-12);checks=checks+1;
for variation=1:3
 p=g.parameters;p.L_flare_1=40+variation*1.125;p.them=variation*.125;p.aperture_w=20+variation*.75;
 d=Vivaldi_Calculation(p);
 assert(abs(d.slot_feed_w*exp(d.r_flare*d.L_flare)-p.aperture_w)<1e-12);
 assert(norm(d.port2-(d.secondRotation*d.port1'+d.secondTranslation)',Inf)<1e-12);checks=checks+2;
end
invalid={struct('r_cabin',.4),struct('them',-6.4),struct('aperture_w',.4),struct('positionx',100)};
for k=1:numel(invalid)
 caught=false;try,Vivaldi_Calculation(invalid{k});catch ex,caught=strcmp(ex.identifier,'Vivaldi:Geometry');end
 assert(caught);checks=checks+1;
end
cfg=Vivaldi_HFSS_Simulation('defaults');assert((cfg.stop-cfg.start)/cfg.step+1==61);checks=checks+1;
db=Vivaldi_GUI('materials');assert(numel(db)==11 && db(1).conductivity==3.8e7);checks=checks+1;
out=tempname;mkdir(out);cleaner=onCleanup(@()rmdir(out,'s'));
a=Vivaldi_HFSS_Builder('generate',g.parameters,db(1),out,cfg,true);
b=Vivaldi_HFSS_Builder('generate',g.parameters,db(1),fullfile(out,'Tiếng Việt'),cfg,true);
assert(~strcmp(a.project,b.project) && ~isfile(a.project) && ~isfile(a.done));checks=checks+1;
s=fileread(a.script);su=fileread(b.script);
assert(all(double(s)<128) && all(double(su)<128) && has(su,'ChrW('));checks=checks+1;
assert(~has(s,'oDesign.Solve') && ~has(s,'GetObjectsInGroup'));checks=checks+1;
assert(has(s,'If Not Check("BUILD_18 SaveAEDT") Then Exit Sub'));checks=checks+1;
assert(has(s,'"BothSides:=", true') && has(s,'"Type:=", "Discrete"'));checks=checks+1;
assert(has(s,sprintf('%.17gmm',-g.L_patch)));checks=checks+1;
assert(has(s,'"PartCoordinateSystem:=", "slot_feed_td"'));checks=checks+1;
assert(has(s,'"PartCoordinateSystem:=", "patch_td"'));checks=checks+1;
caught=false;try,Vivaldi_HFSS_Builder('generate',g.parameters,db(4),out,cfg,true);catch ex,caught=strcmp(ex.identifier,'Vivaldi:Material');end
assert(caught);checks=checks+1;
% Chỉ tạo tệp fixture trống để thử sinh script mô phỏng, KHÔNG coi là CAD thật.
f=fopen(a.project,'wt');fprintf(f,'TEST FIXTURE ONLY');fclose(f);
f=fopen(a.done,'wt');fprintf(f,'TEST FIXTURE ONLY');fclose(f);
runjob=Vivaldi_HFSS_Simulation('generate',a,cfg);ss=fileread(runjob.script);
assert(has(ss,'oDesign.Solve') && has(ss,'"SaveRadFields:=", true'));checks=checks+1;
assert(~has(ss,'Set oHfssApp  = CreateObject("AnsoftHfss.'));checks=checks+1;
assert(~isfile(runjob.project) && ~isfile(runjob.done));checks=checks+1;
assert(has(ss,'OPTIONAL_FAILED AxialRatio'));checks=checks+1;
crlf=fullfile(out,'crlf.vbs');f=fopen(crlf,'wb');fwrite(f,uint8(sprintf('Sub Main()\r\nCheck "probe"\r\nEnd Sub\r\nMain\r\n')));fclose(f);
Vivaldi_HFSS_Builder('ascii',crlf);assert(has(fileread(crlf),'If Not Check("probe") Then Exit Sub'));checks=checks+1;
fprintf('PASS: %d core smoke assertions (no MATLAB GUI / HFSS execution)\n',checks);

clear cleaner
