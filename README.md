# OMEES — Tableau de Bord Surveillance Moustique Tigre (Hérault)

## Vue d'ensemble

Cette plateforme web permet la **surveillance et la visualisation** de la présence du moustique tigre (*Aedes albopictus*) dans le département de l'Hérault. Elle est composée de deux interfaces complémentaires et d'un script de préparation des données.

---

## Structure des fichiers

```
/
├── index.html                          # Vue citoyen
├── mosquito_dashboard_regional.html    # Tableau de bord élu
├── Data/
│   ├── albo_weekly_herault.json        # Données hebdomadaires (base)
│   └── albo_weekly_herault_enriched.json  # Avec population + superficie
├── enrich_json_with_population.py      # Script d'enrichissement
├── preview.webp                        # Image du popup d'accueil
└── responsive.css                      # Styles communs
```

---

## 1. Vue Citoyen — `index.html`

Interface grand public pour consulter le niveau de risque moustique tigre sur la carte de l'Hérault.

### Fonctionnalités

#### Carte interactive (Leaflet)
- Carte choroplèthe des communes de l'Hérault colorée selon le niveau d'abondance
- Trois niveaux de risque : **Faible** (vert), **Modéré** (orange), **Élevé** (rouge)
- Tooltip au survol affichant abondance, température, humidité et pluviométrie
- Navigation temporelle semaine par semaine (slider + boutons Préc/Play/Suiv)

#### Modes d'affichage
| Mode | Données affichées |
|------|-------------------|
| Brute | Abondance brute (ind/piège) |
| Vue risque | Couleurs selon seuils Faible/Modéré/Élevé |

#### Recherche de commune
- Widget de recherche autocomplete (> 2 caractères)
- Affichage du niveau de risque, tendance (↗ ↘ →) et valeurs de la commune sélectionnée
- Zoom automatique sur la commune sur la carte

#### Mode Élu (accès via bouton header)
Active un panneau latéral droit avec :
- **KPIs** : nombre de communes en alerte élevée, modérée, abondance moyenne
- **Onglet Tendances** : évolution temporelle + distribution des risques empilée
- **Onglet Classement** : top 10 communes par abondance (barres horizontales)
- **Onglet Alertes** : liste des communes dépassant le seuil modéré

#### Popup d'accueil
- S'ouvre au chargement de la page
- Présente les 3 gestes de prévention (image preview.webp)
- Accordéons **S'informer** (vidéo YouTube + liens) et **Agir** (signalement ANSES)
- Fermeture avec animation de minimisation → **bulle flottante** dans le coin inférieur gauche
- Clic sur la bulle → réouverture du popup

### Modaux informatifs
- **Comprendre la carte** : explication des 3 niveaux de risque et comment les interpréter
- **Que puis-je faire ?** : conseils pratiques par niveau de risque

---

## 2. Tableau de Bord Élu — `mosquito_dashboard_regional.html`

Interface avancée pour les élus et gestionnaires, avec visualisations scientifiques et données normalisées.

### Architecture de la page

Mise en page en 3 colonnes :
- **Panneau gauche** : contrôles (variable, temps, légende, KPIs, jauge de risque)
- **Centre** : carte Leaflet interactive
- **Panneau droit** : graphiques et analyses (4 onglets)

### Gestion des échelles cartographiques ⭐

Bouton **🔬 Échelle** dans le header — cycle entre 3 modes :

| Bouton | Échelle | Calcul | Données requises |
|--------|---------|--------|-----------------|
| 🔬 Brute | ind/piège | Valeur brute | Aucune |
| 🗺 /km² | ind/km² | abondance ÷ superficie | `superficie_km2` |
| 👤 /hab. | ind/1000hab | (abondance × 1000) ÷ population | `population` |

Les seuils colorimétiques des modes /km² et /hab. sont **calculés dynamiquement** par percentiles (P20–P80) pour garantir un contraste visuel optimal quelle que soit la semaine.

### Variables cartographiables

| Variable | Palette | Seuils |
|----------|---------|--------|
| 🦟 Abondance | Vert → Rouge | 0 / 2 / 5 / 10 / 20 |
| 🌡️ Température | Bleu → Rouge | 0 / 10 / 15 / 20 / 30°C |
| 🌧️ Pluie | Blanc → Bleu foncé | 0 / 10 / 25 / 50 / 100mm |
| 💧 Humidité | Crème → Brun | 40 / 55 / 65 / 75 / 90% |

### Onglets du panneau droit

#### Bivariée
- **Scatter Température × Abondance** : corrélation visuelle entre chaleur et densité de moustiques
- **Scatter Humidité × Abondance** : impact de l'humidité
- **SHAP proxy** : importance relative de chaque variable climatique (température, pluie, humidité) sur l'abondance — calculé par corrélation de Pearson pondérée par le coefficient de variation
- Toggle **📐 Échelle fixe / 🔀 Adaptative** : axes fixes sur toutes les semaines vs. adaptation automatique

#### Classement
- Top 10 communes par abondance avec barres de progression

#### Tendances ⭐
- **Évolution abondance** : courbe avec dégradé rouge→vert selon le niveau de risque, points colorés par commune, lignes de seuil Modéré (3) et Élevé (10)
- **Distribution des risques (empilé)** : % de communes Faible/Modéré/Élevé par semaine sur les 30 dernières semaines
- **Température × Abondance (dual axis)** : deux séries sur deux axes Y avec lignes de seuil
- **Profil climatique** : température, humidité et pluie sur une même fenêtre temporelle
- **Distribution (histogramme)** : répartition statistique des valeurs d'abondance

#### Alertes
- Liste des communes dépassant le seuil modéré (abondance ≥ 2) avec code couleur
- **Séries temporelles top 5** : évolution des 5 communes les plus touchées sur la période

### Fonctionnalités supplémentaires
- **⤢ Expansion** : clic sur l'icône en haut à droite de chaque graphique → affichage plein écran dans un modal
- **Export CSV** (mode élu de index.html) : export des données de la semaine courante

---

## 3. Script d'enrichissement — `enrich_json_with_population.py`

Prépare le fichier JSON de données pour activer les échelles /km² et /hab.

### Utilisation

```bash
python enrich_json_with_population.py \
    --csv  albopictus_climate_suitability_weekly.csv \
    --json albo_weekly_herault.json \
    --out  albo_weekly_herault_enriched.json
```

### Ce que fait le script
1. Lit le CSV source et extrait `P22_POP` et `SUPERFICIE_KM2` par `codgeo`
2. Joint ces données à chaque commune du JSON via `codgeo`
3. Ajoute deux champs à chaque entrée : `population` (float | null) et `superficie_km2` (float | null)
4. Conserve intégralement les champs existants : `libgeo`, `dep`, `codgeo`, `weeks`

### Source des données
| Champ JSON | Colonne CSV | Description |
|-----------|------------|-------------|
| `population` | `P22_POP` | Population communale 2022 (INSEE) |
| `superficie_km2` | `SUPERFICIE_KM2` | Surface de la commune en km² |

---

## 4. Format des données

### albo_weekly_herault.json (structure de base)
```json
[
  {
    "libgeo": "Montpellier",
    "dep": "34",
    "codgeo": "34172",
    "population": 295542.0,
    "superficie_km2": 56.88,
    "weeks": [
      {
        "date": "2023-05-01",
        "date_fin": "2023-05-07",
        "abundance": 4.2,
        "sd_abundance": 1.1,
        "temperature": 18.5,
        "rainfall": 12.3,
        "humidity": 65.0
      }
    ]
  }
]
```

---

## 5. Dépendances externes

| Bibliothèque | Version | Usage |
|-------------|---------|-------|
| Leaflet | 1.9.4 | Carte interactive |
| Chart.js | 4.4.0 | Graphiques |
| chartjs-plugin-annotation | 3.0.1 | Lignes de seuil sur les graphiques |
| CartoDB Basemaps | — | Fond de carte |
| geo.api.gouv.fr | — | Contours communaux (API) |

---

## 6. Configuration rapide

1. Placer les fichiers sur un serveur web (local ou distant)
2. Générer le JSON enrichi avec le script Python
3. Mettre à jour le chemin dans `initDashboard()` si nécessaire : `fetch('Data/albo_weekly_herault_enriched.json')`
4. Pour la bulle du popup : remplacer 🦟 dans `#welcome-bubble` par `<img src="votre_image.png">`

---

*OMEES — Observatoire du Moustique et des Espèces Envahissantes — Hérault (34)*
