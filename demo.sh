#!/bin/bash
# Тестовый скрипт для демонстрации FileService API

echo "=== Демонстрация файлового микросервиса ==="
echo ""

# Проверяем статус сервисов
echo "1. Проверяем статус контейнеров:"
docker-compose ps
echo ""

# Проверяем API здоровья
echo "2. Проверяем здоровье API:"
curl -s http://localhost:8080/health || echo "API недоступен"
echo ""
echo ""

# Показываем Swagger UI
echo "3. Swagger UI доступен по адресу: http://localhost:8080/swagger"
echo ""

# Показываем MinIO консоли
echo "4. MinIO консоли:"
echo "   MinIO1: http://localhost:9011 (minioadmin / minioadmin123)"
echo "   MinIO2: http://localhost:9012 (minioadmin / minioadmin123)"
echo ""

# Проверяем bucket'ы в MinIO
echo "5. Проверяем bucket'ы в MinIO1:"
docker exec minio1 mc ls local
echo ""

echo "6. Файлы в bucket files:"
docker exec minio1 mc ls local/files
echo ""

# Демонстрируем клиентскую библиотеку
echo "7. Следующие шаги для тестирования:"
echo "   - Откройте http://localhost:8080/swagger"
echo "   - Используйте endpoint /api/files/upload для загрузки файла"
echo "   - После решения проблем с AWS SDK, система будет готова к работе"
echo ""

echo "=== Архитектура системы ==="
echo "- Clean Architecture с доменом, приложением, инфраструктурой и WebAPI"
echo "- MediatR для CQRS паттерна"
echo "- Множественные S3 хранилища с Round Robin балансировкой"
echo "- Потоковая обработка файлов без загрузки в память"
echo "- Клиентская библиотека для интеграции"
echo "- Docker контейнеризация"
echo ""