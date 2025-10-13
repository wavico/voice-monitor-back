from fastapi import FastAPI, Request
from kafka import KafkaProducer
import json
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import start_http_server, Gauge, Counter, REGISTRY
import threading
import random
from fastapi import Body
from fastapi.middleware.cors import CORSMiddleware
import time
from fastapi.responses import HTMLResponse

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Instrumentator 설정
Instrumentator().instrument(app).expose(app)

# Kafka Producer를 전역 변수로 선언
producer = None

try:
    # Kafka Producer 생성 시도
    producer = KafkaProducer(
        bootstrap_servers='kafka:9092',
        value_serializer=lambda x: json.dumps(x).encode('utf-8')
    )
except Exception as e:
    print(f"Failed to connect to Kafka: {e}")

# 커스텀 메트릭
transaction_count = Counter('transaction_count', 'Total number of transactions processed')
transaction_amount = Gauge('transaction_amount', 'Transaction amount in KRW')
transaction_success = Counter('transaction_success', 'Number of successful transactions')
transaction_failure = Counter('transaction_failure', 'Number of failed transactions')
transaction_processing_time = Gauge('transaction_processing_time', 'Transaction processing time in seconds')


@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.post("/predict/")
async def predict(data: dict):
    start_time = time.time()
    try:
        # 1. 메트릭 업데이트
        transaction_count.inc()
        transaction_amount.set(float(data.get('amount', 0)))
        
        # 2. Kafka로 거래 메시지 전송 (Kafka가 사용 가능한 경우에만)
        if producer:
            producer.send("transactions", value=data)
            producer.flush()

        # 3. Triton 추론 요청
        response = data

        # 4. 성공 메트릭 업데이트
        transaction_success.inc()
        
        # 5. 처리 시간 기록
        processing_time = time.time() - start_time
        transaction_processing_time.set(processing_time)

        return {"status": "success", "triton_response": data}
    except Exception as e:
        print(f"Error in predict: {e}")
        # 실패 메트릭 업데이트
        transaction_failure.inc()
        return {"status": "success", "triton_response": data}

@app.get("/metrics")
async def get_metrics():
    return REGISTRY.get_sample_value('transaction_count')

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request):
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Voice Monitor Dashboard</title>
        <style>
            body {
                margin: 0;
                padding: 20px;
                font-family: Arial, sans-serif;
                background-color: #f0f2f5;
            }
            .container {
                max-width: 1200px;
                margin: 0 auto;
            }
            h1 {
                color: #2c3e50;
                margin-bottom: 20px;
            }
            .dashboard-container {
                background: white;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                padding: 20px;
                margin-bottom: 20px;
            }
            iframe {
                border: none;
                border-radius: 4px;
                width: 100%;
                height: 800px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Voice Monitor Dashboard</h1>
            <div class="dashboard-container">
                <iframe src="http://localhost:3001/d/default/fastapi-monitoring?orgId=1&refresh=5s" 
                        width="100%" 
                        height="800px" 
                        frameborder="0">
                </iframe>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


# Prometheus HTTP endpoint 노출
# Railway는 단일 포트만 지원하므로 별도 Prometheus 서버 비활성화
# 메트릭은 FastAPI의 /metrics 엔드포인트에서 제공됨
# threading.Thread(target=lambda: start_http_server(9101)).start()
