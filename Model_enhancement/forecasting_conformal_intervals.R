#From github : study_albo_mtp_2023_2024 
# Author : Paul Taconet

########################### Opening packages
library(tidyverse) ## Version ‘2.0.0’
library(caret) ## Version ‘6.0.94’
library(CAST) ## Version ‘1.0.2’
library(ranger) ## Version ‘0.16.0’
library(correlation) ## Version ‘0.8.5’
library(tidyr)

########################### Open dataset containing the dependant and independent variables, ask 

df_model <- read.csv(("df_to_model.csv"),sep = ",") #

# grouper à l'échelle de la ville-semaine de collecte :
df_model <- df_model %>%
  dplyr::relocate(effectif_jour,.before = RR_0_0) %>%
  dplyr::group_by(site, Year,week) %>%
  dplyr::summarise_at(vars(effectif_jour:RFNO), mean, na.rm = TRUE) %>%
  dplyr::ungroup()


df_model <- df_model %>%
  rename(NB_ALBO_TOT = effectif_jour) %>%
  mutate(PRES_ALBO = ifelse(NB_ALBO_TOT>0,"Presence","Absence")) %>% ## to create a "character" variable for presence or absence of Aedes albopictus
  mutate(PRES_ALBO = fct_relevel(PRES_ALBO,c("Presence","Absence"))) %>%
  mutate(PRES_ALBO_NUMERIC = ifelse(PRES_ALBO=="Presence",1,0)) %>% ## to create a numeric variable for presence or absence of Aedes albopictus
  filter(!is.na(NB_ALBO_TOT)) %>%
  dplyr::filter(site!="RENNES")

###########################
#########'Presence model preparation
#########'First step: to select for meteorological and pollutants variables, for every type of variable, the time lag for which the r2 was the highest. Same work is realized for micro climatic, land cover (for each buffer) and socio demographic data.
#########'Second step: to evaluate the correlation between these variables.
#########'Third step: to select the variables not correlated with the highest sense ecological. The first selection is crossed with the other selection done with the VIF with the corSelect function of the fuzzySim package to select variables with the lowest VIF. The final selection is a mixed of both methods.
###########################


##### First step: to select variables for presence models
predictors_presence <- c("TM_0_8","TN_0_7","TX_0_9","UM_5_11","RR_7_8","DRR_0_8","FFM_0_1")

#### Final data frame for the multivariate analysis
df_model_presence <- df_model %>%
  dplyr::select("site","Year", "week" ,  "NB_ALBO_TOT", "PRES_ALBO", predictors_presence)

# On garde uniquement les lignes complètes pour nos prédicteurs et la cible
df_model_presence <- df_model_presence %>%
  drop_na(all_of(predictors_presence), PRES_ALBO)

# Petite vérification pour voir combien de lignes il vous reste :
cat("Nombre de lignes après suppression des NAs :", nrow(df_model_presence), "\n")


## leave location out

#### First step: to parameter the model: leave-one-site-out cross validation
cv_col <- "site"

#### Second step: It will train the model on data from all traps except one location, recursively on all locations. At the end: a table with predicted data for all traps (predicted with data)

indices_cv <- CAST::CreateSpacetimeFolds(df_model_presence, spacevar = cv_col, k = length(unique(unlist(df_model_presence[,cv_col])))) #### Take into acocunt spatil avariability

## Optimising the various model parameters: finding them as a function of predictive power, in relation to a predictive value (ROC, MAE, etc)
tr = trainControl(method="cv", ## Definition of method sampling: cross validation
                  #number = 5,
                  #repeats = 5,
                  index = indices_cv$index,  ##  list of elements to sampling
                  indexOut = indices_cv$indexOut,##  list of items to be set aside for each resampling
                  summaryFunction = twoClassSummary,#comboSummary, ## Calcul of ROC and AUC
                  classProbs = TRUE,
                  savePredictions = 'final',
                  verboseIter = FALSE
                  #search = "random"
)

#### Third step: realisation of the model of random forest, with the method of permutation to evaluate variable importance and calculating the ROC
# mod_presence <- CAST::ffs(predictors = df_model_presence[,predictors_presence], response = df_model_presence$PRES_ALBO, method = "ranger", tuneLength = 10, trControl = tr, metric = "ROC", maximize = TRUE,  preProcess = c("center","scale"))

###########################
#########' Conformal Prediction for Presence/Absence
###########################

sites <- unique(df_model_presence$site)
results_list <- list()
alpha <- 0.05

for (s in sites) {
  
  # Split leave-one-site-out
  df_train <- df_model_presence %>% filter(site != s)
  df_test  <- df_model_presence %>% filter(site == s)
  
  # 1. Modèle
  mod <- ranger(
    formula   = PRES_ALBO ~ .,
    data      = df_train %>% dplyr::select(all_of(predictors_presence), PRES_ALBO),
    num.trees = 500,
    probability = TRUE 
  )
  
  # 2. CALIBRATION PAR CLASSE (Prédictions OOB)
  preds_oob <- mod$predictions
  vraies_classes <- df_train$PRES_ALBO
  
  idx_pres <- which(vraies_classes == "Presence")
  idx_abs  <- which(vraies_classes == "Absence")
  
  scores_nc_pres <- 1 - preds_oob[idx_pres, "Presence"]
  scores_nc_abs  <- 1 - preds_oob[idx_abs, "Absence"]
  
  # 3. SEUILLAGE PAR CLASSE 
  tau_pres <- quantile(scores_nc_pres, probs = 1 - alpha, na.rm = TRUE)
  tau_abs  <- quantile(scores_nc_abs,  probs = 1 - alpha, na.rm = TRUE)
  
  # 4. PRÉDICTION
  preds_test <- predict(mod, data = df_test)$predictions
  
  df_test <- df_test %>%
    mutate(
      # On stocke aussi la proba pour le boxplot plus tard
      prob_presence = preds_test[, "Presence"],
      in_pres = preds_test[, "Presence"] >= (1 - tau_pres),
      in_abs  = preds_test[, "Absence"]  >= (1 - tau_abs),
      
      obs_3cat = case_when(
        in_pres & in_abs  ~ "Incertain",
        in_pres & !in_abs ~ "Presence",
        !in_pres & in_abs ~ "Absence",
        TRUE              ~ "Vide"
      )
    )
  
  results_list[[s]] <- df_test
}

# Assembler tous les sites
df_cv_presence_conformal <- bind_rows(results_list)

# Affichage des pourcentages par catégorie
print(
  df_cv_presence_conformal %>%
    group_by(obs_3cat) %>%
    summarise(n = n()) %>%
    mutate(pct = round(n / sum(n) * 100, 1))
)

# Dataviz : Boxplot des probabilités selon la catégorie conforme
p <- ggplot(df_cv_presence_conformal, aes(x = obs_3cat, y = prob_presence, fill = obs_3cat)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(values = c("Absence" = "#2c7bb6", "Incertain" = "#ffffbf", "Presence" = "#d7191c")) +
  labs(title = "Distribution des probabilités par catégorie conforme",
       x = "Décision du modèle (3 catégories)",
       y = "Probabilité prédite (Ranger)") +
  theme_minimal()

print(p)

res_multiv_model_presence <- list(df_cv = df_cv_presence_conformal, df_mod = df_model_presence) ## to save models, data frame of the model and predictions
saveRDS(res_multiv_model_presence,"res_multiv_model_presence_forecasting_llo.rds")
# --- CALCUL DES MÉTRIQUES ---

# 1. Calcul de la Couverture Globale (Vraie classe = PRES_ALBO)
couverture_globale <- mean(
  (df_cv_presence_conformal$PRES_ALBO == "Presence" & df_cv_presence_conformal$in_pres) |
    (df_cv_presence_conformal$PRES_ALBO == "Absence"  & df_cv_presence_conformal$in_abs)
)

# 2. Calcul de la Couverture par Classe
couverture_pres <- mean(df_cv_presence_conformal$in_pres[df_cv_presence_conformal$PRES_ALBO == "Presence"])
couverture_abs  <- mean(df_cv_presence_conformal$in_abs[df_cv_presence_conformal$PRES_ALBO == "Absence"])

# 3. Calcul de la Taille Moyenne (Efficacité)
taille_moyenne <- mean(df_cv_presence_conformal$in_pres + df_cv_presence_conformal$in_abs)

# --- AFFICHAGE DU BILAN ---
cat("=== BILAN DE LA PRÉDICTION CONFORME ===\n")
cat(sprintf("Couverture Globale    : %.1f %%\n", couverture_globale * 100))
cat(sprintf("Couverture (Presence) : %.1f %%\n", couverture_pres * 100))
cat(sprintf("Couverture (Absence)  : %.1f %%\n", couverture_abs * 100))
cat(sprintf("Taille moyenne du set : %.2f classes par prédiction\n", taille_moyenne))
cat("---------------------------------------\n")
print(table(df_cv_presence_conformal$obs_3cat))

#ESSAI
# --- COMPARAISON : MODÈLE CLASSIQUE vs MODÈLE CONFORME ---

# 1. Création des prédictions classiques (seuil à 0.5)
df_compare <- df_cv_presence_conformal %>%
  mutate(
    # Le modèle classique tranche toujours à 50%
    pred_classique = ifelse(prob_presence >= 0.5, "Presence", "Absence"),
    # On vérifie s'il s'est trompé
    erreur_classique = ifelse(pred_classique == PRES_ALBO, "Correct", "Erreur")
  )

# 2. La Matrice de confusion du modèle classique
cat("=== 1. MATRICE DE CONFUSION DU MODÈLE CLASSIQUE (Seuil 50%) ===\n")
print(table(Prediction_Classique = df_compare$pred_classique, Realite = df_compare$PRES_ALBO))

# 3. Le croisement magique : où sont passées les erreurs ?
cat("\n=== 2. OÙ LE MODÈLE CONFORME A-T-IL PLACÉ CES ERREURS ? ===\n")
print(table(Statut_Classique = df_compare$erreur_classique, Decision_Conforme = df_compare$obs_3cat))

# 4. Un graphique pour la présentation commanditaire
library(ggplot2)
p2 <- ggplot(df_compare, aes(x = erreur_classique, fill = obs_3cat)) +
  geom_bar(position = "fill", color = "black", alpha = 0.8) +
  scale_fill_manual(values = c("Absence" = "#2c7bb6", "Incertain" = "#ffffbf", "Presence" = "#d7191c", "Vide" = "grey")) +
  labs(title = "Que deviennent les erreurs du modèle classique ?",
       subtitle = "Proportion des décisions conformes selon si le modèle de base avait raison ou tort",
       x = "Le modèle classique (50%) s'était-il trompé ?",
       y = "Proportion (1.0 = 100%)",
       fill = "Décision du modèle Conforme") +
  theme_minimal()

print(p2)
