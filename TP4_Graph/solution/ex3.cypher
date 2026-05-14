// ============================================================
// EXERCICE 3 — Algorithmes de Graphe (6 pts)
// Fichier : starter/ex3_graph_algorithms.cypher
// ============================================================

// --------------------------------------------------
// 3.1 Plus court chemin entre deux étudiants
// "Comment Ahmed peut-il rencontrer Yasmina ?"
// --------------------------------------------------
MATCH p = shortestPath(
  (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT*]-(yasmina:Etudiant {prenom: "Yasmina"})
)
RETURN [n IN nodes(p) | n.prenom] AS chemin, length(p) AS distance;


// --------------------------------------------------
// 3.2 Étudiants les plus connectés (centralité de degré)
// Utiliser GDS (Graph Data Science)
// --------------------------------------------------

// Étape 1 : Créer un graphe projeté en mémoire (si GDS est installé)
CALL gds.graph.project(
  'reseau-social',
  'Etudiant',
  {
    CONNAIT: {
      orientation: 'UNDIRECTED'
    }
  }
) YIELD graphName, nodeCount, relationshipCount;

// Étape 2 : Calculer la centralité de degré
CALL gds.degree.stream('reseau-social')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).prenom AS prenom,
       gds.util.asNode(nodeId).nom AS nom,
       gds.util.asNode(nodeId).universite AS universite,
       score AS nombre_connexions
ORDER BY score DESC
LIMIT 10;

// Alternative sans GDS (centralité de degré en pur Cypher)
MATCH (e:Etudiant)-[:CONNAIT]-(ami:Etudiant)
RETURN e.prenom, e.nom, e.universite, count(ami) AS nombre_connexions
ORDER BY nombre_connexions DESC
LIMIT 10;


// --------------------------------------------------
// 3.3 Détection de communautés (Louvain)
// Identifier les "cercles sociaux"
// --------------------------------------------------

// Avec GDS : algorithme de Louvain
CALL gds.louvain.stream('reseau-social')
YIELD nodeId, communityId, intermediateCommunityIds
RETURN gds.util.asNode(nodeId).prenom AS prenom,
       gds.util.asNode(nodeId).nom AS nom,
       gds.util.asNode(nodeId).universite AS universite,
       communityId AS communaute
ORDER BY communaute, prenom;

// Statistiques des communautés détectées
CALL gds.louvain.stream('reseau-social')
YIELD nodeId, communityId
WITH communityId, collect(gds.util.asNode(nodeId).prenom) AS membres
RETURN communityId AS communaute,
       size(membres) AS taille,
       membres[0..5] AS exemple_membres
ORDER BY taille DESC;

// Supprimer le graphe projeté après utilisation
CALL gds.graph.drop('reseau-social') YIELD graphName;


// --------------------------------------------------
// 3.4 Recommandation de contacts
// "Avec qui Ahmed devrait-il se connecter ?"
// Algo : amis en commun + cours en commun + même filière
// --------------------------------------------------

MATCH (ahmed:Etudiant {prenom: "Ahmed"})

// Amis en commun (friends-of-friends non connectés)
OPTIONAL MATCH (ahmed)-[:CONNAIT]-(ami:Etudiant)-[:CONNAIT]-(cible:Etudiant)
WHERE cible <> ahmed AND NOT (ahmed)-[:CONNAIT]-(cible)
WITH ahmed, cible, count(DISTINCT ami) AS amis_commun

// Cours en commun
OPTIONAL MATCH (ahmed)-[:SUIT]->(c:Cours)<-[:SUIT]-(cible)
WITH ahmed, cible, amis_commun, count(DISTINCT c) AS cours_commun

// Même filière
WITH ahmed, cible, amis_commun, cours_commun,
     CASE WHEN ahmed.filiere = cible.filiere THEN 1 ELSE 0 END AS meme_filiere

// Score pondéré
WITH cible,
     amis_commun * 3 + cours_commun * 2 + meme_filiere * 1 AS score_recommandation,
     amis_commun, cours_commun, meme_filiere

WHERE score_recommandation > 0
RETURN cible.prenom, cible.nom, cible.universite, cible.filiere,
       amis_commun, cours_commun, meme_filiere,
       score_recommandation
ORDER BY score_recommandation DESC, cible.prenom
LIMIT 10;


// --------------------------------------------------
// 3.5 Chemin de compétences
// "Quels cours dois-je suivre pour maîtriser 'Machine Learning' ?"
// --------------------------------------------------

// Trouver tous les cours qui mènent à la compétence "Machine Learning"
// (directement ou via prérequis en chaîne)
MATCH path = (c:Cours)-[:REQUIERT*]->(comp:Competence {nom: "Machine Learning"})
RETURN [n IN nodes(path) | 
  CASE WHEN n:Cours THEN n.code + ": " + n.intitule 
       WHEN n:Competence THEN n.nom END
] AS chemin_cours,
length(path) AS niveau_profondeur
ORDER BY niveau_profondeur;

// Version alternative : cours directs requis pour ML
MATCH (c:Cours)-[:REQUIERT]->(comp:Competence {nom: "Machine Learning"})
RETURN c.code, c.intitule, c.credits, c.departement;

// Version avec étudiant spécifique : quels cours manque-t-il à Ahmed ?
MATCH (ahmed:Etudiant {prenom: "Ahmed"})
MATCH (c:Cours)-[:REQUIERT*]->(comp:Competence {nom: "Machine Learning"})
WHERE NOT (ahmed)-[:SUIT]->(c)
RETURN DISTINCT c.code, c.intitule, c.credits
ORDER BY c.code;
