@echo off
rem This batch file will launch one Storage API host, three Configuration API hosts and the CLM Platform UI.
rem When starting the individual APIs we override the connection string, endpoint and log settings using command line options.
rem If you have already customized appsettings.json the CLI options might collide with your changes.

rem This should point to where you installed or extracted the CLM Platform zip file
set INSTALL_DIR=C:\Program Files\Configit\CLM Platform On-Premise\1.1.0
set TRAEFIK_EXE=traefik_windows-amd64.exe
set TRAEFIK_CONFIG=scenarios\3_lb_round_robin.toml
set TRAEFIK_PORT=80

set CONNECTION_STRING=StorageType=Directory;RootPath=%cd%\data
set LOG_DIR=%cd%\logs

rem Start three Configuration API hosts with individual ports and log files
pushd %INSTALL_DIR%\bin\configurator
FOR /L %%A IN (1,1,3) DO (
  start dotnet Configit.ClmPlatform.Configurator.Host.dll ^
  --Storage:ConnectionString=%CONNECTION_STRING% ^
  --Kestrel:Endpoints:Http:Url="http://localhost:901%%A" ^
  --Serilog:WriteTo:0:Args:path="%LOG_DIR%\configurator%%A.txt" --Serilog:WriteTo:1:Name="Console"
)
popd

rem Start a single Storage API host
pushd %INSTALL_DIR%\bin\storage
start dotnet Configit.ClmPlatform.Storage.Host.dll ^
--Storage:ConnectionString=%CONNECTION_STRING% ^
--Kestrel:Endpoints:Http:Url="http://localhost:9021" ^
--Serilog:WriteTo:0:Args:path="%LOG_DIR%\storage.txt" --Serilog:WriteTo:1:Name="Console"
popd

rem Start Configurator/documentation site.
pushd %INSTALL_DIR%\bin\ui
start dotnet Configit.ClmPlatform.UI.Host.dll ^
--Kestrel:Endpoints:Http:Url="http://localhost:9001" ^
--UI:ConfigurationApiUrl=http://localhost:%TRAEFIK_PORT%/configurator/v1 ^
--UI:StorageApiUrl=http://localhost:%TRAEFIK_PORT%/storage/v1 ^
--Serilog:WriteTo:0:Args:path="%LOG_DIR%\ui.txt" --Serilog:WriteTo:1:Name="Console"
popd

rem Wait for the hosts to start...
timeout /t 5

rem Start Traefik
start %TRAEFIK_EXE% -c %TRAEFIK_CONFIG% --entryPoints='Name:http Address::%TRAEFIK_PORT%'

rem Open Traefik dashboard in the browser
start /max http://localhost:8080

rem Open CLM Platform configurator in the browser
start /max http://localhost:%TRAEFIK_PORT%