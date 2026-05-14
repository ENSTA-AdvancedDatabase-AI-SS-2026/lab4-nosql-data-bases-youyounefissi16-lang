"""
TP1 - Exercice 5 : Pipeline & Transactions Redis
Use Case : Commande atomique ShopFast
"""
import redis
import time
import json

r = redis.Redis(host='localhost', port=6379, decode_responses=True)


def bulk_insert_products(r, products: list) -> float:
    """
    Insérer plusieurs produits en utilisant un pipeline Redis.
    Retourner le temps d'exécution en secondes.
    """
    start = time.time()
    pipe = r.pipeline()
    for product in products:
        pid = product["id"]
        pipe.hset(f"product:{pid}", mapping=product)
        # Ajouter au Sorted Set de prix pour les range queries
        pipe.zadd("products:by_price", {str(pid): float(product.get("price", 0))})
        # Ajouter à la catégorie
        if "category" in product:
            pipe.sadd(f"category:{product['category']}", str(pid))
    pipe.execute()
    return time.time() - start


def place_order_atomic(r, user_id: int, cart: dict) -> dict:
    """
    Passer une commande de manière atomique avec MULTI/EXEC.
    cart = {"product_id": quantity, ...}

    Opérations atomiques :
    1. Décrémenter le stock de chaque produit
    2. Vider le panier
    3. Enregistrer la commande
    4. Mettre à jour le leaderboard des ventes

    Retourner {"success": True, "order_id": "..."} ou {"success": False, "error": "..."}
    """
    import uuid
    order_id = str(uuid.uuid4())[:8].upper()

    # Vérifier d'abord le stock (hors transaction)
    for product_id, qty in cart.items():
        stock = r.hget(f"product:{product_id}", "stock")
        if stock is None:
            return {"success": False, "error": f"Produit {product_id} introuvable"}
        if int(stock) < qty:
            return {"success": False, "error": f"Stock insuffisant pour produit {product_id}"}

    # Transaction atomique
    pipe = r.pipeline(transaction=True)
    try:
        pipe.watch(*[f"product:{pid}" for pid in cart.keys()])
        pipe.multi()

        for product_id, qty in cart.items():
            # Décrémenter le stock
            pipe.hincrby(f"product:{product_id}", "stock", -qty)
            # Mettre à jour le leaderboard
            pipe.zincrby("leaderboard:sales", qty, str(product_id))

        # Vider le panier
        pipe.delete(f"cart:{user_id}")

        # Enregistrer la commande
        order_data = json.dumps({
            "order_id": order_id,
            "user_id": user_id,
            "items": cart,
            "timestamp": time.time()
        })
        pipe.lpush(f"orders:{user_id}", order_data)
        pipe.expire(f"orders:{user_id}", 86400 * 365)  # 1 an

        pipe.execute()
        return {"success": True, "order_id": order_id}

    except redis.WatchError:
        return {"success": False, "error": "Conflit de concurrent, réessayez"}
    finally:
        pipe.reset()


def compare_with_without_pipeline(r, n: int = 1000):
    """Comparer les temps avec et sans pipeline."""
    # Sans pipeline
    r.flushdb()
    start = time.time()
    for i in range(n):
        r.set(f"key:{i}", f"value:{i}")
    t_without = time.time() - start

    # Avec pipeline
    r.flushdb()
    start = time.time()
    pipe = r.pipeline()
    for i in range(n):
        pipe.set(f"key:{i}", f"value:{i}")
    pipe.execute()
    t_with = time.time() - start

    print(f"\n=== Pipeline vs Sans pipeline ({n} opérations) ===")
    print(f"  Sans pipeline : {t_without:.3f}s")
    print(f"  Avec pipeline : {t_with:.3f}s")
    print(f"  Accélération  : ×{t_without/t_with:.1f}")


if __name__ == "__main__":
    r.flushdb()

    # Insérer des produits en bulk
    products = [
        {"id": i, "name": f"Produit {i}", "price": str(i * 1000),
         "category": ["phones", "laptops", "audio"][i % 3], "stock": "20"}
        for i in range(1, 21)
    ]
    elapsed = bulk_insert_products(r, products)
    print(f"✅ {len(products)} produits insérés en {elapsed*1000:.1f}ms")

    # Simuler un panier et une commande
    user_id = 42
    cart = {1: 2, 5: 1, 10: 3}
    for pid, qty in cart.items():
        r.hincrby(f"cart:{user_id}", str(pid), qty)

    print(f"\nPanier avant : {r.hgetall(f'cart:{user_id}')}")
    result = place_order_atomic(r, user_id, cart)
    print(f"Résultat commande : {result}")
    print(f"Panier après : {r.hgetall(f'cart:{user_id}')}")
    print(f"Stock produit 1 après : {r.hget('product:1', 'stock')}")

    compare_with_without_pipeline(r, 1000)
