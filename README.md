# Modelowanie i prognozowanie cen gazu TTF

Wielowymiarowa analiza ekonometryczna cen front-month futures TTF z wykorzystaniem
modeli ARIMAX (warunkowa średnia), GARCH-X (warunkowa wariancja) oraz testów
kointegracji (Engle-Granger, Johansen).

Autorzy: Maciek Gilecki, Wioletta Grabias.

## Struktura projektu

```
.
├── R/
│   ├── 01_fetch_data.R     # pobranie szeregów: Brent (FRED), EUR/USD (FRED),
│   │                       # zapasy UE (AGSI+ API), HDD (Open-Meteo)
│   └── 02_merge_data.R     # scalenie wszystkich źródeł do jednego panelu dziennego
├── data/
│   ├── raw/                # surowe CSV-ki z poszczególnych źródeł
│   │   ├── ttf.csv         # TTF front-month z Kaggle/Investing.com (zachowany)
│   │   ├── brent.csv       # generowane przez 01_fetch_data.R
│   │   ├── eurusd.csv      # j.w.
│   │   ├── storage_eu.csv  # j.w. (wymaga klucza AGSI+)
│   │   └── weather_hdd.csv # j.w.
│   └── processed/
│       └── ttf_merged.csv  # finalny panel dzienny używany przez .Rmd
├── docs/
│   └── Docs.pdf            # specyfikacja projektu
├── TTF_Ekonometria.Rmd     # główny raport (renderuj do HTML)
└── README.md
```

## Zmienne w modelu

| Symbol | Opis | Źródło | Częstotliwość natywna |
|---|---|---|---|
| `TTF` | Cena front-month TTF [EUR/MWh] | Investing.com via Kaggle | dzienna |
| `Brent` | Ropa Brent [USD/bbl] | FRED `DCOILBRENTEU` | dzienna |
| `EURUSD` | USD za 1 EUR | FRED `DEXUSEU` | dzienna |
| `Storage_pct` | % wypełnienia magazynów UE | AGSI+ API (GIE) | dzienna |
| `T_mean_EU` | Ważona śr. temperatura Europy Zach. [°C] | Open-Meteo Historical | dzienna |
| `HDD` | Heating Degree Days (baza 18 °C) | Open-Meteo Historical | dzienna |

## Pierwsze uruchomienie

### 1. Klucz API AGSI+ (jednorazowo)

Zapasy gazu UE pobierane są z [AGSI+ API](https://agsi.gie.eu/) operatora GIE.
API jest **darmowe**, ale wymaga rejestracji konta:

1. Załóż konto na <https://agsi.gie.eu/account>.
2. W panelu wygeneruj klucz API.
3. Ustaw klucz jako zmienną środowiskową — najwygodniej trwale w `~/.Renviron`:

   ```
   AGSI_API_KEY=twoj_klucz_tutaj
   ```

   Alternatywnie w sesji R:

   ```r
   Sys.setenv(AGSI_API_KEY = "twoj_klucz_tutaj")
   ```

> **Bez klucza** skrypt `01_fetch_data.R` pominie zapasy i pójdzie dalej —
> model będzie wciąż wielowymiarowy (Brent, EUR/USD, HDD), ale słabszy.

Pozostałe źródła (FRED, Open-Meteo) **nie wymagają klucza**.

### 2. Pobranie i scalenie danych

W R lub RStudio, z poziomu katalogu projektu:

```r
source("R/01_fetch_data.R")   # pobiera Brent, EUR/USD, storage, pogodę
source("R/02_merge_data.R")   # scala z TTF do data/processed/ttf_merged.csv
```

Skrypty zainstalują brakujące pakiety automatycznie.

### 3. Renderowanie raportu

```r
rmarkdown::render("TTF_Ekonometria.Rmd")
```

Wynik: `TTF_Ekonometria.html` w katalogu projektu.

## Wymagane pakiety R

Automatycznie instalowane przez skrypty:

- **Pobieranie**: `quantmod`, `httr`, `jsonlite`, `dplyr`, `lubridate`, `readr`, `purrr`, `tidyr`, `zoo`
- **Modelowanie**: `tidyverse`, `forecast`, `tseries`, `FinTS`, `rugarch`, `moments`,
  `urca`, `xts`, `patchwork`, `knitr`, `kableExtra`, `GGally`

## Co się zmieniło względem pierwotnej wersji

Pierwsza wersja raportu była **jednowymiarowa** (tylko cena TTF) — została odrzucona
przez prowadzącego jako niezgodna ze specyfikacją z `docs/Docs.pdf`. Aktualna wersja:

1. Wprowadza **regresory egzogeniczne** Brent, EUR/USD, zapasy UE i HDD.
2. Dodaje sekcję **kointegracji** (Engle-Granger, Johansen) jako uzasadnienie
   długookresowej relacji TTF–Brent.
3. Rozszerza ARIMA → **ARIMAX**, GARCH → **GARCH-X**
   (`Storage_pct` w równaniu warunkowej wariancji).
4. Dodaje **walidację out-of-sample** (walk-forward na okresie 2024)
   oraz **test Diebolda–Mariano** porównujący model jednowymiarowy z ARIMAX.
5. Aktualizuje hipotezy badawcze (H2–H5 odzwierciedlają wielowymiarowy charakter).
