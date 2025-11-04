using FileService.Client;
using System.Text;
using ClientFileInfo = FileService.Client.Models.FileInfo;

namespace FileService.Client.Example;

/// <summary>
/// Пример использования клиентской библиотеки FileService
/// </summary>
public class FileServiceExample
{
    private readonly FileServiceClient _fileServiceClient;

    public FileServiceExample(string fileServiceBaseUrl)
    {
        _fileServiceClient = new FileServiceClient(fileServiceBaseUrl);
    }

    public FileServiceExample(FileServiceClient fileServiceClient)
    {
        _fileServiceClient = fileServiceClient;
    }

    /// <summary>
    /// Демонстрирует полный цикл работы с файлами: загрузка, получение информации, скачивание, удаление
    /// </summary>
    public async Task DemonstrateFileOperationsAsync()
    {
        Console.WriteLine("=== Демонстрация работы с FileService ===\n");

        try
        {
            // 1. Загружаем файл
            Console.WriteLine("1. Загружаем файл...");
            var fileContent = "Это тестовый файл для демонстрации работы FileService";
            var fileBytes = Encoding.UTF8.GetBytes(fileContent);
            
            using var fileStream = new MemoryStream(fileBytes);
            var uploadResult = await _fileServiceClient.UploadFileAsync(
                fileStream, 
                "test-file.txt", 
                "text/plain",
                "demo,test,example");

            Console.WriteLine($"   Файл загружен с ID: {uploadResult.Id}");
            Console.WriteLine($"   Имя файла: {uploadResult.OriginalFileName}");
            Console.WriteLine($"   Размер: {uploadResult.Size} байт");
            Console.WriteLine($"   Тип: {uploadResult.ContentType}");
            Console.WriteLine($"   Дата загрузки: {uploadResult.UploadedAt}");
            Console.WriteLine();

            // 2. Получаем информацию о файле
            Console.WriteLine("2. Получаем информацию о файле...");
            var fileInfo = await _fileServiceClient.GetFileInfoAsync(uploadResult.Id);
            if (fileInfo != null)
            {
                Console.WriteLine($"   ID: {fileInfo.Id}");
                Console.WriteLine($"   Имя: {fileInfo.OriginalFileName}");
                Console.WriteLine($"   Размер: {fileInfo.Size} байт");
                Console.WriteLine($"   Тип: {fileInfo.ContentType}");
                Console.WriteLine($"   Дата загрузки: {fileInfo.UploadedAt}");
            }
            Console.WriteLine();

            // 3. Скачиваем файл
            Console.WriteLine("3. Скачиваем файл...");
            using var downloadStream = await _fileServiceClient.GetFileStreamAsync(uploadResult.Id);
            using var reader = new StreamReader(downloadStream);
            var downloadedContent = await reader.ReadToEndAsync();
            
            Console.WriteLine($"   Содержимое файла: {downloadedContent}");
            Console.WriteLine($"   Контент совпадает: {downloadedContent == fileContent}");
            Console.WriteLine();

            // 4. Удаляем файл
            Console.WriteLine("4. Удаляем файл...");
            var deleteResult = await _fileServiceClient.DeleteFileAsync(uploadResult.Id);
            Console.WriteLine($"   Файл удален: {deleteResult}");
            Console.WriteLine();

            // 5. Проверяем, что файл действительно удален
            Console.WriteLine("5. Проверяем удаление...");
            var deletedFileInfo = await _fileServiceClient.GetFileInfoAsync(uploadResult.Id);
            Console.WriteLine($"   Файл найден после удаления: {deletedFileInfo != null}");
            
            Console.WriteLine("\n=== Демонстрация завершена успешно ===");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Ошибка во время демонстрации: {ex.Message}");
            throw;
        }
    }

    /// <summary>
    /// Демонстрирует загрузку файла из реального файла
    /// </summary>
    /// <param name="filePath">Путь к файлу</param>
    public async Task<string> UploadFileFromPathAsync(string filePath)
    {
        if (!File.Exists(filePath))
            throw new System.IO.FileNotFoundException($"Файл не найден: {filePath}");

        var fileName = Path.GetFileName(filePath);
        var contentType = GetContentType(fileName);

        Console.WriteLine($"Загружаем файл: {fileName}");
        
        using var fileStream = File.OpenRead(filePath);
        var result = await _fileServiceClient.UploadFileAsync(fileStream, fileName, contentType);
        
        Console.WriteLine($"Файл загружен с ID: {result.Id}");
        return result.Id;
    }

    /// <summary>
    /// Демонстрирует скачивание файла в указанную папку
    /// </summary>
    /// <param name="fileId">ID файла</param>
    /// <param name="downloadPath">Путь для сохранения</param>
    public async Task DownloadFileToPathAsync(string fileId, string downloadPath)
    {
        // Получаем информацию о файле для получения имени
        var fileInfo = await _fileServiceClient.GetFileInfoAsync(fileId);
        if (fileInfo == null)
        {
            Console.WriteLine($"Файл с ID {fileId} не найден");
            return;
        }

        var fullPath = Path.Combine(downloadPath, fileInfo.OriginalFileName);
        
        Console.WriteLine($"Скачиваем файл {fileInfo.OriginalFileName} в {fullPath}");
        
        using var downloadStream = await _fileServiceClient.GetFileStreamAsync(fileId);
        using var fileStream = File.Create(fullPath);
        await downloadStream.CopyToAsync(fileStream);
        
        Console.WriteLine($"Файл сохранен: {fullPath}");
    }

    private static string GetContentType(string fileName)
    {
        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        return extension switch
        {
            ".txt" => "text/plain",
            ".json" => "application/json",
            ".xml" => "application/xml",
            ".pdf" => "application/pdf",
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png" => "image/png",
            ".gif" => "image/gif",
            ".zip" => "application/zip",
            _ => "application/octet-stream"
        };
    }

    public void Dispose()
    {
        _fileServiceClient?.Dispose();
    }
}