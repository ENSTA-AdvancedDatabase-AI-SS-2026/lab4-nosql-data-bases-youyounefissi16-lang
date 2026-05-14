"""
TP3 - Exercice 2 : Ingestion de données IoT
Use Case : SmartGrid DZ - 10 000 capteurs, 5 minutes de mesures
"""
from cassandra.cluster import Cluster
from cassandra.query import BatchStatement, BatchType
from cassandra.policies import DCAwareRoundRobinPolicy
import uuid
import random
from datetime import datetime, timedelta
import time

# Configuration
CASSANDRA_HOST = 'localhost'
KEYSPACE = 'smartgrid'
NB_CAPTEURS = 10000
MINUTES_HISTORIQUE = 5
BATCH_SIZE = 50  # Max recommandé par batch Cassandra

WILAYAS = ["Alger", "Oran", "Constantine", "Annaba", "Blida"]
COMMUNES = {
    "Alger": ["Bab Ezzouar", "Hydra", "El Harrach", "Dar El Beida"],
    "Oran": ["Bir El Djir", "Es Senia", "Arzew"],
    "Constantine": ["El Khroub", "Ain Smara", "Hamma Bouziane"],
    "Annaba": ["El Bouni", "El Hadjar", "Seraidi"],
    "Blida": ["Bougara", "Boufarik", "Larbaa"],
}

CODES_ALERTE = {
    "SURTEN": "Surtension détectée",
    "SSOTEN": "Sous-tension détectée",
    "SURCHA": "Surcharge détectée",
    "SURCH2": "Surchauffe équipement",
}


def connect():
    """Connexion au cluster Cassandra"""
    cluster = Cluster(
        [CASSANDRA_HOST],
        load_balancing_policy=DCAwareRoundRobinPolicy(local_dc='datacenter1')
    )
    session = cluster.connect(KEYSPACE)
    session.default_timeout = 30
    return session, cluster


def prepare_statements(session):
    """Préparer les statements une seule fois (performance)"""
    insert_mesure = session.prepare("""
        INSERT INTO mesures_par_capteur
            (capteur_id, date_jour, timestamp, wilaya, commune,
             tension_v, courant_a, puissance_kw, frequence_hz,
             temperature, alerte, code_alerte)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        USING TTL 7776000
    """)

    insert_alerte = session.prepare("""
        INSERT INTO alertes_par_wilaya
            (wilaya, date_jour, timestamp, capteur_id,
             code_alerte, description, gravite, resolue)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        USING TTL 31536000
    """)

    insert_agregat = session.prepare("""
        INSERT INTO agregats_horaires
            (wilaya, date_heure, nb_capteurs,
             puissance_moy_kw, puissance_max_kw, puissance_min_kw, nb_alertes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        USING TTL 157680000
    """)

    return insert_mesure, insert_alerte, insert_agregat


def generate_mesure(capteur_id, wilaya, commune, timestamp):
    """Générer une mesure réaliste pour un capteur"""
    tension_base = 220  # Volts (réseau algérien 220V/50Hz)

    # Anomalie aléatoire (5% de chance)
    has_anomaly = random.random() < 0.05
    if has_anomaly:
        tension = round(tension_base + random.choice([-25, 25]) + random.gauss(0, 3), 2)
        code = random.choice(list(CODES_ALERTE.keys()))
    else:
        tension = round(tension_base + random.gauss(0, 5), 2)
        code = None

    return {
        "capteur_id": capteur_id,
        "date_jour": timestamp.date(),
        "timestamp": timestamp,
        "wilaya": wilaya,
        "commune": commune,
        "tension_v": tension,
        "courant_a": round(random.uniform(0.5, 15.0), 2),
        "puissance_kw": round(random.uniform(0.1, 3.3), 3),
        "frequence_hz": round(50 + random.gauss(0, 0.1), 2),
        "temperature": round(random.uniform(20, 65), 1),
        "alerte": has_anomaly,
        "code_alerte": code,
    }


def insert_single(session, stmt_mesure, mesure: dict):
    """Insérer une seule mesure avec un prepared statement"""
    session.execute(stmt_mesure, (
        mesure["capteur_id"],
        mesure["date_jour"],
        mesure["timestamp"],
        mesure["wilaya"],
        mesure["commune"],
        mesure["tension_v"],
        mesure["courant_a"],
        mesure["puissance_kw"],
        mesure["frequence_hz"],
        mesure["temperature"],
        mesure["alerte"],
        mesure["code_alerte"],
    ))


def insert_batch(session, stmt_mesure, stmt_alerte, mesures: list):
    """
    Insérer un batch de mesures.
    - UNLOGGED BATCH pour les séries temporelles (même partition → efficace)
    - Batches de max BATCH_SIZE items
    """
    # Grouper par (capteur_id, date_jour) pour que chaque batch touche 1 partition
    # → LOGGED BATCH n'est utile que pour des partitions différentes
    batch = BatchStatement(batch_type=BatchType.UNLOGGED)
    alertes = []

    for mesure in mesures:
        batch.add(stmt_mesure, (
            mesure["capteur_id"],
            mesure["date_jour"],
            mesure["timestamp"],
            mesure["wilaya"],
            mesure["commune"],
            mesure["tension_v"],
            mesure["courant_a"],
            mesure["puissance_kw"],
            mesure["frequence_hz"],
            mesure["temperature"],
            mesure["alerte"],
            mesure["code_alerte"],
        ))

        if mesure["alerte"]:
            alertes.append(mesure)

    session.execute(batch)

    # Insérer les alertes séparément (table différente)
    if alertes:
        batch_alertes = BatchStatement(batch_type=BatchType.UNLOGGED)
        for m in alertes:
            code = m["code_alerte"]
            batch_alertes.add(stmt_alerte, (
                m["wilaya"],
                m["date_jour"],
                m["timestamp"],
                m["capteur_id"],
                code,
                CODES_ALERTE.get(code, "Anomalie détectée"),
                3 if code.startswith("SURCHA") else 2,  # gravité
                False,  # non résolue
            ))
        session.execute(batch_alertes)


def run_ingestion(session):
    """
    Générer et insérer NB_CAPTEURS × MINUTES_HISTORIQUE mesures.
    1. Générer les capteurs (ID aléatoires + assignation wilaya/commune)
    2. Pour chaque minute des MINUTES_HISTORIQUE dernières minutes
       → Insérer les mesures par batches de BATCH_SIZE
    3. Mesurer et afficher le débit
    """
    print(f"Démarrage ingestion : {NB_CAPTEURS:,} capteurs × {MINUTES_HISTORIQUE} min")
    print(f"Total attendu : {NB_CAPTEURS * MINUTES_HISTORIQUE:,} mesures")
    print(f"Taille des batches : {BATCH_SIZE}")
    print()

    stmt_mesure, stmt_alerte, stmt_agregat = prepare_statements(session)

    # Générer les capteurs une fois
    capteurs = []
    for _ in range(NB_CAPTEURS):
        wilaya = random.choice(WILAYAS)
        commune = random.choice(COMMUNES[wilaya])
        capteurs.append((uuid.uuid4(), wilaya, commune))

    now = datetime.now()
    total_inseres = 0
    start = time.time()

    for minute in range(MINUTES_HISTORIQUE):
        ts = now - timedelta(minutes=MINUTES_HISTORIQUE - minute)
        print(f"  Ingestion minute {minute + 1}/{MINUTES_HISTORIQUE} ({ts.strftime('%H:%M:%S')})...",
              end=" ", flush=True)

        t0 = time.time()
        # Traiter les capteurs par batches
        for i in range(0, len(capteurs), BATCH_SIZE):
            batch_capteurs = capteurs[i:i + BATCH_SIZE]
            mesures = [
                generate_mesure(cid, wilaya, commune, ts)
                for cid, wilaya, commune in batch_capteurs
            ]
            insert_batch(session, stmt_mesure, stmt_alerte, mesures)
            total_inseres += len(mesures)

        elapsed_min = time.time() - t0
        print(f"{NB_CAPTEURS / elapsed_min:,.0f} mesures/s")

    elapsed_total = time.time() - start
    print(f"\n✅ {total_inseres:,} mesures insérées en {elapsed_total:.1f}s")
    print(f"   Débit moyen  : {total_inseres / elapsed_total:,.0f} mesures/seconde")
    print(f"   Batches      : {total_inseres // BATCH_SIZE:,} (taille {BATCH_SIZE})")


def verify_ingestion(session):
    """Vérifier quelques statistiques après ingestion"""
    print("\n=== Vérification ===")
    from cassandra.query import SimpleStatement

    # Compter les alertes par wilaya
    for wilaya in WILAYAS:
        from datetime import date
        today = date.today()
        rows = session.execute(
            "SELECT COUNT(*) FROM alertes_par_wilaya WHERE wilaya = %s AND date_jour = %s",
            (wilaya, today)
        )
        count = rows.one()[0]
        print(f"  Alertes {wilaya} aujourd'hui : {count}")


if __name__ == "__main__":
    print("Connexion à Cassandra...")
    session, cluster = connect()

    try:
        run_ingestion(session)
        verify_ingestion(session)
    finally:
        cluster.shutdown()
