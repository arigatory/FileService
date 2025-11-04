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
            // Принудительная сборка мусора после каждого запроса
            var beforeGC = GC.GetTotalMemory(false);
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            var afterGC = GC.GetTotalMemory(false);
            
            var memoryFreed = beforeGC - afterGC;
            
            // Логгируем только если освободилось много памяти
            if (memoryFreed > 1024 * 1024) // > 1MB
            {
                _logger.LogInformation(
                    "Memory cleaned up: {MemoryFreed:N0} bytes for {Method} {Path}",
                    memoryFreed, context.Request.Method, context.Request.Path);
            }
        }
    }
}