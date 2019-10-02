#!/bin/bash
# This script file will launch one Storage API host, three Configuration API hosts and the CLM Platform UI.
# When starting the individual APIs we override the connection string, endpoint and log settings using command line options.
# If you have already customized appsettings.json the CLI options might collide with your changes.

# This should point to where you extracted the CLM Platform zip file
INSTALL_DIR="./clm-platform-1.1.0"
TRAEFIK_EXE="./traefik_linux-amd64"
TRAEFIK_CONFIG="./scenarios/3_lb_round_robin.toml"
TRAEFIK_PORT=80

CONNECTION_STRING="StorageType=Directory;RootPath=${PWD}/data"
LOG_DIR="${PWD}/logs"

trap "exit" INT TERM ERR
trap "kill 0" EXIT

# Start three Configuration API hosts with individual ports and log files
for i in {1..3}
do
  pushd "${INSTALL_DIR}/bin/configurator"
  dotnet Configit.ClmPlatform.Configurator.Host.dll \
  --Storage:ConnectionString=$CONNECTION_STRING \
  --Kestrel:Endpoints:Http:Url="http://localhost:901${i}" \
  --Logging:File:Path="${LOG_DIR}/configurator${i}-{Date}.txt" &
  popd
done

# Start a single Storage API host
pushd "${INSTALL_DIR}/bin/storage"
dotnet Configit.ClmPlatform.Storage.Host.dll \
--Storage:ConnectionString=$CONNECTION_STRING \
--Kestrel:Endpoints:Http:Url="http://localhost:9021" \
--Logging:File:Path="${LOG_DIR}/storage-{Date}.txt" &
popd

# Start Configurator/documentation site.
pushd "${INSTALL_DIR}/bin/ui"
dotnet Configit.ClmPlatform.UI.Host.dll \
--Kestrel:Endpoints:Http:Url="http://localhost:9001" \
--UI:ConfigurationApiUrl="http://localhost:${TRAEFIK_PORT}/configurator/v1" \
--UI:StorageApiUrl="http://localhost:${TRAEFIK_PORT}/storage/v1" \
--Logging:File:Path="${LOG_DIR}/ui-{Date}.txt" &
popd

# Wait for the hosts to start
sleep 5s

# Start Traefik
$TRAEFIK_EXE -c $TRAEFIK_CONFIG --entryPoints="Name:http Address::${TRAEFIK_PORT}" &

wait