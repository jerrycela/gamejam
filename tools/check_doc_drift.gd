extends SceneTree
## Documentation-drift detector (2026-08-13, written after a day of finding
## drift only by accident — the point is to stop that pattern for the next
## person who edits these docs).
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##        -s res://tools/check_doc_drift.gd
##
## Exit code 0 = no drift detected. Non-zero = drift found, OR the check
## itself failed to parse something it expected to find (see "Fail-loud
## contract" below) — both cases are treated as failure, never silently
## skipped as green.
##
## ---------------------------------------------------------------------------
## Fail-loud contract (do not weaken this)
## ---------------------------------------------------------------------------
## A check that finds 0 candidates to examine is NOT the same as a check that
## examined N candidates and found 0 problems. If a regex that is expected to
## match several real, currently-known rows/refs/files matches nothing, that
## almost certainly means the document's structure changed and the regex no
## longer applies — silently reporting "0 problems" in that case would make
## this script exactly the kind of always-green check this project spent
## today finding and fixing in the test suite (see PROJECT_STATE.md Known
## Problems / the two vacuous-test fixes in commit 0a1564c). Every check
## below asserts a minimum expected match count and reports PARSE_ERROR
## (a failure, not a pass) if that minimum isn't met.
##
## ---------------------------------------------------------------------------
## Coverage (see final report to team-lead for what this deliberately does
## NOT cover, and why)
## ---------------------------------------------------------------------------
## 1. docs/12 godot_scene existence  — every component whose approved_version
##    is not NOT_CREATED claims a res:// scene path; that file must exist.
##    (Directly the L1-2 false "檔案不存在" the audit caught.)
## 2. docs/13 constant sync, both directions — every PresentationController
##    constant docs/13's table cites must exist in the script with a matching
##    value; every *_MS constant in the script must be cited somewhere in
##    docs/13 (this second direction is the actual shape of today's real
##    miss: FALLBACK_VISUAL_DWELL_MS existed in code, absent from the table).
## 3. docs/06 §14 asset registry, both directions — every asset id docs/06's
##    registry section claims exists must have a real file under
##    assets/textures/ or assets/source/image/; every real file under those
##    two directories must be mentioned somewhere in that same section.
## 4. AGENTS.md:NNN citations across the whole docs/specs tree — the cited
##    line must exist, be non-blank, and not be a heading/separator. This
##    can't verify the citation still means what it claims (that needs
##    semantic reading a script can't do), but it catches the exact failure
##    mode from today: spectra init shifting every line number by 29.

var failures: Array[String] = []
var passes: Array[String] = []
var parse_errors: Array[String] = []


func _init() -> void:
	_check_docs12_scene_paths()
	_check_docs13_constants()
	_check_docs06_asset_registry()
	_check_agents_md_line_refs()
	_report()


## ---------------------------------------------------------------------------
## Check 1: docs/12 approved components' godot_scene paths must exist.
## ---------------------------------------------------------------------------
func _check_docs12_scene_paths() -> void:
	var check_name := "docs/12 godot_scene paths"
	var text := _read("res://docs/12_FIGMA_COMPONENT_MANIFEST.md")
	if text.is_empty():
		parse_errors.append("%s: could not read docs/12_FIGMA_COMPONENT_MANIFEST.md" % check_name)
		return

	# A manifest data row: starts with "| `COMPONENT_ID` |". This deliberately
	# does NOT hardcode a column count/order — table columns have already
	# been reordered once this project's life; anchoring only on the first
	# cell survives that kind of reshuffle. The header row ("| Component
	# ID |...") and the separator row ("|---|...") don't have a backtick
	# right after the leading pipe, so they don't match.
	var row_re := RegEx.new()
	row_re.compile("(?m)^\\|\\s*`([A-Z0-9_]+)`\\s*\\|(.*)$")
	var rows := row_re.search_all(text)

	if rows.size() < 8:
		# 11 real rows exist today; 8 is a conservative floor that still
		# catches "the whole table vanished" without being brittle to one or
		# two rows being added/removed later.
		parse_errors.append(
			"%s: only matched %d manifest rows (expected >= 8) — table structure may have changed, regex may no longer apply"
			% [check_name, rows.size()]
		)
		return

	var scene_re := RegEx.new()
	scene_re.compile("res://[^\\s`]+")

	var checked := 0
	for row: RegExMatch in rows:
		var component_id: String = row.get_string(1)
		var rest: String = row.get_string(2)
		var is_pending: bool = rest.contains("NOT_CREATED")
		var scene_match := scene_re.search(rest)
		if scene_match == null:
			# A row with no res:// path at all is itself a structural
			# surprise worth failing on, not skipping quietly.
			failures.append(
				"docs/12 row `%s` has no res:// godot_scene path at all (rest of row: %s)"
				% [component_id, rest.strip_edges()]
			)
			continue
		var scene_path: String = scene_match.get_string(0)
		if is_pending:
			continue
		checked += 1
		if not FileAccess.file_exists(scene_path):
			failures.append(
				"docs/12 says `%s` (approved, not NOT_CREATED) maps to `%s`, but that file does not exist"
				% [component_id, scene_path]
			)

	if checked == 0:
		parse_errors.append(
			"%s: 0 non-NOT_CREATED rows found — either every component regressed to PENDING_CREATE (very unlikely) or the NOT_CREATED marker/column format changed"
			% check_name
		)
		return

	passes.append("%s: checked %d approved component(s) against real files" % [check_name, checked])


## ---------------------------------------------------------------------------
## Check 2: docs/13 <-> presentation_controller.gd constant sync, both ways.
## ---------------------------------------------------------------------------
func _check_docs13_constants() -> void:
	var check_name := "docs/13 constant sync"
	var doc_text := _read("res://docs/13_PRESENTATION_MAPPING.md")
	var code_text := _read("res://scripts/presentation/presentation_controller.gd")
	if doc_text.is_empty():
		parse_errors.append("%s: could not read docs/13_PRESENTATION_MAPPING.md" % check_name)
		return
	if code_text.is_empty():
		parse_errors.append("%s: could not read scripts/presentation/presentation_controller.gd" % check_name)
		return

	# Direction A: every constant docs/13 cites must exist in code with a
	# matching value. docs/13 cites constants as `PresentationController.NAME`.
	var doc_const_re := RegEx.new()
	doc_const_re.compile("PresentationController\\.([A-Z0-9_]+)")
	var doc_refs := doc_const_re.search_all(doc_text)

	if doc_refs.size() < 2:
		parse_errors.append(
			"%s: only found %d `PresentationController.X` citations in docs/13 (expected >= 2) — table format may have changed"
			% [check_name, doc_refs.size()]
		)
		return

	# The table's fallback_duration_ms cell is the integer immediately before
	# the constant-name cell, e.g. "| `true` | `1500` | `PresentationController.FALLBACK_DEAL_CARD_MS` |".
	var doc_row_value_re := RegEx.new()

	var code_const_re := RegEx.new()
	code_const_re.compile("(?m)^\\s*const\\s+([A-Z0-9_]+)\\s*(?::\\s*\\w+\\s*)?=\\s*([^\\n]+)$")
	var code_matches := code_const_re.search_all(code_text)
	if code_matches.size() < 2:
		parse_errors.append(
			"%s: only found %d top-level `const NAME = value` declarations in presentation_controller.gd (expected >= 2) — script structure may have changed"
			% [check_name, code_matches.size()]
		)
		return

	var code_consts: Dictionary = {}
	for m: RegExMatch in code_matches:
		var name: String = m.get_string(1)
		var value: String = m.get_string(2).strip_edges().trim_suffix(",")
		code_consts[name] = value

	var doc_cited_names: Dictionary = {}
	for ref: RegExMatch in doc_refs:
		var const_name: String = ref.get_string(1)
		doc_cited_names[const_name] = true
		if not code_consts.has(const_name):
			failures.append(
				"docs/13 cites `PresentationController.%s`, but no such const exists in presentation_controller.gd"
				% const_name
			)
			continue
		# Cross-check the numeric value in the same table row, when present.
		doc_row_value_re.compile("`(\\d+)`\\s*\\|\\s*`PresentationController\\.%s`" % const_name)
		var value_match := doc_row_value_re.search(doc_text)
		if value_match != null:
			var doc_value: String = value_match.get_string(1)
			var code_value: String = code_consts[const_name]
			if code_value.strip_edges() != doc_value:
				failures.append(
					"docs/13 table says `%s` = %s, but presentation_controller.gd has `%s = %s`"
					% [const_name, doc_value, const_name, code_value]
				)

	# Direction B (the shape of today's real miss): every *_MS constant in
	# code must be cited somewhere in docs/13. Restricted to the _MS naming
	# convention deliberately — that's the exact shape of what docs/13
	# itself claims to be the registry for (fallback_duration_ms values);
	# widening this to every const (e.g. FALLBACK_VISUAL_TEXT) would flag
	# things docs/13 never claimed to own.
	var ms_checked := 0
	for name in code_consts.keys():
		if not String(name).ends_with("_MS"):
			continue
		ms_checked += 1
		if not doc_cited_names.has(name):
			failures.append(
				"presentation_controller.gd defines `%s = %s` (a *_MS timing constant), but docs/13's Mapping table never cites it"
				% [name, code_consts[name]]
			)

	if ms_checked == 0:
		parse_errors.append(
			"%s: 0 *_MS constants found in presentation_controller.gd (expected >= 2) — naming convention may have changed"
			% check_name
		)
		return

	passes.append(
		"%s: checked %d doc->code citation(s) and %d code *_MS constant(s) against each other"
		% [check_name, doc_refs.size(), ms_checked]
	)


## ---------------------------------------------------------------------------
## Check 3: docs/06 §14 asset registry <-> real files, both ways.
## ---------------------------------------------------------------------------
func _check_docs06_asset_registry() -> void:
	var check_name := "docs/06 §14 asset registry"
	var text := _read("res://docs/06_AI_ART_AND_MEDIA_PROMPTS.md")
	if text.is_empty():
		parse_errors.append("%s: could not read docs/06_AI_ART_AND_MEDIA_PROMPTS.md" % check_name)
		return

	var section_re := RegEx.new()
	section_re.compile("(?s)## 14\\. Naming and Registry(.*)$")
	var section_match := section_re.search(text)
	if section_match == null:
		parse_errors.append(
			"%s: could not find a '## 14. Naming and Registry' heading — section may have been renamed or removed"
			% check_name
		)
		return
	var section_text: String = section_match.get_string(1)

	var asset_id_re := RegEx.new()
	asset_id_re.compile("[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*_V\\d{3}")

	# Direction A (docs claims exist): scoped tightly to the naming list
	# fenced block plus the SUPERSEDED bullet list, NOT the whole section —
	# the section's prose also mentions intentionally-hypothetical/removed
	# names (e.g. a possible future .mp4 name, and the explicitly-removed
	# STAGE00 name) that are not claims of current files and would be false
	# positives here.
	var fenced_re := RegEx.new()
	fenced_re.compile("(?s)```text\\n(.*?)```")
	var fenced_match := fenced_re.search(section_text)
	var superseded_re := RegEx.new()
	superseded_re.compile("(?s)已取代素材（SUPERSEDED）.*?\\n\\n(.*?)\\n\\n\\*\\*通則")
	var superseded_match := superseded_re.search(section_text)

	var claimed_current_ids: Dictionary = {}
	if fenced_match != null:
		for m: RegExMatch in asset_id_re.search_all(fenced_match.get_string(1)):
			claimed_current_ids[m.get_string(0)] = true
	if superseded_match != null:
		for m: RegExMatch in asset_id_re.search_all(superseded_match.get_string(1)):
			claimed_current_ids[m.get_string(0)] = true

	if claimed_current_ids.size() < 5:
		parse_errors.append(
			"%s: only extracted %d asset id(s) from the naming-list block + SUPERSEDED bullets (expected >= 5) — block structure may have changed"
			% [check_name, claimed_current_ids.size()]
		)
		return

	for id in claimed_current_ids.keys():
		if not _asset_id_exists_on_disk(id):
			failures.append(
				"docs/06 §14 lists `%s` as a current/superseded asset, but no file matching that id exists under assets/textures/ or assets/source/image/"
				% id
			)

	# Direction B (real files must be mentioned somewhere in §14): broader
	# net is fine here, because extra mentions elsewhere in the section only
	# make this direction more lenient, never less correct.
	var section_ids: Dictionary = {}
	for m: RegExMatch in asset_id_re.search_all(section_text):
		section_ids[m.get_string(0)] = true

	var disk_ids := _asset_ids_on_disk()
	if disk_ids.size() < 5:
		parse_errors.append(
			"%s: only found %d real asset file(s) under assets/textures/ + assets/source/image/ (expected >= 5) — directories may have moved"
			% [check_name, disk_ids.size()]
		)
		return

	for id in disk_ids:
		if not section_ids.has(id):
			failures.append(
				"a file matching asset id `%s` exists under assets/textures/ or assets/source/image/, but §14 never mentions it"
				% id
			)

	passes.append(
		"%s: cross-checked %d claimed id(s) against disk and %d real file id(s) against the doc section"
		% [check_name, claimed_current_ids.size(), disk_ids.size()]
	)


func _asset_id_exists_on_disk(asset_id: String) -> bool:
	return _asset_ids_on_disk().has(asset_id)


func _asset_ids_on_disk() -> Dictionary:
	var ids: Dictionary = {}
	var asset_id_re := RegEx.new()
	asset_id_re.compile("[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*_V\\d{3}")
	for dir_path in ["res://assets/textures", "res://assets/source/image"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var m := asset_id_re.search(file_name)
				if m != null:
					ids[m.get_string(0)] = true
			file_name = dir.get_next()
		dir.list_dir_end()
	return ids


## ---------------------------------------------------------------------------
## Check 4: every "AGENTS.md:NNN" citation across docs/specs points at a real,
## non-blank, non-heading line in the current AGENTS.md.
## ---------------------------------------------------------------------------
func _check_agents_md_line_refs() -> void:
	var check_name := "AGENTS.md line citations"
	var agents_text := _read("res://AGENTS.md")
	if agents_text.is_empty():
		parse_errors.append("%s: could not read AGENTS.md" % check_name)
		return
	var agents_lines := agents_text.split("\n")

	var citation_re := RegEx.new()
	citation_re.compile("AGENTS\\.md:(\\d+)")

	var search_paths := _find_markdown_files()
	if search_paths.size() < 5:
		parse_errors.append(
			"%s: only found %d markdown files to scan under docs/ and specs/ (expected >= 5) — directory layout may have changed"
			% [check_name, search_paths.size()]
		)
		return

	var total_citations := 0
	for path in search_paths:
		var text := _read(path)
		for m: RegExMatch in citation_re.search_all(text):
			total_citations += 1
			var line_no := int(m.get_string(1))
			var index := line_no - 1
			if index < 0 or index >= agents_lines.size():
				failures.append(
					"%s cites `AGENTS.md:%d`, but AGENTS.md only has %d lines"
					% [path, line_no, agents_lines.size()]
				)
				continue
			var line_content: String = agents_lines[index].strip_edges()
			if line_content.is_empty():
				failures.append(
					"%s cites `AGENTS.md:%d`, but that line is blank"
					% [path, line_no]
				)
			elif line_content.begins_with("#") or line_content == "---":
				failures.append(
					"%s cites `AGENTS.md:%d`, but that line is a heading/separator (\"%s\"), not content"
					% [path, line_no, line_content]
				)

	if total_citations == 0:
		parse_errors.append(
			"%s: 0 `AGENTS.md:NNN` citations found anywhere under docs/ or specs/ (expected several) — citation format may have changed"
			% check_name
		)
		return

	passes.append("%s: checked %d citation(s) across %d file(s)" % [check_name, total_citations, search_paths.size()])


func _find_markdown_files() -> Array[String]:
	var result: Array[String] = []
	for dir_path in ["res://docs", "res://docs/plans", "res://specs"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".md"):
				result.append(dir_path + "/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return result


## ---------------------------------------------------------------------------
## Shared helpers
## ---------------------------------------------------------------------------
func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _report() -> void:
	print("=== Documentation Drift Check ===\n")

	print("--- Passed (%d) ---" % passes.size())
	for p in passes:
		print("  OK  " + p)

	print("\n--- Parse errors (%d) — the check itself could not run as expected ---" % parse_errors.size())
	for e in parse_errors:
		print("  PARSE_ERROR  " + e)

	print("\n--- Drift found (%d) ---" % failures.size())
	for f in failures:
		print("  DRIFT  " + f)

	print("")
	if parse_errors.is_empty() and failures.is_empty():
		print("RESULT: PASS — no drift detected, all checks ran to completion.")
		quit(0)
	else:
		print(
			"RESULT: FAIL — %d parse error(s), %d drift finding(s). A parse error is a failure, not a skip."
			% [parse_errors.size(), failures.size()]
		)
		quit(1)
