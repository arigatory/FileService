using FileService.Application.Handlers;
using FileService.Infrastructure;
using FileService.WebApi.Middleware;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using System.Runtime;

var builder = WebApplication.CreateBuilder(args);

// Стандартные серверные настройки для потокового проксирования
GCSettings.LatencyMode = GCLatencyMode.SustainedLowLatency;

// Настройка Kestrel
builder.Services.Configure<KestrelServerOptions>(options =>
{
    options.Limits.MaxRequestBodySize = long.MaxValue;
    options.Limits.RequestHeadersTimeout = TimeSpan.FromDays(1);
    options.Limits.KeepAliveTimeout = TimeSpan.FromDays(1);
    options.Limits.MaxConcurrentConnections = null;
    options.Limits.MaxConcurrentUpgradedConnections = null;
    options.Limits.MinRequestBodyDataRate = null;
    options.Limits.MinResponseDataRate = null;
});

builder.Services.Configure<FormOptions>(options =>
{
    options.ValueLengthLimit = int.MaxValue;
    options.MultipartBodyLengthLimit = long.MaxValue;
    options.MultipartHeadersLengthLimit = int.MaxValue;
    options.BufferBody = false;
    options.BufferBodyLengthLimit = 1;
    options.MemoryBufferThreshold = 1;
    options.MultipartBoundaryLengthLimit = 128;
});

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Регистрируем MediatR
builder.Services.AddMediatR(cfg => {
    cfg.RegisterServicesFromAssembly(typeof(UploadFileCommandHandler).Assembly);
});

// Добавляем Infrastructure
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseMiddleware<ConcurrencyLimitMiddleware>();
app.UseMiddleware<MemoryMonitoringMiddleware>();
app.UseAuthorization();
app.MapControllers();

// Health endpoints
app.MapGet("/health", () => "OK");
app.MapGet("/status", () => ConcurrencyLimitMiddleware.GetSystemStatus());

app.Run();
