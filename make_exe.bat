rem uru 187
rem pik use 187
start /wait mkexy kkb_report.rb
type kkb_report.exy.icon.txt >> kkb_report.exy

@set upx_exe=C:\Program files_free\Free_UPX\upx.exe
@set /P ver="Input Release Version:"
@set time_tmp=%time: =0%
@set now=%date:/=%_%time_tmp:~0,2%%time_tmp:~3,2%%time_tmp:~6,2%
@set output_dir=bin\kkb_report_v%ver%_%now%

mkdir "%output_dir%"
mkdir "%output_dir%\src"

@for %%i in (
  config_default.yaml
  env.yaml
  kkb_report_readme.txt
  kkb_report_history.txt
  ëSåèïÒçêÉÇÅ[Éh.bat
  dependencies\*
) do @echo %%i & @copy %%i "%output_dir%"

@for %%i in (
  make_exe.bat
  kkb_report.exy.icon.txt
  kkb_report.ico
  kkb_report.rb
) do @echo src\%%i & @copy %%i %output_dir%\src

@echo D | @xcopy /S lib "%output_dir%\src\lib"

start /wait cmd /c exerb kkb_report.exy -o "%output_dir%\kkb_report.exe"
"%upx_exe%" "%output_dir%\kkb_report.exe"
