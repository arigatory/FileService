namespace FileService.Application.DTOs;

public class FileUploadDto
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public DateTime UploadedAt { get; set; }
}

public class FileDownloadDto
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public Stream FileStream { get; set; } = null!;
}

public class FileInfoDto
{
    public string Id { get; set; } = null!;
    public string OriginalFileName { get; set; } = null!;
    public string ContentType { get; set; } = null!;
    public long Size { get; set; }
    public DateTime UploadedAt { get; set; }
}