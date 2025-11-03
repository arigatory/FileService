using Microsoft.AspNetCore.Mvc;
using FileService.Client;

namespace FileService.ClientApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FilesController : ControllerBase
{
    private readonly FileServiceClient _fileServiceClient;
    private readonly ILogger<FilesController> _logger;

    public FilesController(FileServiceClient fileServiceClient, ILogger<FilesController> logger)
    {
        _fileServiceClient = fileServiceClient;
        _logger = logger;
    }

    /// <summary>
    /// Загружает файл через FileService
    /// </summary>
    [HttpPost("upload")]
    public async Task<IActionResult> UploadFile(IFormFile file, [FromForm] string? tags = null)
    {
        try
        {
            if (file == null || file.Length == 0)
                return BadRequest("Файл не выбран или пустой");

            _logger.LogInformation("Загружаем файл {FileName} через FileService", file.FileName);
            
            using var stream = file.OpenReadStream();
            var result = await _fileServiceClient.UploadFileAsync(stream, file.FileName, file.ContentType, tags);
            
            _logger.LogInformation("Файл загружен с ID: {FileId}", result.Id);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при загрузке файла");
            return StatusCode(500, $"Ошибка загрузки файла: {ex.Message}");
        }
    }

    /// <summary>
    /// Скачивает файл через FileService
    /// </summary>
    [HttpGet("{id}/download")]
    public async Task<IActionResult> DownloadFile(string id)
    {
        try
        {
            _logger.LogInformation("Скачиваем файл с ID: {FileId}", id);
            
            var fileInfo = await _fileServiceClient.GetFileInfoAsync(id);
            if (fileInfo == null)
                return NotFound($"Файл с ID '{id}' не найден");

            var stream = await _fileServiceClient.GetFileStreamAsync(id);
            
            _logger.LogInformation("Файл {FileName} скачан", fileInfo.OriginalFileName);
            return File(stream, fileInfo.ContentType ?? "application/octet-stream", fileInfo.OriginalFileName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при скачивании файла {FileId}", id);
            return StatusCode(500, $"Ошибка скачивания файла: {ex.Message}");
        }
    }

    /// <summary>
    /// Удаляет файл через FileService
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteFile(string id)
    {
        try
        {
            _logger.LogInformation("Удаляем файл с ID: {FileId}", id);
            
            var success = await _fileServiceClient.DeleteFileAsync(id);
            if (success)
            {
                _logger.LogInformation("Файл {FileId} удален", id);
                return NoContent();
            }
            else
            {
                return NotFound($"Файл с ID '{id}' не найден");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при удалении файла {FileId}", id);
            return StatusCode(500, $"Ошибка удаления файла: {ex.Message}");
        }
    }

    /// <summary>
    /// Получает информацию о файле через FileService
    /// </summary>
    [HttpGet("{id}/info")]
    public async Task<IActionResult> GetFileInfo(string id)
    {
        try
        {
            _logger.LogInformation("Получаем информацию о файле с ID: {FileId}", id);
            
            var fileInfo = await _fileServiceClient.GetFileInfoAsync(id);
            if (fileInfo == null)
                return NotFound($"Файл с ID '{id}' не найден");

            return Ok(fileInfo);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении информации о файле {FileId}", id);
            return StatusCode(500, $"Ошибка получения информации: {ex.Message}");
        }
    }
}