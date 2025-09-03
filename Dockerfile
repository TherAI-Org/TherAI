FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY Backend/requirements.txt ./Backend/requirements.txt
RUN pip install --no-cache-dir -r Backend/requirements.txt

COPY Backend ./Backend

EXPOSE 8080
CMD ["uvicorn", "Backend.app:app", "--host", "0.0.0.0", "--port", "8080"]