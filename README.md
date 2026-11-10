# 中文拼音输入法配置仓库（Rime / 雾凇拼音）

基于 GitHub 成熟开源项目搭建的本地中文拼音输入法：

| 组件 | 项目 | 角色 |
|---|---|---|
| 引擎 | [rime/librime](https://github.com/rime/librime)（自编译 1.17.0，含 lua/octagram/charcode 插件） | 输入法核心 |
| 前端 | ibus-rime（系统包） | 接入 GNOME |
| 词库与方案 | [iDvel/rime-ice 雾凇拼音](https://github.com/iDvel/rime-ice)（**git submodule**） | 上游，随时更新 |
| 个人配置 | 本仓库 `user/` 目录 | 补丁 + 个人词库，git 管理 |

## 目录结构

```
shurufa/
├── rime-ice/            # 雾凇拼音上游（submodule，指向 github.com/iDvel/rime-ice）
├── user/                # ★ 你的个性化层（git 管理，部署时覆盖到输入法目录）
│   ├── default.custom.yaml      # 全局补丁：方案列表、候选页大小
│   ├── rime_ice.custom.yaml     # 雾凇拼音补丁：挂载个人词库、置顶短语、排序开关
│   ├── my_words.dict.yaml       # ★ 个人词库（词+拼音+权重，权重优先于上游）
│   ├── my_phrase.txt            # ★ 个人置顶短语（永远排在候选最前）
│   └── rime_ice.userdb.txt      # 用户词频快照（save.sh 自动生成，可 diff）
├── scripts/
│   ├── build-librime.sh         # 从源码编译 librime 引擎
│   ├── deploy.sh                # 部署到 ~/.config/ibus/rime 并重建词库
│   ├── save.sh                  # 把积累的用户词频同步回仓库（git 版本化）
│   └── update.sh                # 更新上游雾凇拼音 + 重新部署
├── tools/
│   └── add_words.py             # 个人词库管理（支持自动注音、批量导入）
└── engine/                      # librime 源码（gitignore，不入库）
```

## 安装

### 1. 安装系统依赖（需要 sudo）

```bash
sudo apt-get install -y ibus-rime rsync python3-pip \
  cmake ninja-build g++ pkg-config \
  libboost-dev libboost-regex-dev libgoogle-glog-dev libyaml-cpp-dev \
  libleveldb-dev libmarisa-dev libopencc-dev liblua5.4-dev
```

可选：`python3 -m pip install --user pypinyin`（让 add_words.py 支持自动注音）。

### 2. 编译安装 librime（需要 sudo）

Ubuntu 22.04 自带的 librime 1.7.3 太旧，雾凇拼音需要 ≥ 1.11：

```bash
bash scripts/build-librime.sh          # 构建 1.17.0（约 3~5 分钟）
sudo cmake --install engine/librime/build
sudo ldconfig
which rime_deployer                    # 应为 /usr/local/bin/rime_deployer
```

### 3. 部署输入法配置

```bash
bash scripts/deploy.sh
```

首次部署会把旧输入法目录备份为 `~/.config/ibus/rime.bak-时间戳`。

### 4. GNOME 添加输入源

设置 → 键盘 → 输入源 → 添加 → 中文（中国）→ 中文（Rime）。
或用命令（保留已有输入源，追加 Rime）：

```bash
gsettings get org.gnome.desktop.input-sources sources   # 查看当前
gsettings set org.gnome.desktop.input-sources sources \
  "[('xkb', 'us'), ('ibus', 'rime')]"
```

### 5. 注销并重新登录

GNOME Wayland 下输入法由会话加载，重新登录后即可用 `Ctrl+Space`（或 Super+Space）切换到雾凇拼音。

## 词库个性化

### 个人词库 my_words.dict.yaml（参与排序、可组句）

适合：人名、地名、专业术语等需要「按拼音正常输入」的词。
格式：`词语<Tab>拼音编码<Tab>权重`，权重越大越靠前（上游常用词多在几万~几百万，个人词建议 1000000 起）。

```bash
# 快捷添加（自动注音，需要 pypinyin）
python3 tools/add_words.py "张三"
# 指定权重 + 多音字显式注音
python3 tools/add_words.py "重庆" 2000000 "chong qing"
# 批量导入（词表.txt 每行：词语 [Tab 权重] [Tab 拼音]）
python3 tools/add_words.py --file 词表.txt
# 删除
python3 tools/add_words.py --delete "张三"

bash scripts/deploy.sh    # 改完重新部署生效
```

原理：`rime_ice.custom.yaml` 把主词库替换为 `my_words`，后者先加载你的词条、
再 `import_tables: [rime_ice]` 导入雾凇全部词库；重复词条以最上面的权重为准，所以你的词条永远优先。

### 个人置顶短语 my_phrase.txt（永远第一，不参与组句）

适合：邮箱、手机号、地址、口头禅等固定输出。格式：`词汇<Tab>简拼编码<Tab>权重`。

```
张三	zs	9
公司邮箱	gsyx	5
```

### 上游的置顶工具（不动上游文件，直接用）

- `custom_phrase.txt`：上游自带的置顶短语（如 `ig` → 一个），`initial_quality: 99`。
- `pin_cand_filter`：输入某编码时指定字词永远第一，在 `rime_ice.custom.yaml` 里有补丁示例。

## 常用词排序优化

候选排序由高到低依次受以下机制控制：

| 机制 | 作用 | 数据 |
|---|---|---|
| 个人置顶短语 my_phrase | 永远第一 | `user/my_phrase.txt` |
| 上游置顶 custom_phrase / pin_cand | 永远第一 | 上游文件 |
| **个人词条权重** | 你的词压过上游词 | `user/my_words.dict.yaml` |
| **上游词库词频** | 800 万字语料统计的基础排序 | 子模块 cn_dicts/* |
| **用户词典自动学习** | 输入过的词按使用次数自动提权 | `rime_ice.userdb.txt` |
| 长词优先 / 智能组句 / 英文降权 | 整句质量与候选体验 | 上游 lua 配置 |

日常调优技巧：

- **候选不想要的词**：`Ctrl+Delete` 删除或降权当前候选项。
- **常用词越用越靠前**：用户词典自动学习（`enable_user_dict: true`），
  积累的词频用 `bash scripts/save.sh` 同步回仓库，git 提交后即版本化——
  换机器重装时 `deploy.sh` 会自动恢复词频。
- **长词偏好**：调整 `rime_ice.custom.yaml` 里的 `long_word_filter/count`。
- **词频数据可手工编辑**：`user/rime_ice.userdb.txt` 是纯文本，
  格式 `编码\t词语\t次数\t...`，可直接改次数后重新部署。

## 日常维护

```bash
# 每天/每周：把这段时间积累的词频提交到 git
bash scripts/save.sh && git add -A && git commit -m "dict: 更新用户词频"

# 定期：更新上游雾凇拼音（词库 + 配置 + lua 脚本）
bash scripts/update.sh

# 更新 librime 引擎
bash scripts/build-librime.sh <新版本号> && sudo cmake --install engine/librime/build && sudo ldconfig
```

注意：个人配置都在 `user/` 目录，上游更新**不会覆盖**你的个性化内容
（这就是 Rime patch 机制 + 仓库分层的意义）。

## 故障排查

- **切换不到输入法**：确认已注销重登录；`ibus list-engine | grep -i rime` 应有输出。
- **候选列表异常/缺词**：`bash scripts/deploy.sh` 重新构建；查看 `~/.config/ibus/rime/runLog.txt`。
- **lua 功能（日期、计算器）失效**：确认 librime 装到了 /usr/local 且带插件：
  `which rime_deployer`、`ls /usr/local/lib/rime-plugins/ 2>/dev/null || true`。
- **想回到上游原版词库**：删除 `user/rime_ice.custom.yaml` 里的
  `"translator/dictionary": my_words` 一行，重新部署。

## 卸载

```bash
sudo apt-get remove ibus-rime
sudo rm -rf /usr/local/lib/librime* /usr/local/include/rime* /usr/local/lib/rime-plugins \
  /usr/local/bin/rime_* /usr/local/share/rime-data   # 移除自编译引擎（如需）
```
