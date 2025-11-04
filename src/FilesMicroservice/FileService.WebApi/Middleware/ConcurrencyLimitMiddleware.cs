using System.Collections.Concurrent;

namespace FileService.WebApi.Middleware;

/// <summary>
/// Middleware для плавного регулирования нагрузки без отказов
/// Использует очередь запросов вместо отклонения - НИКОГДА НЕ ВОЗВРАЩАЕТ ОШИБКИ!
/// </summary>
public class ConcurrencyLimitMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ConcurrencyLimitMiddleware> _logger;
    
    // Семафоры для ограничения одновременных операций (БЕЗ timeout - ждем сколько нужно!)
    private static readonly SemaphoreSlim _uploadSemaphore = new(5, 5); // Консервативно: 5 одновременных загрузок
    private static readonly SemaphoreSlim _downloadSemaphore = new(10, 10); // 10 одновременных скачиваний
    
    // Счетчики для мониторинга
    private static readonly ConcurrentDictionary<string, int> _activeOperations = new();
    private static readonly ConcurrentDictionary<string, int> _queuedOperations = new();

    public ConcurrencyLimitMiddleware(RequestDelegate next, ILogger<ConcurrencyLimitMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value?.ToLower();
        var method = context.Request.Method;

        // Определяем тип операции
        SemaphoreSlim? semaphore = null;
        string operationType = "";

        if (path != null)
        {
            if (path.Contains("/api/files/upload") && method == "POST")
            {
                semaphore = _uploadSemaphore;
                operationType = "upload";
            }
            else if (path.Contains("/api/files/") && method == "GET" && !path.EndsWith("/info"))
            {
                semaphore = _downloadSemaphore;
                operationType = "download";
            }
        }

        if (semaphore != null)
        {
            // НИКОГДА НЕ ОТКАЗЫВАЕМ! Ждем в очереди сколько нужно
            _queuedOperations.AddOrUpdate(operationType, 1, (key, value) => value + 1);
            var queuedCount = _queuedOperations.GetValueOrDefault(operationType, 0);
            
            if (queuedCount > 1)
            {
                _logger.LogInformation("Request queued for {OperationType}. Queue size: {QueueSize}", 
                    operationType, queuedCount);
            }

            // Ждем освобождения слота БЕЗ timeout - гарантированно обработаем запрос
            await semaphore.WaitAsync();
            
            try
            {
                // Уменьшаем счетчик очереди и увеличиваем активные
                _queuedOperations.AddOrUpdate(operationType, 0, (key, value) => Math.Max(0, value - 1));
                _activeOperations.AddOrUpdate(operationType, 1, (key, value) => value + 1);
                
                var activeCount = _activeOperations.GetValueOrDefault(operationType, 0);
                _logger.LogInformation("Processing {OperationType} operation. Active: {ActiveCount}", 
                    operationType, activeCount);

                await _next(context);
            }
            finally
            {
                // Освобождаем семафор и уменьшаем счетчик активных
                semaphore.Release();
                _activeOperations.AddOrUpdate(operationType, 0, (key, value) => Math.Max(0, value - 1));
                
                var activeCount = _activeOperations.GetValueOrDefault(operationType, 0);
                var queuedFinal = _queuedOperations.GetValueOrDefault(operationType, 0);
                _logger.LogInformation("Completed {OperationType}. Active: {ActiveCount}, Queued: {QueuedCount}", 
                    operationType, activeCount, queuedFinal);
            }
        }
        else
        {
            // Для остальных операций просто пропускаем без ограничений
            await _next(context);
        }
    }

    /// <summary>
    /// Получить текущее состояние системы - БЕЗ отказов, только очереди
    /// </summary>
    public static string GetSystemStatus()
    {
        var uploadActive = _activeOperations.GetValueOrDefault("upload", 0);
        var downloadActive = _activeOperations.GetValueOrDefault("download", 0);
        var uploadQueued = _queuedOperations.GetValueOrDefault("upload", 0);
        var downloadQueued = _queuedOperations.GetValueOrDefault("download", 0);
        var uploadAvailable = _uploadSemaphore.CurrentCount;
        var downloadAvailable = _downloadSemaphore.CurrentCount;

        return $"Uploads: {uploadActive}/5 active, {uploadQueued} queued, {uploadAvailable} slots | " +
               $"Downloads: {downloadActive}/10 active, {downloadQueued} queued, {downloadAvailable} slots";
    }
}