namespace FileService.Domain.Entities;

public class FileMetadata
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public string StorageKey { get; set; } = null!;
    public string StorageProvider { get; set; } = null!;
    public DateTime UploadedAt { get; set; }
    public string? Tags { get; set; }
}
