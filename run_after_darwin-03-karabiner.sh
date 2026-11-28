#!/bin/zsh
# karabiner.json 全体は置き換えない。未作成ならテンプレートを置き、既存なら切替ルールだけ足す。
set -euo pipefail
if [ "$(uname)" != "Darwin" ]; then
	exit 0
fi

source_dir="${CHEZMOI_SOURCE_DIR:-}"
if [[ -z "$source_dir" ]]; then
	source_dir="$(chezmoi source-path)"
fi
template="$source_dir/dot_config/karabiner/karabiner.json"
dest="${KARABINER_JSON_DEST:-$HOME/.config/karabiner/karabiner.json}"

if [[ ! -f "$template" ]]; then
	echo "[chezmoi] Karabiner テンプレートが見つかりません: $template" >&2
	exit 1
fi

python3 - "$template" "$dest" <<'PY'
import copy
import json
import os
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
dest = Path(sys.argv[2])

template = json.loads(template_path.read_text(encoding="utf-8"))
try:
    template_rules = template["profiles"][0]["complex_modifications"]["rules"]
except (KeyError, IndexError, TypeError) as exc:
    raise SystemExit(f"Karabiner テンプレートの切替ルールを読めません: {exc}") from exc
if not isinstance(template_rules, list) or not template_rules:
    raise SystemExit("Karabiner テンプレートに complex_modifications.rules がありません")

if not dest.exists():
    dest.parent.mkdir(parents=True, exist_ok=True)
    temporary = dest.with_name(dest.name + ".tmp")
    temporary.write_bytes(template_path.read_bytes())
    os.chmod(temporary, 0o600)
    os.replace(temporary, dest)
    raise SystemExit(0)

try:
    data = json.loads(dest.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"既存の karabiner.json を読めません: {exc}") from exc
if not isinstance(data, dict):
    raise SystemExit("既存の karabiner.json の最上位がオブジェクトではありません")
profiles = data.get("profiles")
if not isinstance(profiles, list) or not profiles:
    raise SystemExit("既存の karabiner.json に profiles がありません")

changed = False
for profile in profiles:
    if not isinstance(profile, dict):
        raise SystemExit("既存の profile がオブジェクトではありません")
    complex_modifications = profile.get("complex_modifications")
    if complex_modifications is None:
        complex_modifications = {}
        profile["complex_modifications"] = complex_modifications
    if not isinstance(complex_modifications, dict):
        raise SystemExit("既存の complex_modifications がオブジェクトではありません")
    rules = complex_modifications.get("rules")
    if rules is None:
        rules = []
        complex_modifications["rules"] = rules
    if not isinstance(rules, list):
        raise SystemExit("既存の complex_modifications.rules が配列ではありません")
    descriptions = {
        rule.get("description")
        for rule in rules
        if isinstance(rule, dict) and isinstance(rule.get("description"), str)
    }
    for rule in template_rules:
        description = rule.get("description")
        if not isinstance(description, str) or description in descriptions:
            continue
        rules.append(copy.deepcopy(rule))
        descriptions.add(description)
        changed = True

if not changed:
    raise SystemExit(0)

mode = dest.stat().st_mode & 0o777
temporary = dest.with_name(dest.name + ".tmp")
temporary.write_text(
    json.dumps(data, ensure_ascii=False, indent=4) + "\n",
    encoding="utf-8",
)
os.chmod(temporary, mode)
os.replace(temporary, dest)
PY
