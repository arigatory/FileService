FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Копируем файлы проектов
COPY ["src/FilesMicroservice/FileService.WebApi/FileService.WebApi.csproj", "src/FilesMicroservice/FileService.WebApi/"]
COPY ["src/FilesMicroservice/FileService.Application/FileService.Application.csproj", "src/FilesMicroservice/FileService.Application/"]
COPY ["src/FilesMicroservice/FileService.Infrastructure/FileService.Infrastructure.csproj", "src/FilesMicroservice/FileService.Infrastructure/"]
COPY ["src/FilesMicroservice/FileService.Domain/FileService.Domain.csproj", "src/FilesMicroservice/FileService.Domain/"]

# Восстанавливаем зависимости
RUN dotnet restore "src/FilesMicroservice/FileService.WebApi/FileService.WebApi.csproj"

# Копируем весь исходный код
COPY . .

# Строим приложение
WORKDIR "/src/src/FilesMicroservice/FileService.WebApi"
RUN dotnet build "FileService.WebApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "FileService.WebApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "FileService.WebApi.dll"]