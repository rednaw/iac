FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
USER nobody
ENV PORT=8080
EXPOSE 8080
CMD ["python", "-u", "app.py"]
