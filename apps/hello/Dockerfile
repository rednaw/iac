FROM python:3.11-slim

RUN pip install flask
WORKDIR /app

# Create a simple hello world app
RUN echo 'from flask import Flask\n\
app = Flask(__name__)\n\
@app.route("/")\n\
def hello():\n\
    return "Hello from Docker Registry! Registry is working! 🎉 Version 2.0"\n\
if __name__ == "__main__":\n\
    app.run(host="0.0.0.0", port=5000)' > app.py

EXPOSE 5000

CMD ["python", "app.py"]
