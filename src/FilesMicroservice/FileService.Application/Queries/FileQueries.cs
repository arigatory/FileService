using MediatR;
using FileService.Application.DTOs;

namespace FileService.Application.Queries;

public class GetFileQuery : IRequest<FileDownloadDto?>
{
    public string FileId { get; set; } = null!;
}

public class GetFileInfoQuery : IRequest<FileInfoDto?>
{
    public string FileId { get; set; } = null!;
}