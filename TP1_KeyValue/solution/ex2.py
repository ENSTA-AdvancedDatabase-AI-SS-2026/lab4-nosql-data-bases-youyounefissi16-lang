"""
TP1 - Exercice 2 : Sessions utilisateur avec TTL (sliding expiration)
Use Case : ShopFast - Gestion des sessions
"""
import redis
import uuid
import json
import time

r = redis.Redis(host='localhost', port=6379, decode_responses=True)

SESSION_TTL = 30 * 60  # 30 minutes en secondes


def create_session(r, user_id: int, user_data: dict) -> str:
    """
    Créer une nouvelle session pour un utilisateur.
    Retourner le session_token (UUID).
    Clé : "session:{token}"
    TTL : 30 minutes
    """
    token = str(uuid.uuid4())
    session = {
        "user_id": str(user_id),
        "created_at": str(time.time()),
        **user_data
    }
    r.hset(f"session:{token}", mapping=session)
    r.expire(f"session:{token}", SESSION_TTL)
    # Indexer le token par user_id pour lookup inverse
    r.set(f"user_session:{user_id}", token, ex=SESSION_TTL)
    return token


def get_session(r, token: str) -> dict | None:
    """
    Récupérer une session par son token.
    Retourner None si expirée ou inexistante.
    NE PAS renouveler ici (utiliser renew_session pour ça).
    """
    data = r.hgetall(f"session:{token}")
    return data if data else None


def renew_session(r, token: str) -> bool:
    """
    Renouveler le TTL d'une session existante (sliding expiration).
    Retourner True si renouvelée, False si session introuvable.
    """
    key = f"session:{token}"
    if not r.exists(key):
        return False
    # Renouveler la session principale
    r.expire(key, SESSION_TTL)
    # Renouveler aussi l'index user → token
    user_id = r.hget(key, "user_id")
    if user_id:
        r.expire(f"user_session:{user_id}", SESSION_TTL)
    return True


def delete_session(r, token: str) -> bool:
    """
    Supprimer une session (logout).
    Retourner True si supprimée.
    """
    key = f"session:{token}"
    user_id = r.hget(key, "user_id")
    deleted = r.delete(key)
    if user_id:
        r.delete(f"user_session:{user_id}")
    return bool(deleted)


def get_session_ttl(r, token: str) -> int:
    """Retourner le TTL restant en secondes (-2 si n'existe pas)."""
    return r.ttl(f"session:{token}")


if __name__ == "__main__":
    r.flushdb()

    print("=== Test Sessions ===")
    token = create_session(r, 42, {"nom": "Ahmed", "email": "ahmed@shopfast.dz", "role": "client"})
    print(f"Session créée : {token[:8]}...")

    session = get_session(r, token)
    print(f"Session récupérée : {session}")
    print(f"TTL initial : {get_session_ttl(r, token)}s")

    time.sleep(1)
    renew_session(r, token)
    print(f"TTL après renouvellement : {get_session_ttl(r, token)}s")

    delete_session(r, token)
    print(f"Après suppression : {get_session(r, token)}")
