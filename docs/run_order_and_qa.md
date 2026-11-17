# Executable order and final validation

## Already imported OlistDB

1. Open SSMS connected to `OlistDB`; do not rerun any `sp_rename` commands.
2. Run `sql/01_views.sql` to (re)create the analytical views, which retain source tables unchanged.
3. Run `sql/02_validation.sql` and compare with `docs/source_validation.md`. Confirm `category_translation` import has **71**, not 72, source rows (check header/blank extra record).
4. Run `sql/03_analysis.sql` (combined all 12 questions) or run individual `sql/G1.sql` ... `sql/O2.sql` in question order; this is safe for data (SELECT-only; C6 uses a temporary table).
5. Run `sql/04_dashboard_exports.sql`; export each result set with column headers. Reconcile with `results/dashboard_month_group.csv`, `results/C1_segments.csv` and frequency export.
6. Open `dashboard/Track_C_Customer_Behavior_Dashboard.xlsx` in desktop Excel, set B5/E5 dropdown filters to All, confirm `Reconciliation` differences near zero, test both dropdowns individually and together, confirm 3 charts redraw.
7. Enter installed SQL Server / SSMS / Excel version and actual team contributions in README and `docs/contributions_template.md`. Review report limitations before submitting.

## Clean fresh database

1. Run `sql/01_schema.sql` to create empty tables in `OlistDB` if absent.
2. Import the 8 original CSVs (except optional geolocation) into existing destination tables with **SQL Server Import and Export Data Wizard**, UTF-8, comma delimiter, double-quote text qualifier, header row, full review message and DATETIME2 timestamps; do not manually modify CSVs.
3. Check counts/errors/rejections against `docs/source_validation.md`.
4. Continue at step 2 above.

Do **not** commit original dataset CSVs, database backup, credentials or connection strings to GitHub. Original public source URL is in README.
