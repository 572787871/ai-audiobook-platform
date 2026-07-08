#!/bin/bash
set -e
cd "$(dirname "$0")/.."
echo "=== 1. Build and start docker-compose ==="
docker compose up -d --build
echo "Waiting for backend..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo "Backend ready"
    break
  fi
  sleep 2
  if [ $i -eq 30 ]; then
    echo "Backend failed to start"
    docker compose logs backend
    exit 1
  fi
done
echo "=== 2. Health check ==="
curl -sf http://localhost:8000/health | python3 -m json.tool
echo "=== 3. Register test user ==="
REGISTER_RESP=$(curl -sf -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test@example.com\",\"username\":\"testuser\",\"password\":\"testpass123\"}")
TOKEN=$(echo "$REGISTER_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"access_token\"])")
echo "Token OK"
echo "=== 4. Get current user ==="
curl -sf http://localhost:8000/api/auth/me -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
echo "=== 5. Login ==="
curl -sf -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test@example.com\",\"password\":\"testpass123\"}" | python3 -m json.tool
echo "=== 6. Upload text file ==="
printf "第一章内容\n\n第二章内容\n" > /tmp/test_audiobook.txt
UPLOAD_RESP=$(curl -sf -X POST http://localhost:8000/api/books/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/tmp/test_audiobook.txt" \
  -F "title=test_audiobook" \
  -F "author=test_author" \
  -F "description=smoke_test")
BOOK_ID=$(echo "$UPLOAD_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"id\"])")
echo "Book ID: $BOOK_ID"
echo "=== 7. List books ==="
curl -sf "http://localhost:8000/api/books" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
echo "=== 8. Create TTS task ==="
TASK_RESP=$(curl -sf -X POST http://localhost:8000/api/tasks \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"book_id\":$BOOK_ID,\"task_type\":\"tts\"}")
TASK_ID=$(echo "$TASK_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"id\"])")
echo "Task ID: $TASK_ID"
echo "=== 9. Wait for task ==="
for i in $(seq 1 60); do
  TASK_STATUS=$(curl -sf "http://localhost:8000/api/tasks/$TASK_ID" -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"status\"])")
  echo "  Status: $TASK_STATUS (attempt $i)"
  if [ "$TASK_STATUS" = "completed" ]; then
    echo "Task completed!"
    break
  fi
  if [ "$TASK_STATUS" = "failed" ]; then
    echo "Task failed!"
    exit 1
  fi
  sleep 3
done
echo "=== 10. Check book detail ==="
curl -sf "http://localhost:8000/api/books/$BOOK_ID" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
echo "=== 11. Download audio ==="
curl -sf -o /tmp/test_output.mp3 "http://localhost:8000/api/books/$BOOK_ID/download" -H "Authorization: Bearer $TOKEN"
ls -la /tmp/test_output.mp3
echo "=== 12. Cleanup ==="
docker compose down -v
rm -f /tmp/test_audiobook.txt /tmp/test_output.mp3
echo "==================================="
echo "✅ Smoke test PASSED!"
echo "==================================="
