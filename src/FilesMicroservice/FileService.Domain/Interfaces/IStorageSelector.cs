namespace FileService.Domain.Interfaces;

public interface IStorageSelector
{
    IStorageProvider SelectStorageProvider();
    IStorageProvider? GetStorageProvider(string providerName);
}