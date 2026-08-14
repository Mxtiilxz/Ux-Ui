FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY Kairos.sln .
COPY src/Kairos.API/Kairos.API.csproj             src/Kairos.API/
COPY src/Kairos.Application/Kairos.Application.csproj src/Kairos.Application/
COPY src/Kairos.Domain/Kairos.Domain.csproj       src/Kairos.Domain/
COPY src/Kairos.Infrastructure/Kairos.Infrastructure.csproj src/Kairos.Infrastructure/

RUN dotnet restore

COPY . .
RUN dotnet publish src/Kairos.API/Kairos.API.csproj -c Release -o /app/out

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# QuestPDF dibuja los PDF con SkiaSharp, que es código nativo y no viene en la
# imagen de runtime. Sin estas librerías la generación del CV y del reporte
# mensual muere con SIGSEGV la primera vez que alguien las usa. fonts-dejavu-core
# es imprescindible: Skia necesita al menos una fuente instalada para medir texto.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libfontconfig1 \
      libfreetype6 \
      fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/out .

RUN mkdir -p wwwroot/uploads

# El observador de cambios de appsettings.json usa inotify, que en varios hosts
# de contenedores no funciona de forma fiable y tumba el proceso al arrancar
# (exit 139, con el stack en PhysicalFilesWatcher). Dentro de la imagen el
# archivo nunca cambia, así que vigilarlo no aporta nada.
ENV DOTNET_hostBuilder__reloadConfigOnChange=false
# Red de seguridad para cualquier otro observador: sondear en vez de usar inotify.
ENV DOTNET_USE_POLLING_FILE_WATCHER=true

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Kairos.API.dll"]
