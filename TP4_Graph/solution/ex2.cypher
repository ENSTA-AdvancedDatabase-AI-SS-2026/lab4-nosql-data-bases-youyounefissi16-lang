// TP4 - Exercice 2 : Requêtes de Base Cypher
// Use Case : UniConnect DZ

// ─── 2.1 : Amis directs d'Ahmed (1 saut) ─────────────────────────────────────
MATCH (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT]-(ami:Etudiant)
RETURN ami.prenom, ami.nom, ami.universite, ami.filiere
ORDER BY ami.prenom;


// ─── 2.2 : Amis d'amis d'Ahmed (non déjà amis) ───────────────────────────────
MATCH (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT*2]-(suggestion:Etudiant)
WHERE NOT (ahmed)-[:CONNAIT]-(suggestion)
  AND suggestion <> ahmed
RETURN DISTINCT suggestion.prenom, suggestion.nom,
       suggestion.universite, suggestion.filiere
ORDER BY suggestion.prenom
LIMIT 10;


// ─── 2.3 : Étudiants qui suivent le même cours que Fatima mais ne la connaissent pas
MATCH (fatima:Etudiant {prenom: "Fatima"})-[:SUIT]->(cours:Cours)<-[:SUIT]-(autre:Etudiant)
WHERE NOT (fatima)-[:CONNAIT]-(autre)
  AND autre <> fatima
RETURN DISTINCT autre.prenom, autre.nom, autre.universite,
       collect(cours.intitule) AS cours_communs
ORDER BY autre.prenom;


// ─── 2.4 : Clubs les plus populaires (par nombre de membres) ─────────────────
MATCH (e:Etudiant)-[:MEMBRE_DE]->(c:Club)
RETURN c.nom, c.universite, c.domaine,
       count(e) AS nb_membres
ORDER BY nb_membres DESC;


// ─── 2.5 : Profil complet d'un étudiant ──────────────────────────────────────
MATCH (e:Etudiant {prenom: "Ahmed"})
OPTIONAL MATCH (e)-[:CONNAIT]-(ami:Etudiant)
OPTIONAL MATCH (e)-[:SUIT]->(cours:Cours)
OPTIONAL MATCH (e)-[:MAITRISE]->(comp:Competence)
OPTIONAL MATCH (e)-[:MEMBRE_DE]->(club:Club)
RETURN e.prenom + " " + e.nom AS etudiant,
       e.universite,
       e.filiere,
       collect(DISTINCT ami.prenom) AS amis,
       collect(DISTINCT cours.intitule) AS cours_suivis,
       collect(DISTINCT comp.nom) AS competences,
       collect(DISTINCT club.nom) AS clubs;
