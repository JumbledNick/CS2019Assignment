# Arts Museum Database (MySQL)

A relational database for an art museum that owns a permanent collection, borrows and lends objects within a group of partner museums (the *Arts Friends Circle*), runs regular and featured exhibitions, invites loyal visitors and employs curators and supervisors. It is a worked solution to the University of Aberdeen module **CS2019 Databases and Data Management, Assessment 2**: requirements analysis, (E)ER design in UML notation, relational mapping, normalisation to 3NF, MySQL implementation and sample data.

![EER diagram](docs/eer-diagram.png)

*(E)ER diagram in UML notation. A vector version is in [`docs/eer-diagram.svg`](docs/eer-diagram.svg).*

## Repository contents

| Path | What it is |
|---|---|
| `sql/artsmuseum.sql` | **Everything in one file**: creates the database, the 31 tables, loads the sample data and installs the views and triggers |
| `sql/01_schema.sql` | Database and tables only |
| `sql/02_data.sql` | Sample data (310 rows; every table has more than five rows) |
| `sql/03_views_and_triggers.sql` | Three views and fourteen triggers (installed after the data) |
| `sql/04_transactions.sql` | The thirteen transaction requirements as SQL (T1 and T2 change data) |
| `docs/CS2019-ASMNT2-Reference-Solution.pdf` / `.docx` | The full written solution to Tasks 1 to 10 |
| `docs/REPORT.md` | The same report as Markdown |
| `docs/eer-diagram.png`, `.svg`, `docs/figures/` | The (E)ER diagram and four enlargements |
| `tests/sqlite_smoke_test.py` | Automated checks (see below) |

## Quick start

Requires **MySQL 8.0.16 or later** (earlier versions parse but ignore `CHECK` constraints).

```bash
# create the database, tables, data, views and triggers
mysql -u root -p < sql/artsmuseum.sql

# try the transaction requirements (T1 and T2 modify data)
mysql -u root -p ArtsMuseumDB < sql/04_transactions.sql
```

The script starts with `DROP DATABASE IF EXISTS ArtsMuseumDB`, so it rebuilds that database from scratch.

In MySQL Workbench: *File → Open SQL Script → `sql/artsmuseum.sql` → Execute*. The trigger section uses the `DELIMITER` command, which the `mysql` client and Workbench understand.

## Model at a glance

| Area | Tables |
|---|---|
| Controlled vocabularies | `Origin`, `Epoch`, `Style`, `Material` |
| Partners and artists | `Museum`, `Artist` |
| Art objects (superclass + subclasses sharing the key) | `ArtObject`; by category `Painting`, `Sculpture`, `Statue`, `OtherObject`; by ownership `PermanentObject`, `BorrowedObject` |
| Loans | `Borrowing` (into the museum), `Lending` (out of the museum) |
| Exhibitions | `Exhibition` → `RegularExhibition`, `FeaturedExhibition`; `Gallery`; `ExhibitionFeature`, `ExhibitionObject`, `ReplicaSale` |
| Loyal visitors | `LoyalVisitor`, `VisitorPreference`, `Invitation` |
| Staff | `Staff` → `Curator`, `Supervisor`; `Maintains`, `SupervisesGallery`, `SupervisesFeatured` |

Design highlights (details in the report):

- **Two independent generalisations of `ArtObject`** (category and ownership) mapped to a superclass table plus one table per subclass; triggers keep each subclass row consistent with its discriminator.
- **Artist identity** (name, date born, date died) is kept unique even for living artists through a generated stand-in for the missing death date.
- **Loan history**: an object can be borrowed or lent many times; the date is part of the loan's key.
- **Business rules in the database**: identifier formats (`AO0001`, `LM1001`), date order, status rules (an object is `ON_DISPLAY` exactly when it hangs in a gallery), and curator specialisation and workload limits.
- **Views** expose only what visitors may see; acquisition cost and loan details stay internal.
- All 31 relations are in **3NF (and BCNF)**; the functional dependencies are in Task 4 of the report.

## Checks

No MySQL server was available when the scripts were written, so they were verified by translating them mechanically to SQLite and running:

```bash
python3 tests/sqlite_smoke_test.py
```

The test creates all tables, loads all rows, runs `PRAGMA foreign_key_check`, verifies 17 cross-table business rules, confirms that 12 kinds of invalid data are rejected and runs the 13 transactions. The constructs that exist only in MySQL (`ENUM`, the generated column, `CREATE OR REPLACE VIEW`, triggers, `DELIMITER`) follow the MySQL 8.0 syntax but have not been executed against a live MySQL server; if one of them reports an error, the message names the statement.

## Notes

- Museum names, people, addresses and phone numbers in the sample data are fictional (phone numbers use ranges reserved for fiction).
- Object identifiers use two letters and four digits, so the scheme supports 10,000 objects; widen the pattern before the collection approaches that size.
- This is a reference solution to a university exercise. If you use it for assessed work, follow your institution's rules, and consider keeping the repository private until you are sure that publishing solutions is allowed.
