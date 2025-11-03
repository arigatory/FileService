using FileService.Client;
using System.Text;

namespace FileService.ExampleUsage;

/// <summary>
/// Расширенный пример использования FileService Client
/// </summary>
public class AdvancedFileServiceExample
{
    private readonly FileServiceClient _client;

    public AdvancedFileServiceExample(string baseUrl)
    {
        _client = new FileServiceClient(baseUrl);
    }

    /// <summary>
    /// Демонстрирует массовую загрузку файлов
    /// </summary>
    public async Task BulkUploadExampleAsync()
    {
        Console.WriteLine("=== Пример массовой загрузки файлов ===\n");

        var filesToUpload = new[]
        {
            ("document1.txt", "text/plain", "Это первый документ"),
            ("document2.json", "application/json", "{\"message\": \"Hello World\"}"),
            ("document3.xml", "application/xml", "<root><message>XML content</message></root>")
        };

        var uploadedFiles = new List<string>();

        foreach (var (fileName, contentType, content) in filesToUpload)
        {
            try
            {
                using var stream = new MemoryStream(Encoding.UTF8.GetBytes(content));
                var result = await _client.UploadFileAsync(stream, fileName, contentType, $"bulk-upload,{DateTime.Now:yyyy-MM-dd}");
                
                Console.WriteLine($"✓ Uploaded {fileName} with ID: {result.Id}");
                uploadedFiles.Add(result.Id);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ Failed to upload {fileName}: {ex.Message}");
            }
        }

        Console.WriteLine($"\nЗагружено файлов: {uploadedFiles.Count}\n");

        // Проверяем загруженные файлы
        Console.WriteLine("=== Проверка загруженных файлов ===");
        foreach (var fileId in uploadedFiles)
        {
            try
            {
                var fileInfo = await _client.GetFileInfoAsync(fileId);
                if (fileInfo != null)
                {
                    Console.WriteLine($"File: {fileInfo.OriginalFileName}, Size: {fileInfo.Size} bytes, Type: {fileInfo.ContentType}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ Error getting info for {fileId}: {ex.Message}");
            }
        }

        // Очищаем загруженные файлы
        Console.WriteLine("\n=== Очистка файлов ===");
        foreach (var fileId in uploadedFiles)
        {
            try
            {
                var deleted = await _client.DeleteFileAsync(fileId);
                Console.WriteLine($"{(deleted ? "✓" : "✗")} File {fileId} deletion: {deleted}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ Error deleting {fileId}: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Демонстрирует работу с большими файлами
    /// </summary>
    public async Task LargeFileExampleAsync()
    {
        Console.WriteLine("\n=== Пример работы с большим файлом ===\n");

        // Создаем большой файл в памяти (1MB)
        var largeContent = new string('A', 1024 * 1024); // 1MB of 'A' characters
        var largeFileBytes = Encoding.UTF8.GetBytes(largeContent);

        Console.WriteLine($"Создан файл размером: {largeFileBytes.Length:N0} байт");

        try
        {
            using var stream = new MemoryStream(largeFileBytes);
            
            Console.WriteLine("Загружаем большой файл...");
            var uploadResult = await _client.UploadFileAsync(stream, "large-file.txt", "text/plain", "large-file,test");
            
            Console.WriteLine($"✓ Большой файл загружен с ID: {uploadResult.Id}");
            Console.WriteLine($"  Размер: {uploadResult.Size:N0} байт");

            // Проверяем информацию
            var fileInfo = await _client.GetFileInfoAsync(uploadResult.Id);
            Console.WriteLine($"  Проверка размера: {fileInfo?.Size:N0} байт");

            // Скачиваем и проверяем
            Console.WriteLine("Скачиваем большой файл...");
            using var downloadStream = await _client.GetFileStreamAsync(uploadResult.Id);
            using var memoryStream = new MemoryStream();
            await downloadStream.CopyToAsync(memoryStream);
            
            var downloadedSize = memoryStream.Length;
            Console.WriteLine($"✓ Скачано: {downloadedSize:N0} байт");
            Console.WriteLine($"  Размеры совпадают: {downloadedSize == largeFileBytes.Length}");

            // Удаляем файл
            var deleted = await _client.DeleteFileAsync(uploadResult.Id);
            Console.WriteLine($"✓ Файл удален: {deleted}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Ошибка при работе с большим файлом: {ex.Message}");
        }
    }

    /// <summary>
    /// Демонстрирует обработку ошибок
    /// </summary>
    public async Task ErrorHandlingExampleAsync()
    {
        Console.WriteLine("\n=== Пример обработки ошибок ===\n");

        // Попытка скачать несуществующий файл
        try
        {
            Console.WriteLine("Попытка скачать несуществующий файл...");
            using var stream = await _client.GetFileStreamAsync("non-existent-id");
            Console.WriteLine("✗ Не должно было выполниться!");
        }
        catch (FileNotFoundException)
        {
            Console.WriteLine("✓ Корректно обработана ошибка: файл не найден");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Неожиданная ошибка: {ex.Message}");
        }

        // Попытка получить информацию о несуществующем файле
        try
        {
            Console.WriteLine("Попытка получить информацию о несуществующем файле...");
            var fileInfo = await _client.GetFileInfoAsync("non-existent-id");
            if (fileInfo == null)
            {
                Console.WriteLine("✓ Корректно возвращен null для несуществующего файла");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Неожиданная ошибка: {ex.Message}");
        }

        // Попытка удалить несуществующий файл
        try
        {
            Console.WriteLine("Попытка удалить несуществующий файл...");
            var deleted = await _client.DeleteFileAsync("non-existent-id");
            Console.WriteLine($"✓ Результат удаления несуществующего файла: {deleted}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"✗ Неожиданная ошибка: {ex.Message}");
        }
    }

    public void Dispose()
    {
        _client?.Dispose();
    }
}