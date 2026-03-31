#!/usr/bin/env python3
"""Validate SQL CREATE TABLE statements extracted from local_database.gd.

Parses the GDScript _create_tables() function, extracts SQL strings from
_execute() calls, and runs them against an in-memory SQLite database to
verify syntax and foreign key consistency.

Usage: python ci/validate_db_schema.py v1/scripts/autoload/local_database.gd
"""
import re
import sqlite3
import sys


def extract_create_tables_region(content):
    """Extract the body of _create_tables() from GDScript source."""
    # Find the start of _create_tables()
    match = re.search(r'^func _create_tables\(\)[^:]*:', content, re.MULTILINE)
    if not match:
        return None
    start = match.end()

    # Find the next top-level function (line starting with 'func ')
    next_func = re.search(r'^\nfunc ', content[start:], re.MULTILINE)
    if next_func:
        end = start + next_func.start()
    else:
        end = len(content)

    return content[start:end]


def extract_sql_from_execute_calls(region):
    """Extract SQL strings from _execute(...) calls in a GDScript region.

    Handles patterns like:
        _execute("CREATE TABLE..." + "col1," + "col2" + ");")
        _execute("CREATE TABLE...);")
    """
    sql_statements = []

    # Find all _execute( ... ) calls — handle multiline with parenthesis nesting
    # Strategy: find each _execute( and then collect until matching )
    i = 0
    while i < len(region):
        idx = region.find("_execute(", i)
        if idx == -1:
            break

        # Find the content between _execute( and the matching closing )
        start = idx + len("_execute(")
        depth = 1
        pos = start
        while pos < len(region) and depth > 0:
            if region[pos] == '(':
                depth += 1
            elif region[pos] == ')':
                depth -= 1
            pos += 1

        call_content = region[start:pos - 1]

        # Extract all quoted strings from the call content
        strings = re.findall(r'"([^"]*)"', call_content)
        if strings:
            sql = "".join(strings)
            if sql.strip():
                sql_statements.append(sql.strip())

        i = pos

    return sql_statements


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <local_database.gd>")
        sys.exit(2)

    gd_path = sys.argv[1]
    with open(gd_path, encoding="utf-8") as f:
        content = f.read()

    region = extract_create_tables_region(content)
    if region is None:
        print("ERROR: _create_tables() function not found in source file")
        sys.exit(1)

    statements = extract_sql_from_execute_calls(region)
    if not statements:
        print("ERROR: No SQL statements found in _create_tables()")
        sys.exit(1)

    # Filter to only CREATE TABLE statements (skip PRAGMAs etc.)
    create_stmts = [s for s in statements if s.upper().startswith("CREATE TABLE")]

    if not create_stmts:
        print("ERROR: No CREATE TABLE statements found")
        sys.exit(1)

    # Execute against in-memory SQLite
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON;")

    errors = []
    validated = 0

    for sql in create_stmts:
        # Extract table name for error reporting
        table_match = re.search(r'CREATE TABLE\s+(?:IF NOT EXISTS\s+)?(\w+)', sql, re.IGNORECASE)
        table_name = table_match.group(1) if table_match else "unknown"

        try:
            conn.execute(sql)
            validated += 1
            print(f"OK: {table_name}")
        except sqlite3.OperationalError as e:
            errors.append((table_name, str(e), sql))

    # Verify foreign key integrity
    try:
        fk_errors = conn.execute("PRAGMA foreign_key_check;").fetchall()
        for row in fk_errors:
            errors.append((row[0], f"foreign key violation: references {row[2]}", ""))
    except sqlite3.OperationalError:
        pass

    conn.close()

    if errors:
        print()
        for table_name, error, sql in errors:
            print(f"ERROR: CREATE TABLE {table_name}: {error}")
            if sql:
                # Show first 120 chars of the SQL for context
                preview = sql[:120] + "..." if len(sql) > 120 else sql
                print(f"  SQL: {preview}")
            print()
        print(f"FAILED: {len(errors)} error(s), {validated} table(s) valid")
        sys.exit(1)
    else:
        print(f"\nPASSED: All {validated} CREATE TABLE statements are valid SQL")


if __name__ == "__main__":
    main()
