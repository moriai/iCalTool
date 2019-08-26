# iCalTool

macOS のカレンダー（Calendar, 旧称 iCal）をコマンドラインで触るためのツールです。CSV ファイルを取り込んで、Calendar に同期させることができます。

## コマンドのビルドとインストール

まずは、ソースコードを丸ごと自分の環境にコピーするなり、git clone するなりしてください。そのあとはお好みの方法でインストールして下さい。

### 方法 1. Swift Package Manager を使う

```
$ swift build -c release
$ cp .build/release/iCalTool ~/bin
```

`~/bin` の部分は適当にパスの通っているディレクトリに直して下さい。

### 方法 2. Xcode もしくは xcodebuild を使う

Swift Package Manager で xcodeproj を生成する必要があります。

```
$ swift package generate-xcodeproj
```

`iCalTool.xcodeproj` が生成されますので、あとは、Xcode もしくは xcodebuild でビルドして下さい。

なお、`iCalTool.xcodeproj` を生成した直後は、ターゲットが iOS などになっている場合があります。この時は、My Mac をターゲットに設定し直して下さい。


## 使い方

引数なしで起動すると、以下のように簡単な usage を表示します。

```
$ iCalTool
iCalTool 1.0.2
The macOS Calendar manipulation tool

Usage: iCalTool [Flag] <Subcommand> ...

Flags:
    -v  Enable verbose output
    -s  Enable silent output
    -h  Print help message

Subcommands:
    list[n|i] [calendar-name [start-date [end-date]]]
    add [csv-file|-]
    sync (csv-file|-) [start-date [end-date]]
    diff (csv-file|-) [start-date [end-date]]
    delete [uuid]...
    help

```

サブコマンドの `add`, `sync`, `delete` は、あなたのカレンダーの内容を変更しますので、注意してお使いください。

### list[n|i] [calendar-name [start-date [end-date]]]

指定したカレンダーを CSV 形式で出力します。ただし、<font color="Red">エンコーディングは UTF-8 で出力されます</font>ので、出力を保存したファイルを EXCEL で開きたい場合には、適切なツール（`nkf` など）で Shift JIS に変換してからファイルに保存した方が良いでしょう。

カレンダーとして "" もしくは "." を指定すると、macOS のカレンダーアプリのデフォールトカレンダーを指定したことになります。ただ、なぜかそうならないこともあり、原因は不明です。

`start-date` と `end-date` で出力する期間を指定することができます。指定可能なフォーマットは `yyyy/MM/dd[ HH:mm[:ss]]` です。

`list` の代わりに `listn` とするとノートも出力されます。 `listi` とすると UUID のみが出力されます。

引数に何も指定しない場合には、カレンダーの一覧が出力されます。

### delete [uuid]...

指定した UUID のイベントをカレンダーから削除します。

### add [csv-file|-]

`csv-file` に記述されたイベントをカレンダーに追加します。イベントに指定されたカレンダーが存在しない時にはエラーになりますので、事前に macOS のカレンダーアプリでカレンダーを追加しておいてください。

ファイルのフォーマットは以下の CSV 形式です。個人的に Windows 環境からカレンダーデータを持ってくることが多いため、<font color="Red">ファイルのエンコーディングは Shift JIS になっています。</font>
次のバージョンではフォーマット周りはコンフィグ可能にしたいと思います。

```
"表示名","件名","開始日時","終了日時","終日","場所",,,,,"ノート"
```

各カラムは macOS の以下の項目にマッピングされます。「なし」は対応する項目がないことを意味します。

```
calendar,title,startDate,endDate,isAllDay,location,なし,なし,なし,なし,notes
```

つまり、`"表示名"` が macOS でのカレンダー名になります。なお、"" で囲まなくても正しく処理されますので、CSV ファイルを EXCEL で読み込んで、再度 CSV で書き込んでも大丈夫なはずです。行末は "\n" のみでも "\r\n" でも大丈夫なはずです。

ファイル名として `-` を指定すると、標準入力から読み込まれます。主な使い途としては、

```
$ nkf -s *.csv | iCalTool add -
```

というところです。

### sync (csv-file|-) [start-date [end-date]]

`start-date` と `end-date` の間のカレンダーを `csv-file` の内容で置き換えます。この時、全く同じ内容のイベントの UUID は変更されませんが、イベントのノートを含め、少しでも変更があれば、新たな UUID に付け替えられます。

ファイルのフォーマットは CSV 形式で `add` サブコマンドと同じです。<font color="Red">ファイルのエンコーディングは Shift JIS です。</font>

`start-date` や `end-date` が指定されない場合には、`csv-file` の中身をスキャンして、最も早くから始まるイベントの開始日時を `start-date`、最も遅く終了するイベントの終了日時を `end-date` とします。


ファイル名として `-` を指定すると、標準入力から読み込まれます。

### diff (csv-file|-) [start-date [end-date]]

`start-date` と `end-date` の間のカレンダーと `csv-file` の内容を比較します。`sync` と同様で、`sync` の dry run 相当です。

## その他注意事項

本ソフトウェアは as-is での公開となります。バグ等により macOS 上のカレンダーが壊れることがありますが、それに対する責任は負いません。壊れても良い環境でご利用ください。

本ソフトウェアの開発とテストは macOS Mojave (10.14.6) + Swift 5.1 で行なっています。


著者: Satoshi Moriai <https://github.com/moriai>
バージョン: 1.0.2 (2019/8/27)
