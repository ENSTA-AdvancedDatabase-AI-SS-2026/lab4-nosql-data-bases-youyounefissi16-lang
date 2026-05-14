// TP4 - Exercice 1 : Création du graphe UniConnect DZ
// Effacer la base pour partir propre
MATCH (n) DETACH DELETE n;

// ─── 1.1 : Contraintes d'unicité ─────────────────────────────────────────────
CREATE CONSTRAINT etudiant_id IF NOT EXISTS FOR (e:Etudiant) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT cours_code IF NOT EXISTS FOR (c:Cours) REQUIRE c.code IS UNIQUE;
CREATE CONSTRAINT competence_nom IF NOT EXISTS FOR (c:Competence) REQUIRE c.nom IS UNIQUE;
CREATE CONSTRAINT club_nom IF NOT EXISTS FOR (c:Club) REQUIRE c.nom IS UNIQUE;
CREATE CONSTRAINT entreprise_nom IF NOT EXISTS FOR (e:Entreprise) REQUIRE e.nom IS UNIQUE;

// ─── 1.2 : Créer les compétences ──────────────────────────────────────────────
UNWIND [
  {nom: "Python", categorie: "Programmation"},
  {nom: "Java", categorie: "Programmation"},
  {nom: "C++", categorie: "Programmation"},
  {nom: "SQL", categorie: "Bases de Données"},
  {nom: "NoSQL", categorie: "Bases de Données"},
  {nom: "Machine Learning", categorie: "IA"},
  {nom: "Deep Learning", categorie: "IA"},
  {nom: "Traitement du Signal", categorie: "IA"},
  {nom: "React", categorie: "Web"},
  {nom: "Node.js", categorie: "Web"},
  {nom: "Docker", categorie: "DevOps"},
  {nom: "Linux", categorie: "Systèmes"},
  {nom: "Réseaux", categorie: "Infrastructure"},
  {nom: "Sécurité Informatique", categorie: "Infrastructure"},
  {nom: "Matlab", categorie: "Simulation"}
] AS comp
MERGE (:Competence {nom: comp.nom, categorie: comp.categorie});

// ─── 1.3 : Créer les cours ────────────────────────────────────────────────────
UNWIND [
  {code: "INFO401", intitule: "Bases de Données Avancées", credits: 6, dept: "Informatique"},
  {code: "INFO402", intitule: "Intelligence Artificielle", credits: 6, dept: "Informatique"},
  {code: "INFO403", intitule: "Développement Web", credits: 4, dept: "Informatique"},
  {code: "INFO404", intitule: "Systèmes Distribués", credits: 5, dept: "Informatique"},
  {code: "INFO405", intitule: "Cloud Computing", credits: 4, dept: "Informatique"},
  {code: "MATH301", intitule: "Statistiques et Probabilités", credits: 4, dept: "Mathématiques"},
  {code: "ELEC401", intitule: "Systèmes Embarqués", credits: 5, dept: "Electronique"},
  {code: "TELE401", intitule: "Protocoles Réseaux", credits: 5, dept: "Telecoms"},
  {code: "GL401", intitule: "Architecture Logicielle", credits: 6, dept: "GL"}
] AS cours
MERGE (:Cours {code: cours.code, intitule: cours.intitule,
               credits: cours.credits, departement: cours.dept});

// Lier les cours aux compétences requises
MATCH (c:Cours {code: "INFO401"}), (s:Competence {nom: "SQL"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO401"}), (s:Competence {nom: "NoSQL"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO402"}), (s:Competence {nom: "Machine Learning"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO402"}), (s:Competence {nom: "Python"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO402"}), (s:Competence {nom: "Deep Learning"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO403"}), (s:Competence {nom: "React"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO403"}), (s:Competence {nom: "Node.js"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO404"}), (s:Competence {nom: "Docker"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO404"}), (s:Competence {nom: "Linux"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "TELE401"}), (s:Competence {nom: "Réseaux"}) MERGE (c)-[:REQUIERT]->(s);

// ─── 1.4 : Créer les clubs ────────────────────────────────────────────────────
UNWIND [
  {nom: "Club IA USTHB", universite: "USTHB", domaine: "Intelligence Artificielle"},
  {nom: "Club Web UMBB", universite: "UMBB", domaine: "Développement Web"},
  {nom: "Club Cyber USTO", universite: "USTO", domaine: "Cybersécurité"},
  {nom: "Club Robotique UMC", universite: "UMC", domaine: "Robotique"},
  {nom: "Club Open Source UBMA", universite: "UBMA", domaine: "Open Source"},
  {nom: "Club Entrepreneuriat USTHB", universite: "USTHB", domaine: "Startup"}
] AS club
MERGE (:Club {nom: club.nom, universite: club.universite, domaine: club.domaine});

// ─── 1.5 : Créer les entreprises ─────────────────────────────────────────────
UNWIND [
  {nom: "Sonatrach", secteur: "Energie", ville: "Alger"},
  {nom: "Mobilis", secteur: "Telecoms", ville: "Alger"},
  {nom: "Ooredoo Algérie", secteur: "Telecoms", ville: "Alger"},
  {nom: "CNIS", secteur: "Technologie", ville: "Alger"},
  {nom: "Cerist", secteur: "Recherche", ville: "Alger"},
  {nom: "Condor Electronics", secteur: "Electronique", ville: "Bordj Bou Arreridj"},
  {nom: "NCA Rouiba", secteur: "Industrie", ville: "Alger"}
] AS ent
MERGE (:Entreprise {nom: ent.nom, secteur: ent.secteur, ville: ent.ville});

// ─── 1.6 : Créer 50 étudiants ────────────────────────────────────────────────
UNWIND [
  {id:"E001",prenom:"Ahmed",nom:"Bensalem",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E002",prenom:"Fatima",nom:"Ouali",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E003",prenom:"Yasmina",nom:"Mekki",universite:"UMBB",filiere:"GL",annee:2,ville:"Boumerdes"},
  {id:"E004",prenom:"Karim",nom:"Hadj",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E005",prenom:"Nadia",nom:"Larbi",universite:"USTO",filiere:"Informatique",annee:3,ville:"Oran"},
  {id:"E006",prenom:"Omar",nom:"Seddiki",universite:"UMC",filiere:"Telecoms",annee:2,ville:"Constantine"},
  {id:"E007",prenom:"Amira",nom:"Rahmani",universite:"USTHB",filiere:"Mathématiques",annee:3,ville:"Alger"},
  {id:"E008",prenom:"Rachid",nom:"Boumaza",universite:"UBMA",filiere:"Electronique",annee:4,ville:"Annaba"},
  {id:"E009",prenom:"Lina",nom:"Chabane",universite:"UMBB",filiere:"GL",annee:1,ville:"Boumerdes"},
  {id:"E010",prenom:"Djamel",nom:"Ferhat",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E011",prenom:"Samira",nom:"Chikh",universite:"USTO",filiere:"Informatique",annee:2,ville:"Oran"},
  {id:"E012",prenom:"Houria",nom:"Benali",universite:"UMC",filiere:"Telecoms",annee:3,ville:"Constantine"},
  {id:"E013",prenom:"Ali",nom:"Mazouz",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E014",prenom:"Meriem",nom:"Yahiaoui",universite:"UBMA",filiere:"Electronique",annee:2,ville:"Annaba"},
  {id:"E015",prenom:"Mustapha",nom:"Ghali",universite:"UMBB",filiere:"Informatique",annee:3,ville:"Boumerdes"},
  {id:"E016",prenom:"Imane",nom:"Touati",universite:"USTHB",filiere:"GL",annee:2,ville:"Alger"},
  {id:"E017",prenom:"Youcef",nom:"Belkacem",universite:"USTO",filiere:"Mathématiques",annee:4,ville:"Oran"},
  {id:"E018",prenom:"Sihem",nom:"Merzougui",universite:"UMC",filiere:"Informatique",annee:1,ville:"Constantine"},
  {id:"E019",prenom:"Bilal",nom:"Hamdi",universite:"UBMA",filiere:"GL",annee:3,ville:"Annaba"},
  {id:"E020",prenom:"Asma",nom:"Boudali",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E021",prenom:"Hicham",nom:"Kaci",universite:"UMBB",filiere:"Telecoms",annee:2,ville:"Boumerdes"},
  {id:"E022",prenom:"Rania",nom:"Zerrouki",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E023",prenom:"Walid",nom:"Aissaoui",universite:"USTO",filiere:"Electronique",annee:3,ville:"Oran"},
  {id:"E024",prenom:"Nesrine",nom:"Mansouri",universite:"UMC",filiere:"GL",annee:2,ville:"Constantine"},
  {id:"E025",prenom:"Abdelaziz",nom:"Saadi",universite:"UBMA",filiere:"Informatique",annee:3,ville:"Annaba"},
  {id:"E026",prenom:"Chaima",nom:"Benaouda",universite:"USTHB",filiere:"Mathématiques",annee:1,ville:"Alger"},
  {id:"E027",prenom:"Sofiane",nom:"Belmekki",universite:"UMBB",filiere:"Informatique",annee:3,ville:"Boumerdes"},
  {id:"E028",prenom:"Dalila",nom:"Hadjadj",universite:"USTHB",filiere:"GL",annee:4,ville:"Alger"},
  {id:"E029",prenom:"Fares",nom:"Guendouz",universite:"USTO",filiere:"Informatique",annee:2,ville:"Oran"},
  {id:"E030",prenom:"Nour",nom:"Bouchama",universite:"UMC",filiere:"Electronique",annee:3,ville:"Constantine"},
  {id:"E031",prenom:"Tarik",nom:"Messaoud",universite:"UBMA",filiere:"Informatique",annee:1,ville:"Annaba"},
  {id:"E032",prenom:"Wafa",nom:"Berber",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E033",prenom:"Mehdi",nom:"Kebaili",universite:"UMBB",filiere:"Telecoms",annee:4,ville:"Boumerdes"},
  {id:"E034",prenom:"Loubna",nom:"Aoudia",universite:"USTHB",filiere:"GL",annee:2,ville:"Alger"},
  {id:"E035",prenom:"Ismail",nom:"Rezzoug",universite:"USTO",filiere:"Informatique",annee:3,ville:"Oran"},
  {id:"E036",prenom:"Aicha",nom:"Djaballah",universite:"UMC",filiere:"Mathematiques",annee:2,ville:"Constantine"},
  {id:"E037",prenom:"Abdelkrim",nom:"Slimani",universite:"UBMA",filiere:"Informatique",annee:4,ville:"Annaba"},
  {id:"E038",prenom:"Sonia",nom:"Boudjelal",universite:"USTHB",filiere:"Electronique",annee:1,ville:"Alger"},
  {id:"E039",prenom:"Nassim",nom:"Kebir",universite:"UMBB",filiere:"GL",annee:3,ville:"Boumerdes"},
  {id:"E040",prenom:"Hayet",nom:"Amrani",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E041",prenom:"Amine",nom:"Ziani",universite:"USTO",filiere:"Informatique",annee:2,ville:"Oran"},
  {id:"E042",prenom:"Cylia",nom:"Benkhalifa",universite:"UMC",filiere:"GL",annee:3,ville:"Constantine"},
  {id:"E043",prenom:"Khaled",nom:"Moussaoui",universite:"UBMA",filiere:"Telecoms",annee:2,ville:"Annaba"},
  {id:"E044",prenom:"Sarra",nom:"Mebarki",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E045",prenom:"Adel",nom:"Haouari",universite:"UMBB",filiere:"Electronique",annee:4,ville:"Boumerdes"},
  {id:"E046",prenom:"Zineb",nom:"Chibane",universite:"USTHB",filiere:"Informatique",annee:1,ville:"Alger"},
  {id:"E047",prenom:"Lyes",nom:"Belhadj",universite:"USTO",filiere:"GL",annee:3,ville:"Oran"},
  {id:"E048",prenom:"Karima",nom:"Tlemcani",universite:"UMC",filiere:"Informatique",annee:2,ville:"Constantine"},
  {id:"E049",prenom:"Nabil",nom:"Boudiaf",universite:"UBMA",filiere:"Informatique",annee:4,ville:"Annaba"},
  {id:"E050",prenom:"Amina",nom:"Hamitouche",universite:"USTHB",filiere:"Mathématiques",annee:3,ville:"Alger"}
] AS data
MERGE (e:Etudiant {id: data.id})
SET e += data;

// ─── 1.7 : Créer les relations CONNAIT ───────────────────────────────────────
// Réseau connexe : chaque étudiant connaît au moins 2 autres
UNWIND [
  ["E001","E002",2023,"cours"], ["E001","E004",2022,"projet"], ["E001","E007",2024,"club"],
  ["E001","E013",2023,"cours"], ["E002","E003",2023,"conférence"], ["E002","E009",2023,"cours"],
  ["E003","E015",2024,"projet"], ["E003","E027",2023,"cours"], ["E004","E010",2022,"cours"],
  ["E004","E022",2023,"projet"], ["E005","E011",2023,"cours"], ["E005","E029",2024,"conférence"],
  ["E006","E012",2022,"cours"], ["E006","E024",2023,"projet"], ["E007","E026",2024,"cours"],
  ["E007","E040",2023,"club"], ["E008","E014",2022,"cours"], ["E008","E045",2023,"projet"],
  ["E009","E039",2023,"cours"], ["E010","E016",2024,"club"], ["E010","E028",2023,"cours"],
  ["E011","E017",2023,"cours"], ["E011","E041",2024,"projet"], ["E012","E018",2022,"cours"],
  ["E013","E020",2023,"cours"], ["E013","E032",2024,"club"], ["E014","E038",2023,"cours"],
  ["E015","E021",2022,"cours"], ["E015","E033",2023,"projet"], ["E016","E034",2024,"cours"],
  ["E017","E036",2023,"cours"], ["E018","E048",2024,"projet"], ["E019","E025",2022,"cours"],
  ["E019","E031",2023,"club"], ["E020","E044",2023,"cours"], ["E020","E046",2024,"projet"],
  ["E021","E033",2022,"cours"], ["E022","E028",2024,"club"], ["E022","E034",2023,"cours"],
  ["E023","E029",2022,"cours"], ["E023","E035",2023,"projet"], ["E024","E042",2024,"cours"],
  ["E025","E037",2023,"cours"], ["E025","E049",2022,"club"], ["E026","E050",2023,"cours"],
  ["E027","E039",2024,"projet"], ["E028","E040",2023,"cours"], ["E029","E041",2022,"cours"],
  ["E030","E036",2023,"projet"], ["E031","E043",2024,"cours"], ["E032","E044",2023,"club"],
  ["E033","E039",2022,"cours"], ["E034","E040",2024,"projet"], ["E035","E047",2023,"cours"],
  ["E036","E048",2022,"club"], ["E037","E049",2023,"cours"], ["E038","E046",2024,"projet"],
  ["E042","E048",2023,"cours"], ["E043","E049",2022,"club"], ["E044","E050",2024,"cours"]
] AS rel
MATCH (a:Etudiant {id: rel[0]}), (b:Etudiant {id: rel[1]})
MERGE (a)-[:CONNAIT {depuis: rel[2], contexte: rel[3]}]->(b)
MERGE (b)-[:CONNAIT {depuis: rel[2], contexte: rel[3]}]->(a);

// ─── 1.8 : Relations SUIT (étudiant → cours avec notes) ──────────────────────
UNWIND [
  ["E001","INFO401",1,14.5], ["E001","INFO402",1,16.0], ["E002","INFO401",1,17.5],
  ["E003","INFO403",2,13.0], ["E004","INFO401",2,18.0], ["E004","INFO404",1,15.5],
  ["E005","INFO401",1,12.5], ["E005","INFO402",2,11.0], ["E006","TELE401",1,14.0],
  ["E007","MATH301",1,19.0], ["E007","INFO402",2,17.5], ["E008","ELEC401",1,15.0],
  ["E010","INFO401",1,13.5], ["E010","INFO403",2,15.0], ["E011","INFO401",1,11.5],
  ["E013","INFO401",2,16.5], ["E013","INFO402",1,15.0], ["E013","INFO404",2,14.0],
  ["E015","INFO403",1,12.0], ["E016","GL401",1,16.0], ["E017","MATH301",2,18.5],
  ["E020","INFO401",1,14.0], ["E022","INFO401",2,17.0], ["E022","INFO402",1,16.5],
  ["E025","INFO401",1,13.0], ["E027","INFO403",2,14.5], ["E028","GL401",1,15.5],
  ["E032","INFO401",1,16.0], ["E034","GL401",2,14.0], ["E035","INFO401",1,12.0],
  ["E039","INFO403",1,15.0], ["E040","INFO401",2,17.5], ["E040","INFO402",1,16.0],
  ["E044","INFO401",1,13.5], ["E047","GL401",2,15.0], ["E050","MATH301",1,18.0]
] AS rel
MATCH (e:Etudiant {id: rel[0]}), (c:Cours {code: rel[1]})
MERGE (e)-[:SUIT {semestre: rel[2], note: rel[3]}]->(c);

// ─── 1.9 : Relations MAITRISE (étudiant → compétence) ────────────────────────
UNWIND [
  ["E001","Python","avancé"], ["E001","SQL","intermédiaire"], ["E001","NoSQL","débutant"],
  ["E002","Python","intermédiaire"], ["E002","React","intermédiaire"], ["E003","React","avancé"],
  ["E003","Node.js","intermédiaire"], ["E004","Python","expert"], ["E004","Machine Learning","avancé"],
  ["E005","SQL","avancé"], ["E005","Java","intermédiaire"], ["E006","Réseaux","avancé"],
  ["E007","Python","avancé"], ["E007","Machine Learning","expert"], ["E007","Deep Learning","intermédiaire"],
  ["E008","C++","avancé"], ["E008","Linux","intermédiaire"], ["E010","Python","intermédiaire"],
  ["E010","React","débutant"], ["E011","SQL","intermédiaire"], ["E013","Python","expert"],
  ["E013","NoSQL","avancé"], ["E013","Docker","intermédiaire"], ["E015","React","intermédiaire"],
  ["E016","Java","avancé"], ["E017","Python","avancé"], ["E017","Matlab","expert"],
  ["E020","Python","intermédiaire"], ["E020","SQL","avancé"], ["E022","Python","avancé"],
  ["E022","Machine Learning","intermédiaire"], ["E025","Linux","avancé"], ["E027","React","avancé"],
  ["E028","Java","expert"], ["E032","Python","avancé"], ["E032","SQL","intermédiaire"],
  ["E034","Java","avancé"], ["E034","Docker","intermédiaire"], ["E035","Python","intermédiaire"],
  ["E040","Python","expert"], ["E040","Deep Learning","avancé"], ["E044","SQL","intermédiaire"],
  ["E047","Java","avancé"], ["E050","Python","intermédiaire"], ["E050","Matlab","avancé"]
] AS rel
MATCH (e:Etudiant {id: rel[0]}), (c:Competence {nom: rel[1]})
MERGE (e)-[:MAITRISE {niveau: rel[2]}]->(c);

// ─── 1.10 : Relations MEMBRE_DE et A_STAGE_CHEZ ──────────────────────────────
UNWIND [
  ["E001","Club IA USTHB","membre"], ["E002","Club IA USTHB","vice-président"],
  ["E004","Club IA USTHB","président"], ["E007","Club IA USTHB","membre"],
  ["E003","Club Web UMBB","membre"], ["E015","Club Web UMBB","président"],
  ["E005","Club Cyber USTO","membre"], ["E011","Club Cyber USTO","vice-président"],
  ["E006","Club Robotique UMC","membre"], ["E012","Club Robotique UMC","président"],
  ["E008","Club Open Source UBMA","membre"], ["E019","Club Open Source UBMA","président"],
  ["E010","Club Entrepreneuriat USTHB","membre"], ["E013","Club IA USTHB","membre"],
  ["E016","Club Entrepreneuriat USTHB","président"], ["E020","Club IA USTHB","membre"]
] AS rel
MATCH (e:Etudiant {id: rel[0]}), (c:Club {nom: rel[1]})
MERGE (e)-[:MEMBRE_DE {role: rel[2]}]->(c);

UNWIND [
  ["E004","Cerist",2024,6], ["E013","Mobilis",2023,3],
  ["E022","Ooredoo Algérie",2024,6], ["E028","CNIS",2023,4],
  ["E037","Sonatrach",2024,3], ["E040","Cerist",2023,6],
  ["E049","Condor Electronics",2024,4]
] AS rel
MATCH (e:Etudiant {id: rel[0]}), (ent:Entreprise {nom: rel[1]})
MERGE (e)-[:A_STAGE_CHEZ {annee: rel[2], duree_mois: rel[3]}]->(ent);

// ─── 1.11 : Import CSV (fichier import/students.csv) ─────────────────────────
// Le fichier CSV est dans le dossier import/ (monté dans Neo4j)
// Exécuter séparément pour éviter les doublons avec les étudiants déjà créés :

// LOAD CSV WITH HEADERS FROM 'file:///students.csv' AS row
// MERGE (e:Etudiant { id: row.id })
// SET e.prenom     = row.prenom,
//     e.nom        = row.nom,
//     e.universite = row.universite,
//     e.filiere    = row.filiere,
//     e.annee      = toInteger(row.annee),
//     e.ville      = row.ville;

// Vérification finale
MATCH (n) RETURN labels(n)[0] AS type, count(n) AS total ORDER BY total DESC;
MATCH ()-[r]->() RETURN type(r) AS relation, count(r) AS total ORDER BY total DESC;
