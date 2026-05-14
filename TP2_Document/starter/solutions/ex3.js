
/**
 * TP2 - Exercice 3 : Pipelines d'Agrégation
 * Use Case : Statistiques médicales HealthCare DZ
 */

use("medical_db");

// ─── 3.1 : Distribution des diagnostics par wilaya ────────────────────────────
print("=== 3.1 : Top diagnostics par wilaya ===");

const diagParWilaya = db.patients.aggregate([
  { $unwind: "$consultations" },
  {
    $group: {
      _id: {
        wilaya: "$adresse.wilaya",
        diagnostic: "$consultations.diagnostic"
      },
      count: { $sum: 1 }
    }
  },
  { $sort: { "count": -1 } },
  {
    $project: {
      _id: 0,
      wilaya: "$_id.wilaya",
      diagnostic: "$_id.diagnostic",
      count: 1
    }
  },
  { $limit: 20 }
]).toArray();

printjson(diagParWilaya);


// ─── 3.2 : Médicament le plus prescrit par spécialité ─────────────────────────
print("\n=== 3.2 : Top médicaments par spécialité ===");

const medsParSpecialite = db.patients.aggregate([
  { $unwind: "$consultations" },
  { $unwind: "$consultations.medicaments" },
  {
    $group: {
      _id: {
        specialite: "$consultations.medecin.specialite",
        medicament: "$consultations.medicaments.nom"
      },
      nb_prescriptions: { $sum: 1 }
    }
  },
  { $sort: { nb_prescriptions: -1 } },
  // Garder le top 1 par spécialité
  {
    $group: {
      _id: "$_id.specialite",
      topMedicament: { $first: "$_id.medicament" },
      nbPrescriptions: { $first: "$nb_prescriptions" }
    }
  },
  { $sort: { "_id": 1 } }
]).toArray();

printjson(medsParSpecialite);


// ─── 3.3 : Évolution mensuelle des consultations ──────────────────────────────
print("\n=== 3.3 : Consultations par mois (12 derniers mois) ===");

const unAnAvant = new Date();
unAnAvant.setFullYear(unAnAvant.getFullYear() - 1);

const evolutionMensuelle = db.patients.aggregate([
  { $unwind: "$consultations" },
  {
    $match: {
      "consultations.date": { $gte: unAnAvant }
    }
  },
  {
    $group: {
      _id: {
        annee: { $year: "$consultations.date" },
        mois: { $month: "$consultations.date" }
      },
      nb_consultations: { $sum: 1 }
    }
  },
  { $sort: { "_id.annee": 1, "_id.mois": 1 } },
  {
    $project: {
      _id: 0,
      periode: {
        $concat: [
          { $toString: "$_id.annee" },
          "-",
          { $cond: [{ $lt: ["$_id.mois", 10] }, { $concat: ["0", { $toString: "$_id.mois" }] }, { $toString: "$_id.mois" }] }
        ]
      },
      nb_consultations: 1
    }
  }
]).toArray();

printjson(evolutionMensuelle);


// ─── 3.4 : Patients à risque multiple ────────────────────────────────────────
print("\n=== 3.4 : Profil patients à risque élevé ===");

const aujourdhui = new Date();
const soixanteAnsAvant = new Date(aujourdhui);
soixanteAnsAvant.setFullYear(soixanteAnsAvant.getFullYear() - 60);

const patientsRisque = db.patients.aggregate([
  {
    $match: {
      antecedents: { $all: ["Diabète type 2", "HTA"] },
      dateNaissance: { $lte: soixanteAnsAvant }  // > 60 ans
    }
  },
  {
    $addFields: {
      age: {
        $floor: {
          $divide: [
            { $subtract: [new Date(), "$dateNaissance"] },
            1000 * 60 * 60 * 24 * 365.25
          ]
        }
      },
      nb_consultations: { $size: "$consultations" }
    }
  },
  {
    $group: {
      _id: null,
      nb_patients_risque: { $sum: 1 },
      age_moyen: { $avg: "$age" },
      consultations_moyennes: { $avg: "$nb_consultations" },
      patients: {
        $push: {
          nom: "$nom",
          prenom: "$prenom",
          age: "$age",
          antecedents: "$antecedents"
        }
      }
    }
  },
  {
    $project: {
      _id: 0,
      nb_patients_risque: 1,
      age_moyen: { $round: ["$age_moyen", 1] },
      consultations_moyennes: { $round: ["$consultations_moyennes", 1] },
      patients: 1
    }
  }
]).toArray();

printjson(patientsRisque);


// ─── 3.5 : Rapport médecins ───────────────────────────────────────────────────
print("\n=== 3.5 : Top 5 médecins & taux de ré-consultation ===");

const rapportMedecins = db.patients.aggregate([
  { $unwind: "$consultations" },
  {
    $group: {
      _id: {
        medecin: "$consultations.medecin.nom",
        specialite: "$consultations.medecin.specialite"
      },
      total_consultations: { $sum: 1 },
      patients_uniques: { $addToSet: "$_id" }
    }
  },
  {
    $addFields: {
      nb_patients_uniques: { $size: "$patients_uniques" },
      // Taux de ré-consultation = (total - uniques) / uniques * 100
      taux_reconsultation: {
        $cond: [
          { $gt: [{ $size: "$patients_uniques" }, 0] },
          {
            $round: [
              {
                $multiply: [
                  {
                    $divide: [
                      { $subtract: ["$total_consultations", { $size: "$patients_uniques" }] },
                      { $size: "$patients_uniques" }
                    ]
                  },
                  100
                ]
              },
              1
            ]
          },
          0
        ]
      }
    }
  },
  {
    $project: {
      _id: 0,
      medecin: "$_id.medecin",
      specialite: "$_id.specialite",
      total_consultations: 1,
      nb_patients_uniques: 1,
      taux_reconsultation_pct: "$taux_reconsultation"
    }
  },
  { $sort: { total_consultations: -1 } },
  { $limit: 5 }
]).toArray();

printjson(rapportMedecins);
