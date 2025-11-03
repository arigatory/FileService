namespace FileService.Domain.Interfaces;

public interface IStorageProvider
{
    string ProviderName { get; }
    Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, CancellationToken cancellationToken = default);
    Task<Stream> DownloadFileAsync(string storageKey, CancellationToken cancellationToken = default);
    Task<bool> DeleteFileAsync(string storageKey, CancellationToken cancellationToken = default);
    Task<bool> FileExistsAsync(string storageKey, CancellationToken cancellationToken = default);
}