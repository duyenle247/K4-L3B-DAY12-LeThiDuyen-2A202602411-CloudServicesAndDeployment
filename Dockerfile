# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /health
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: Builder ───
FROM python:3.11-slim AS builder

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ─── Stage 2: Runtime ───
FROM python:3.11-slim AS runtime

WORKDIR /app

# Tạo user thường (non-root) để đảm bảo bảo mật
RUN useradd -m -u 1000 appuser

# Copy môi trường Python từ stage builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Copy mã nguồn sau khi cài dependencies để tận dụng Docker layer cache
COPY . .

# Gán quyền thư mục cho appuser
RUN chown -R appuser:appuser /app

# Chuyển sang chạy bằng non-root user
USER appuser

# Healthcheck gọi vào endpoint /health
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request, os; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health')" || exit 1

EXPOSE 8000

# Bind Uvicorn vào 0.0.0.0 và đọc cổng từ ${PORT:-8000}
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
