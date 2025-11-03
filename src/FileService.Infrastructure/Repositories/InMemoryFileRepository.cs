using FileService.Domain.Entities;
using FileService.Domain.Interfaces;
using System.Collections.Concurrent;

namespace FileService.Infrastructure.Repositories;

public class InMemoryFileRepository : IFileRepository
{
    private readonly ConcurrentDictionary<string, FileMetadata> _files = new();

    public Task<string> SaveFileMetadataAsync(FileMetadata metadata, CancellationToken cancellationToken = default)
    {
        if (metadata == null)
            throw new ArgumentNullException(nameof(metadata));

        if (string.IsNullOrWhiteSpace(metadata.Id))
            metadata.Id = Guid.NewGuid().ToString();

        _files.AddOrUpdate(metadata.Id, metadata, (key, existing) => metadata);
        
        return Task.FromResult(metadata.Id);
    }

    public Task<FileMetadata?> GetFileMetadataAsync(string fileId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(fileId))
            return Task.FromResult<FileMetadata?>(null);

        _files.TryGetValue(fileId, out var metadata);
        return Task.FromResult(metadata);
    }

    public Task<bool> DeleteFileMetadataAsync(string fileId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(fileId))
            return Task.FromResult(false);

        return Task.FromResult(_files.TryRemove(fileId, out _));
    }
}