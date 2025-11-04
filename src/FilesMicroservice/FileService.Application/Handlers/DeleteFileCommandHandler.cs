using MediatR;
using FileService.Application.Commands;
using FileService.Domain.Interfaces;
using FileService.Domain.Exceptions;
using DomainFileNotFoundException = FileService.Domain.Exceptions.FileNotFoundException;

namespace FileService.Application.Handlers;

public class DeleteFileCommandHandler : IRequestHandler<DeleteFileCommand, bool>
{
    private readonly IStorageSelector _storageSelector;
    private readonly IFileRepository _fileRepository;

    public DeleteFileCommandHandler(IStorageSelector storageSelector, IFileRepository fileRepository)
    {
        _storageSelector = storageSelector;
        _fileRepository = fileRepository;
    }

    public async Task<bool> Handle(DeleteFileCommand request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FileId))
            throw new ArgumentException("File ID is required.");

        try
        {
            // Получаем метаданные файла
            var fileMetadata = await _fileRepository.GetFileMetadataAsync(request.FileId, cancellationToken);
            if (fileMetadata == null)
                throw new DomainFileNotFoundException(request.FileId);

            // Получаем провайдер хранилища
            var storageProvider = _storageSelector.GetStorageProvider(fileMetadata.StorageProvider);
            if (storageProvider == null)
                throw new StorageException($"Storage provider '{fileMetadata.StorageProvider}' not found.");

            // Удаляем файл из хранилища
            var storageDeleted = await storageProvider.DeleteFileAsync(fileMetadata.StorageKey, cancellationToken);

            // Удаляем метаданные из репозитория
            var metadataDeleted = await _fileRepository.DeleteFileMetadataAsync(request.FileId, cancellationToken);

            return storageDeleted && metadataDeleted;
        }
        catch (Exception ex) when (!(ex is DomainFileNotFoundException || ex is StorageException))
        {
            throw new StorageException("Failed to delete file.", ex);
        }
    }
}