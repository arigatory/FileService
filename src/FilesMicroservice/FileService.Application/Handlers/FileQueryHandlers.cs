using MediatR;
using FileService.Application.Queries;
using FileService.Application.DTOs;
using FileService.Domain.Interfaces;
using FileService.Domain.Exceptions;

namespace FileService.Application.Handlers;

public class GetFileQueryHandler : IRequestHandler<GetFileQuery, FileDownloadDto?>
{
    private readonly IStorageSelector _storageSelector;
    private readonly IFileRepository _fileRepository;

    public GetFileQueryHandler(IStorageSelector storageSelector, IFileRepository fileRepository)
    {
        _storageSelector = storageSelector;
        _fileRepository = fileRepository;
    }

    public async Task<FileDownloadDto?> Handle(GetFileQuery request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FileId))
            return null;

        try
        {
            // Получаем метаданные файла
            var fileMetadata = await _fileRepository.GetFileMetadataAsync(request.FileId, cancellationToken);
            if (fileMetadata == null)
                return null;

            // Получаем провайдер хранилища
            var storageProvider = _storageSelector.GetStorageProvider(fileMetadata.StorageProvider);
            if (storageProvider == null)
                throw new StorageException($"Storage provider '{fileMetadata.StorageProvider}' not found.");

            // Получаем поток файла из хранилища
            var fileStream = await storageProvider.DownloadFileAsync(fileMetadata.StorageKey, cancellationToken);

            return new FileDownloadDto
            {
                Id = fileMetadata.Id,
                OriginalFileName = fileMetadata.OriginalFileName,
                ContentType = fileMetadata.ContentType,
                Size = fileMetadata.Size,
                FileStream = fileStream
            };
        }
        catch (Exception ex) when (!(ex is StorageException))
        {
            throw new StorageException("Failed to download file.", ex);
        }
    }
}

public class GetFileInfoQueryHandler : IRequestHandler<GetFileInfoQuery, FileInfoDto?>
{
    private readonly IFileRepository _fileRepository;

    public GetFileInfoQueryHandler(IFileRepository fileRepository)
    {
        _fileRepository = fileRepository;
    }

    public async Task<FileInfoDto?> Handle(GetFileInfoQuery request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FileId))
            return null;

        var fileMetadata = await _fileRepository.GetFileMetadataAsync(request.FileId, cancellationToken);
        if (fileMetadata == null)
            return null;

        return new FileInfoDto
        {
            Id = fileMetadata.Id,
            OriginalFileName = fileMetadata.OriginalFileName,
            ContentType = fileMetadata.ContentType,
            Size = fileMetadata.Size,
            UploadedAt = fileMetadata.UploadedAt
        };
    }
}