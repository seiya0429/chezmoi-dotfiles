# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理。ソースの既定の場所は `~/.local/share/chezmoi` です（`sourceDir` の手動上書きは不要）。

## 初回（新規 Mac）

1. 事前準備: Apple ID ログインなど
2. 次のどちらか: Homebrew 経由で `brew install chezmoi`、または [one-line install](https://github.com/chezmoi/chezmoi#one-line-package-install) で chezmoi のみ入れる。Homebrew 自体は未導入でも、初回の `chezmoi apply` 内で `run_once_after_darwin-02-homebrew.sh` がインストールする（ネットワーク必須）。
3. リポジトリを元に初期化（GitHub 上の URL に置き換え）:
  ```bash
   chezmoi init https://github.com/seiya0429/chezmoi-dotfiles.git
   chezmoi apply
  ```
   このとき **sudo を求められる**ことがあります（`run_onchange_darwin-macos-defaults.sh` 内のファイアウォール・Spotlight 等）。
4. 補足ブートストラップ: `chezmoi apply` 内で `run_after_darwin-01-xcode-clt.sh` が CLT 未導入時にインストーラを起動する。CLT のインストール完了後にもう一度 `chezmoi apply` するとよい。`dot_Brewfile` を変えたあとパッケージを揃える場合は、`chezmoi apply` 済みで `~/.Brewfile` があるなら `brew bundle --file ~/.Brewfile`、または PATH に Homebrew が無いときは `/opt/homebrew/bin/brew bundle --file ~/.Brewfile`。ソースだけ更新した段階なら `brew bundle --file ~/.local/share/chezmoi/dot_Brewfile`（chezmoi の既定のソースパス前提）。`run_once_*` を再実行したい場合は `chezmoi state delete-bucket --bucket=scriptState`（公式ドキュメント参照）。

## 日常的な編集

- ソースは `$(chezmoi source-path)`（通常 `~/.local/share/chezmoi`）で、変更後は `chezmoi apply` または `chezmoi cd` して `git` で push します。

## Agent skills

Claude Code と Codex の skills は chezmoi で **それぞれ独立管理** しています（シンボリックリンク共有なし）。

| ツール | ソース | 反映先 |
|--------|--------|--------|
| Claude Code | `dot_claude/skills/` | `~/.claude/skills/` |
| Codex | `dot_codex/skills/` | `~/.codex/skills/` |
| Cursor | —（Git 管理しない） | `~/.cursor/skills/` / `~/.cursor/skills-cursor/` |

skill を追加・更新したら `chezmoi apply` で反映します。両方に同じ skill が必要な場合は、それぞれのディレクトリに置いてください。

Cursor の skills（ユーザー作成の `~/.cursor/skills/` と Cursor 同梱の `~/.cursor/skills-cursor/`）は **このリポジトリでは管理しません**。Cursor 側の更新・同期に任せ、chezmoi ソースにも置かないでください。

## 手動での設定

### SSH鍵の設定

1PasswordのSSH鍵を使うための設定追加
SSHエージェントを1Passwordアプリから確認して追加する

下記が追加されていることを確認

```bash
cat ~/.ssh/config
```

例:

```
Host *
	IdentityAgent "~/Library/Group Containers/XXXXXXX.com.1password/t/agent.sock"
```

### MacOSの設定手動変更

- Spotlightのショートカットを無効化する
- デフォルトブラウザを変更する
- ライブ変換オフ

### asdfの設定

### Node.js

```bash
asdf plugin add nodejs
asdf install nodejs 20.9.0
asdf global nodejs 20.9.0
```

## TIPS

### Mas CLIでインストールするアプリケーションIDを探す方法

```bash
mas search "アプリケーション名"
```

### 移行前に `git clone` で `~/dotfiles` していた場合

- 以降の正は `~/.local/share/chezmoi` の VCS です。内容を揃えたうえで `chezmoi init` し直すか、手元の clone を捨てて上記 `chezmoi init <url>` から入り直すと一貫します。
- `/Users/seiya/dotfiles` など **chezmoi ソース外への直 clone は使わない**（二重管理と `DOTFILES IS DIRTY` 警告の原因になる）。編集は `chezmoi cd` または `~/.local/share/chezmoi` を開く。
- 正本は `https://github.com/seiya0429/chezmoi-dotfiles` のみ。旧 `dotfiles` リポはアーカイブ済み（read-only）のため push 不可。

