# Dashboard smoke tests performed in the artifact calculation engine

The workbook is source-driven (`Monthly_By_Group`, `Segments`, `Frequency`), with 3 chart objects anchored to Dashboard. 40 month × customer-group fact rows, 20 purchase months, and 2 interactive dropdowns on `Dashboard!B5` and `Dashboard!E5`.

| Selected month | Group | Delivered orders | Merchandise revenue BRL | AOV BRL | Valid review coverage |
|---|---|---:|---:|---:|---:|
| All | All | 96,211 | 13,181,027.13 | 137.00 | 99.33% |
| 2017-03 | All | 2,546 | 359,198.85 | 141.08 | 99.25% |
| All | Repeat | 5,896 | 725,355.04 | 123.02 | 99.12% |
| 2017-03 | Repeat | 164 | 21,399.06 | 130.48 | 100.00% |

Values in each state were checked against sums from `results/dashboard_month_group.csv`. The workbook has no detected `#REF!`, `#DIV/0!`, `#VALUE!`, `#NAME?`, or `#N/A` formula errors during this test.

**Important limitation:** These are formula-based Excel Data Validation dropdowns, not native PivotTable slicers. The assignment suggests slicers or PivotTable/report filters. The two dropdowns do affect specified calculations and graphs, but if your instructor requires *native slicers*, create actual PivotTables and connect them to slicers in desktop Excel before submission. This cannot be certified using only the available spreadsheet authoring API.

**The academic submitting team must also test** both controls individually and together in desktop Microsoft Excel, check chart redraws, save the file with selected month and group restored to `All`, and verify screenshot matches the workbook. The live SQL Server instance was not accessible in this build environment.
