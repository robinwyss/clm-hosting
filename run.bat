@echo off
rem This batch file will launch one Storage API host, three Configuration API hosts and the CLM Platform UI.
rem When starting the individual APIs we override the connection string, endpoint and log settings using command line options.
rem If you have already customized appsettings.json the CLI options might collide with your changes.

rem This should point to where you installed or extracted the CLM Platform zip file
set INSTALL_DIR=C:\Program Files\CLM Platform\1.1.0
set TRAEFIK_EXE=traefik.exe
set TRAEFIK_CONFIG=scenarios\3_lb_round_robin.yaml
set TRAEFIK_PORT=80

rem Use local directory for data storage and logs
set CONNECTION_STRING=StorageType=Directory;RootPath=%cd%\data
set LOG_DIR=%cd%\logs

rem Start three Configuration API hosts with individual ports and log files
pushd %INSTALL_DIR%\bin\configurator
FOR /L %%A IN (1,1,3) DO (
  start dotnet Configit.ClmPlatform.Configurator.Host.dll ^
  --Storage:ConnectionString=%CONNECTION_STRING% ^
  --Kestrel:Endpoints:Http:Url="http://localhost:901%%A" ^
  --Logging:File:Path="%LOG_DIR%\configurator%%A-{Date}.txt" --Logging:Console:IncludeScopes=false
)
popd

rem Start a single Storage API host
pushd %INSTALL_DIR%\bin\storage
start dotnet Configit.ClmPlatform.Storage.Host.dll ^
--Storage:ConnectionString=%CONNECTION_STRING% ^
--Kestrel:Endpoints:Http:Url="http://localhost:9021" ^
--Logging:File:Path="%LOG_DIR%\storage-{Date}.txt" --Logging:Console:IncludeScopes=false
popd

rem Start Configurator/documentation site and point the API urls to traefik
pushd %INSTALL_DIR%\bin\ui
start dotnet Configit.ClmPlatform.UI.Host.dll ^
--Kestrel:Endpoints:Http:Url="http://localhost:9001" ^
--UI:UseProxy=false ^
--UI:ConfigurationApiUrl=http://localhost:%TRAEFIK_PORT%/configurator/v1 ^
--UI:StorageApiUrl=http://localhost:%TRAEFIK_PORT%/storage/v1 ^
--Logging:File:Path="%LOG_DIR%\ui-{Date}.txt" --Logging:Console:IncludeScopes=false
popd

rem Wait for the hosts to start...
%SystemRoot%\System32\timeout.exe /t 5

rem Start Traefik
start %TRAEFIK_EXE% --entrypoints.web.address=:%TRAEFIK_PORT% ^
--providers.file.filename=%TRAEFIK_CONFIG% ^
--api.insecure=true --api.dashboard=true --log.level=debug

rem Wait for traefik to start...
%SystemRoot%\System32\timeout.exe /t 5

rem Open Traefik dashboard in the browser
start /max http://localhost:8080

rem Open CLM Platform configurator in the browser
start /max http://localhost:%TRAEFIK_PORT%