
/**
 * TP2 - Exercice 4 : Index et Optimisation
 */

use("medical_db");

// ─── 4.1 : Créer les index appropriés ────────────────────────────────────────

// Index 1 : Recherche fréquente par wilaya + antécédents
// Composé : wilaya d'abord (haute cardinalité groupée), puis antécédents
db.patients.createIndex(
  { "adresse.wilaya": 1, antecedents: 1 },
  { name: "idx_wilaya_antecedents" }
);
print("Index 1 créé : wilaya + antécédents");

// Index 2 : Recherche par date de consultation (pour les requêtes temporelles)
// Multikey index : automatiquement appliqué car consultations est un tableau
db.patients.createIndex(
  { "consultations.date": -1 },
  { name: "idx_consultations_date" }
);
print("Index 2 créé : consultations.date DESC");

// Index 3 : Texte sur diagnostics pour recherche full-text
db.patients.createIndex(
  { "consultations.diagnostic": "text", "consultations.notes": "text" },
  { name: "idx_text_diagnostics", weights: { "consultations.diagnostic": 10, "consultations.notes": 1 } }
);
print("Index 3 créé : text search sur diagnostics");

// Index 4 : Analyses par patient (pour les $lookup)
db.analyses.createIndex(
  { patient_id: 1, date: -1 },
  { name: "idx_analyses_patient_date" }
);
print("Index 4 créé : analyses par patient + date");

// Index 5 : Allergies (fréquemment requêtées pour la sécurité)
db.patients.createIndex(
  { allergies: 1 },
  { name: "idx_allergies" }
);
print("Index 5 créé : allergies");


// ─── 4.2 : Comparer avec explain() ────────────────────────────────────────────
print("\n=== Comparaison explain() - requête par wilaya + antécédents ===");

const requeteTest = {
  "adresse.wilaya": "Alger",
  antecedents: "Diabète type 2"
};

const statsAvec = db.patients.find(requeteTest).explain("executionStats");

print("\nAvec index idx_wilaya_antecedents :");
print("  Stratégie         :", statsAvec.queryPlanner.winningPlan.stage);
print("  Docs examinés     :", statsAvec.executionStats.totalDocsExamined);
print("  Docs retournés    :", statsAvec.executionStats.nReturned);
print("  Temps exécution   :", statsAvec.executionStats.executionTimeMillis, "ms");

// Pour voir la différence, forcer un COLLSCAN en utilisant hint
const statsForce = db.patients.find(requeteTest).hint({ $natural: 1 }).explain("executionStats");
print("\nSans index (COLLSCAN forcé) :");
print("  Stratégie         :", statsForce.queryPlanner.winningPlan.stage);
print("  Docs examinés     :", statsForce.executionStats.totalDocsExamined);
print("  Docs retournés    :", statsForce.executionStats.nReturned);
print("  Temps exécution   :", statsForce.executionStats.executionTimeMillis, "ms");


// ─── 4.3 : Index composé optimal pour requête complexe ────────────────────────
// Requête complexe : patients diabétiques à Alger, triés par date de dernière consultation
// Ordre optimal des champs dans un index composé : Equality → Sort → Range
db.patients.createIndex(
  { "adresse.wilaya": 1, antecedents: 1, "consultations.date": -1 },
  { name: "idx_wilaya_antecedents_date" }
);
print("\nIndex 4.3 créé : wilaya + antécédents + date consultation");
print("Explication : wilaya (equality) → antécédents (equality) → date (sort)");


// ─── 4.4 : Index TTL pour archivage des analyses ─────────────────────────────
// Expirer les analyses de plus de 5 ans (5 * 365.25 * 24 * 3600 secondes)
const CINQ_ANS_SECONDES = Math.floor(5 * 365.25 * 24 * 3600);  // 157 788 000 s

// Note : TTL index fonctionne sur un champ Date, supprime le document entier
db.analyses.createIndex(
  { date: 1 },
  {
    expireAfterSeconds: CINQ_ANS_SECONDES,
    name: "idx_ttl_analyses_5ans"
  }
);
print("\nIndex TTL créé : analyses expirées après 5 ans");
print("expireAfterSeconds =", CINQ_ANS_SECONDES, "(" + (CINQ_ANS_SECONDES / 86400 / 365.25).toFixed(1) + " ans)");

// Vérifier tous les index créés
print("\n=== Index sur patients ===");
printjson(db.patients.getIndexes().map(i => ({ name: i.name, key: i.key })));

print("\n=== Index sur analyses ===");
printjson(db.analyses.getIndexes().map(i => ({ name: i.name, key: i.key })));
