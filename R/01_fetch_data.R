#' 01_fetch_data.R
#'
#' Pobranie surowych szeregow czasowych do data/raw/:
#'  - Brent       (FRED:  DCOILBRENTEU)        - cena ropy [USD/baryle], dzienna
#'  - EUR/USD     (FRED:  DEXUSEU)             - kurs USD za 1 EUR, dzienna
#'  - Zapasy gazu (AGSI+ API, kraj = EU)       - % wypelnienia magazynow, dzienna/tygodniowa
#'  - HDD pogoda  (Open-Meteo Historical API)  - heating degree days (proxy popytu), dzienna
#'
#' Wymagania:
#'  - Klucz AGSI+ (darmowy po rejestracji na https://agsi.gie.eu/account)
#'    ustawiony w zmiennej srodowiskowej AGSI_API_KEY lub w pliku ~/.Renviron:
#'      AGSI_API_KEY=twoj_klucz_tutaj
#'  - Pakiety: quantmod, httr, jsonlite, dplyr, lubridate, readr

required <- c("quantmod", "httr", "jsonlite", "dplyr", "lubridate", "readr", "purrr", "tidyr")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install) > 0) install.packages(to_install)
invisible(lapply(required, library, character.only = TRUE))

# -----------------------------------------------------------------------------
# Konfiguracja zakresu czasowego
# -----------------------------------------------------------------------------
# TTF mamy do listopada 2024; pobieramy reszte od 2015-01-01 (przed-szok)
# do 2024-11-29 (koniec TTF), z marginesem zeby wystarczylo do prognoz.
START_DATE <- as.Date("2015-01-01")
END_DATE   <- as.Date("2024-11-29")

OUT_DIR <- file.path("data", "raw")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("Zakres pobierania:", as.character(START_DATE), "-", as.character(END_DATE), "\n\n")

# -----------------------------------------------------------------------------
# 1) FRED: Brent + EUR/USD
# -----------------------------------------------------------------------------
fetch_fred <- function() {
  cat("[1/3] FRED: Brent (DCOILBRENTEU) i USD/EUR (DEXUSEU)...\n")

  getSymbols("DCOILBRENTEU", src = "FRED", from = START_DATE, to = END_DATE,
             auto.assign = TRUE)
  getSymbols("DEXUSEU",      src = "FRED", from = START_DATE, to = END_DATE,
             auto.assign = TRUE)

  brent <- data.frame(
    Date  = as.Date(index(DCOILBRENTEU)),
    Brent = as.numeric(DCOILBRENTEU$DCOILBRENTEU)
  ) |> filter(Date >= START_DATE, Date <= END_DATE, !is.na(Brent))

  # DEXUSEU = USD za 1 EUR (czyli wlasnie EUR/USD w konwencji rynkowej).
  eurusd <- data.frame(
    Date   = as.Date(index(DEXUSEU)),
    EURUSD = as.numeric(DEXUSEU$DEXUSEU)
  ) |> filter(Date >= START_DATE, Date <= END_DATE, !is.na(EURUSD))

  write_csv(brent,  file.path(OUT_DIR, "brent.csv"))
  write_csv(eurusd, file.path(OUT_DIR, "eurusd.csv"))

  cat("  -> brent.csv:  ", nrow(brent), "obs.\n")
  cat("  -> eurusd.csv: ", nrow(eurusd), "obs.\n\n")
}

# -----------------------------------------------------------------------------
# 2) AGSI+ : poziom zapasow gazu UE
# -----------------------------------------------------------------------------
fetch_agsi <- function() {
  cat("[2/3] AGSI+ API: poziom zapasow gazu UE (kraj = EU)...\n")

  api_key <- Sys.getenv("AGSI_API_KEY")
  if (nchar(api_key) == 0) {
    warning(
      "Brak AGSI_API_KEY w srodowisku. Pomijam zapasy gazu UE.\n",
      "Aby pobrac: zarejestruj sie na https://agsi.gie.eu/account ",
      "i ustaw zmienna srodowiskowa AGSI_API_KEY.\n",
      "  -> w R: Sys.setenv(AGSI_API_KEY = 'twoj_klucz')\n",
      "  -> trwale: dopisz linie do ~/.Renviron"
    )
    return(invisible(NULL))
  }

  base_url <- "https://agsi.gie.eu/api"

  # Paginacja po stronach (AGSI+ zwraca max 300 rekordow na strone)
  fetch_page <- function(page) {
    resp <- GET(
      base_url,
      query = list(
        country = "EU",
        from    = format(START_DATE, "%Y-%m-%d"),
        to      = format(END_DATE,   "%Y-%m-%d"),
        size    = 300,
        page    = page
      ),
      add_headers("x-key" = api_key)
    )
    stop_for_status(resp)
    fromJSON(content(resp, "text", encoding = "UTF-8"), flatten = TRUE)
  }

  all_rows <- list()
  page <- 1
  repeat {
    j <- fetch_page(page)
    if (is.null(j$data) || length(j$data) == 0) break
    all_rows[[page]] <- j$data
    last_page <- if (!is.null(j$last_page)) j$last_page else page
    cat("  strona", page, "/", last_page, "- rekordow:", nrow(j$data), "\n")
    if (page >= last_page) break
    page <- page + 1
    Sys.sleep(0.2)
  }

  if (length(all_rows) == 0) {
    warning("AGSI+ nie zwrocil danych.")
    return(invisible(NULL))
  }

  storage <- bind_rows(all_rows) |>
    transmute(
      Date         = as.Date(gasDayStart),
      Storage_pct  = as.numeric(full),                       # % wypelnienia
      Storage_TWh  = suppressWarnings(as.numeric(workingGasVolume)) / 1000,
      Withdrawal   = suppressWarnings(as.numeric(withdrawal)),
      Injection    = suppressWarnings(as.numeric(injection))
    ) |>
    filter(!is.na(Date), !is.na(Storage_pct)) |>
    arrange(Date) |>
    distinct(Date, .keep_all = TRUE)

  write_csv(storage, file.path(OUT_DIR, "storage_eu.csv"))
  cat("  -> storage_eu.csv:", nrow(storage), "obs.\n\n")
}

# -----------------------------------------------------------------------------
# 3) Open-Meteo: HDD (Heating Degree Days) dla Europy Zachodniej
# -----------------------------------------------------------------------------
# Wagi w/g szacowanego udzialu w popycie gazowym (DE/UK najwieksze rynki):
EU_CITIES <- tibble::tibble(
  city   = c("Frankfurt", "Paris", "Amsterdam", "London", "Brussels", "Milan"),
  lat    = c(50.11,        48.85,    52.37,        51.51,    50.85,      45.46),
  lon    = c( 8.68,         2.35,     4.90,        -0.13,     4.35,       9.19),
  weight = c(0.35,          0.20,     0.10,         0.20,     0.05,       0.10)
)

fetch_openmeteo <- function() {
  cat("[3/3] Open-Meteo: srednia dzienna temperatura i HDD dla Europy Zach...\n")

  base_url <- "https://archive-api.open-meteo.com/v1/archive"

  fetch_city <- function(city, lat, lon, weight) {
    cat("  ", city, "(lat=", lat, ", lon=", lon, ")\n")
    resp <- GET(
      base_url,
      query = list(
        latitude   = lat,
        longitude  = lon,
        start_date = format(START_DATE, "%Y-%m-%d"),
        end_date   = format(END_DATE,   "%Y-%m-%d"),
        daily      = "temperature_2m_mean",
        timezone   = "Europe/Berlin"
      )
    )
    stop_for_status(resp)
    j <- fromJSON(content(resp, "text", encoding = "UTF-8"))

    tibble::tibble(
      Date = as.Date(j$daily$time),
      city = city,
      tmean = as.numeric(j$daily$temperature_2m_mean),
      weight = weight
    )
  }

  city_data <- purrr::pmap_dfr(EU_CITIES, fetch_city)

  # Wazona srednia temperatura -> HDD (baza 18 stopni C)
  weather <- city_data |>
    filter(!is.na(tmean)) |>
    group_by(Date) |>
    summarise(
      T_mean_EU = sum(tmean * weight) / sum(weight),
      .groups   = "drop"
    ) |>
    mutate(HDD = pmax(18 - T_mean_EU, 0)) |>
    arrange(Date)

  write_csv(weather, file.path(OUT_DIR, "weather_hdd.csv"))
  cat("  -> weather_hdd.csv:", nrow(weather), "obs.\n\n")
}

# -----------------------------------------------------------------------------
# Uruchomienie
# -----------------------------------------------------------------------------
main <- function() {
  fetch_fred()
  fetch_agsi()
  fetch_openmeteo()
  cat("Gotowe. Pliki zapisane w:", normalizePath(OUT_DIR), "\n")
}

if (!interactive()) main()
