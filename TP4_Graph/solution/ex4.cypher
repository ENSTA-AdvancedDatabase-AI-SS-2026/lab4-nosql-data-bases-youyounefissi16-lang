// ============================================================
// EXERCICE 4 — Requêtes Avancées (6 pts)
// Fichier : starter/ex4_advanced.cypher
// ============================================================

// --------------------------------------------------
// 4.1 Trouver un tuteur
// "Étudiant en Master qui maîtrise Python et a eu >14/20 en BDD"
// --------------------------------------------------

MATCH (tuteur:Etudiant)
WHERE tuteur.annee = "Master"
  AND (tuteur)-[:MAITRISE {niveau: "Avancé"}]->(:Competence {nom: "Python"})

// Vérifier la note en BDD
MATCH (tuteur)-[s:SUIT]->(c:Cours {code: "INFO401"})
WHERE s.note > 14

RETURN tuteur.prenom, tuteur.nom, tuteur.universite, tuteur.filiere,
       s.note AS note_bdd,
       tuteur.ville AS ville
ORDER BY s.note DESC;

// Version plus souple (Python à tout niveau >= Intermédiaire)
MATCH (tuteur:Etudiant)-[m:MAITRISE]->(comp:Competence {nom: "Python"})
WHERE tuteur.annee = "Master"
  AND m.niveau IN ["Intermédiaire", "Avancé", "Expert"]
MATCH (tuteur)-[s:SUIT]->(c:Cours {code: "INFO401"})
WHERE s.note > 14
RETURN tuteur.prenom, tuteur.nom, tuteur.universite,
       m.niveau AS niveau_python, s.note AS note_bdd
ORDER BY s.note DESC, m.niveau;


// --------------------------------------------------
// 4.2 Réseau alumni dans une entreprise
// "Qui de mon réseau (jusqu'à 3 sauts) travaille chez Sonatrach ?"
// --------------------------------------------------

MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH path = (moi)-[:CONNAIT*1..3]-(alumni:Etudiant)-[:A_STAGE_CHEZ]->(ent:Entreprise {nom: "Sonatrach"})
WITH moi, alumni, ent, path, length(path) AS distance_reseau

RETURN alumni.prenom, alumni.nom, alumni.universite, alumni.filiere,
       distance_reseau,
       [n IN nodes(path)[1..-1] WHERE n:Etudiant | n.prenom] AS intermediaires,
       ent.nom AS entreprise, ent.secteur, ent.ville
ORDER BY distance_reseau, alumni.nom;

// Version avec détails du stage
MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH path = (moi)-[:CONNAIT*1..3]-(alumni:Etudiant)-[stage:A_STAGE_CHEZ]->(ent:Entreprise {nom: "Sonatrach"})
RETURN alumni.prenom, alumni.nom,
       stage.annee AS annee_stage,
       stage.duree_mois AS duree_mois,
       length(path) AS distance_reseau,
       ent.secteur, ent.ville
ORDER BY distance_reseau, stage.annee DESC;


// --------------------------------------------------
// 4.3 Détection de ponts
// Quels étudiants connectent des communautés isolées ?
// --------------------------------------------------

// Méthode : Betweenness Centrality avec GDS
CALL gds.graph.project(
  'reseau-ponts',
  'Etudiant',
  {
    CONNAIT: {
      orientation: 'UNDIRECTED'
    }
  }
) YIELD graphName, nodeCount, relationshipCount;

// Calculer la betweenness centrality
CALL gds.betweenness.stream('reseau-ponts')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS etudiant, score
WHERE score > 0
RETURN etudiant.prenom, etudiant.nom, etudiant.universite,
       score AS score_betweenness
ORDER BY score DESC
LIMIT 10;

// Alternative sans GDS : étudiants avec amis dans des universités différentes
MATCH (e:Etudiant)-[:CONNAIT]-(ami:Etudiant)
WHERE e.universite <> ami.universite
WITH e, count(DISTINCT ami.universite) AS nb_universites_connectees,
     collect(DISTINCT ami.universite) AS universites
WHERE nb_universites_connectees >= 2
RETURN e.prenom, e.nom, e.universite,
       nb_universites_connectees,
       universites AS ponts_vers
ORDER BY nb_universites_connectees DESC;

// Nettoyage
CALL gds.graph.drop('reseau-ponts') YIELD graphName;


// --------------------------------------------------
// 4.4 Analyse temporelle
// Croissance du réseau : nouvelles connexions par mois
// --------------------------------------------------

// Nombre de nouvelles connexions par mois (basé sur la propriété 'depuis')
MATCH ()-[c:CONNAIT]->()
WHERE c.depuis IS NOT NULL
WITH c.depuis AS annee, count(c) AS nouvelles_connexions
RETURN annee, nouvelles_connexions
ORDER BY annee;

// Version plus détaillée : si on a une date complète (format YYYY-MM)
MATCH ()-[c:CONNAIT]->()
WHERE c.depuis IS NOT NULL
WITH toString(c.depuis) + "-01" AS mois, count(c) AS nouvelles_connexions
RETURN mois, nouvelles_connexions
ORDER BY mois;

// Croissance cumulative du réseau
MATCH ()-[c:CONNAIT]->()
WHERE c.depuis IS NOT NULL
WITH c.depuis AS annee, count(c) AS nouvelles_connexions
ORDER BY annee
WITH collect({annee: annee, count: nouvelles_connexions}) AS data
UNWIND range(0, size(data)-1) AS i
RETURN data[i].annee AS annee,
       data[i].count AS nouvelles_connexions,
       reduce(s = 0, j IN range(0, i) | s + data[j].count) AS total_cumule;

// Évolution par université
MATCH (e1:Etudiant)-[c:CONNAIT]->(e2:Etudiant)
WHERE c.depuis IS NOT NULL
WITH c.depuis AS annee, e1.universite AS universite, count(c) AS connexions
RETURN annee, universite, connexions
ORDER BY annee, connexions DESC;


// --------------------------------------------------
// 4.5 Score de similarité
// Étudiants les plus similaires à Ahmed (cours, compétences, clubs)
// Utiliser le coefficient de Jaccard
// --------------------------------------------------

MATCH (ahmed:Etudiant {prenom: "Ahmed"})
MATCH (autre:Etudiant)
WHERE autre <> ahmed

// Cours en commun
OPTIONAL MATCH (ahmed)-[:SUIT]->(c1:Cours)
WITH ahmed, autre, collect(DISTINCT c1.code) AS ahmed_cours

OPTIONAL MATCH (autre)-[:SUIT]->(c2:Cours)
WITH ahmed, autre, ahmed_cours, collect(DISTINCT c2.code) AS autre_cours

// Compétences en commun
OPTIONAL MATCH (ahmed)-[:MAITRISE]->(comp1:Competence)
WITH ahmed, autre, ahmed_cours, autre_cours, collect(DISTINCT comp1.nom) AS ahmed_comp

OPTIONAL MATCH (autre)-[:MAITRISE]->(comp2:Competence)
WITH ahmed, autre, ahmed_cours, autre_cours, ahmed_comp, collect(DISTINCT comp2.nom) AS autre_comp

// Clubs en commun
OPTIONAL MATCH (ahmed)-[:MEMBRE_DE]->(club1:Club)
WITH ahmed, autre, ahmed_cours, autre_cours, ahmed_comp, autre_comp, collect(DISTINCT club1.nom) AS ahmed_clubs

OPTIONAL MATCH (autre)-[:MEMBRE_DE]->(club2:Club)
WITH ahmed, autre, ahmed_cours, autre_cours, ahmed_comp, autre_comp, ahmed_clubs, collect(DISTINCT club2.nom) AS autre_clubs

// Calcul Jaccard pour chaque dimension
WITH autre, ahmed_cours, autre_cours, ahmed_comp, autre_comp, ahmed_clubs, autre_clubs,
     // Jaccard Cours
     CASE WHEN size(ahmed_cours) + size(autre_cours) = 0 THEN 0
          ELSE size([x IN ahmed_cours WHERE x IN autre_cours]) * 1.0 / 
               size(apoc.coll.union(ahmed_cours, autre_cours)) END AS jaccard_cours,
     // Jaccard Compétences
     CASE WHEN size(ahmed_comp) + size(autre_comp) = 0 THEN 0
          ELSE size([x IN ahmed_comp WHERE x IN autre_comp]) * 1.0 / 
               size(apoc.coll.union(ahmed_comp, autre_comp)) END AS jaccard_comp,
     // Jaccard Clubs
     CASE WHEN size(ahmed_clubs) + size(autre_clubs) = 0 THEN 0
          ELSE size([x IN ahmed_clubs WHERE x IN autre_clubs]) * 1.0 / 
               size(apoc.coll.union(ahmed_clubs, autre_clubs)) END AS jaccard_clubs

// Score global pondéré
WITH autre,
     jaccard_cours, jaccard_comp, jaccard_clubs,
     (jaccard_cours * 0.4 + jaccard_comp * 0.4 + jaccard_clubs * 0.2) AS score_similarite

WHERE score_similarite > 0
RETURN autre.prenom, autre.nom, autre.universite, autre.filiere,
       round(jaccard_cours, 3) AS jaccard_cours,
       round(jaccard_comp, 3) AS jaccard_comp,
       round(jaccard_clubs, 3) AS jaccard_clubs,
       round(score_similarite, 3) AS score_similarite
ORDER BY score_similarite DESC
LIMIT 10;

// --------------------------------------------------
// Version sans APOC (Jaccard pur Cypher)
// --------------------------------------------------
MATCH (ahmed:Etudiant {prenom: "Ahmed"})
MATCH (autre:Etudiant)
WHERE autre <> ahmed

OPTIONAL MATCH (ahmed)-[:SUIT]->(c1:Cours)
WITH ahmed, autre, collect(DISTINCT c1.code) AS ahmed_cours
OPTIONAL MATCH (autre)-[:SUIT]->(c2:Cours)
WITH ahmed, autre, ahmed_cours, collect(DISTINCT c2.code) AS autre_cours

OPTIONAL MATCH (ahmed)-[:MAITRISE]->(comp1:Competence)
WITH ahmed, autre, ahmed_cours, autre_cours, collect(DISTINCT comp1.nom) AS ahmed_comp
OPTIONAL MATCH (autre)-[:MAITRISE]->(comp2:Competence)
WITH ahmed, autre, ahmed_cours, autre_cours, ahmed_comp, collect(DISTINCT comp2.nom) AS autre_comp

OPTIONAL MATCH (ahmed)-[:MEMBRE_DE]->(club1:Club)
WITH ahmed, autre, ahmed_cours, autre_cours, ahmed_comp, autre_comp, collect(DISTINCT club1.nom) AS ahmed_clubs
OPTIONAL MATCH (autre)-[:MEMBRE_DE]->(club2:Club)
WITH ahmed, autre, ahmed_cours, autre_cours, ahmed_comp, autre_comp, ahmed_clubs, collect(DISTINCT club2.nom) AS autre_clubs

WITH autre, ahmed_cours, autre_cours, ahmed_comp, autre_comp, ahmed_clubs, autre_clubs,
     // Intersection + Union manuelles
     [x IN ahmed_cours WHERE x IN autre_cours] AS inter_cours,
     ahmed_cours + [x IN autre_cours WHERE NOT x IN ahmed_cours] AS union_cours,
     [x IN ahmed_comp WHERE x IN autre_comp] AS inter_comp,
     ahmed_comp + [x IN autre_comp WHERE NOT x IN ahmed_comp] AS union_comp,
     [x IN ahmed_clubs WHERE x IN autre_clubs] AS inter_clubs,
     ahmed_clubs + [x IN autre_clubs WHERE NOT x IN ahmed_clubs] AS union_clubs

WITH autre,
     CASE WHEN size(union_cours) = 0 THEN 0 ELSE size(inter_cours) * 1.0 / size(union_cours) END AS jaccard_cours,
     CASE WHEN size(union_comp) = 0 THEN 0 ELSE size(inter_comp) * 1.0 / size(union_comp) END AS jaccard_comp,
     CASE WHEN size(union_clubs) = 0 THEN 0 ELSE size(inter_clubs) * 1.0 / size(union_clubs) END AS jaccard_clubs

WITH autre, jaccard_cours, jaccard_comp, jaccard_clubs,
     (jaccard_cours * 0.4 + jaccard_comp * 0.4 + jaccard_clubs * 0.2) AS score_similarite

WHERE score_similarite > 0
RETURN autre.prenom, autre.nom, autre.universite, autre.filiere,
       round(jaccard_cours, 3) AS jaccard_cours,
       round(jaccard_comp, 3) AS jaccard_comp,
       round(jaccard_clubs, 3) AS jaccard_clubs,
       round(score_similarite, 3) AS score_similarite
ORDER BY score_similarite DESC
LIMIT 10;
