#' 02_merge_data.R
#'
#' Scalenie wszystkich szeregow z data/raw/ do jednego panelu dziennego
#' w data/processed/ttf_merged.csv.
#'
#' Strategia czestotliwosci:
#'  - TTF, Brent, EUR/USD       -> dzienne natywnie (kalendarz dni roboczych)
#'  - Zapasy gazu UE (AGSI+)    -> dzienne natywnie (od 2014 AGSI+ raportuje dziennie)
#'  - Pogoda / HDD              -> dzienne natywnie (Open-Meteo)
#'
#' Wspolny kalendarz: dni z dostepna obserwacja TTF (sesje gieldowe),
#' braki w pozostalych zmiennych uzupelniamy LOCF (last observation carried forward)
#' z limitem 5 dni - dluzsze luki sygnalizuje braki danych do raportu.

required <- c("dplyr", "lubridate", "readr", "tidyr", "zoo")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install) > 0) install.packages(to_install)
invisible(lapply(required, library, character.only = TRUE))

RAW_DIR  <- file.path("data", "raw")
OUT_DIR  <- file.path("data", "processed")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# Wczytanie i normalizacja TTF (parser daty - format DD/MM/YYYY z Investing.com)
# -----------------------------------------------------------------------------
ttf <- read_csv(file.path(RAW_DIR, "ttf.csv"), show_col_types = FALSE) |>
  mutate(
    Date = suppressWarnings(parse_date_time(
      Date, orders = c("dmy", "mdy", "ymd")
    )),
    Date  = as.Date(Date),
    Price = as.numeric(gsub(",", "", as.character(Price)))
  ) |>
  select(Date, TTF = Price) |>
  filter(!is.na(Date), !is.na(TTF)) |>
  arrange(Date) |>
  distinct(Date, .keep_all = TRUE)

cat("TTF      :", nrow(ttf), "obs.,",
    as.character(min(ttf$Date)), "-", as.character(max(ttf$Date)), "\n")

# -----------------------------------------------------------------------------
# Pozostale szeregi (z mozliwoscia braku pliku, gdy fetch nie pobral)
# -----------------------------------------------------------------------------
read_optional <- function(path) {
  if (file.exists(path)) read_csv(path, show_col_types = FALSE) else NULL
}

# Storage z AGSI+: obslugujemy oba formaty
#   (a) z API (skrypt 01_fetch_data.R): kolumny Date, Storage_pct, ...
#   (b) z manualnego eksportu CSV na stronie AGSI+:
#         typowe naglowki: "Gas Day", "Full", "Full (%)", ew. ze srednikami zamiast przecinkow
read_storage <- function() {
  # Spróbuj kilku popularnych lokalizacji i nazw plików
  candidates <- c(
    file.path(RAW_DIR, "storage_eu.csv"),
    file.path("data", "storage_eu.csv"),
    file.path(RAW_DIR, "agsi_eu.csv"),
    file.path("data", "agsi_eu.csv")
  )
  path <- candidates[file.exists(candidates)][1]
  if (is.na(path)) return(NULL)

  # Auto-wykryj separator (przecinek lub srednik)
  first_line <- readLines(path, n = 1, warn = FALSE)
  sep <- if (lengths(regmatches(first_line, gregexpr(";", first_line))) >
             lengths(regmatches(first_line, gregexpr(",", first_line)))) ";" else ","

  raw <- read.csv(path, sep = sep, stringsAsFactors = FALSE,
                  check.names = FALSE, na.strings = c("", "NA", "-"))

  # Znajdz kolumne daty
  date_col <- names(raw)[grepl("^(date|gas\\s*day|gasdaystart)$",
                               names(raw), ignore.case = TRUE)][1]
  if (is.na(date_col)) {
    warning("Nie znalazlem kolumny daty w pliku storage. Kolumny: ",
            paste(names(raw), collapse = ", "))
    return(NULL)
  }

  # Znajdz kolumne % wypelnienia
  full_col <- names(raw)[grepl("^(full|storage_pct|full\\s*\\(%\\))$",
                               names(raw), ignore.case = TRUE)][1]
  if (is.na(full_col)) {
    # Heurystyka: kolumna z 'full' w nazwie i wartosciami 0-100
    full_candidates <- names(raw)[grepl("full", names(raw), ignore.case = TRUE)]
    full_col <- full_candidates[1]
  }
  if (is.na(full_col)) {
    warning("Nie znalazlem kolumny 'Full (%)' w pliku storage.")
    return(NULL)
  }

  # Parser daty (AGSI+ uzywa YYYY-MM-DD)
  dates <- suppressWarnings(parse_date_time(
    raw[[date_col]], orders = c("ymd", "dmy", "mdy")
  ))
  pct <- suppressWarnings(as.numeric(gsub(",", ".", as.character(raw[[full_col]]))))

  res <- data.frame(Date = as.Date(dates), Storage_pct = pct) |>
    filter(!is.na(Date), !is.na(Storage_pct)) |>
    arrange(Date) |>
    distinct(Date, .keep_all = TRUE)

  cat("Storage  : zrodlo =", path, "(separator:", sep, ", kolumna daty:",
      date_col, ", kolumna %:", full_col, ")\n")
  res
}

brent   <- read_optional(file.path(RAW_DIR, "brent.csv"))
eurusd  <- read_optional(file.path(RAW_DIR, "eurusd.csv"))
storage <- read_storage()
weather <- read_optional(file.path(RAW_DIR, "weather_hdd.csv"))

if (!is.null(brent))   cat("Brent    :", nrow(brent),   "obs.\n")
if (!is.null(eurusd))  cat("EUR/USD  :", nrow(eurusd),  "obs.\n")
if (!is.null(storage)) cat("Storage  :", nrow(storage), "obs.\n")
if (!is.null(weather)) cat("HDD      :", nrow(weather), "obs.\n")

# -----------------------------------------------------------------------------
# Polaczenie po dacie TTF (left join) + LOCF dla brakow
# -----------------------------------------------------------------------------
merged <- ttf

if (!is.null(brent)) {
  merged <- merged |>
    left_join(brent |> select(Date, Brent), by = "Date")
}
if (!is.null(eurusd)) {
  merged <- merged |>
    left_join(eurusd |> select(Date, EURUSD), by = "Date")
}
if (!is.null(storage)) {
  merged <- merged |>
    left_join(storage |> select(Date, Storage_pct), by = "Date")
}
if (!is.null(weather)) {
  merged <- merged |>
    left_join(weather |> select(Date, T_mean_EU, HDD), by = "Date")
}

# LOCF (max 5 dni - typowy dlugi weekend)
locf_cols <- intersect(c("Brent", "EURUSD", "Storage_pct", "T_mean_EU", "HDD"),
                      names(merged))

merged <- merged |>
  mutate(across(all_of(locf_cols), ~ zoo::na.locf(.x, maxgap = 5, na.rm = FALSE)))

# -----------------------------------------------------------------------------
# Raport jakosci danych
# -----------------------------------------------------------------------------
cat("\n--- Raport jakosci ---\n")
quality <- merged |>
  summarise(across(everything(), ~ sum(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "Zmienna", values_to = "NA_count") |>
  mutate(NA_pct = round(100 * NA_count / nrow(merged), 2))
print(quality)

# Pozostawiamy tylko wiersze, ktore maja TTF + co najmniej Brent i EUR/USD
# (zmienne dzienne, fundamentalne). Storage i HDD moga miec luki na poczatku.
core_cols <- intersect(c("TTF", "Brent", "EURUSD"), names(merged))
merged_clean <- merged |>
  filter(if_all(all_of(core_cols), ~ !is.na(.x)))

cat("\nOkno z kompletem zmiennych dziennych:",
    as.character(min(merged_clean$Date)), "-",
    as.character(max(merged_clean$Date)),
    "(", nrow(merged_clean), "obs. )\n")

write_csv(merged_clean, file.path(OUT_DIR, "ttf_merged.csv"))
cat("\nZapisano:", file.path(OUT_DIR, "ttf_merged.csv"), "\n")
