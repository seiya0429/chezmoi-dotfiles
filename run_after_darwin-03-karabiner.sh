#!/bin/zsh
# karabiner.json 全体は置き換えない。未作成ならテンプレートを置き、既存なら切替ルールを同じ位置でソースに合わせる。
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
import re
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
dest = Path(sys.argv[2])
REV_SUFFIX = re.compile(r"\s*\(rev \d+\)\s*$")


def loads_jsonc(text):
    """Karabiner が受け付ける // と /* */ を除いてから JSON として読む。"""
    stripped = []
    index = 0
    length = len(text)
    while index < length:
        character = text[index]
        if character == '"':
            stripped.append(character)
            index += 1
            while index < length:
                stripped.append(text[index])
                if text[index] == "\\":
                    index += 1
                    if index < length:
                        stripped.append(text[index])
                elif text[index] == '"':
                    break
                index += 1
            index += 1
            continue
        if character == "/" and index + 1 < length and text[index + 1] == "/":
            index += 2
            while index < length and text[index] not in "\r\n":
                index += 1
            continue
        if character == "/" and index + 1 < length and text[index + 1] == "*":
            index += 2
            while index + 1 < length and not (text[index] == "*" and text[index + 1] == "/"):
                index += 1
            if index + 1 >= length:
                raise json.JSONDecodeError("コメントが閉じていません", text, index)
            index += 2
            continue
        stripped.append(character)
        index += 1
    return json.loads("".join(stripped))


def rule_key(rule):
    if not isinstance(rule, dict):
        return None
    description = rule.get("description")
    if not isinstance(description, str) or description.strip() == "":
        return None
    return REV_SUFFIX.sub("", description)


def sync_rules(rules, template_rules):
    for template_rule in template_rules:
        if not isinstance(template_rule, dict):
            raise SystemExit("テンプレートの切替ルールがオブジェクトではありません")
        key = rule_key(template_rule)
        if key is None:
            raise SystemExit("テンプレートの切替ルールに description がありません")
        replacement = copy.deepcopy(template_rule)
        indexes = [index for index, rule in enumerate(rules) if rule_key(rule) == key]
        if not indexes:
            rules.append(replacement)
            continue
        if rules[indexes[0]] != replacement:
            rules[indexes[0]] = replacement
        for index in reversed(indexes[1:]):
            del rules[index]


try:
    template = loads_jsonc(template_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"Karabiner テンプレートを読めません: {exc}") from exc
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
    data = loads_jsonc(dest.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"既存の karabiner.json を読めません: {exc}") from exc
if not isinstance(data, dict):
    raise SystemExit("既存の karabiner.json の最上位がオブジェクトではありません")
profiles = data.get("profiles")
if not isinstance(profiles, list) or not profiles:
    raise SystemExit("既存の karabiner.json に profiles がありません")

original = copy.deepcopy(data)
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
    sync_rules(rules, template_rules)

if data == original:
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
