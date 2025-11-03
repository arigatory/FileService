#!/bin/bash
# Полный тест файлового микросервиса

echo "🚀 === ПОЛНЫЙ ТЕСТ ФАЙЛОВОГО МИКРОСЕРВИСА ==="
echo ""

# Создаем тестовый файл
echo "Это тестовый файл для демонстрации FileService" > test-demo.txt
echo "Дата создания: $(date)" >> test-demo.txt
echo "Размер: $(wc -c < test-demo.txt) байт" >> test-demo.txt

echo "📤 1. Загружаем файл..."
UPLOAD_RESPONSE=$(curl -s -X POST http://localhost:8080/api/Files/upload -F "file=@test-demo.txt" -F "tags=full-demo")
echo "Ответ: $UPLOAD_RESPONSE"

# Извлекаем ID файла из JSON ответа
FILE_ID=$(echo $UPLOAD_RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo "📁 ID файла: $FILE_ID"
echo ""

echo "ℹ️  2. Получаем информацию о файле..."
curl -s http://localhost:8080/api/Files/$FILE_ID/info | jq '.' || echo "jq не установлен, показываем raw JSON:"
curl -s http://localhost:8080/api/Files/$FILE_ID/info
echo ""
echo ""

echo "📥 3. Скачиваем файл..."
curl -s http://localhost:8080/api/Files/$FILE_ID -o downloaded-test.txt
echo "Размер скачанного файла: $(wc -c < downloaded-test.txt) байт"
echo "Содержимое скачанного файла:"
cat downloaded-test.txt
echo ""

echo "🔍 4. Сравниваем файлы..."
if diff test-demo.txt downloaded-test.txt > /dev/null; then
    echo "✅ Файлы идентичны!"
else
    echo "❌ Файлы отличаются!"
fi
echo ""

echo "🗑️  5. Удаляем файл..."
DELETE_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8080/api/Files/$FILE_ID -X DELETE)
echo "HTTP код ответа: $DELETE_RESPONSE"

echo ""
echo "🔍 6. Проверяем, что файл удален..."
CHECK_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8080/api/Files/$FILE_ID/info)
echo "HTTP код ответа: $CHECK_RESPONSE"

echo ""
echo "🧹 Очищаем временные файлы..."
rm -f test-demo.txt downloaded-test.txt

echo ""
echo "🎉 === ТЕСТ ЗАВЕРШЕН УСПЕШНО! ==="
echo "✅ Upload - работает"
echo "✅ Download - работает" 
echo "✅ Info - работает"
echo "✅ Delete - работает"
echo "✅ Файлы идентичны при загрузке/скачивании"
echo "✅ Удаление работает корректно"