[← 실습 1](./01-네트워크-기초-요청과-응답-보기.md) · [목차](../Docker-실습.md) · [실습 3 →](./03-Docker-없이-Node-앱-직접-실행.md)

# 실습 2. 셸 조합과 nano

**무엇을 하나요**: 서버 VM에는 화면이 없어 메모장·마우스·Ctrl+F 없이 터미널로만 고치고 찾아야 합니다. 명령을 이어 붙이고(`|`), 결과를 파일로 보내고(`>`, `>>`), 환경변수와 종료 코드를 확인합니다. 터미널 안에서 편집기 nano로 파일을 고칩니다. Docker 실습 내내 쓰는 기본기입니다. (교안 02장)

**필요한 것**: 실습 1에서 만든 `~/basics` 폴더. (셸 = 지금 명령을 받아 실행하는 프로그램. 터미널 안에서 돌아갑니다)

> **바로 가기** · [1. 파이프와 리다이렉트](#1단계-파이프와-리다이렉트) · [2. 환경변수와 종료 코드](#2단계-환경변수와-종료-코드) · [3. 터미널 편집기 nano](#3단계-터미널-편집기-nano) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 파이프와 리다이렉트

```bash
cd ~/basics
cat /etc/os-release                  # 13줄 전부 — 필요한 것은 한두 줄
cat /etc/os-release | grep CODENAME  # CODENAME이 든 줄만
# VERSION_CODENAME=noble
# UBUNTU_CODENAME=noble
echo "first" > note.txt      # > : 파일에 씀 (있던 내용은 지워짐)
echo "second" >> note.txt    # >> : 파일 끝에 이어 씀
cat note.txt                 # first / second 두 줄
echo "new" > note.txt
cat note.txt                 # new 한 줄만 남음
```

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `cat 파일` | 파일 내용을 화면에 보여 줌 |
| `/etc/os-release` | 이 VM의 운영체제 정보가 적힌 파일 |
| `\|` (파이프, Shift+역슬래시 키) | 앞 명령의 출력을 뒤 명령의 입력으로 넘김 |
| `grep 글자` | 그 글자가 든 줄만 골라 보여 줌 |
| `echo "글자"` | 글자를 출력 |
| `> 파일` | 출력을 화면 대신 파일에 씀. **있던 내용은 지워짐** |
| `>> 파일` | 출력을 파일 **끝에 이어** 씀 |

**이렇게 나오면 성공**
- `cat /etc/os-release` → `PRETTY_NAME="Ubuntu 24.04.5 LTS"`부터 13줄. 화면이 없는 VM에서는 이 중 필요한 줄을 눈으로 찾는 대신 `grep`으로 거릅니다
- `grep CODENAME` → `VERSION_CODENAME=noble`, `UBUNTU_CODENAME=noble` 두 줄
- 첫 `cat note.txt` → `first`, `second` 두 줄
- 마지막 `cat note.txt` → `new` 한 줄(`>`가 앞 내용을 지웠기 때문)

`noble`은 우분투 24.04의 코드명입니다. 실습 4의 Docker 설치 명령이 이 값을 꺼내 씁니다.

## 2단계. 환경변수와 종료 코드

```bash
echo $HOME                   # /home/lab
export GREETING=hello        # 환경변수 만들기
echo $GREETING               # hello
env | grep GREETING          # GREETING=hello
ls nothing.txt               # ls: cannot access 'nothing.txt': No such file or directory
echo $?                      # 2
ls note.txt
echo $?                      # 0
```

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `$HOME` | 환경변수 `HOME`의 값. 내 홈 폴더 |
| `export 이름=값` | 환경변수를 만듦. `=` 앞뒤에 **띄어쓰기 없이** |
| `$이름` | 그 환경변수의 값을 꺼냄 |
| `env` | 지금 있는 환경변수를 모두 보여 줌. `grep`으로 하나만 골라 봄 |
| `ls 파일` | 파일이 있는지 보여 줌. `nothing.txt`는 일부러 없는 파일 |
| `echo $?` | 바로 앞 명령의 **종료 코드**. 0이면 성공, 0이 아니면 실패 |

**이렇게 나오면 성공**: 각 줄의 `#` 뒤와 같으면 됩니다. `ls nothing.txt`의 오류(`No such file or directory` = 그런 파일이나 폴더가 없음)는 **일부러 낸 것**이니 괜찮습니다.

- 환경변수 = 이름=값으로 둔 설정. 실습 3에서 `PORT=3001 node app.js`로 앱의 포트를 바꾸고, 실습 6부터는 `docker run -e`로 컨테이너에 넣습니다
- `docker ps -a`의 `Exited (0)` 괄호 안 숫자도 종료 코드입니다

> **`echo $?`가 뭔가요?**
>
> 리눅스 명령은 끝날 때마다 "잘 끝났는지"를 **숫자 하나**로 남깁니다. 이 숫자를 **종료 코드**(exit code)라고 합니다. 화면에 보이지는 않고, `$?`라는 곳에 잠깐 담겨 있습니다. `echo $?`는 그 숫자를 화면에 찍어 보는 명령입니다.
>
> | 숫자 | 뜻 | 예 |
> |---|---|---|
> | `0` | 성공 | `ls note.txt`(파일 있음) 뒤 → `0` |
> | `0`이 아닌 수 | 실패하거나 못 찾음. 숫자는 명령마다 다름 | `ls nothing.txt`(파일 없음) 뒤 → `2` / `grep`이 찾는 글자가 없을 때 → `1` |
>
> - **꼭 "바로 앞" 명령의 결과**입니다. 중간에 다른 명령을 치면 그 명령의 결과로 바뀝니다. `echo $?`를 두 번 치면 두 번째는 첫 번째 `echo`가 성공했으니 `0`입니다
> - 화면에 오류 글자가 길게 나와도, 성공·실패는 이 숫자로 확실히 알 수 있습니다. 그래서 자동으로 도는 스크립트나 CI/CD(나중 과목)가 "다음 단계로 넘어갈지"를 이 숫자로 정합니다
> - Docker에서도 똑같습니다. 컨테이너 안 프로그램이 끝나면 `docker ps -a`에 `Exited (0)`(정상 종료) 또는 `Exited (1)`(오류로 종료)처럼 이 숫자가 보입니다. 0이 아니면 `docker logs 이름`으로 이유를 봅니다

## 3단계. 터미널 편집기 nano

터미널 안에서 파일을 고치는 편집기입니다. 마우스 대신 **화살표 키**로 움직입니다.

```bash
nano memo.txt                # 없는 파일이면 새로 만듦
```

화면 맨 아래 두 줄이 단축키 안내입니다. `^`는 **Ctrl** 키입니다(`^O` = Ctrl+O). macOS도 Cmd가 아니라 **Ctrl**입니다.

1. 두 줄을 입력합니다: `hello nano`, `second line` (줄 바꿈은 Enter)
2. **Ctrl+O**(저장) → 맨 아래에 `File Name to Write: memo.txt`가 나오면 **Enter** → `[ Wrote 2 lines ]`(2줄 저장함)
3. **Ctrl+X**로 나옵니다
4. `cat memo.txt`로 두 줄을 확인합니다

| 할 일 | 키 |
|---|---|
| 저장 | Ctrl+O → Enter |
| 종료 | Ctrl+X (저장 안 했으면 아래에 `Save modified buffer?`(고친 내용 저장할까요?)가 나옴 → Y → Enter, 저장하지 않으려면 N) |
| 붙여넣기 | VS Code 터미널 붙여넣기와 같음(Windows Ctrl+V 또는 Ctrl+Shift+V, macOS Cmd+V) |
| 찾기 · 줄 잘라내기 · 붙이기 | Ctrl+W · Ctrl+K · Ctrl+U |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 상황 | 해결 |
|---|---|
| 저장했는데 `cat`에 아무것도 없음 | Ctrl+O 뒤에 **Enter**를 안 누른 것. nano로 다시 열어 Ctrl+O → Enter |
| 화면 아래에 `File Name to Write`가 떠 있는 채로 멈춤 | Enter를 누르면 저장됩니다 |
| 실수로 엉뚱한 키를 눌러 화면이 이상함 | Ctrl+X → 저장할지 물으면 N → 다시 `nano memo.txt` |

</details>

**vi가 열렸을 때 빠져나오기** — `git commit`처럼 편집기를 여는 명령이 nano 대신 vi(vim)를 열 때가 있습니다. vi는 nano와 조작이 전혀 다릅니다. `vi memo.txt`로 한 번 들어갔다가 **Esc** → `:q!` → **Enter**로 나와 봅니다(저장하지 않고 나감. 저장하고 나가려면 `:wq`).

## 끝났는지 확인
- ☐ `cat /etc/os-release`(13줄)와 `cat /etc/os-release | grep CODENAME`(2줄)의 차이를 봤다
- ☐ `cat note.txt`에 `new` 한 줄이 보인다
- ☐ `ls nothing.txt` 바로 뒤 `echo $?`에 `2`가 나왔다
- ☐ `cat memo.txt`에 nano로 쓴 두 줄이 보인다
- ☐ vi에서 `:q!`로 빠져나왔다

## 정리
- 지울 것은 없습니다. `~/basics` 폴더와 파일은 확인 문제에서 씁니다

## 확인 문제
1. `>>`로 `note.txt`에 `apple`, `banana` 두 줄을 이어 붙인 뒤 `cat note.txt | grep an`을 실행하세요. 무엇이 나오나요? 바로 뒤 `echo $?`의 값은?
2. nano로 `~/basics/index.html`을 열어 내용을 `<h1>edited by nano</h1>`로 바꿔 저장하세요. 실습 1처럼 웹 서버(`python3 -m http.server 8000`)를 띄우고 다른 터미널에서 `curl localhost:8000`으로 바뀐 내용을 확인한 뒤, 웹 서버를 Ctrl+C로 끕니다.
