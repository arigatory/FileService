using FileService.Application.Handlers;
using FileService.Infrastructure;
using FileService.WebApi.Middleware;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.IIS;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using System.Reflection;
using System.Runtime;

var builder = WebApplication.CreateBuilder(args);

// Настройка агрессивной сборки мусора для минимального потребления памяти
GCSettings.LatencyMode = GCLatencyMode.Batch; // Приоритет - освобождение памяти
AppContext.SetSwitch("System.GC.RetainVM", false); // Не удерживаем память в VM

// Настройка лимитов для больших файлов
builder.Services.Configure<IISServerOptions>(options =>
{
    options.MaxRequestBodySize = long.MaxValue; // Без ограничений
});

builder.Services.Configure<KestrelServerOptions>(options =>
{
    options.Limits.MaxRequestBodySize = long.MaxValue; // Без ограничений
});

builder.Services.Configure<FormOptions>(options =>
{
    options.ValueLengthLimit = int.MaxValue;
    options.MultipartBodyLengthLimit = long.MaxValue;
    options.MultipartHeadersLengthLimit = int.MaxValue;
    options.BufferBody = false;  // Отключаем буферизацию тела запроса
    options.BufferBodyLengthLimit = 1;  // Минимальный буфер - 1 байт
    options.MemoryBufferThreshold = 1;  // Сразу используем временные файлы - 1 байт
    options.MultipartBoundaryLengthLimit = 128; // Минимальный размер boundary
});

// Add services to the container.
builder.Services.AddControllers();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "File Service API", 
        Version = "v1",
        Description = "Микросервис для загрузки, получения и удаления файлов с поддержкой нескольких S3 хранилищ"
    });
    
    // Включаем XML комментарии для Swagger
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

// Добавляем MediatR
builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(UploadFileCommandHandler).Assembly));

// Добавляем Infrastructure
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Добавляем middleware для мониторинга памяти
app.UseMiddleware<MemoryMonitoringMiddleware>();

app.UseAuthorization();

app.MapControllers();

// Health check endpoint
app.MapGet("/health", () => "OK");

// Force garbage collection after app initialization
GC.Collect();
GC.WaitForPendingFinalizers();
GC.Collect();

app.Run();