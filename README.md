# Visualisation de l'abondance du moustique tigre — Hérault

> Projet réalisé dans le cadre du **Marathon du Web**

## Présentation du projet

Ce projet propose une application de visualisation cartographique interactive des données d'abondance du moustique tigre (*Aedes albopictus*) sur le département de l'Hérault. L'application est construite avec **Mviewer**, un visualiseur cartographique open source basé sur OpenLayers, qui permet de superposer et d'interroger des couches de données géographiques issues de plusieurs sources.

L'objectif est de croiser les observations entomologiques avec des données socio-environnementales afin d'identifier les zones à risque et d'en faciliter la lecture pour le grand public comme pour les acteurs de santé publique.

---

## Données utilisées

### Données principales

| Source | Description | Type |
|--------|-------------|------|
| **INRAE — OMEES** | Observations d'*Aedes albopictus* géolocalisées avec dimension temporelle | WMS — `geodata.bac-a-sable.inrae.fr` |

### Données d'enrichissement

| Source | Variable | Intérêt |
|--------|----------|---------|
| **Hérault Data** — Stations d'épuration | `capacite_EH` (Équivalent Habitant) | Les stations d'épuration constituent des gîtes larvaires privilégiés ; la capacité EH est un indicateur de la taille du site et de sa surface en eau stagnante |
| **Données communales** | `pop2022` (population par commune) | Permet de contextualiser la densité d'observations par rapport à la population exposée |

---

## Stack technique

- **Mviewer** — visualiseur cartographique (OpenLayers)
- **GeoServer** — serveur de diffusion des flux WMS (INRAE)
- **Configuration XML** — paramétrage des couches, thématiques et comportements de l'application
- **Templates Mustache** — fiches d'information interactives au clic sur une entité

---

## Structure du projet

```
/
├── apps/
│   └── moustiques/
│       ├── config.xml          # Configuration principale Mviewer
│       └── templates/
│           └── fiche.mst       # Template Mustache fiche d'info
└── README.md
```

---

## Fonctionnalités de la visualisation

- Affichage des observations de moustiques tigres sur fond cartographique
- Filtrage temporel des observations (slider de date)
- Superposition des stations d'épuration avec taille proportionnelle à la capacité EH
- Fiche d'information contextuelle au clic : espèce, date, commune, population, capacité EH locale
- Légende et contrôle d'opacité par couche

---

## Comprendre l'outil de prédiction

Les données visualisées dans l'application sont issues d'un modèle statistique de prédiction de l'activité du moustique tigre. Cette section en explique le fonctionnement.

### Variable cible

Le modèle cherche à prédire la **ponte moyennée par site et par date de collecte**, exprimée en nombre quotidien d'œufs par piège. Cette mesure est collectée sur le terrain via des ovitraps (pièges à œufs) disposés sur plusieurs sites.

### Deux modèles complémentaires

Pour distinguer les conditions qui *déclenchent* l'activité des moustiques de celles qui en *gouvernent l'intensité*, deux modèles ont été développés en parallèle :

- **Modèle de présence/absence** — répond à la question *"y a-t-il des moustiques actifs ?"*. La variable de sortie est binaire : 1 si des œufs sont détectés, 0 sinon.
- **Modèle d'abondance** — répond à la question *"combien ?"*. Il prédit le nombre moyen d'œufs par piège et par jour, uniquement pour les événements de piégeage positifs.

### Pipeline de construction du modèle

**Étape 1 — Sélection des variables météorologiques pertinentes**

Des cartes de corrélation croisée (CCM) sont calculées entre la variable cible et chaque variable météorologique (température, précipitations, humidité…), moyennées sur une semaine glissante avec des décalages temporels de 0 à 12 semaines. Cela permet d'identifier avec quel délai chaque facteur météo influence la ponte — par exemple, une pluie intense se répercute sur l'activité des moustiques plusieurs semaines plus tard.

**Étape 2 — Filtrage et sélection**

- Pour chaque variable météo, seul le décalage temporel avec la corrélation la plus forte est conservé.
- Les variables faiblement associées à la ponte (coefficient de corrélation de distance < 0,1) sont écartées.
- En cas de redondance entre deux variables très corrélées (Pearson > 0,7), seule celle présentant la meilleure pertinence écologique et interprétabilité est retenue.

**Étape 3 — Entraînement par forêts aléatoires (Random Forest)**

Deux modèles de forêts aléatoires sont entraînés :
- un **RF de classification binaire** pour la présence/absence,
- un **RF de régression** pour l'abondance.

Pour éviter le surapprentissage et évaluer la capacité du modèle à généraliser à des sites non observés, une **validation croisée spatiale** est appliquée : les modèles sont entraînés sur trois sites et testés sur le quatrième, de manière itérative.

**Étape 4 — Combinaison des prédictions**

Les deux modèles sont combinés pour produire une **prédiction unifiée** :
- Si la probabilité de présence dépasse le seuil de 0,5 → la valeur d'abondance prédite est conservée.
- Sinon → la prédiction est fixée à 0.

Cette approche en deux temps permet d'éviter de surestimer l'abondance dans des conditions où les moustiques seraient tout simplement absents.

---

## Compréhension du modèle de prédiction de l'activité des moustiques

Dans le cadre de ce projet, nous avons travaillé à la **compréhension d'un modèle statistique de prédiction de l'activité du moustique tigre**, développé à partir de données de piégeage par ovitramptes (pièges à œufs). Ce modèle n'a pas été réalisé par notre équipe, mais sa lecture et son interprétation ont guidé nos choix de visualisation.

### Variable cible

La variable prédite est la **ponte moyennée par site et par date de collecte**, exprimée en nombre quotidien d'œufs par piège.

### Deux modèles complémentaires

Pour distinguer les facteurs déclenchant l'activité des moustiques de ceux qui en gouvernent l'intensité, deux modèles ont été développés :

- **Modèle de présence/absence** — réponse binaire (1 = œufs détectés, 0 = absence), visant à identifier les conditions météorologiques permettant l'activité des moustiques
- **Modèle d'abondance** — réponse continue (nombre moyen d'œufs par piège et par jour, sur les seuls événements positifs), visant à prédire l'intensité de la ponte

### Pipeline de modélisation

**Étape 1 — Sélection des variables météorologiques**

Des cartes de corrélation croisée (CCM) ont été calculées entre la variable réponse et chaque variable météorologique moyennée sur une semaine, avec des décalages temporels de 0 à 12 semaines. Les CCM permettent d'évaluer les associations entre deux séries temporelles qui peuvent être décalées dans le temps — par exemple, une forte chaleur une semaine N peut n'influencer la ponte qu'en semaine N+3.

**Étape 2 — Sélection du décalage optimal**

Pour chaque variable météorologique, le décalage (en semaines) présentant la corrélation la plus forte avec la variable réponse a été retenu.

**Étape 3 — Filtrage et gestion de la colinéarité**

- Les variables avec une association trop faible (coefficient de corrélation de distance < 0,1) ont été écartées
- En cas de colinéarité forte entre deux variables (corrélation de Pearson > 0,7), seule la plus pertinente écologiquement a été conservée

**Étape 4 — Entraînement par forêts aléatoires (Random Forest)**

Deux modèles Random Forest ont été entraînés :
- Un **RF de classification binaire** pour la présence/absence
- Un **RF de régression** pour l'abondance

Pour éviter le surapprentissage et tester la capacité de généralisation à des sites non observés, une **validation croisée spatiale** a été appliquée : les modèles sont entraînés sur 3 sites et testés sur le 4ème, itérativement.

**Étape 5 — Combinaison des prédictions**

Les deux modèles sont combinés en une prédiction unifiée :
- Si la **probabilité de présence** dépasse le seuil de 0,5 → la valeur du modèle d'abondance est conservée
- Sinon → la prédiction est fixée à **0**

```
Probabilité présence > 0.5  →  valeur abondance prédite
Probabilité présence ≤ 0.5  →  0 (absence)
```

### Apport pour notre visualisation

La compréhension de ce pipeline nous a permis de contextualiser les variables météorologiques et environnementales à afficher en priorité dans Mviewer, et d'interpréter correctement les variations temporelles et spatiales des observations.

---

## Sources et licences

- Données OMEES / INRAE — usage dans le cadre du Marathon du Web
- [Stations d'épuration — Hérault Data](https://www.herault-data.fr/explore/dataset/stations-epuration-lherault/) — Licence Ouverte v2.0
- Données population communale — INSEE 2022 — Licence Ouverte v2.0
