# Handoff — stan projektu TTF Ekonometria

**Data ostatniej aktualizacji:** 24.05.2026, 12:35
**Aktywne sesje:**
- Sesja 1 (02:15): wielowymiarowy refactor (ARIMA → ARIMAX, GARCH → GARCH-X + kointegracja)
- Sesja 2 (12:10): formalna selekcja zmiennych + uzupełnienie HDD

## Gdzie jesteśmy

Pierwotna wersja `.Rmd` była jednowymiarowa (sama cena TTF) i została **odrzucona przez prowadzącego**. Projekt przepisany na model wielowymiarowy z 4 regresorami fundamentalnymi. W sesji 2 dodano formalną sekcję **„Selekcja zmiennych objaśniających"** (sekcja 6, między testami stacjonarności a kointegracją) oraz pobrano brakujące dane HDD. **Knit jeszcze niezrobiony po sesji 2.**

## Stan zmiennych w modelu

| Zmienna | Status | Źródło |
|---|---|---|
| `TTF` | ✓ działa | Kaggle, `data/raw/ttf.csv` (1790 obs., 2017-10-23 → 2024-11-29) |
| `Brent` | ✓ działa | FRED `DCOILBRENTEU` (download.file) |
| `EURUSD` | ✓ działa | FRED `DEXUSEU` (download.file) |
| `Storage_pct` | ✓ działa | AGSI+ ręczny CSV, `data/raw/StorageData_GIE_2015-01-01_2024-11-24.csv` |
| `HDD` | ✓ **DZIAŁA** (sesja 2) | Open-Meteo Archive API, pobrane skryptem `fetch_hdd.ps1`, `data/raw/weather_hdd.csv` (3621 dni, 6 miast ważonych) |
| `T_mean_EU` | ✓ jw. | jw. |

**Efektywny model**: TTF + Brent + EUR/USD + Storage_pct + HDD (5 zmiennych, pełen zestaw).

## Sekcja Selekcji zmiennych (sesja 2)

Dodana jako sekcja 6 (między „Testy stacjonarności" a „Analiza kointegracji"). Logika:

1. **A priori ekonomiczne** (sekcja 3.2, dodana wcześniej) — mechanizm rynkowy dla każdej z 4 zmiennych: Brent (substytucja/indeksacja LNG), EURUSD (kurs importu LNG), Storage (theory of storage), HDD (popyt sezonowy)
2. **Statyczna regresja OLS w pierwszych różnicach** (`r_Brent`, `r_EURUSD`, `d_Storage`, `d_HDD`) — uzasadnione metodologicznie, bo regresory I(0)
3. **VIF + test t Walda + eliminacja wsteczna (p > 0.10) + porównanie zagnieżdżone (AIC/BIC)**
4. Wynik → `selected_diff_vars` → mapping → `selected_arimax_vars` (poziomy)
5. ARIMAX szacuje teraz **dwa modele**: `fit_arimax_full` (GUM, referencyjny) i `fit_arimax_sel` (po selekcji, używany downstream w GARCH/OOS/prognozie)
6. GARCH-X używa `selected_diff_vars` jako `ext_mean_cols`

## TODO — co jeszcze trzeba zrobić

### Priorytet 1 — KNIT i weryfikacja

Knit `.Rmd` → PDF. Po knit-cie sprawdzić:
- [ ] Wynik selekcji w sekcji 6: które regresory przeszły, czy są tam wszystkie 4 (silne ekonomicznie) czy mniej
- [ ] Tabela porównawcza ARIMA vs ARIMAX-pełny vs ARIMAX-po-selekcji (sekcja 9) — różnice AICc/BIC
- [ ] Czy `fit_arimax = fit_arimax_sel` nie wywala downstream (GARCH, OOS, forecast)
- [ ] Wartości liczbowe w sekcji „Weryfikacja hipotez" (Sekcja 14) — niektóre liczby w tabeli pochodzą z poprzedniego knit-u (np. H4: $\alpha_1 + \beta_1 \approx 0.999$); HDD włączone może je nieznacznie zmienić

### Priorytet 2 — Po knit-cie sprawdzić

### Priorytet 2 — Po następnym knit-cie sprawdzić (dziedzictwo z sesji 1)

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
│   │   └── weather_hdd.csv                               # ✓ pobrane przez fetch_hdd.ps1 (sesja 2)
│   └── processed/
│       └── ttf_merged.csv                                # finalny panel (generowany)
├── docs/                                                 # NIE DOTYKAĆ - notatki/research
│   ├── Docs.pdf                                          # specyfikacja od wykładowcy
│   └── TTF_Ekonometria_rozszerzona.docx
├── .gitignore
├── HANDOFF.md                                            # ten plik
├── README.md
├── fetch_hdd.ps1                                         # skrypt PS pobierający HDD (sesja 2, omija R)
├── TTF_Ekonometria.Rmd                                   # główny raport (~1390 linii po sesji 2)
└── TTF_Ekonometria.pdf                                   # ostatni knit (do odświeżenia)
```

## Co zostało zrobione w sesji 2 (12:10)

### Selekcja zmiennych objaśniających (sekcja 6 w `.Rmd`)

- Dodano osobny rozdział *„Selekcja zmiennych objaśniających"* między testami stacjonarności a kointegracją — narracja: *wziąłem dane → obrobiłem → sprawdziłem które się nadają → modeluję na tych które się nadają*
- Metoda: statyczna regresja OLS w pierwszych różnicach + VIF + test t Walda + eliminacja wsteczna (p > 0.10) + porównanie zagnieżdżone po AIC/BIC
- 4 nowe chunki: `vif-test`, `ols-tstats`, `backward-elim`, `nested-ols`, `mapping-to-arimax`
- Mapowanie różnice → poziomy: `r_Brent → log_Brent`, `r_EURUSD → log_EURUSD`, `d_Storage → Storage_pct`, `d_HDD → HDD`
- Wyjście: `selected_diff_vars` i `selected_arimax_vars`

### Integracja z resztą modelu

- Chunk `arimax` przerobiony: szacuje teraz `fit_arimax_full` (GUM, all 4 regs) **oraz** `fit_arimax_sel` (selected)
- `fit_arimax = fit_arimax_sel`, `xreg_full = xreg_sel` → downstream (GARCH, OOS, prognoza) używa modelu po selekcji
- Tabela porównawcza ARIMA vs ARIMAX-pełny vs ARIMAX-po-selekcji (sekcja 9)
- Chunk `garch-prepare` używa `selected_diff_vars` jako `ext_mean_cols` (spójność średniej GARCH z selekcją); wariancja zachowuje `Storage_pct`

### Uzasadnienie ekonomiczne (sekcja 3.2)

- Dodana tabela mechanizmów ekonomicznych dla każdej z 4 zmiennych (substytucyjność Brent, indeksacja LNG, kurs importu, theory of storage, HDD = popyt sezonowy)
- Lista zmiennych świadomie odrzuconych z uzasadnieniem: cena prądu (endogeniczna), LNG/rurociągi (miesięczne), Henry Hub (duplikuje Brent), CO2 EUA (szoki regulacyjne)

### HDD — pobrane

- API Open-Meteo Archive odpowiada (HTTP 200 z PL)
- Skrypt `fetch_hdd.ps1` (PowerShell, niezależny od R) pobrał 60 requestów (6 miast × 10 lat), 100% sukcesu, 3621 dni pokrycia 2015-01-01 → 2024-11-29
- Plik `data/raw/weather_hdd.csv` (Date, T_mean_EU, HDD) — format identyczny z tym, którego oczekuje kod R
- Przy następnym knit-cie: `file.exists(weather_path) == TRUE` → `weather` wczytany → `has_hdd = TRUE` → HDD wchodzi do selekcji i do modeli

## Następna sesja — co powiedzieć asystentowi

> „Przeczytaj HANDOFF.md. Zrób knit i pokaż wyniki selekcji (sekcja 6) oraz tabelę ARIMA vs ARIMAX-pełny vs ARIMAX-po-selekcji (sekcja 9). Jeśli H4/H5 zmieniły werdykt — zaktualizuj tabelę weryfikacji hipotez (sekcja 14)."

Wszystkie istotne konteksty są w tym pliku — nowa sesja nie musi czytać całej historii rozmowy.
