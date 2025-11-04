using FileService.Domain.Interfaces;

namespace FileService.Infrastructure.Storage;

public class RoundRobinStorageSelector : IStorageSelector
{
    private readonly List<IStorageProvider> _storageProviders;
    private readonly Dictionary<string, IStorageProvider> _providersByName;
    private int _currentIndex = 0;
    private readonly object _lock = new object();

    public RoundRobinStorageSelector(IEnumerable<IStorageProvider> storageProviders)
    {
        _storageProviders = storageProviders?.ToList() ?? throw new ArgumentNullException(nameof(storageProviders));
        
        if (!_storageProviders.Any())
            throw new ArgumentException("At least one storage provider must be provided.", nameof(storageProviders));

        _providersByName = _storageProviders.ToDictionary(p => p.ProviderName, p => p);
    }

    public IStorageProvider SelectStorageProvider()
    {
        lock (_lock)
        {
            var provider = _storageProviders[_currentIndex];
            _currentIndex = (_currentIndex + 1) % _storageProviders.Count;
            return provider;
        }
    }

    public IStorageProvider? GetStorageProvider(string providerName)
    {
        return _providersByName.TryGetValue(providerName, out var provider) ? provider : null;
    }
}

public class RandomStorageSelector : IStorageSelector
{
    private readonly List<IStorageProvider> _storageProviders;
    private readonly Dictionary<string, IStorageProvider> _providersByName;
    private readonly Random _random;

    public RandomStorageSelector(IEnumerable<IStorageProvider> storageProviders)
    {
        _storageProviders = storageProviders?.ToList() ?? throw new ArgumentNullException(nameof(storageProviders));
        
        if (!_storageProviders.Any())
            throw new ArgumentException("At least one storage provider must be provided.", nameof(storageProviders));

        _providersByName = _storageProviders.ToDictionary(p => p.ProviderName, p => p);
        _random = new Random();
    }

    public IStorageProvider SelectStorageProvider()
    {
        var index = _random.Next(_storageProviders.Count);
        return _storageProviders[index];
    }

    public IStorageProvider? GetStorageProvider(string providerName)
    {
        return _providersByName.TryGetValue(providerName, out var provider) ? provider : null;
    }
}