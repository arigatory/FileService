using FileService.Client;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "FileService Client App", 
        Version = "v1",
        Description = "Клиентское приложение для работы с FileService через библиотеку"
    });
});

// Регистрируем FileService клиент
builder.Services.AddHttpClient<FileServiceClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration.GetValue<string>("FileServiceUrl") ?? "http://localhost:8080");
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthorization();

app.MapControllers();

app.Run();