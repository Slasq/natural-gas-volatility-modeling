# Modelowanie cen gazu TTF: ARIMA + GARCH

Projekt zaliczeniowy z ekonometrii — analiza szeregu czasowego cen
gazu ziemnego na holenderskim hubie TTF (Title Transfer Facility).

## Cel

Zbudowanie i porównanie modeli klasy ARIMA oraz GARCH dla cen TTF
w okresie obejmującym szok podażowy 2022 r. (odcięcie dostaw z Rosji).

## Metodyka

- Test stacjonarności (ADF, KPSS)
- Identyfikacja rzędów ARIMA (ACF/PACF, AIC/BIC grid search)
- Diagnostyka reszt (Ljung-Box, Jarque-Bera)
- Test efektu ARCH (ARCH-LM)
- Estymacja GARCH(1,1), eGARCH, gjrGARCH z błędem t-Studenta
- Prognoza warunkowej średniej i wariancji

## Stack

- R 4.5
- Pakiety: `forecast`, `rugarch`, `tseries`, `FinTS`, `tidyverse`

## Dane

Dutch TTF Natural Gas Futures Historical Dataset z Kaggle:
https://www.kaggle.com/datasets/arushirawat/dutch-ttf-natural-gas-futures-historical-dataset

Pobierz CSV i umieść w `data/ttf.csv`.

## Uruchomienie

```r
# Instalacja pakietów
install.packages(c("tidyverse", "forecast", "tseries", "FinTS",
                   "rugarch", "moments", "patchwork", "knitr",
                   "kableExtra", "tinytex"))

# Knit do PDF
rmarkdown::render("TTF_Ekonometria.Rmd")
```

## Autor

Maciek Gilecki, Wioletta Grabias — Inżynieria i Analiza Danych, Politechnika Rzeszowska
