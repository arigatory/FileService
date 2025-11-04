using MediatR;
using FileService.Application.DTOs;

namespace FileService.Application.Commands;

public class UploadFileCommand : IRequest<FileUploadDto>
{
    public Stream FileStream { get; set; } = null!;
    public string FileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public string? Tags { get; set; }
    public long FileSize { get; set; }  // Размер файла передается отдельно
}