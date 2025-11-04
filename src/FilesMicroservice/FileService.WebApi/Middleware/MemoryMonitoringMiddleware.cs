namespace FileService.WebApi.Middleware;

/// <summary>
/// Middleware для мониторинга памяти и принудительной сборки мусора
/// </summary>
public class MemoryMonitoringMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<MemoryMonitoringMiddleware> _logger;

    public MemoryMonitoringMiddleware(RequestDelegate next, ILogger<MemoryMonitoringMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var initialMemory = GC.GetTotalMemory(false);
        
        try
        {
            await _next(context);
        }
        finally
        {
            // Естественная сборка мусора без принуждения
            // В потоковой архитектуре GC должен работать сам по себе
            var afterMemory = GC.GetTotalMemory(false);
            
            // Логгируем только значительные изменения памяти
            var memoryChange = afterMemory - initialMemory;
            if (Math.Abs(memoryChange) > 5 * 1024 * 1024) // > 5MB
            {
                _logger.LogInformation(
                    "Memory change: {MemoryChange:+N0;-N0;0} bytes for {Method} {Path}",
                    memoryChange, context.Request.Method, context.Request.Path);
            }
        }
    }
}