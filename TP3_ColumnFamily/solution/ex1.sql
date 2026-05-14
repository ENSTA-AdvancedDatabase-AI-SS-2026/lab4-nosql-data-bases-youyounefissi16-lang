-- TP3 - Exercice 1 : Schéma Cassandra
-- Use Case : SmartGrid DZ - IoT Électrique

-- ─── 1.1 : Créer le Keyspace ──────────────────────────────────────────────────
-- Pour le TP local (Docker single node) : replication_factor = 1
-- En production (3 nœuds) : utiliser NetworkTopologyStrategy avec factor 3

CREATE KEYSPACE IF NOT EXISTS smartgrid
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
}
AND durable_writes = true;

-- Production (décommenter pour cluster multi-nœuds) :
-- CREATE KEYSPACE IF NOT EXISTS smartgrid
-- WITH replication = {
--   'class': 'NetworkTopologyStrategy',
--   'datacenter1': 3
-- }
-- AND durable_writes = true;

USE smartgrid;


-- ─── 1.2 : Table mesures_par_capteur ──────────────────────────────────────────
-- Requête cible : "Toutes les mesures du capteur X entre T1 et T2"
--
-- Choix de la Partition Key : (capteur_id, date_jour)
--   → capteur_id seul risque de créer des "wide partitions" avec 10 000 mesures/jour
--   → On bucket par jour : max ~1440 lignes/partition (1 mesure/minute × 24h)
--   → Cela évite les hot partitions et respecte la limite de 100MB par partition
--
-- Clustering Key : timestamp DESC
--   → Les requêtes veulent les données les plus récentes en premier

DROP TABLE IF EXISTS mesures_par_capteur;
CREATE TABLE IF NOT EXISTS mesures_par_capteur (
  capteur_id   UUID,
  date_jour    DATE,        -- Bucket par jour pour éviter les wide partitions
  timestamp    TIMESTAMP,
  wilaya       TEXT,
  commune      TEXT,
  tension_v    FLOAT,
  courant_a    FLOAT,
  puissance_kw FLOAT,
  frequence_hz FLOAT,
  temperature  FLOAT,
  alerte       BOOLEAN,
  code_alerte  TEXT,
  PRIMARY KEY ((capteur_id, date_jour), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 7776000   -- 90 jours en secondes (90 × 24 × 3600)
  AND comment = 'Mesures IoT par capteur, bucketisées par jour. TTL 90j.';


-- ─── 1.3 : Table alertes_par_wilaya ───────────────────────────────────────────
-- Requête cible : "Alertes de la wilaya X le jour Y"
--
-- Partition Key : (wilaya, date_jour) → Lectures groupées par wilaya+jour
-- Clustering Key : timestamp DESC → Les plus récentes en premier
-- Note : gravite peut aussi être utilisé comme clustering key secondaire
--        pour trier par criticité, mais cela complique les requêtes → on laisse DESC

DROP TABLE IF EXISTS alertes_par_wilaya;
CREATE TABLE IF NOT EXISTS alertes_par_wilaya (
  wilaya       TEXT,
  date_jour    DATE,
  timestamp    TIMESTAMP,
  capteur_id   UUID,
  code_alerte  TEXT,
  description  TEXT,
  gravite      INT,   -- 1=info, 2=warning, 3=critique
  resolue      BOOLEAN,
  PRIMARY KEY ((wilaya, date_jour), timestamp, capteur_id)
) WITH CLUSTERING ORDER BY (timestamp DESC, capteur_id ASC)
  AND default_time_to_live = 31536000   -- 1 an (365 × 24 × 3600)
  AND comment = 'Alertes groupées par wilaya et jour. TTL 1 an.';


-- ─── 1.4 : Table agregats_horaires ────────────────────────────────────────────
-- Requête cible : "Consommation moyenne par heure pour le dashboard wilaya"
--
-- Partition Key : wilaya → Toutes les données d'une wilaya ensemble
-- Clustering Key : date_heure DESC → Dashboard affiche les dernières valeurs
-- Note : les agrégats sont pré-calculés (pattern materialized view)
--        → Mise à jour lors de l'ingestion, evite les scans complets

DROP TABLE IF EXISTS agregats_horaires;
CREATE TABLE IF NOT EXISTS agregats_horaires (
  wilaya            TEXT,
  date_heure        TIMESTAMP,    -- Tronquée à l'heure (ex: 2024-01-15 14:00:00)
  nb_capteurs       INT,
  puissance_moy_kw  FLOAT,
  puissance_max_kw  FLOAT,
  puissance_min_kw  FLOAT,
  nb_alertes        INT,
  PRIMARY KEY (wilaya, date_heure)
) WITH CLUSTERING ORDER BY (date_heure DESC)
  AND default_time_to_live = 157680000   -- 5 ans (5 × 365.25 × 24 × 3600)
  AND comment = 'Agrégats horaires pré-calculés par wilaya. TTL 5 ans.';


-- Vérification
DESCRIBE TABLES;

-- Résumé des choix
-- mesures_par_capteur : PK((capteur_id, date_jour), timestamp DESC)  → lookup par capteur + plage temps
-- alertes_par_wilaya  : PK((wilaya, date_jour), timestamp DESC)       → lookup par wilaya + jour
-- agregats_horaires   : PK(wilaya, date_heure DESC)                   → dashboard par wilaya

