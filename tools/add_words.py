#!/usr/bin/env python3
"""个人词库管理工具：向 user/my_words.dict.yaml 添加 / 更新 / 删除词条。

用法：
    python3 tools/add_words.py "词语" [权重] [拼音]
    python3 tools/add_words.py --file 词表.txt [--dry-run]
    python3 tools/add_words.py --delete "词语"

词表.txt 每行一条：词语 [Tab 权重] [Tab 拼音]
  - 拼音省略时尝试用 pypinyin 自动注音（python3 -m pip install --user pypinyin）
  - 权重省略时默认 1000000（上游词库常用词多在几万~几百万区间）
  - 多音字请显式给出拼音，如：重庆<Tab>2000000<Tab>chong qing

改完运行 scripts/deploy.sh 生效。
"""
import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DICT_PATH = REPO / "user" / "my_words.dict.yaml"
DEFAULT_WEIGHT = 1000000


def auto_pinyin(word: str):
    """用 pypinyin 自动注音；不可用或失败返回 None。"""
    try:
        from pypinyin import pinyin, Style
    except ImportError:
        return None
    try:
        syls = pinyin(word, style=Style.NORMAL, heteronym=False)
    except Exception:
        return None
    out = []
    for s in syls:
        p = s[0]
        p = re.sub(r"([nl])ü(e?)", r"\1v\2", p)  # nü→nv、lüe→lve（雾凇注音规范）
        out.append(p)
    return " ".join(out)


def load():
    """读取词库文件：返回 (头部文本, 条目字典{词:(编码,权重)}, 注释行列表)。"""
    if not DICT_PATH.exists():
        sys.exit(f"✗ 找不到 {DICT_PATH}")
    text = DICT_PATH.read_text(encoding="utf-8")
    header, sep, body = text.partition("...\n")
    if not sep:
        sys.exit(f"✗ {DICT_PATH} 缺少 '...' 分隔符，文件可能损坏")
    entries, comments = {}, []
    for raw in body.splitlines():
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            comments.append(line)
            continue
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0].strip() and parts[1].strip():
            word = parts[0].strip()
            code = parts[1].strip()
            weight = int(parts[2]) if len(parts) > 2 and parts[2].strip().isdigit() else DEFAULT_WEIGHT
            entries[word] = (code, weight)
        else:
            comments.append(line)  # 格式异常的行原样保留，避免破坏
    return header, entries, comments


def save(header, entries, comments):
    """按「权重从高到低、词语字典序」重写词库文件。"""
    lines = header.rstrip("\n").splitlines()
    lines += ["...", ""]
    for c in comments:
        if c.strip():
            lines.append(c)
    if comments and comments[-1].strip():
        lines.append("")
    for word, (code, weight) in sorted(entries.items(), key=lambda kv: (-kv[1][1], kv[0])):
        lines.append(f"{word}\t{code}\t{weight}")
    lines.append("")
    DICT_PATH.write_text("\n".join(lines), encoding="utf-8")


def validate(code: str):
    if not re.fullmatch(r"[a-z0-9 ]+", code):
        sys.exit(f"✗ 编码含非法字符：{code}（只允许小写字母、数字、空格）")


def add(word: str, weight: int, code: str | None):
    if not code:
        code = auto_pinyin(word)
        if not code:
            sys.exit(f"✗ 无法自动注音「{word}」，请安装 pypinyin 或显式给出拼音：\n"
                     f"  python3 -m pip install --user pypinyin\n"
                     f"  或：python3 tools/add_words.py \"{word}\" {weight} \"<拼音>\"")
    validate(code)
    header, entries, comments = load()
    entries[word] = (code, weight)
    save(header, entries, comments)
    print(f"✓ 已添加：{word}\t{code}\t{weight}")


def batch(path: Path, dry_run: bool):
    added = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        word = parts[0].strip()
        weight = int(parts[1]) if len(parts) > 1 and parts[1].strip().isdigit() else DEFAULT_WEIGHT
        code = parts[2].strip() if len(parts) > 2 else ""
        if not code:
            code = auto_pinyin(word) or ""
        validate(code)
        header, entries, comments = load()
        entries[word] = (code, weight)
        if not dry_run:
            save(header, entries, comments)
        added += 1
        print(f"  + {word}\t{code}\t{weight}")
    if dry_run:
        print(f"（dry-run）共 {added} 条，未写入。")
    else:
        print(f"✓ 已写入 {added} 条。运行 scripts/deploy.sh 生效。")


def delete(word: str):
    header, entries, comments = load()
    if word in entries:
        del entries[word]
        save(header, entries, comments)
        print(f"✓ 已删除：{word}")
    else:
        print(f"（词库中没有「{word}」，未改动）")


def main():
    ap = argparse.ArgumentParser(description="个人词库管理（my_words.dict.yaml）")
    ap.add_argument("word", nargs="?", help="要添加的词语")
    ap.add_argument("weight", nargs="?", type=int, default=DEFAULT_WEIGHT, help="词频权重")
    ap.add_argument("pinyin", nargs="?", help="拼音编码（可省略，自动注音）")
    ap.add_argument("--file", type=Path, help="批量导入词表文件")
    ap.add_argument("--delete", metavar="WORD", help="删除词条")
    ap.add_argument("--dry-run", action="store_true", help="与 --file 配合，只预览不写入")
    args = ap.parse_args()

    if args.delete:
        delete(args.delete)
    elif args.file:
        batch(args.file, args.dry_run)
    elif args.word:
        add(args.word, args.weight, args.pinyin)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
