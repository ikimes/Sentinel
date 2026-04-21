set shell := ["zsh", "-cu"]

root := justfile_directory()
api_project := root + "/Sentinel.Api/Sentinel.Api.csproj"
web_project := root + "/Sentinel.Web/Sentinel.Web.csproj"
apphost_project := root + "/Sentinel.AppHost/Sentinel.AppHost.csproj"
api_tests_project := root + "/Sentinel.Api.Tests/Sentinel.Api.Tests.csproj"
solution := root + "/Sentinel.sln"

default:
    @just --list

build:
    dotnet build {{solution}}

test:
    dotnet test {{api_tests_project}}

api:
    dotnet run --project {{api_project}} --launch-profile http

web:
    DOTNET_WATCH_SUPPRESS_EMOJIS=1 dotnet watch --project {{web_project}} run --launch-profile http

apphost:
    dotnet run --project {{apphost_project}}

dev-ui:
    trap '[[ -n "${api_pid:-}" ]] && kill ${api_pid} 2>/dev/null || true' EXIT; \
    dotnet run --project {{api_project}} --launch-profile http >/tmp/sentinel-api.log 2>&1 & \
    api_pid=$!; \
    echo "Starting Sentinel API on http://localhost:5022 (pid: ${api_pid})"; \
    until curl -sf http://localhost:5022/ >/dev/null; do sleep 1; done; \
    echo "Starting Sentinel Web watch on http://localhost:5026"; \
    DOTNET_WATCH_SUPPRESS_EMOJIS=1 dotnet watch --project {{web_project}} run --launch-profile http
