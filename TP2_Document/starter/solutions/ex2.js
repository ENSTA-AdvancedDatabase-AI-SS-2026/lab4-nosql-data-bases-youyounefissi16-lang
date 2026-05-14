/**
 * TP2 - Exercice 2 : Requêtes de Base MongoDB
 * Use Case : HealthCare DZ
 */

use("medical_db");

// ─── 2.1 : Patients diabétiques de plus de 50 ans à Alger ────────────────────
print("=== 2.1 : Patients diabétiques > 50 ans à Alger ===");

const cinquanteAnsAvant = new Date();
cinquanteAnsAvant.setFullYear(cinquanteAnsAvant.getFullYear() - 50);

const diabetiquesAlger = db.patients.find({
  "adresse.wilaya": "Alger",
  antecedents: { $regex: /Diabète/i },
  dateNaissance: { $lte: cinquanteAnsAvant }
}, {
  nom: 1, prenom: 1, dateNaissance: 1, antecedents: 1
}).toArray();

printjson(diabetiquesAlger);
print("Nombre:", diabetiquesAlger.length);


// ─── 2.2 : Patients allergiques Pénicilline avec ≥ 3 consultations ────────────
print("\n=== 2.2 : Allergiques Pénicilline avec ≥ 3 consultations ===");

const allergiquesConsultations = db.patients.find({
  allergies: "Pénicilline",
  $expr: { $gte: [{ $size: "$consultations" }, 3] }
}, {
  nom: 1, prenom: 1, allergies: 1,
  nb_consultations: { $size: "$consultations" }
}).toArray();

printjson(allergiquesConsultations);


// ─── 2.3 : Projection - Nom, prénom et dernière consultation ─────────────────
print("\n=== 2.3 : Projection - dernière consultation ===");

const projectionDerniereConsult = db.patients.aggregate([
  {
    $project: {
      nom: 1,
      prenom: 1,
      derniereConsultation: { $arrayElemAt: ["$consultations", -1] }
    }
  },
  { $limit: 5 }
]).toArray();

printjson(projectionDerniereConsult);


// ─── 2.4 : Patients sans antécédents, tension systolique > 140 ───────────────
print("\n=== 2.4 : Patients sans antécédents, tension systolique > 140 ===");

const sansTerrain = db.patients.find({
  antecedents: { $size: 0 },
  "consultations.tension.systolique": { $gt: 140 }
}, {
  nom: 1, prenom: 1, antecedents: 1, "consultations.tension": 1
}).toArray();

printjson(sansTerrain);


// ─── 2.5 : Recherche textuelle sur les diagnostics ───────────────────────────
print("\n=== 2.5 : Recherche textuelle - 'hypertension' ===");

// D'abord créer l'index text (idempotent)
db.patients.createIndex(
  { "consultations.diagnostic": "text", "consultations.notes": "text" },
  { name: "idx_text_diagnostics" }
);

const rechercheTexte = db.patients.find(
  { $text: { $search: "hypertension" } },
  { nom: 1, prenom: 1, score: { $meta: "textScore" } }
).sort({ score: { $meta: "textScore" } }).toArray();

printjson(rechercheTexte);
