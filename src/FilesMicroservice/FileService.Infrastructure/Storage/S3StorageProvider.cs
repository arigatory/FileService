using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Util;
using Amazon.S3.Transfer;
using FileService.Domain.Interfaces;
using FileService.Domain.Exceptions;
using DomainFileNotFoundException = FileService.Domain.Exceptions.FileNotFoundException;

namespace FileService.Infrastructure.Storage;

public class S3StorageProvider : IStorageProvider
{
    private readonly IAmazonS3 _s3Client;
    private readonly string _bucketName;
    private readonly string _providerName;

    public S3StorageProvider(IAmazonS3 s3Client, string bucketName, string? providerName = null)
    {
        _s3Client = s3Client ?? throw new ArgumentNullException(nameof(s3Client));
        _bucketName = bucketName ?? throw new ArgumentNullException(nameof(bucketName));
        _providerName = providerName ?? $"S3-{bucketName}";
    }

    public string ProviderName => _providerName;

    public async Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, CancellationToken cancellationToken = default)
    {
        try
        {
            var key = GenerateStorageKey(fileName);
            
            // КОНСТАНТНАЯ ПАМЯТЬ: Используем TransferUtility с минимальными настройками для постоянного потребления
            using var transferUtility = new Amazon.S3.Transfer.TransferUtility(_s3Client);
            
            var request = new Amazon.S3.Transfer.TransferUtilityUploadRequest
            {
                BucketName = _bucketName,
                Key = key,
                InputStream = fileStream,
                ContentType = contentType,
                // Минимальные настройки для константной памяти
                PartSize = 5 * 1024 * 1024, // 5MB parts - минимум для S3 multipart
                CannedACL = Amazon.S3.S3CannedACL.Private,
                ServerSideEncryptionMethod = Amazon.S3.ServerSideEncryptionMethod.None,
                StorageClass = Amazon.S3.S3StorageClass.Standard,
                AutoCloseStream = false,
                AutoResetStreamPosition = false
            };

            await transferUtility.UploadAsync(request, cancellationToken);
            
            return key;
        }
        catch (AmazonS3Exception ex)
        {
            throw new StorageException($"S3 specific error uploading file: {ex.ErrorCode} - {ex.Message}", ex);
        }
        catch (TaskCanceledException ex)
        {
            throw new StorageException($"Upload timeout for file: {fileName}", ex);
        }
        catch (Exception ex) when (!(ex is StorageException))
        {
            throw new StorageException($"Error uploading file to S3: {ex.Message}", ex);
        }
    }

    public async Task<Stream> DownloadFileAsync(string storageKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var request = new GetObjectRequest
            {
                BucketName = _bucketName,
                Key = storageKey
            };

            var response = await _s3Client.GetObjectAsync(request, cancellationToken);
            return response.ResponseStream;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            throw new DomainFileNotFoundException(storageKey);
        }
        catch (Exception ex) when (!(ex is DomainFileNotFoundException))
        {
            throw new StorageException($"Error downloading file from S3: {ex.Message}", ex);
        }
    }

    public async Task<bool> DeleteFileAsync(string storageKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var request = new DeleteObjectRequest
            {
                BucketName = _bucketName,
                Key = storageKey
            };

            var response = await _s3Client.DeleteObjectAsync(request, cancellationToken);
            return response.HttpStatusCode == System.Net.HttpStatusCode.NoContent;
        }
        catch (Exception ex)
        {
            throw new StorageException($"Error deleting file from S3: {ex.Message}", ex);
        }
    }

    public async Task<bool> FileExistsAsync(string storageKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var request = new GetObjectMetadataRequest
            {
                BucketName = _bucketName,
                Key = storageKey
            };

            await _s3Client.GetObjectMetadataAsync(request, cancellationToken);
            return true;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
        catch (Exception ex)
        {
            throw new StorageException($"Error checking file existence in S3: {ex.Message}", ex);
        }
    }

    private static string GenerateStorageKey(string fileName)
    {
        var timestamp = DateTime.UtcNow.ToString("yyyy/MM/dd");
        var uniqueId = Guid.NewGuid().ToString("N");
        var extension = Path.GetExtension(fileName);
        return $"{timestamp}/{uniqueId}{extension}";
    }
}