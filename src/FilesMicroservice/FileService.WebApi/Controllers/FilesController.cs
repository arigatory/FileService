using Microsoft.AspNetCore.Mvc;
using MediatR;
using FileService.Application.Commands;
using FileService.Application.Queries;
using FileService.Application.DTOs;
using FileService.Domain.Exceptions;
using DomainFileNotFoundException = FileService.Domain.Exceptions.FileNotFoundException;

namespace FileService.WebApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FilesController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<FilesController> _logger;

    public FilesController(IMediator mediator, ILogger<FilesController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    /// <summary>
    /// Загружает файл в хранилище
    /// </summary>
    /// <param name="file">Файл для загрузки</param>
    /// <param name="tags">Дополнительные теги</param>
    /// <returns>Информация о загруженном файле</returns>
    [HttpPost("upload")]
    public async Task<ActionResult<FileUploadDto>> UploadFile(IFormFile file, [FromForm] string? tags = null)
    {
        try
        {
            if (file == null || file.Length == 0)
                return BadRequest("File is required and cannot be empty.");

            var command = new UploadFileCommand
            {
                FileStream = file.OpenReadStream(),
                FileName = file.FileName,
                ContentType = file.ContentType,
                Tags = tags,
                FileSize = file.Length  // Передаем размер файла отдельно
            };

            var result = await _mediator.Send(command);
            return Ok(result);
        }
        catch (InvalidFileException ex)
        {
            _logger.LogWarning("Invalid file upload attempt: {Message}", ex.Message);
            return BadRequest(ex.Message);
        }
        catch (StorageException ex)
        {
            _logger.LogError(ex, "Storage error during file upload");
            return StatusCode(500, "Internal server error during file upload.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during file upload");
            return StatusCode(500, "Unexpected error occurred.");
        }
    }

    /// <summary>
    /// Получает файл по его ID
    /// </summary>
    /// <param name="id">ID файла</param>
    /// <returns>Файл в виде потока</returns>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetFile(string id)
    {
        try
        {
            var query = new GetFileQuery { FileId = id };
            var result = await _mediator.Send(query);

            if (result == null)
                return NotFound($"File with ID '{id}' not found.");

            return File(result.FileStream, result.ContentType, result.OriginalFileName);
        }
        catch (DomainFileNotFoundException ex)
        {
            _logger.LogWarning("File not found: {Message}", ex.Message);
            return NotFound(ex.Message);
        }
        catch (StorageException ex)
        {
            _logger.LogError(ex, "Storage error during file download");
            return StatusCode(500, "Internal server error during file download.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during file download");
            return StatusCode(500, "Unexpected error occurred.");
        }
    }

    /// <summary>
    /// Получает информацию о файле без скачивания
    /// </summary>
    /// <param name="id">ID файла</param>
    /// <returns>Информация о файле</returns>
    [HttpGet("{id}/info")]
    public async Task<ActionResult<FileInfoDto>> GetFileInfo(string id)
    {
        try
        {
            var query = new GetFileInfoQuery { FileId = id };
            var result = await _mediator.Send(query);

            if (result == null)
                return NotFound($"File with ID '{id}' not found.");

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting file info");
            return StatusCode(500, "Unexpected error occurred.");
        }
    }

    /// <summary>
    /// Удаляет файл по его ID
    /// </summary>
    /// <param name="id">ID файла</param>
    /// <returns>Результат операции удаления</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteFile(string id)
    {
        try
        {
            var command = new DeleteFileCommand { FileId = id };
            var result = await _mediator.Send(command);

            if (!result)
                return NotFound($"File with ID '{id}' not found.");

            return NoContent();
        }
        catch (DomainFileNotFoundException ex)
        {
            _logger.LogWarning("File not found during deletion: {Message}", ex.Message);
            return NotFound(ex.Message);
        }
        catch (StorageException ex)
        {
            _logger.LogError(ex, "Storage error during file deletion");
            return StatusCode(500, "Internal server error during file deletion.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during file deletion");
            return StatusCode(500, "Unexpected error occurred.");
        }
    }
}