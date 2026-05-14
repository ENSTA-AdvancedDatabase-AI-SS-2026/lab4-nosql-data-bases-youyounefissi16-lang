/**
 * TP2 - Exercice 5 : $lookup et Données Référencées
 */

use("medical_db");

// ─── 5.1 : Dossier complet d'un patient (patients + analyses) ─────────────────
print("=== 5.1 : Dossier complet - Ahmed Bensalem ===");

const dossierComplet = db.patients.aggregate([
  { $match: { nom: "Bensalem", prenom: "Ahmed" } },
  {
    $lookup: {
      from: "analyses",
      localField: "_id",
      foreignField: "patient_id",
      as: "analyses_laboratoire"
    }
  },
  {
    $project: {
      cin: 1, nom: 1, prenom: 1,
      dateNaissance: 1,
      adresse: 1,
      groupeSanguin: 1,
      antecedents: 1,
      allergies: 1,
      nb_consultations: { $size: "$consultations" },
      derniereConsultation: { $arrayElemAt: ["$consultations", -1] },
      analyses_laboratoire: 1
    }
  }
]).toArray();

printjson(dossierComplet);


// ─── 5.2 : Patients avec glycémie > 1.26 g/L ─────────────────────────────────
print("\n=== 5.2 : Patients avec glycémie > 1.26 g/L ===");

const glycemieElevee = db.analyses.aggregate([
  {
    $match: {
      type: "Glycémie",
      "resultats.glycemie_jeun": { $gt: 1.26 }
    }
  },
  {
    $lookup: {
      from: "patients",
      localField: "patient_id",
      foreignField: "_id",
      as: "patient"
    }
  },
  { $unwind: "$patient" },
  {
    $project: {
      _id: 0,
      "patient.nom": 1,
      "patient.prenom": 1,
      "patient.adresse.wilaya": 1,
      date_analyse: "$date",
      glycemie_jeun: "$resultats.glycemie_jeun",
      HbA1c: "$resultats.HbA1c"
    }
  },
  { $sort: { glycemie_jeun: -1 } }
]).toArray();

printjson(glycemieElevee);


// ─── 5.3 : Taux d'analyses anormales par wilaya ───────────────────────────────
print("\n=== 5.3 : Taux d'analyses anormales par wilaya ===");

// Définition d'analyse "anormale" : glycémie > 1.10, Hb < 11, créatinine > 1.2
const statsParWilaya = db.analyses.aggregate([
  {
    $lookup: {
      from: "patients",
      localField: "patient_id",
      foreignField: "_id",
      as: "patient"
    }
  },
  { $unwind: "$patient" },
  {
    $addFields: {
      est_anormale: {
        $switch: {
          branches: [
            {
              case: { $and: [{ $eq: ["$type", "Glycémie"] }, { $gt: ["$resultats.glycemie_jeun", 1.10] }] },
              then: true
            },
            {
              case: { $and: [{ $eq: ["$type", "NFS"] }, { $lt: ["$resultats.hemoglobine", 11] }] },
              then: true
            },
            {
              case: { $and: [{ $eq: ["$type", "Créatinine"] }, { $gt: ["$resultats.creatinine", 1.2] }] },
              then: true
            }
          ],
          default: false
        }
      }
    }
  },
  {
    $group: {
      _id: "$patient.adresse.wilaya",
      total_analyses: { $sum: 1 },
      analyses_anormales: { $sum: { $cond: ["$est_anormale", 1, 0] } }
    }
  },
  {
    $addFields: {
      taux_anomalie_pct: {
        $round: [
          { $multiply: [{ $divide: ["$analyses_anormales", "$total_analyses"] }, 100] },
          1
        ]
      }
    }
  },
  { $sort: { taux_anomalie_pct: -1 } }
]).toArray();

printjson(statsParWilaya);
