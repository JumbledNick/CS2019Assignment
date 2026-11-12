#!/usr/bin/env python3
"""
Smoke test for the Arts Museum database.

No MySQL server was available while this project was prepared, so the MySQL scripts are
translated mechanically to SQLite (foreign keys ON, CHECK constraints ON, REGEXP supplied)
and executed. The script then
  * loads all sample data,
  * verifies every cross-table business rule that the MySQL triggers enforce,
  * runs the thirteen transaction queries and prints their results.

Usage:  python3 tests/sqlite_smoke_test.py            (from the repository root)
"""
import re, sqlite3, sys, pathlib, json

ROOT = pathlib.Path(__file__).resolve().parent.parent
SQL = ROOT / "sql"


def strip_comments(s):
    return re.sub(r"--[^\n]*", "", s)


def to_sqlite(ddl):
    s = strip_comments(ddl)
    s = re.sub(r"DROP DATABASE[^;]*;", "", s, flags=re.I)
    s = re.sub(r"CREATE DATABASE[^;]*;", "", s, flags=re.I)
    s = re.sub(r"USE\s+\w+\s*;", "", s, flags=re.I)
    s = re.sub(r"SET NAMES[^;]*;", "", s, flags=re.I)
    s = re.sub(r"\)\s*ENGINE=InnoDB[^;]*;", ");", s)
    s = re.sub(r"\bAUTO_INCREMENT\b", "", s)
    s = re.sub(r"\bUNSIGNED\b", "", s)
    s = re.sub(r"(\b\w+)\s+ENUM\(([^)]*)\)",
               lambda m: f"{m.group(1)} TEXT CHECK ({m.group(1)} IN ({m.group(2)}))", s)
    s = re.sub(r"UNIQUE KEY\s+\w+\s*\(", "UNIQUE (", s)
    return s


def connect():
    con = sqlite3.connect(":memory:")
    con.execute("PRAGMA foreign_keys = ON")
    con.create_function("REGEXP", 2, lambda pat, val: 1 if val is not None and re.search(pat, val) else 0)
    return con


def split_statements(text):
    """Split on ';' but not inside single-quoted string literals."""
    out, buf, inq = [], [], False
    for ch in text:
        if ch == "'":
            inq = not inq
        if ch == ";" and not inq:
            stmt = "".join(buf).strip()
            if stmt:
                out.append(stmt)
            buf = []
        else:
            buf.append(ch)
    tail = "".join(buf).strip()
    if tail:
        out.append(tail)
    return out


def run_script(con, text):
    for stmt in split_statements(text):
        con.execute(stmt)


def sqlite_query(sql):
    sql = re.sub(r"CONCAT\(([^,]+),\s*([^,]+),\s*([^)]+)\)", r"(\1 || \2 || \3)", sql)
    return sql


def main():
    con = connect()
    schema = to_sqlite((SQL / "01_schema.sql").read_text(encoding="utf-8"))
    run_script(con, schema)
    tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    print(f"[ok] {len(tables)} tables created")

    run_script(con, to_sqlite((SQL / "02_data.sql").read_text(encoding="utf-8")))
    counts = {t: con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in tables}
    assert all(c > 5 for c in counts.values()), {t: c for t, c in counts.items() if c <= 5}
    print(f"[ok] sample data loaded: {sum(counts.values())} rows, every table has more than 5 rows")
    fk_problems = con.execute("PRAGMA foreign_key_check").fetchall()
    assert not fk_problems, fk_problems
    print("[ok] PRAGMA foreign_key_check: no violations")

    # ---- views (translated) ----
    views = strip_comments((SQL / "03_views_and_triggers.sql").read_text(encoding="utf-8"))
    views = views.split("DELIMITER $$")[0]
    views = views.replace("CREATE OR REPLACE VIEW", "CREATE VIEW")
    views = re.sub(r"USE\s+\w+\s*;", "", views)
    run_script(con, views)
    print("[ok] 3 views created")

    # ---- cross-table rules that the MySQL triggers enforce ----
    rules = {
        "subtype row matches category (Painting)":
            "SELECT COUNT(*) FROM Painting p JOIN ArtObject a USING(objectID) WHERE a.category <> 'PAINTING'",
        "subtype row matches category (Sculpture)":
            "SELECT COUNT(*) FROM Sculpture p JOIN ArtObject a USING(objectID) WHERE a.category <> 'SCULPTURE'",
        "subtype row matches category (Statue)":
            "SELECT COUNT(*) FROM Statue p JOIN ArtObject a USING(objectID) WHERE a.category <> 'STATUE'",
        "subtype row matches category (OtherObject)":
            "SELECT COUNT(*) FROM OtherObject p JOIN ArtObject a USING(objectID) WHERE a.category <> 'OTHER'",
        "every object has exactly one category subtype row":
            "SELECT COUNT(*) FROM ArtObject a WHERE (SELECT COUNT(*) FROM Painting WHERE objectID=a.objectID)"
            "+(SELECT COUNT(*) FROM Sculpture WHERE objectID=a.objectID)+(SELECT COUNT(*) FROM Statue WHERE objectID=a.objectID)"
            "+(SELECT COUNT(*) FROM OtherObject WHERE objectID=a.objectID) <> 1",
        "PermanentObject rows are PERMANENT":
            "SELECT COUNT(*) FROM PermanentObject p JOIN ArtObject a USING(objectID) WHERE a.ownership <> 'PERMANENT'",
        "BorrowedObject rows are BORROWED":
            "SELECT COUNT(*) FROM BorrowedObject p JOIN ArtObject a USING(objectID) WHERE a.ownership <> 'BORROWED'",
        "every object has exactly one ownership subtype row":
            "SELECT COUNT(*) FROM ArtObject a WHERE (SELECT COUNT(*) FROM PermanentObject WHERE objectID=a.objectID)"
            "+(SELECT COUNT(*) FROM BorrowedObject WHERE objectID=a.objectID) <> 1",
        "ON_DISPLAY <=> galleryID present":
            "SELECT COUNT(*) FROM ArtObject WHERE (status='ON_DISPLAY') <> (galleryID IS NOT NULL)",
        "ON_LOAN <=> open lending record":
            "SELECT COUNT(*) FROM ArtObject a WHERE (a.status='ON_LOAN') <> "
            "EXISTS(SELECT 1 FROM Lending l WHERE l.objectID=a.objectID AND l.dateReturned IS NULL)",
        "RETURNED <=> borrowed with no open borrowing":
            "SELECT COUNT(*) FROM ArtObject a WHERE a.ownership='BORROWED' AND (a.status='RETURNED') <> "
            "(NOT EXISTS(SELECT 1 FROM Borrowing b WHERE b.objectID=a.objectID AND b.dateReturned IS NULL))",
        "Regular/Featured subtype rows match exhibitionKind":
            "SELECT (SELECT COUNT(*) FROM RegularExhibition r JOIN Exhibition e USING(exhibitionID) WHERE e.exhibitionKind<>'REGULAR')"
            "+(SELECT COUNT(*) FROM FeaturedExhibition r JOIN Exhibition e USING(exhibitionID) WHERE e.exhibitionKind<>'FEATURED')",
        "Staff subtype rows match staffType":
            "SELECT (SELECT COUNT(*) FROM Curator c JOIN Staff s USING(staffID) WHERE s.staffType<>'CURATOR')"
            "+(SELECT COUNT(*) FROM Supervisor c JOIN Staff s USING(staffID) WHERE s.staffType<>'SUPERVISOR')",
        "curator specialisation = object category":
            "SELECT COUNT(*) FROM Maintains m JOIN Curator c USING(staffID) JOIN ArtObject a USING(objectID) WHERE c.specialisation<>a.category",
        "curator workload <= maxObjects":
            "SELECT COUNT(*) FROM (SELECT m.staffID FROM Maintains m JOIN Curator c USING(staffID) GROUP BY m.staffID, c.maxObjects HAVING COUNT(*) > c.maxObjects)",
        "replica sold only for exhibited objects":
            "SELECT COUNT(*) FROM ReplicaSale r WHERE NOT EXISTS (SELECT 1 FROM ExhibitionObject e WHERE e.exhibitionID=r.exhibitionID AND e.objectID=r.objectID)",
        "no object is on loan to us and out on loan at the same time":
            "SELECT COUNT(*) FROM Lending l JOIN Borrowing b USING(objectID)",
    }
    bad = 0
    for name, sql in rules.items():
        n = con.execute(sql).fetchone()[0]
        print(f"[{'ok' if n == 0 else 'FAIL'}] rule: {name}" + ("" if n == 0 else f"  -> {n} violations"))
        bad += n != 0
    assert bad == 0, "business-rule violations found"

    # ---- negative tests: the constraints must reject bad data ----
    def must_fail(label, sql):
        try:
            con.execute("SAVEPOINT s")
            con.execute(sql)
        except sqlite3.IntegrityError as e:
            print(f"[ok] rejected: {label}  ({e})")
        else:
            raise AssertionError("accepted bad data: " + label)
        finally:
            con.execute("ROLLBACK TO s"); con.execute("RELEASE s")

    must_fail("object id format", "INSERT INTO ArtObject VALUES ('XX0001','t','d',1900,'PAINTING','PERMANENT','IN_STORE',NULL,1,1,1,NULL)")
    must_fail("PERMANENT object cannot be RETURNED", "UPDATE ArtObject SET status='RETURNED' WHERE objectID='AO0001'")
    must_fail("featured exhibition ends before it starts", "UPDATE FeaturedExhibition SET endDate='2020-01-01' WHERE exhibitionID=9")
    must_fail("duplicate artist identity (living artist, NULL death date)",
              "INSERT INTO Artist (artistID,artistName,dateBorn,dateDied) VALUES (99,'Hiroshi Tanaka','1958-04-23',NULL)")
    must_fail("unknown foreign key", "INSERT INTO Painting (objectID,paintingMedium) VALUES ('AO9999','Oil')")
    must_fail("loyalty number format", "INSERT INTO LoyalVisitor (loyaltyNo,firstName,lastName,address,joinDate) VALUES ('ZZ1','a','b','c','2020-01-01')")
    must_fail("replica for an object that is not in the exhibition", "INSERT INTO ReplicaSale VALUES (7,'AO0001',10.00,1)")
    must_fail("lending of a borrowed object", "INSERT INTO Lending VALUES ('AO0005','2026-01-01',1,'2026-02-01',NULL)")
    must_fail("deleting an object that has loan history", "DELETE FROM ArtObject WHERE objectID='AO0006'")
    must_fail("deleting a gallery that still holds objects", "DELETE FROM Gallery WHERE galleryID=1")
    must_fail("negative cost", "UPDATE PermanentObject SET acquisitionCost=-1 WHERE objectID='AO0001'")
    must_fail("invalid enum value", "UPDATE Invitation SET response='MAYBE' WHERE loyaltyNo='LM1001' AND exhibitionID=7")

    con.execute("INSERT INTO Artist (artistID,artistName,dateBorn,dateDied) VALUES (98,'Hiroshi Tanaka','1990-01-01',NULL)")
    con.execute("DELETE FROM Artist WHERE artistID=98")
    print("[ok] accepted: same artist name with a different birth date")

    # ---- transactions ----
    sql_t = strip_comments((SQL / "04_transactions.sql").read_text(encoding="utf-8"))
    sql_t = re.sub(r"USE\s+\w+\s*;", "", sql_t)
    stmts = split_statements(sql_t)
    results = {}
    names = ["T1(insert ArtObject)", "T1(insert Painting)", "T1(insert PermanentObject)", "T2", "T3", "T4", "T5", "T6",
             "T7", "T8", "T9", "T10", "T11", "T12", "T13"]
    stmts = [x for x in stmts if not re.match(r"(START TRANSACTION|COMMIT)\b", x, re.I)]
    assert len(stmts) == len(names), (len(stmts), len(names))
    pairs = list(zip(names, stmts))
    for name, st in pairs:                       # queries first: they see the original sample data
        if st.upper().startswith("SELECT"):
            cur = con.execute(sqlite_query(st))
            results[name] = ([d[0] for d in cur.description], cur.fetchall())
    con.execute("SAVEPOINT t")
    for name, st in pairs:                       # then the data-changing transactions
        if not st.upper().startswith("SELECT"):
            cur = con.execute(sqlite_query(st))
            results[name] = (["rows affected"], [(cur.rowcount,)])
    assert con.execute("SELECT COUNT(*) FROM ArtObject").fetchone()[0] == 25
    assert con.execute("SELECT endDate FROM FeaturedExhibition WHERE exhibitionID=9").fetchone()[0] == "2027-01-31"
    con.execute("ROLLBACK TO t")
    print("[ok] T1-T13 executed (T1/T2 changes rolled back again)")
    for name in sorted(results, key=lambda n: (len(n) > 3 and n[1:].split("(")[0].isdigit() and int(n[1:].split("(")[0]) or 0)):
        cols, rows = results[name]
        print(f"\n== {name}  ({len(rows)} rows)")
        print(" | ".join(cols))
        for r in rows[:30]:
            print(" | ".join("NULL" if v is None else str(v) for v in r))

    out = ROOT / "out" if (ROOT / "out").exists() else None
    if out:
        (out / "query_results.json").write_text(json.dumps(results, indent=1, default=str), encoding="utf-8")
    print("\nALL CHECKS PASSED")


if __name__ == "__main__":
    sys.exit(main())
