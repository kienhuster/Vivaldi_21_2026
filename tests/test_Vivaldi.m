function tests=test_Vivaldi
% Chạy trên MATLAB: results=runtests('tests'); assertSuccess(results).
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.root);
t.TestData.out=tempname;mkdir(t.TestData.out);
end
function teardownOnce(t)
if isfolder(t.TestData.out),rmdir(t.TestData.out,'s');end
end
function testDefaultNumbers(t)
g=Vivaldi_Calculation();
verifyEqual(t,numel(fieldnames(g.parameters)),19);
verifyEqual(t,[g.slot_t_L g.L_flare g.de_L g.de_W g.h_cabin g.h_cabout g.h_cabmid],[6.4 46.4 22 22 2.5 2 2],'AbsTol',1e-12);
verifyEqual(t,[g.r_flare g.x_feed g.z_feed g.L_patch],[.0795017124 2.499330861 .663696710 49.236303290],'AbsTol',1e-9);
verifyEqual(t,g.slot_feed_w*exp(g.r_flare*g.L_flare),g.aperture_w,'AbsTol',1e-12);
verifyEqual(t,g.bounds,[-10 -1 -2.836303290;12 21 46.4],'AbsTol',1e-9);
end
function testTransform(t)
g=Vivaldi_Calculation();
verifyEqual(t,g.port1,[.450669139 0 -2.836303290],'AbsTol',1e-9);
verifyEqual(t,g.port2,[11 10.549330861 -2.836303290],'AbsTol',1e-9);
verifyEqual(t,g.secondRotation*g.secondRotation',eye(3),'AbsTol',1e-15);
verifyEqual(t,dot(g.secondRotation*[1;0;0],[1;0;0]),0);
verifyEqual(t,norm(diff(g.line1)),g.r_cabmid-g.r_cabin,'AbsTol',1e-14);
verifyEqual(t,norm(diff(g.line2)),norm(diff(g.line1)),'AbsTol',1e-14);
end
function testDecimalParameters(t)
g=Vivaldi_Calculation(struct('L_flare_1',43.125,'aperture_w',22.75,'them',.375,'deg_slot_t',19.25,'thickness',2.4));
verifyEqual(t,g.L_flare,49.9,'AbsTol',1e-12);
verifyEqual(t,g.de_L,25.15,'AbsTol',1e-12);
verifyEqual(t,g.slot_feed_w*exp(g.r_flare*g.L_flare),22.75,'AbsTol',1e-12);
d=Vivaldi_Calculation();verifyNotEqual(t,g.port1,d.port1);
verifyEqual(t,g.port2,(g.secondRotation*g.port1'+g.secondTranslation)','AbsTol',1e-12);
end
function testInvalidGeometry(t)
verifyError(t,@()Vivaldi_Calculation(struct('r_cabin',.4)),'Vivaldi:Geometry');
verifyError(t,@()Vivaldi_Calculation(struct('aperture_w',.4)),'Vivaldi:Geometry');
verifyError(t,@()Vivaldi_Calculation(struct('them',-6.4)),'Vivaldi:Geometry');
verifyError(t,@()Vivaldi_Calculation(struct('positionx',100)),'Vivaldi:Geometry');
verifyError(t,@()Vivaldi_Calculation(struct('deg_slot_t',90)),'Vivaldi:Geometry');
verifyError(t,@()Vivaldi_Calculation(struct('unknown',1)),'Vivaldi:Input');
end
function testMaterialSearchAndValidation(t)
db=Vivaldi_GUI('materials');
a=Vivaldi_GUI('filtermaterials',db,'ALUM');verifyEqual(t,{a.name},{'Aluminum'});
a=Vivaldi_GUI('filtermaterials',db,'');verifyEqual(t,numel(a),11);
a=db(1);a.conductivity=NaN;verifyError(t,@()Vivaldi_GUI('validatematerial',a),'MATLAB:expectedFinite');
a=db(1);a.name='';verifyError(t,@()Vivaldi_GUI('validatematerial',a),'Vivaldi:Material');
end
function testMaterialPersistence(t)
db=Vivaldi_GUI('materials');m=db(1);m.name='Custom validated metal';m.conductivity=1.23e7;
p=fullfile(t.TestData.out,'custom_materials.mat');Vivaldi_GUI('savematerials',m,p);
verifyEqual(t,Vivaldi_GUI('loadmaterials',p),m);
verifyError(t,@()Vivaldi_GUI('savematerials',[m m],p),'Vivaldi:Material');
end
function testSweep(t)
c=Vivaldi_HFSS_Simulation('defaults');verifyEqual(t,(c.stop-c.start)/c.step+1,61);
c.power=[0 0];verifyError(t,@()Vivaldi_HFSS_Simulation('validate',c),'Vivaldi:Sources');
c=Vivaldi_HFSS_Simulation('defaults');c.step=.7;verifyError(t,@()Vivaldi_HFSS_Simulation('validate',c),'Vivaldi:Sweep');
end
function testScriptGenerationAndNoOverwrite(t)
db=Vivaldi_GUI('materials');a=Vivaldi_HFSS_Builder('generate',struct,db(1),t.TestData.out);
b=Vivaldi_HFSS_Builder('generate',struct,db(1),t.TestData.out);
verifyNotEqual(t,a.project,b.project);verifyFalse(t,isfile(a.project));verifyFalse(t,isfile(a.done));
s=fileread(a.script);verifyTrue(t,all(double(s)<128));
verifyTrue(t,contains(s,'Ansoft.ElectronicsDesktop.2021.2'));
verifyFalse(t,contains(s,'oDesign.Solve'));verifyFalse(t,contains(s,'GetObjectsInGroup'));
verifyTrue(t,contains(s,'"BothSides:=", true'));
verifyTrue(t,contains(s,'"PartCoordinateSystem:=", "slot_feed_td"'));
verifyTrue(t,contains(s,'If Not Check("BUILD_18 SaveAEDT") Then Exit Sub'));
verifyTrue(t,contains(s,'"NumClones:=", "2"'));
verifyTrue(t,contains(s,'"KeepOriginals:=", true'));
verifyTrue(t,contains(s,'"Type:=", "Discrete"'));
verifyTrue(t,contains(s,'"Magnitude:=", "0W"'));
verifyTrue(t,contains(s,'ValidateDesign()'));
end
function testPrecisionAndUnicode(t)
db=Vivaldi_GUI('materials');g=Vivaldi_Calculation(struct('L_flare_1',43.125,'them',.375));
a=Vivaldi_HFSS_Builder('generate',g.parameters,db(1),fullfile(t.TestData.out,'Tiếng Việt'));
s=fileread(a.script);verifyTrue(t,all(double(s)<128));verifyTrue(t,contains(s,'ChrW('));
verifyTrue(t,contains(s,sprintf('%.17gmm',-g.L_patch)));
end
function testDielectricRejectedByBuilder(t)
db=Vivaldi_GUI('materials');verifyError(t,@()Vivaldi_HFSS_Builder('generate',struct,db(4),t.TestData.out),'Vivaldi:Material');
end
function testLibraryResolution(t)
Vivaldi_HFSS_Builder('library');verifyTrue(t,startsWith(which('hfssRectangle'),fullfile(t.TestData.root,'third_party','hfss-api')));
end
function testCsvImport(t)
p=fullfile(t.TestData.out,'csv');mkdir(p);
f=fopen(fullfile(p,'SParameters.csv'),'wt');fprintf(f,'Freq [GHz],dB(S(1:1)) []\n5,-10\n6,-12\n');fclose(f);
r=Vivaldi_HFSS_Simulation('read',p);verifyEqual(t,r.SParameters{:,2},[-10;-12]);
end

function testGuiSmoke(t)
assumeTrue(t,usejava('desktop'),'Cần MATLAB desktop để thử uifigure/preview.');
f=Vivaldi_GUI();cleanup=onCleanup(@()delete(f));
verifyTrue(t,isvalid(f));verifyEqual(t,numel(findall(f,'Type','uitab')),5);
end
