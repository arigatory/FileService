using MediatR;
using FileService.Application.Commands;
using FileService.Application.DTOs;
using FileService.Domain.Entities;
using FileService.Domain.Interfaces;
using FileService.Domain.Exceptions;

namespace FileService.Application.Handlers;

public class UploadFileCommandHandler : IRequestHandler<UploadFileCommand, FileUploadDto>
{
    private readonly IStorageSelector _storageSelector;
    private readonly IFileRepository _fileRepository;

    public UploadFileCommandHandler(IStorageSelector storageSelector, IFileRepository fileRepository)
    {
        _storageSelector = storageSelector;
        _fileRepository = fileRepository;
    }

    public async Task<FileUploadDto> Handle(UploadFileCommand request, CancellationToken cancellationToken)
    {
        if (request.FileStream == null || !request.FileStream.CanRead)
            throw new InvalidFileException("Invalid file stream provided.");

        if (string.IsNullOrWhiteSpace(request.FileName))
            throw new InvalidFileException("File name is required.");

        if (string.IsNullOrWhiteSpace(request.ContentType))
            throw new InvalidFileException("Content type is required.");

        if (request.FileSize <= 0)
            throw new InvalidFileException("File size must be greater than zero.");

        try
        {
            // Выбираем провайдер хранилища
            var storageProvider = _storageSelector.SelectStorageProvider();
            
            // Загружаем файл в хранилище
            var storageKey = await storageProvider.UploadFileAsync(
                request.FileStream, 
                request.FileName, 
                request.ContentType, 
                cancellationToken);

            // Создаем метаданные файла
            var fileMetadata = new FileMetadata
            {
                Id = Guid.NewGuid().ToString(),
                OriginalFileName = request.FileName,
                ContentType = request.ContentType,
                Size = request.FileSize,  // Используем переданный размер вместо Stream.Length
                StorageKey = storageKey,
                StorageProvider = storageProvider.ProviderName,
                UploadedAt = DateTime.UtcNow,
                Tags = request.Tags
            };

            // Сохраняем метаданные в репозитории
            await _fileRepository.SaveFileMetadataAsync(fileMetadata, cancellationToken);

            return new FileUploadDto
            {
                Id = fileMetadata.Id,
                OriginalFileName = fileMetadata.OriginalFileName,
                ContentType = fileMetadata.ContentType,
                Size = fileMetadata.Size,
                UploadedAt = fileMetadata.UploadedAt
            };
        }
        catch (Exception ex) when (!(ex is InvalidFileException))
        {
            throw new StorageException("Failed to upload file.", ex);
        }
        finally
        {
            // Принудительная сборка мусора для гарантии освобождения памяти
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
        }
    }
}