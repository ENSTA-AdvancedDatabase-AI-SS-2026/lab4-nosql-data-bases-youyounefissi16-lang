-- TP3 - Exercice 3 : Requêtes CQL
-- Use Case : SmartGrid DZ

USE smartgrid;

-- ─── 3.1 : Mesures d'un capteur sur les 6 dernières heures ───────────────────
-- NOTE : Remplacer <uuid> par un vrai capteur_id de votre ingestion
-- La table est buckétisée par (capteur_id, date_jour), donc on spécifie les deux

SELECT capteur_id, timestamp, tension_v, courant_a, puissance_kw, alerte
FROM mesures_par_capteur
WHERE capteur_id = <uuid_capteur>
  AND date_jour = toDate(now())
  AND timestamp >= dateOf(now()) - 6h   -- CQL supporte les durées relatives
ORDER BY timestamp DESC;

-- Si la plage croise minuit (hier/aujourd'hui), faire 2 requêtes et merger côté app :
-- SELECT ... WHERE capteur_id = ? AND date_jour = toDate(now()) AND timestamp >= ?;
-- SELECT ... WHERE capteur_id = ? AND date_jour = toDate(now()) - 1d AND timestamp >= ?;


-- ─── 3.2 : Dernière mesure de chaque capteur d'une wilaya ────────────────────
-- Cassandra ne supporte pas GROUP BY arbitraire
-- Approche : si on connaît les capteur_ids, faire LIMIT 1 par capteur
-- En pratique : maintenir une table dédiée "derniere_mesure_par_capteur"
-- ou utiliser une Materialized View (bonus TP3)

-- Exemple pour un capteur connu :
SELECT capteur_id, timestamp, tension_v, puissance_kw, alerte
FROM mesures_par_capteur
WHERE capteur_id = <uuid_capteur>
  AND date_jour = toDate(now())
ORDER BY timestamp DESC
LIMIT 1;


-- ─── 3.3 : Capteurs en alerte dans la wilaya "Alger" aujourd'hui ─────────────
SELECT wilaya, timestamp, capteur_id, code_alerte, description, gravite
FROM alertes_par_wilaya
WHERE wilaya = 'Alger'
  AND date_jour = toDate(now())
ORDER BY timestamp DESC;

-- Compter les alertes du jour
SELECT COUNT(*)
FROM alertes_par_wilaya
WHERE wilaya = 'Alger'
  AND date_jour = toDate(now());


-- ─── 3.4 : Consommation totale par heure sur une journée ─────────────────────
-- Utiliser la table des agrégats pré-calculés
SELECT wilaya, date_heure, nb_capteurs,
       puissance_moy_kw, puissance_max_kw, puissance_min_kw, nb_alertes
FROM agregats_horaires
WHERE wilaya = 'Alger'
ORDER BY date_heure DESC
LIMIT 24;   -- 24 dernières heures


-- ─── 3.5 : Détection d'anomalie : tension hors plage 200V-240V ───────────────
-- ATTENTION : La table mesures_par_capteur est partitionnée par capteur_id
-- Une requête sans capteur_id nécessiterait un ALLOW FILTERING → déconseillé
-- Solution correcte : maintenir une table "alertes" déjà filtrée

-- Requête correcte (sur la table dédiée) :
SELECT wilaya, timestamp, capteur_id, code_alerte
FROM alertes_par_wilaya
WHERE wilaya = 'Alger'
  AND date_jour = toDate(now())
  AND code_alerte IN ('SURTEN', 'SSOTEN')
ORDER BY timestamp DESC;

-- Mauvaise approche à ÉVITER en production :
-- SELECT * FROM mesures_par_capteur
-- WHERE tension_v < 200 OR tension_v > 240
-- ALLOW FILTERING;   ← scan complet, dangereux avec des millions de lignes


-- ─── 3.6 : Top 10 capteurs les plus actifs cette semaine ─────────────────────
-- Cassandra ne peut pas faire un COUNT + ORDER sur des partitions différentes
-- Solution pattern : table de compteurs dédiée (counter table)

-- Exemple de table compteur (à créer si besoin) :
-- CREATE TABLE nb_mesures_capteur (
--   capteur_id UUID,
--   nb_mesures COUNTER,
--   PRIMARY KEY (capteur_id)
-- );
-- UPDATE nb_mesures_capteur SET nb_mesures = nb_mesures + 1 WHERE capteur_id = ?;

-- Pour ce TP, on peut lire les données de la semaine d'un capteur connu :
SELECT capteur_id, date_jour, COUNT(*) AS nb_mesures
FROM mesures_par_capteur
WHERE capteur_id = <uuid_capteur>
  AND date_jour >= toDate(now()) - 7d
GROUP BY capteur_id, date_jour;


-- ─── 3.7 : ALLOW FILTERING — Pourquoi l'éviter ? ─────────────────────────────
-- MAUVAIS exemple :
-- SELECT * FROM mesures_par_capteur WHERE wilaya = 'Alger' ALLOW FILTERING;
-- → Cassandra doit scanner TOUTES les partitions (= tous les capteurs)
--   et filtrer côté coordonnateur. O(N) sur le nombre de lignes total.
--   En production avec des millions de lignes : timeout garanti.

-- BONNE approche : créer une table qui répond exactement à la question
-- Table alertes_par_wilaya → filtre par wilaya sans ALLOW FILTERING car
-- wilaya EST dans la partition key → lecture de seulement les partitions concernées

SELECT wilaya, timestamp, capteur_id, code_alerte
FROM alertes_par_wilaya
WHERE wilaya = 'Alger'
  AND date_jour = toDate(now());
-- → O(1) : 1 partition exacte lue, pas de scan complet
