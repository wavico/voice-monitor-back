from fastapi import FastAPI, Request
from kafka import KafkaProducer
import json
import tritonclient.grpc
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import start_http_server, Gauge, Counter, REGISTRY
import threading
import random
from fastapi import Body
from fastapi.middleware.cors import CORSMiddleware
import time

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

def triton_infer(data: dict):
    return {"inference": "dummy"}

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
        response = triton_infer(data)

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

# Prometheus HTTP endpoint 노출
threading.Thread(target=lambda: start_http_server(9101)).start()
