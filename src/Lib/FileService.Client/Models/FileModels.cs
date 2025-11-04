namespace FileService.Client.Models;

public class FileUploadResult
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public DateTime UploadedAt { get; set; }
}

public class FileInfo
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public DateTime UploadedAt { get; set; }
}

public class FileDownloadResult
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public Stream FileStream { get; set; } = null!;
}