"""
TP5 - Benchmark Comparatif NoSQL
Redis vs MongoDB vs Cassandra vs Neo4j
"""
import time
import statistics
import threading
from typing import Callable
import redis
from pymongo import MongoClient, InsertOne
from cassandra.cluster import Cluster


# ─── UTIL ───────────────────────────────────────────────

def measure_latency(fn: Callable, iterations: int = 1000) -> dict:
    latencies = []

    for _ in range(iterations):
        start = time.perf_counter()
        fn()
        latencies.append((time.perf_counter() - start) * 1000)

    latencies.sort()

    return {
        "mean_ms": statistics.mean(latencies),
        "p50_ms": latencies[int(0.50 * len(latencies))],
        "p95_ms": latencies[int(0.95 * len(latencies))],
        "p99_ms": latencies[int(0.99 * len(latencies))],
        "max_ms": max(latencies),
        "throughput_rps": 1000 / statistics.mean(latencies)
    }


def print_results(name: str, results: dict):
    print(f"\n{'='*50}")
    print(f" {name}")
    print(f"{'='*50}")
    for k, v in results.items():
        print(f"{k:20s}: {v:.2f}")


# ─── REDIS WRITE ───────────────────────────────────────────────

def benchmark_write_redis(n: int = 100_000):
    r = redis.Redis(host='localhost', port=6379)
    r.flushdb()

    pipe = r.pipeline()

    def write():
        for i in range(n):
            pipe.set(f"user:{i}", f"data:{i}")

            if i % 1000 == 0:
                pipe.execute()
        pipe.execute()

    results = measure_latency(write, iterations=1)
    print_results("Redis WRITE (Pipeline)", results)


# ─── MONGODB WRITE ─────────────────────────────────────────────

def benchmark_write_mongodb(n: int = 100_000):
    client = MongoClient("mongodb://admin:admin123@localhost:27017/")
    db = client["benchmark"]
    col = db["users"]
    col.drop()

    def write():
        ops = [
            InsertOne({"_id": i, "data": f"data:{i}"})
            for i in range(n)
        ]
        col.bulk_write(ops, ordered=False)

    results = measure_latency(write, iterations=1)
    print_results("MongoDB WRITE (Bulk)", results)


# ─── CASSANDRA WRITE ───────────────────────────────────────────

def benchmark_write_cassandra(n: int = 100_000):
    cluster = Cluster(["localhost"])
    session = cluster.connect("benchmark")

    prepared = session.prepare(
        "INSERT INTO users (id, data) VALUES (?, ?)"
    )

    def write():
        from cassandra.query import BatchStatement, BatchType

        batch = BatchStatement(batch_type=BatchType.UNLOGGED)
        count = 0

        for i in range(n):
            batch.add(prepared, (i, f"data:{i}"))
            count += 1

            if count == 50:
                session.execute(batch)
                batch = BatchStatement(batch_type=BatchType.UNLOGGED)
                count = 0

        if count > 0:
            session.execute(batch)

    results = measure_latency(write, iterations=1)
    print_results("Cassandra WRITE (Batch)", results)


# ─── READ BENCHMARKS ───────────────────────────────────────────

def benchmark_read_redis():
    r = redis.Redis(host='localhost', port=6379)

    def read():
        r.get("user:5000")

    results = measure_latency(read, iterations=1000)
    print_results("Redis READ (GET)", results)


def benchmark_read_mongodb():
    client = MongoClient("mongodb://admin:admin123@localhost:27017/")
    col = client["benchmark"]["users"]

    def read():
        col.find_one({"_id": 5000})

    results = measure_latency(read, iterations=1000)
    print_results("MongoDB READ (find_one)", results)


# ─── CONCURRENT BENCHMARK ───────────────────────────────────────

def benchmark_concurrent(db_fn: Callable, n_clients: int = 50, requests_per_client: int = 200):
    latencies = []

    def worker():
        for _ in range(requests_per_client):
            start = time.perf_counter()
            db_fn()
            latencies.append((time.perf_counter() - start) * 1000)

    threads = []

    start_global = time.time()

    for _ in range(n_clients):
        t = threading.Thread(target=worker)
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    total_time = time.time() - start_global

    latencies.sort()

    results = {
        "mean_ms": statistics.mean(latencies),
        "p95_ms": latencies[int(0.95 * len(latencies))],
        "max_ms": max(latencies),
        "throughput_rps": len(latencies) / total_time
    }

    print_results("CONCURRENT LOAD TEST", results)


# ─── MAIN ───────────────────────────────────────────────────────

if __name__ == "__main__":
    print("🚀 Benchmark NoSQL - Redis vs MongoDB vs Cassandra")

    N = 10000  # safe default

    print("\n📝 WRITE BENCHMARKS")
    benchmark_write_redis(N)
    benchmark_write_mongodb(N)
    benchmark_write_cassandra(N)

    print("\n📖 READ BENCHMARKS")
    benchmark_read_redis()
    benchmark_read_mongodb()

    print("\n⚡ CONCURRENCY TEST")
    benchmark_concurrent(lambda: None, n_clients=50, requests_per_client=200)

    print("\n✅ Benchmark terminé")
