FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Копируем файлы проектов
COPY ["src/FileService.WebApi/FileService.WebApi.csproj", "src/FileService.WebApi/"]
COPY ["src/FileService.Application/FileService.Application.csproj", "src/FileService.Application/"]
COPY ["src/FileService.Infrastructure/FileService.Infrastructure.csproj", "src/FileService.Infrastructure/"]
COPY ["src/FileService.Domain/FileService.Domain.csproj", "src/FileService.Domain/"]

# Восстанавливаем зависимости
RUN dotnet restore "src/FileService.WebApi/FileService.WebApi.csproj"

# Копируем весь исходный код
COPY . .

# Строим приложение
WORKDIR "/src/src/FileService.WebApi"
RUN dotnet build "FileService.WebApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "FileService.WebApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "FileService.WebApi.dll"]