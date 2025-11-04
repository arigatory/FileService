using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Amazon.S3;
using FileService.Domain.Interfaces;
using FileService.Infrastructure.Storage;
using FileService.Infrastructure.Repositories;

namespace FileService.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        // Регистрируем S3 клиенты для разных бакетов
        var s3Configurations = configuration.GetSection("S3Configurations").Get<List<S3Configuration>>() ?? new List<S3Configuration>();
        
        var storageProviders = new List<IStorageProvider>();

        foreach (var s3Config in s3Configurations)
        {
            var s3ClientConfig = new AmazonS3Config
            {
                RegionEndpoint = Amazon.RegionEndpoint.GetBySystemName(s3Config.Region),
                UseHttp = true, // Для MinIO обычно используется HTTP
                // УБИРАЕМ ВСЕ ТАЙМАУТЫ ДЛЯ БОЛЬШИХ ФАЙЛОВ!
                Timeout = TimeSpan.FromDays(1), // 24 часа на операцию
                // ReadWriteTimeout устарело - используем CancellationToken
                MaxConnectionsPerServer = 50 // Больше подключений для параллельности
            };

            // Если указан ServiceUrl (для MinIO), используем его
            if (!string.IsNullOrWhiteSpace(s3Config.ServiceUrl))
            {
                s3ClientConfig.ServiceURL = s3Config.ServiceUrl;
                s3ClientConfig.ForcePathStyle = true; // Требуется для MinIO
            }

            var s3Client = new AmazonS3Client(s3Config.AccessKey, s3Config.SecretKey, s3ClientConfig);
            var storageProvider = new S3StorageProvider(s3Client, s3Config.BucketName, s3Config.ProviderName);
            storageProviders.Add(storageProvider);
        }

        // Если нет конфигурации, создаем дефолтный провайдер для демонстрации
        if (!storageProviders.Any())
        {
            var defaultS3Config = new AmazonS3Config
            {
                UseHttp = true,
                Timeout = TimeSpan.FromDays(1), // 24 часа на операцию
                // ReadWriteTimeout устарело - используем CancellationToken
                MaxConnectionsPerServer = 50
            };
            var defaultS3Client = new AmazonS3Client(defaultS3Config);
            var defaultProvider = new S3StorageProvider(defaultS3Client, "default-bucket", "default-s3");
            storageProviders.Add(defaultProvider);
        }

        // Регистрируем селектор хранилищ
        services.AddSingleton<IStorageSelector>(new RoundRobinStorageSelector(storageProviders));

        // Регистрируем репозиторий
        services.AddSingleton<IFileRepository, InMemoryFileRepository>();

        return services;
    }
}

public class S3Configuration
{
    public string ProviderName { get; set; } = null!;
    public string BucketName { get; set; } = null!;
    public string AccessKey { get; set; } = null!;
    public string SecretKey { get; set; } = null!;
    public string Region { get; set; } = "us-east-1";
    public string? ServiceUrl { get; set; } // Для MinIO или других S3-совместимых сервисов
}