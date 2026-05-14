-- TP3 - Exercice 4 : Compaction et Maintenance Cassandra
-- Use Case : SmartGrid DZ

USE smartgrid;

-- ─── 4.1 : Justification des stratégies de compaction ────────────────────────
--
-- TWCS (TimeWindowCompactionStrategy) → mesures_par_capteur, alertes_par_wilaya
--   ✅ Données d'IoT / séries temporelles : insertions dans la fenêtre temporelle courante
--   ✅ Les données anciennes ne sont jamais mises à jour → pas de conflits de compaction
--   ✅ Compacte par fenêtre de temps → fichiers SSTables propres par période
--   ✅ Expiration TTL : supprime efficacement des fenêtres entières
--   ❌ Ne pas utiliser si on fait des updates/deletes fréquents (= LCS)
--
-- STCS (SizeTieredCompactionStrategy) → défaut, bonne pour les writes intensifs
--   ✅ Simple, efficace pour les workloads write-heavy (ingestion massive)
--   ❌ Ne pas utiliser pour les séries temporelles (fragmentation temporelle)
--
-- LCS (LeveledCompactionStrategy) → agrégats_horaires
--   ✅ Bonne pour les reads-heavy avec peu d'espace disque
--   ✅ Garantit que 90% des lectures touchent 1 seul SSTable
--   ❌ Plus lente en écriture (réorganisation permanente)


-- ─── 4.2 : Configurer TWCS pour les mesures ──────────────────────────────────
-- compaction_window_unit : HOURS est idéal pour des données à TTL 90 jours
-- compaction_window_size : 1 → une fenêtre d'1 heure
-- → 1 SSTable par heure de données, efficient pour les TTL de 90j

ALTER TABLE mesures_par_capteur
WITH compaction = {
  'class': 'TimeWindowCompactionStrategy',
  'compaction_window_unit': 'HOURS',
  'compaction_window_size': 1
};

-- Pour alertes_par_wilaya (TTL 1 an) → fenêtre journalière
ALTER TABLE alertes_par_wilaya
WITH compaction = {
  'class': 'TimeWindowCompactionStrategy',
  'compaction_window_unit': 'DAYS',
  'compaction_window_size': 1
};

-- Pour agrégats_horaires (reads intensifs, peu d'écriture) → LCS
ALTER TABLE agregats_horaires
WITH compaction = {
  'class': 'LeveledCompactionStrategy',
  'sstable_size_in_mb': 160
};

-- Vérifier les stratégies appliquées :
DESCRIBE TABLE mesures_par_capteur;
DESCRIBE TABLE alertes_par_wilaya;
DESCRIBE TABLE agregats_horaires;


-- ─── 4.3 : Vérifier l'utilisation des TTL ────────────────────────────────────
-- Voir le TTL restant d'une ligne spécifique
-- (Remplacer par de vrais IDs de votre ingestion)
SELECT capteur_id, timestamp, tension_v,
       TTL(tension_v) AS secondes_avant_expiration
FROM mesures_par_capteur
WHERE capteur_id = <uuid_capteur>
  AND date_jour = toDate(now())
LIMIT 5;

-- Le TTL est par cellule dans Cassandra (pas par ligne entière)
-- TTL(tension_v) renvoie les secondes avant que la valeur disparaisse
-- 7 776 000 secondes = 90 jours

-- Calculer combien de lignes expirent dans les 7 prochains jours
-- (Impossible directement en CQL → à faire via cqlsh + nodetool ou Spark)
-- Alternative : interroger les lignes dont le timestamp est ancien
SELECT COUNT(*) FROM mesures_par_capteur
WHERE capteur_id = <uuid_capteur>
  AND date_jour = toDate(now()) - 83d   -- ≈ 90j - 7j = données qui expirent bientôt
LIMIT 10000;


-- ─── 4.4 : Identifier et corriger une partition "hot" ─────────────────────────
-- Détection via nodetool (depuis le serveur Cassandra) :
--   nodetool toppartitions smartgrid mesures_par_capteur 10000 10
--   → Affiche les 10 partitions les plus lues pendant 10 secondes

-- Hot partition = une partition reçoit disproportionnellement plus de trafic
-- Cas typiques :
--   1. capteur_id d'un capteur très fréquenté (ex: capteur de sous-station centrale)
--   2. date_jour = aujourd'hui (toutes les écritures vont vers la date courante)

-- Solution 1 : Bucketiser davantage (ex: (capteur_id, date_jour, heure))
--   → Divise chaque partition en 24 sous-partitions
--   PRIMARY KEY ((capteur_id, date_jour, heure_bucket), timestamp)

-- Solution 2 : Ajouter un "shard" numérique (1-N) à la clé de partition
--   PRIMARY KEY ((capteur_id, date_jour, shard), timestamp)
--   WHERE shard = random.randint(1, 8)  ← côté application
--   → Répartit les écritures sur 8 partitions, mais nécessite 8 lectures pour lire

-- Dans notre cas, (capteur_id, date_jour) est déjà un bon choix :
--   - 10 000 capteurs × 1 partition par jour = 10 000 partitions/jour
--   - Taille max ≈ 1440 lignes/partition (1 mesure/min) × 30 octets ≈ 43 KB << 100MB
--   - Pas de hot partition structurelle

-- Vérifier la taille d'une partition via nodetool (shell commande, pas CQL) :
-- docker exec -it nosql_cassandra nodetool cfstats smartgrid.mesures_par_capteur

