using FileService.Domain.Entities;

namespace FileService.Domain.Interfaces;

public interface IFileRepository
{
    Task<string> SaveFileMetadataAsync(FileMetadata metadata, CancellationToken cancellationToken = default);
    Task<FileMetadata?> GetFileMetadataAsync(string fileId, CancellationToken cancellationToken = default);
    Task<bool> DeleteFileMetadataAsync(string fileId, CancellationToken cancellationToken = default);
}