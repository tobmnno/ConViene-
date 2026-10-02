FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    CONVIENE_PROMOTIONS_REFRESH_SECONDS=21600

WORKDIR /app

RUN useradd --create-home --shell /usr/sbin/nologin conviene

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . ./
RUN mkdir -p data/runtime && chown -R conviene:conviene /app

USER conviene

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8000/health', timeout=3)"

CMD ["sh", "-c", "uvicorn api:app --host 0.0.0.0 --port ${PORT}"]
