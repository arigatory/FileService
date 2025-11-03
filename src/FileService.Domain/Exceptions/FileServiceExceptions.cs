namespace FileService.Domain.Exceptions;

public class FileNotFoundException : Exception
{
    public FileNotFoundException(string fileId) 
        : base($"File with ID '{fileId}' was not found.")
    {
    }
}

public class StorageException : Exception
{
    public StorageException(string message) : base(message)
    {
    }

    public StorageException(string message, Exception innerException) : base(message, innerException)
    {
    }
}

public class InvalidFileException : Exception
{
    public InvalidFileException(string message) : base(message)
    {
    }
}