#!/usr/bin/env python3
"""Generate/verify T02.S2 v1 inputs, or measure a compiled production-source probe."""
import argparse
import hashlib
import json
import os
import pathlib
import statistics
import subprocess


def inputs():
    prose = ("Reading **bold**, *italic*, ~~deleted~~ and `literal **code**`; "
             "[a link](https://example.invalid/reading), café, e\u0301, 中文 and 🎵. ")
    section = ("## Section {0:04d}\n\n" + prose * 8 + "\n\n"
               "- Parent **item**\n  - Child `value`\n- [x] Finished\n\n"
               "> Quoted *reading* with [reference][guide].\n\n"
               "| Name | Detail | Count |\n| :--- | :---: | ---: |\n"
               "| **Alpha** | `a\\|b` | 123 |\n| Beta | café 🎵 | 456 |\n\n"
               "```swift\nlet literal = \"**not bold** [not a link](x)\"\n```\n\n---\n\n")
    large = ("# Large Reading Fixture\n\n[guide]: https://example.invalid/guide\n\n"
             + "".join(section.format(i) for i in range(512)))
    yield "project/README.md", b"# Ready Fixture\n\nSmall document for launch and switching.\n"
    yield "project/LARGE.md", large.encode()
    for group in range(100):
        for topic in range(5):
            for item in range(10):
                name = f"project/group-{group:03d}/topic-{topic}/note-{item:02d}.md"
                yield name, f"# Note {group:03d}-{topic}-{item:02d}\n\nFixed folder fixture.\n".encode()
            yield f"project/group-{group:03d}/topic-{topic}/ignored.txt", b"Not Markdown.\n"
        yield f"project/.hidden-{group:03d}/ignored.md", b"# Hidden\n"
        yield f"project/ignored-{group:03d}.app/Contents/ignored.md", b"# Package\n"
    yield "small/README.md", b"# Replacement Fixture\n\nLatest project wins.\n"


def fixture_manifest(entries):
    digest = hashlib.sha256()
    for name, data in sorted(entries):
        digest.update(name.encode() + b"\0" + hashlib.sha256(data).hexdigest().encode() + b"\n")
    large = dict(entries)["project/LARGE.md"]
    return {"schema": 1, "id": "marky-t02-s2-v1", "files": len(entries),
            "bytes": sum(len(data) for _, data in entries), "tree_sha256": digest.hexdigest(),
            "large_document_bytes": len(large), "large_document_sha256": hashlib.sha256(large).hexdigest(),
            "visible_markdown_files": 5002, "visible_directories_including_root": 601,
            "empty_directories": 100, "sections": 512, "prepared_blocks": 3585}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["generate", "verify", "measure", "summarize-ui", "summarize-native"])
    parser.add_argument("root", type=pathlib.Path)
    parser.add_argument("--probe", type=pathlib.Path)
    parser.add_argument("--results", type=pathlib.Path)
    parser.add_argument("--log", type=pathlib.Path)
    parser.add_argument("--memory", type=pathlib.Path)
    args = parser.parse_args()
    entries = list(inputs())
    manifest = fixture_manifest(entries)
    root = args.root.resolve()
    if args.action == "generate":
        if root.exists():
            parser.error("use a new output directory; existing fixtures are never overwritten")
        root.mkdir(parents=True)
        for name, data in entries:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        for index in range(100):
            (root / "project" / f"empty-{index:03d}").mkdir()
        (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    else:
        assert json.loads((root / "manifest.json").read_text()) == manifest, "manifest changed"
        expected = {name for name, _ in entries} | {"manifest.json"}
        actual = {str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()}
        assert actual == expected, "fixture file inventory changed"
        directories = {str(parent) for name, _ in entries
                       for parent in pathlib.PurePosixPath(name).parents if str(parent) != "."}
        directories |= {f"project/empty-{i:03d}" for i in range(100)}
        assert {str(p.relative_to(root)) for p in root.rglob("*") if p.is_dir()} == directories, "fixture directory inventory changed"
        for name, data in entries:
            assert (root / name).read_bytes() == data, f"fixture changed: {name}"
        assert all((root / "project" / f"empty-{i:03d}").is_dir()
                   and not any((root / "project" / f"empty-{i:03d}").iterdir()) for i in range(100))
    if args.action in ("summarize-ui", "summarize-native"):
        if not args.log or not args.memory or not args.results:
            parser.error("summarize-ui requires --log, --memory and --results")
        if args.results.exists():
            parser.error("use a new results path")
        native = args.action == "summarize-native"
        marker = "MARKY_NATIVE_SAMPLE " if native else "MARKY_PERFORMANCE_SAMPLE "
        samples = [json.loads(line.split(marker, 1)[1]) for line in args.log.read_text().splitlines() if marker in line]
        assert [s["run"] for s in samples] == list(range(6)), "six ordered UI samples required"
        assert [s["warmup"] for s in samples] == [True, False, False, False, False, False]
        observer = json.loads(args.memory.read_text())
        by_pid = {s["process_id"]: s for s in observer}
        assert len({s["process_id"] for s in samples}) == 6, "fresh UI processes required"
        assert len({(s["window_width"], s["window_height"]) for s in samples}) == 1, "window size changed"
        if native:
            for sample in samples:
                assert sample["visible"] is True, "dense reader did not become visible"
                assert (sample["window_width"], sample["window_height"]) == (1252, 833), "baseline geometry changed"
                assert 0 <= sample["last_absent_capture_ms"] <= sample["visible_capture_started_ms"] <= sample["click_to_reader_ms"], "invalid visual observation boundaries"
                assert sample["click_to_reader_ms"] > 0 and sample["observations"] >= 1
        for sample in samples:
            memory = by_pid[sample["process_id"]]
            assert memory["successful_reads"] >= 3 and memory["peak_footprint_bytes"] > 0, "missing kernel memory observations"
            assert memory["last_error"] in (0, 3), "memory inspection failed (only exit-race ESRCH is allowed)"
            sample["peak_footprint_bytes"] = memory["peak_footprint_bytes"]
        measured = samples[1:]
        summary = {"median_" + key: statistics.median(s[key] for s in measured)
                   for key in (["click_to_reader_ms"] if native else ["launch_to_reader_ms", "search_to_outline_ms"])}
        summary["max_peak_footprint_bytes"] = max(s["peak_footprint_bytes"] for s in measured)
        args.results.write_text(json.dumps({"fixture": manifest, "samples": samples,
            "summary": summary, "memory_observer": observer}, indent=2) + "\n")
        print(json.dumps(summary, indent=2))
        return
    if args.action != "measure":
        print(json.dumps(manifest, indent=2))
        return
    if not args.probe or not args.results:
        parser.error("measure requires --probe and --results")
    if args.results.exists():
        parser.error("use a new results path")
    samples = []
    # Each scenario gets one discarded fresh-process warm-up, then five fresh processes.
    for scenario in ["prepare", "render", "document", "scan", "project", "cancel-document", "cancel-scan", "replace-project"]:
        for run in range(6):
            result = subprocess.run([str(args.probe.resolve()), scenario, str(root)],
                                    check=True, capture_output=True, text=True,
                                    env={**os.environ, "MARKY_UI_TEST_SEED": "1"})
            sample = json.loads(result.stdout)
            sample.update(run=run, warmup=run == 0)
            samples.append(sample)
            print(json.dumps(sample), flush=True)
    summary = {}
    for scenario in dict.fromkeys(s["scenario"] for s in samples):
        measured = [s for s in samples if s["scenario"] == scenario and not s["warmup"]]
        keys = ["elapsed_ms", "processing_ms", "search_ms", "cancel_to_completion_ms",
                "replacement_ready_ms", "peak_footprint_bytes", "peak_rss_bytes"]
        summary[scenario] = {("max_" if key.startswith("peak_") else "median_") + key:
                             (max if key.startswith("peak_") else statistics.median)(s[key] for s in measured)
                             for key in keys if all(key in s for s in measured)}
    args.results.write_text(json.dumps({"fixture": manifest, "samples": samples, "summary": summary}, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
