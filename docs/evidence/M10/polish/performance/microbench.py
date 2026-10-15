#!/usr/bin/env python3
"""Bounded local microbenchmark; not API, ContainedDirectory, or Pi evidence."""
import argparse
import json
import os
from pathlib import Path
import platform
import sqlite3
import statistics
import tempfile
import time


def stats(values):
    values = sorted(values)
    return {"samples": len(values), "medianMs": statistics.median(values),
            "p95Ms": values[max(0, int(len(values) * .95) - 1)]}


def measure(fn, samples):
    for _ in range(5):
        fn()
    durations = []
    result = None
    for _ in range(samples):
        start = time.perf_counter_ns()
        result = fn()
        durations.append((time.perf_counter_ns() - start) / 1_000_000)
    return result, stats(durations)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {"scope": "local synthetic SQLite/filesystem microbenchmark only",
              "limitations": ["Not EF-generated SQL or authenticated API latency",
                              "Python filesystem calls are not ContainedDirectory syscalls",
                              "No Pi, Docker, real library, media decoding, or engine contacted"],
              "python": platform.python_version(), "sqlite": sqlite3.sqlite_version,
              "platform": platform.platform()}
    # Owned temporary directories and in-memory synthetic catalog only.
    db = sqlite3.connect(":memory:")
    db.executescript('CREATE TABLE media_items(LibraryId TEXT, RelativePath TEXT, Version INTEGER);'
                     'CREATE UNIQUE INDEX ix ON media_items(LibraryId, RelativePath);')
    db.executemany("INSERT INTO media_items VALUES (?, ?, ?)",
                   (("fixture", f"{i:05}.jpg", 1 + i % 5) for i in range(10_000)))
    old_sql = ('SELECT COUNT(*) FROM media_items WHERE LibraryId=?',
               'SELECT SUM(Version) FROM media_items WHERE LibraryId=?')
    new_sql = 'SELECT COUNT(*), COALESCE(SUM(Version),0) FROM media_items WHERE LibraryId=?'
    def old():
        return tuple(db.execute(sql, ("fixture",)).fetchone()[0] for sql in old_sql)
    def new():
        return db.execute(new_sql, ("fixture",)).fetchone()
    old_value, old_stats = measure(old, 200)
    new_value, new_stats = measure(new, 200)
    assert old_value == new_value == (10_000, 30_000)
    empty = db.execute(new_sql, ("empty",)).fetchone()
    assert empty == (0, 0)
    result["catalog"] = {"rows": 10_000, "before": old_stats, "after": new_stats,
                         "beforeStatementsPerCall": 2, "afterStatementsPerCall": 1,
                         "values": list(new_value), "emptyValues": list(empty),
                         "beforePlans": [list(db.execute("EXPLAIN QUERY PLAN " + q, ("fixture",))) for q in old_sql],
                         "afterPlan": list(db.execute("EXPLAIN QUERY PLAN " + new_sql, ("fixture",)))}
    with tempfile.TemporaryDirectory(prefix="thumbnail-", dir=Path(__file__).parent) as owned:
        root = Path(owned)
        for i in range(1_000):
            (root / f"{i:05}.jpg").write_bytes(b"x" * 1024)
        limit, incoming = 512 * 1024 * 1024, 64 * 1024
        def enumerate_cache(sort_always):
            files = []
            used = 0
            with os.scandir(root) as entries:
                for entry in entries:
                    st = entry.stat(follow_symlinks=False)
                    files.append((entry.name, st.st_size, st.st_mtime_ns))
                    used += st.st_size
            # Equivalent to entering OrderBy before the original first break.
            sorted_count = 0
            if sort_always or used + incoming > limit:
                ordered = sorted(files, key=lambda f: f[2])
                sorted_count = len(ordered)
                for _ in ordered:
                    if used + incoming <= limit:
                        break
            return used, len(files), sorted_count
        before, before_stats = measure(lambda: enumerate_cache(True), 30)
        after, after_stats = measure(lambda: enumerate_cache(False), 30)
        assert before[:2] == after[:2] == (1_024_000, 1_000)
        result["thumbnailHeadroom"] = {"cacheFiles": 1_000, "before": before_stats, "after": after_stats,
                                       "beforeEntriesSorted": before[2], "afterEntriesSorted": after[2],
                                       "entriesInspectedPerCallBoth": 1_000,
                                       "remainingEnumerationCost": "unchanged; this isolates only unnecessary sorting"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
