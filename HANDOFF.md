# Handoff — stan projektu TTF Ekonometria

**Data:** 24.05.2026, 02:15
**Sesja:** wielowymiarowy refactor (ARIMA → ARIMAX, GARCH → GARCH-X + kointegracja)

## Gdzie jesteśmy

Pierwotna wersja `.Rmd` była jednowymiarowa (sama cena TTF) i została **odrzucona przez prowadzącego**. Przepisaliśmy projekt na model wielowymiarowy z 4 regresorami fundamentalnymi. Wygenerowany PDF (poprzednia iteracja) miał kilka sprzeczności między tekstem a wynikami liczbowymi — naprawione w bieżącej wersji `.Rmd`. **Drugi knit jeszcze niezrobiony.**

## Stan zmiennych w modelu

| Zmienna | Status | Źródło |
|---|---|---|
| `TTF` | ✓ działa | Kaggle, `data/raw/ttf.csv` (1790 obs., 2017-10-23 → 2024-11-29) |
| `Brent` | ✓ działa | FRED `DCOILBRENTEU` (download.file) |
| `EURUSD` | ✓ działa | FRED `DEXUSEU` (download.file) |
| `Storage_pct` | ✓ działa | AGSI+ ręczny CSV, `data/raw/StorageData_GIE_2015-01-01_2024-11-24.csv` |
| `HDD` | ✗ **NIE POBRANE** | Open-Meteo padał na timeoutach (PL → archive-api) — kod ma graceful skip, narracja wciąż wspomina HDD |
| `T_mean_EU` | ✗ powiązane z HDD | jw. |

**Efektywny model**: TTF + Brent + EUR/USD + Storage_pct (4 zmienne zamiast 5).

## TODO — co jeszcze trzeba zrobić

### Priorytet 1 — HDD

Jest do dokończenia. Trzy opcje (do wyboru):

1. **Ponowić Open-Meteo** w innym terminie / z innej sieci (czasem PL ISP rwie tę domenę). Plik się sam cache'uje do `data/raw/weather_hdd.csv` — wystarczy raz pobrać.
2. **NOAA GSOD** przez pakiet `rnoaa` — alternatywne źródło. Wymaga klucza API (darmowy) z https://www.ncdc.noaa.gov/cdo-web/token.
3. **Wyrzucić HDD całkowicie z narracji** — przegląd Rmd pod kątem słów "HDD", "Heating Degree Days", "T_mean_EU" i albo usunięcie wzmianek, albo dodanie warunku "(jeśli dostępne)".

**Lokalizacje do poprawy gdy zdecydujemy się usunąć HDD z narracji:**
- linia 155: cel projektu
- linia 177: tabela źródeł danych
- linia 678: "Regresory: log Brent, log EURUSD, Storage_pct, HDD" (Sekcja ARIMAX)
- linia 751: "zapasów i HDD" (Sekcja GARCH-X)

### Priorytet 2 — Po następnym knit-cie sprawdzić

- [ ] Czy nowy wykres prognozy ARIMAX (Rys. 9) ma daty na osi X i wstęgi ufności
- [ ] Czy legenda Rys. 8 (OOS) jest czytelna (etykiety Actual/ARIMA/ARIMAX nie obcięte)
- [ ] Czy Phillips-Ouliaris zwraca sensowny wynik (jeśli output `urca` zbyt obszerny, ograniczyć przez `cat()` na wybrane fragmenty)
- [ ] Czy tabela weryfikacji hipotez mieści się na stronie A4 (kolumna "Uzasadnienie" jest długa — w razie czego użyć `linebreak()` z `kableExtra`)
- [ ] Czy polskie znaki wszędzie się renderują (xelatex + babel-polish)

### Priorytet 3 — Opcjonalne ulepszenia (gdyby było mało)

- **Formalne równania** ARIMAX i GARCH(1,1)-X (TeX) w sekcjach metodologicznych — wykładowca może doceniać formalizm
- **DCC-GARCH** jako multivariate rozszerzenie (pakiet `rmgarch`)
- **VAR w stopach zwrotu** (skoro VECM odpada bez kointegracji) — pakiet `vars`
- **Diebold-Mariano z dłuższym horyzontem** (h=5, h=22) — może okazać się że ARIMAX wygrywa na dłuższych horyzontach prognozy

## Co zostało zrobione w tej sesji

### Struktura projektu

- Stworzona struktura `data/raw/`, `data/processed/`
- Wyodrębniono `R/01_fetch_data.R` i `R/02_merge_data.R`, **potem zinlineowano** do `.Rmd` na życzenie użytkownika — folder `R/` usunięty
- `README.md` z instrukcją uruchomienia
- `.gitignore` ignoruje tylko `*.html`, `.Renviron`, `.env` (CSV-y są w repo)

### Output PDF

- YAML zmieniony z `html_document` na `pdf_document` z `xelatex` (obsługa polskich znaków)
- LaTeX pakiety: `babel-polish`, `float` (figure[H]), `booktabs`, `longtable`, `colortbl`
- Wszystkie `kable_styling(bootstrap_options=...)` przepisane na `latex_options = c("striped", "HOLD_position")`

### Modelowanie

- ARIMA → **ARIMAX** z xreg = log(Brent), log(EURUSD), Storage_pct (oraz HDD jeśli dostępny)
- GARCH → **GARCH-X**: regresory w równaniu średniej (r_Brent, r_EURUSD, d_Storage) i wariancji (Storage_pct)
- Porównanie 4 modeli: sGARCH, sGARCH-X, eGARCH-X, gjrGARCH-X (AIC/BIC)
- **Walk-forward OOS** na 2024 + **test Diebolda-Mariano** (ARIMA vs ARIMAX)
- **Kointegracja**: Engle-Granger + **Phillips-Ouliaris** (poprawny) + Johansen

### Narracja i wnioski

- Tabela weryfikacji hipotez z **werdyktami opartymi na realnych wynikach**:
  - H1 ✓ Potwierdzona
  - H2 ✗ Nieuzasadniona (EG p=0.07, Johansen marginal)
  - H3 ✓ Potwierdzona
  - H4 ◐ Częściowo (po BIC wygrywa najprostszy sGARCH, po AIC najlepszy eGARCH-X)
  - H5 ✗ Odrzucona (DM p=0.12)
- Komentarze interpretacyjne pod Rys. 2 (szeregi), Rys. 3 (klastry zmienności), Rys. 4 (ACF/PACF), Rys. 8 (OOS)
- Sekcja "Ograniczenia" wymienia efektywny zakres dat, uwagę o ADF na resztach EG, brak uzasadnienia dla VECM

### Kosmetyka

- "Prognoza **przyszła**" (poprawione)
- Tabela braków: usunięto wiersz Date
- Rys. 8 (OOS): szersza grafika, legenda na dole
- Rys. 9 (forecast): manualny ggplot z datami i wstęgami 80%/95%

## Struktura plików

```
.
├── data/
│   ├── raw/
│   │   ├── ttf.csv                                       # in repo
│   │   ├── StorageData_GIE_2015-01-01_2024-11-24.csv     # AGSI+ ręczny, in repo
│   │   ├── brent.csv                                     # FRED cache (generowany)
│   │   ├── eurusd.csv                                    # FRED cache (generowany)
│   │   └── weather_hdd.csv                               # ← BRAK, do dorobienia
│   └── processed/
│       └── ttf_merged.csv                                # finalny panel (generowany)
├── docs/                                                 # NIE DOTYKAĆ - notatki/research
│   ├── Docs.pdf                                          # specyfikacja od wykładowcy
│   └── TTF_Ekonometria_rozszerzona.docx
├── .gitignore
├── HANDOFF.md                                            # ten plik
├── README.md
├── TTF_Ekonometria.Rmd                                   # główny raport (1049 linii)
└── TTF_Ekonometria.pdf                                   # ostatni knit (do odświeżenia)
```

## Następna sesja — co powiedzieć asystentowi

> "Przeczytaj HANDOFF.md i wróćmy do HDD. Mam/nie mam dane z [Open-Meteo / NOAA / chcę usunąć]. Zrób knit i sprawdź czy [konkretne rzeczy z TODO Priorytet 2]."

Wszystkie istotne konteksty są w tym pliku — nowa sesja nie musi czytać całej historii rozmowy.
