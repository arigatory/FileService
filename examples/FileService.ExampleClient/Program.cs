using FileService.Client.Example;

Console.WriteLine("=== FileService Client Example ===\n");

// URL вашего FileService API
var fileServiceUrl = args.Length > 0 ? args[0] : "http://localhost:5000";

Console.WriteLine($"Подключаемся к FileService: {fileServiceUrl}");

try
{
    var example = new FileServiceExample(fileServiceUrl);
    
    Console.WriteLine("Запускаем демонстрацию работы с файловым сервисом...\n");
    
    // Запускаем базовую демонстрацию
    await example.DemonstrateFileOperationsAsync();
    
    example.Dispose();
    
    Console.WriteLine("\n=== Базовые тесты завершены успешно! ===");
}
catch (HttpRequestException ex)
{
    Console.WriteLine($"Ошибка подключения к серверу: {ex.Message}");
    Console.WriteLine($"Убедитесь, что FileService API запущен и доступен по адресу: {fileServiceUrl}");
    Console.WriteLine("\nДля Docker: docker-compose up -d");
    Console.WriteLine("Для локальной разработки: cd src/FileService.WebApi && dotnet run");
}
catch (Exception ex)
{
    Console.WriteLine($"Произошла ошибка: {ex.Message}");
    if (ex.InnerException != null)
    {
        Console.WriteLine($"Внутренняя ошибка: {ex.InnerException.Message}");
    }
}

Console.WriteLine("\nНажмите любую клавишу для выхода...");
Console.ReadKey();
