# Collection of scripts to extract Black's parameters from a serie of electromigration experiments
# September 2015
# Emmanuel Chery

# Required Packages
library('ggplot2')
library('MASS')
library('scales')


Ranking <- function(V)
# Calcul de l'estimateur de fraction selon le modèle
# rk(i)=(i-0.3)/(n+0.4) pour un vecteur V.
{
    rk <- (rank(V)-0.3)/(length(V)+0.4)
}


Weibit <- function(P)
# Calcul du Weibit selon le modèle
# W= ln(-ln(1-P)) pour un vecteur P.
{
    W=log(-log(1-P))
}


LognormProba <- function(P)
# Calcul de la proba en échelle normal selon le modèle
# W= qnorm(P) pour un vecteur P. Nécessaire pour un graph
# gausso arythmétique. Droite de Henri.
{
    W=qnorm(P)
}


Clean <- function(V,S)
# Nettoyage des temps à la défaillance en fonction du vecteur Status (S)
# Seuls les temps précédés d'un 0 ou d'un 1 sont conservés.
# Finallement, on tri les temps et leur status
{
    V <- V[S==0 | S==1]
    S <- S[S==0 | S==1]
    #Res <- list('TTF'=V,'Status'=S)
    Res <- data.frame('TTF'=V,'Status'=S)
    Res <- Res[order(Res$"TTF"),] # Tri selon les TTF
    return(Res)
}


ArrangeLognorm <- function(Status, TTF, Condition)
# Création d'un dataframe avec le status, le temps à défaillance,
# la probabilité cumulée pour une fonction lognormale et la condition.
# Les données sont d'abord nettoyées (Clean), puis la probabité cumulée
# est calculée.
{
    CleanedData <- Clean(TTF,Status) # Nettoyage -- Données triées
    rk <- Ranking(CleanedData$TTF) # Calcul de l'estimateur de fraction
    Proba <- LognormProba(rk) # Calcul de la proba en echelle lognormale.
    Data <- data.frame('TTF'=CleanedData$TTF,'Status'=CleanedData$Status,'Probability'=Proba,'Conditions'=Condition)
    return(Data)
    # Data (TTF,Status,Probability,Condition)
}


ArrangeWeibul <- function(Status, TTF, Condition)
# Création d'un dataframe avec le status, le temps à défaillance,
# la probabilité cumulée pour une fonction lognormale et la condition.
# Les données sont d'abord nettoyées (Clean), puis la probabité cumulée
# est calculée.
{
    CleanedData <- Clean(TTF,Status) # Nettoyage -- Données triées
    rk <- Ranking(CleanedData$TTF) # Calcul de l'estimateur de fraction
    Proba <- Weibit(rk) # Calcul de la proba en echelle lognormale.
    Data <- data.frame('TTF'=CleanedData$TTF,'Status'=CleanedData$Status,'Probability'=Proba,'Conditions'=Condition)
    return(Data)
    # Data (TTF,Status,Probability,Condition)
}


Plot <- function(Table, Scale="Lognormale")
# Prend la table de données issue de ArrangeXxxxx et trace le graphe correspondant
# Le paramètre facultatif Scale permet de tracer une échelle Weibull.
{
    # Calcul des limites pour le graphe
    lim <- range(Table[,1])
    lim.high <- 10^(ceiling(log(lim[2],10)))
    lim.low <- 10^(floor(log(lim[1],10)))
    # Basé sur les limites, le calculs des etiquettes de l'axe x.
    GraphLabels <- 10^(seq(floor(log(lim[1],10)),ceiling(log(lim[2],10))))

    # Calcul des etiquettes de l'axe y
    # Etiquettes dynamique en fonction de la probabilité minimale

    # Cas Weibull
    if (Scale == "Weibull") {
        if (Table[1,3]<= Weibit(0.1/100)){ # Cas 1: inférieur à 0.1%
            ListeProba <- c(0.01,0.1,1,5,10,20,30,40,50,63,70,80,90,95,99,99.9,99.99)
        }
        if (Table[1,3]<= Weibit(1/100) && Table[1,3]>= Weibit(0.1/100)){ # Cas 2: inférieur à 1% mais supérieur à 0.1%
            ListeProba <- c(0.1,1,5,10,20,30,40,50,63,70,80,90,95,99,99.9)
        }
        if (Table[1,3] >= Weibit(1/100)) { # Cas 3: Supérieur à 1%
            ListeProba <- c(1,5,10,20,30,40,50,63,70,80,90,95,99)
        }
    ProbaNorm <- Weibit(ListeProba/100)

    } else { # Cas distribution lognormale
        if (Table[1,3]<= qnorm(0.1/100)){ # Cas 1: inférieur à 0.1%
            ListeProba <- c(0.01,0.1,1,5,10,20,30,40,50,60,70,80,90,95,99,99.9,99.99)
        }
        if (Table[1,3]<= qnorm(1/100) && Table[1,3]>= qnorm(0.1/100)){ # Cas 2: inférieur à 1% mais supérieur à 0.1%
            ListeProba <- c(0.1,1,5,10,20,30,40,50,60,70,80,90,95,99,99.9)
        }
        if (Table[1,3] >= qnorm(1/100)) { # Cas 3: Supérieur à 1%
            ListeProba <- c(1,5,10,20,30,40,50,60,70,80,90,95,99)
        }
    ProbaNorm <- qnorm(ListeProba/100)
    }

    # Création du sous ensemble avec les temps où le status est à 1.
    # La table est triée pour que les conditions soient continues.
    Table <- Table[Table$Status==1,]
    Table <- Table[order(Table$"Conditions"),]

    # Création du graph
    # Seul les temps ou le status est à 1 sont affichés.
    Plot <- ggplot(data=Table, aes(x=TTF, y=Probability, colour=Conditions, shape=Conditions))
    Plot <- Plot + scale_x_log10(limits = c(lim.low,lim.high),breaks = GraphLabels,labels = trans_format("log10", math_format(10^.x)))
    Plot <- Plot + scale_y_continuous(limits=range(ProbaNorm), breaks=ProbaNorm, labels=ListeProba )
    Plot <- Plot + geom_point(size=4)+annotation_logticks(sides='tb')
    print(Plot)
}


StackData <- function(Table1, Table2)
# Associe 2 dataframe à la suite
{
    Data <- merge(Table1, Table2, all=TRUE)
    Data <- Data[order(Data$"Conditions"),]
    return(Data)
}


Modelization <- function(Data, Condition, Type="Lognormale")
# Genration de la distribution theorique et les intervalles de confience
# à partir de données expérimentales.

# Calcul des limites pour le graphe
lim <- range(Data)
lim.high <- 10^(ceiling(log(lim[2],10)))
lim.low <- 10^(floor(log(lim[1],10)))
x <- 10^seq(log(lim.low,10),log(lim.high,10),0.05) # serie de points pour le modèle

{
    if (Type=="Weibull") {
        fit <- fitdistr(Data,"weibull")
        Shape <- fit$estimate[1]  # Beta
        Scale <- fit$estimate[2]  # Charac time
        y <- pweibull(x, Shape, Scale)

    } else { # All other case are considered as Lognormale
        fit <- fitdistr(Data,"lognormal")
        Scale <- fit$estimate[1]  #   meanlog
        Shape <- fit$estimate[2]  # sdlog
        y <- plnorm(x, Scale, Shape)
    }

Model <- data.frame('TTF'=x,'Status'=1,'Probability'=y,'Conditions'=Condition)
}
