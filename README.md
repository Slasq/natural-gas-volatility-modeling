# Modelowanie i prognozowanie cen gazu TTF

Wielowymiarowa analiza ekonometryczna cen front-month futures TTF z wykorzystaniem
modeli ARIMAX (warunkowa średnia), GARCH-X (warunkowa wariancja) oraz testów
kointegracji (Engle-Granger, Johansen).

Autorzy: Maciek Gilecki, Wioletta Grabias.

## Struktura projektu

```
.
├── data/
│   ├── raw/
│   │   ├── ttf.csv         # TTF front-month z Kaggle/Investing.com (w repo)
│   │   ├── storage_eu.csv  # ręcznie pobrane z AGSI+ (patrz nizej)
│   │   ├── brent.csv       # pobierane automatycznie z FRED (cache)
│   │   ├── eurusd.csv      # j.w.
│   │   └── weather_hdd.csv # pobierane automatycznie z Open-Meteo (cache)
│   └── processed/
│       └── ttf_merged.csv  # finalny panel dzienny (tworzony przy knit)
├── docs/Docs.pdf           # specyfikacja projektu
├── TTF_Ekonometria.Rmd     # cały raport - pobranie danych, modelowanie, prognoza
└── README.md
```

## Zmienne w modelu

| Symbol | Opis | Źródło |
|---|---|---|
| `TTF` | Cena front-month TTF [EUR/MWh] | Investing.com via Kaggle |
| `Brent` | Ropa Brent [USD/bbl] | FRED `DCOILBRENTEU` |
| `EURUSD` | USD za 1 EUR | FRED `DEXUSEU` |
| `Storage_pct` | % wypełnienia magazynów UE | AGSI+ (ręczny eksport CSV) |
| `T_mean_EU` | Ważona śr. temperatura Europy Zach. [°C] | Open-Meteo Historical |
| `HDD` | Heating Degree Days (baza 18 °C) | Open-Meteo Historical |

## Jak uruchomić

### 1. Pobierz zapasy gazu z AGSI+

Wejdź na <https://agsi.gie.eu/data-overview/EU>, ustaw zakres dat
`2015-01-01` – `2024-11-29` i kliknij **Download CSV**. Zapisz plik jako:

```
data/raw/storage_eu.csv
```

Parser w Rmd automatycznie wykrywa separator (`,` lub `;`) i nazwy kolumn,
więc nic nie trzeba edytować.

> Jeśli pominiesz ten krok, raport wciąż się wyrenderuje, ale bez regresora
> `Storage_pct` (4 zmienne zamiast 5).

### 2. Otwórz Rmd w RStudio

```
File -> Open File -> TTF_Ekonometria.Rmd
```

### 3. Knit

Kliknij niebieski przycisk **Knit** (lub `Ctrl+Shift+K`).

Co się stanie podczas pierwszego knit:

1. Auto-instalacja brakujących pakietów (~1-2 min za pierwszym razem).
2. Pobranie Brent i EUR/USD z FRED (CSV bezpośrednio, bez API).
3. Pobranie temperatur z Open-Meteo dla 6 aglomeracji Europy Zach.
4. Wczytanie ręcznie pobranego AGSI+ i wczytanie TTF.
5. Scalenie wszystkiego do jednego panelu dziennego.
6. Pełna analiza: EDA, stacjonarność, kointegracja, ARIMA/ARIMAX, ARCH-LM,
   GARCH-X, walk-forward OOS, Diebold-Mariano, prognoza punktowa i wariancji.

Wynik: `TTF_Ekonometria.html` w katalogu projektu.

**Drugi knit** jest szybki — pobrane dane są cache'owane w `data/raw/`,
walk-forward OOS jest cache'owany na poziomie chunk'a.

## Wymagane pakiety R (auto-instalowane)

`tidyverse`, `lubridate`, `zoo`, `readr`, `quantmod`, `httr`, `jsonlite`,
`forecast`, `tseries`, `FinTS`, `rugarch`, `urca`, `moments`, `xts`,
`patchwork`, `GGally`, `knitr`, `kableExtra`.
   (`Storage_pct` w równaniu warunkowej wariancji).
4. Dodaje **walidację out-of-sample** (walk-forward 2024) z testem
   **Diebolda-Mariano** porównującym model jednowymiarowy z wielowymiarowym.
5. Aktualizuje hipotezy badawcze (H2-H5 odzwierciedlają wielowymiarowy charakter).
