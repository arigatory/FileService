using System.Net.Http.Json;
using System.Text.Json;
using FileService.Client.Models;
using ClientFileInfo = FileService.Client.Models.FileInfo;

namespace FileService.Client;

public class FileServiceClient : IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly bool _disposeHttpClient;
    private readonly JsonSerializerOptions _jsonOptions;

    public FileServiceClient(string baseUrl) : this(new HttpClient { BaseAddress = new Uri(baseUrl) }, true)
    {
    }

    public FileServiceClient(HttpClient httpClient, bool disposeHttpClient = false)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _disposeHttpClient = disposeHttpClient;
        _jsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
    }

    /// <summary>
    /// Загружает файл в файловый сервис
    /// </summary>
    /// <param name="fileStream">Поток файла</param>
    /// <param name="fileName">Имя файла</param>
    /// <param name="contentType">MIME тип файла</param>
    /// <param name="tags">Дополнительные теги</param>
    /// <param name="cancellationToken">Токен отмены</param>
    /// <returns>Результат загрузки с ID файла</returns>
    public async Task<FileUploadResult> UploadFileAsync(
        Stream fileStream, 
        string fileName, 
        string contentType, 
        string? tags = null,
        CancellationToken cancellationToken = default)
    {
        if (fileStream == null)
            throw new ArgumentNullException(nameof(fileStream));
        
        if (string.IsNullOrWhiteSpace(fileName))
            throw new ArgumentException("File name cannot be null or empty.", nameof(fileName));
        
        if (string.IsNullOrWhiteSpace(contentType))
            throw new ArgumentException("Content type cannot be null or empty.", nameof(contentType));

        using var form = new MultipartFormDataContent();
        using var streamContent = new StreamContent(fileStream);
        
        streamContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType);
        form.Add(streamContent, "file", fileName);
        
        if (!string.IsNullOrWhiteSpace(tags))
        {
            form.Add(new StringContent(tags), "tags");
        }

        var response = await _httpClient.PostAsync("api/files/upload", form, cancellationToken);
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<FileUploadResult>(_jsonOptions, cancellationToken);
        return result ?? throw new InvalidOperationException("Failed to deserialize upload result.");
    }

    /// <summary>
    /// Получает файл по его ID
    /// </summary>
    /// <param name="fileId">ID файла</param>
    /// <param name="cancellationToken">Токен отмены</param>
    /// <returns>Поток файла</returns>
    public async Task<Stream> GetFileStreamAsync(string fileId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(fileId))
            throw new ArgumentException("File ID cannot be null or empty.", nameof(fileId));

        var response = await _httpClient.GetAsync($"api/files/{fileId}", cancellationToken);
        
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            throw new System.IO.FileNotFoundException($"File with ID '{fileId}' not found.");
        
        response.EnsureSuccessStatusCode();

        return await response.Content.ReadAsStreamAsync(cancellationToken);
    }

    /// <summary>
    /// Получает информацию о файле без скачивания
    /// </summary>
    /// <param name="fileId">ID файла</param>
    /// <param name="cancellationToken">Токен отмены</param>
    /// <returns>Информация о файле</returns>
    public async Task<ClientFileInfo?> GetFileInfoAsync(string fileId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(fileId))
            throw new ArgumentException("File ID cannot be null or empty.", nameof(fileId));

        var response = await _httpClient.GetAsync($"api/files/{fileId}/info", cancellationToken);
        
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            return null;
        
        response.EnsureSuccessStatusCode();

        return await response.Content.ReadFromJsonAsync<ClientFileInfo>(_jsonOptions, cancellationToken);
    }

    /// <summary>
    /// Удаляет файл по его ID
    /// </summary>
    /// <param name="fileId">ID файла</param>
    /// <param name="cancellationToken">Токен отмены</param>
    /// <returns>True если файл успешно удален</returns>
    public async Task<bool> DeleteFileAsync(string fileId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(fileId))
            throw new ArgumentException("File ID cannot be null or empty.", nameof(fileId));

        var response = await _httpClient.DeleteAsync($"api/files/{fileId}", cancellationToken);
        
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            return false;
        
        response.EnsureSuccessStatusCode();
        return true;
    }

    public void Dispose()
    {
        if (_disposeHttpClient)
        {
            _httpClient?.Dispose();
        }
    }
}