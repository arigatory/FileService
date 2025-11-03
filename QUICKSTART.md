# Быстрый старт FileService

## 1. Запуск сервиса

```bash
cd src/FileService.WebApi
dotnet run
```

Сервис будет доступен по адресу: `https://localhost:7000`
Swagger UI: `https://localhost:7000/swagger`

## 2. Настройка S3

Отредактируйте `appsettings.json`:

```json
{
  "S3Configurations": [
    {
      "ProviderName": "Primary-S3",
      "BucketName": "your-bucket-name",
      "AccessKey": "your-access-key",
      "SecretKey": "your-secret-key",
      "Region": "us-east-1"
    }
  ]
}
```

## 3. Тестирование с примером

```bash
cd examples/FileService.ExampleClient
dotnet run
```

## 4. Использование REST API

### Загрузка файла
```bash
curl -X POST "https://localhost:7000/api/files/upload" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@your-file.txt" \
  -F "tags=demo,test"
```

### Скачивание файла
```bash
curl -X GET "https://localhost:7000/api/files/{file-id}" \
  --output downloaded-file.txt
```

### Удаление файла
```bash
curl -X DELETE "https://localhost:7000/api/files/{file-id}"
```

## 5. Использование клиентской библиотеки

```csharp
using FileService.Client;

var client = new FileServiceClient("https://localhost:7000");

// Загружаем файл
using var fileStream = File.OpenRead("test.txt");
var result = await client.UploadFileAsync(fileStream, "test.txt", "text/plain");
Console.WriteLine($"File ID: {result.Id}");

// Скачиваем файл  
using var downloadStream = await client.GetFileStreamAsync(result.Id);
using var outputFile = File.Create("downloaded.txt");
await downloadStream.CopyToAsync(outputFile);

// Удаляем файл
await client.DeleteFileAsync(result.Id);
```