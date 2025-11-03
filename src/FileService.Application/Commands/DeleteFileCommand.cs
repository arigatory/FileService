using MediatR;

namespace FileService.Application.Commands;

public class DeleteFileCommand : IRequest<bool>
{
    public string FileId { get; set; } = null!;
}