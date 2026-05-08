# 유현 센서 모니터링 (Flutter)

웹 프론트(`yuhyun-sensor-monitoring-front`) · 백엔드(`yuhyun-sensor-monitoring-back`)와 동일한 기능을 제공하는 **모바일/웹 동등성 앱**입니다. Flutter 단일 코드베이스로 Android · iOS · Web · macOS 데스크톱을 지원합니다.

- 백엔드: `https://yuhyun-sensor-monitoring-back.onrender.com` (앱에 기본값으로 박혀 있음)
- 웹↔앱 동등성 검증 내역은 로컬 노트(`동등성체크리스트.md`)에서 관리합니다.

## 주요 기능

| 영역 | 내용 |
|---|---|
| 인증 | 로그인 / 회원가입 / 세션 복원 / 역할별 라우팅 (Admin · Manager · MultiMonitor 등) |
| 대시보드 | KPI 5종, 위험 센서 즉시 확인, 지연 센서 경고, 1분 자동 갱신 |
| 센서 | 4탭(모니터링 · 정의 · 계산식 · 재수집), 검색·현장 드롭다운·상태 5탭 |
| 센서 상세 | 정보·트렌드(오늘/7일/30일/시간별)·로그 + 임계치/계산식/평면도 편집 모달 |
| 알람 | 미확인 알람 뱃지(종 아이콘, 30초 폴링), 개별/전체 확인, 상태 필터 |
| 현장 | 카드·필터·상세 모달, 담당자 chip, 센서 배정, 평면도 업로드 |
| 파일 | 검색·업로드·삭제·다운로드 (웹은 다운로드 안내) |
| 사용자 | 추가·편집·활성화·삭제·비밀번호 변경, 역할 6종 그리드 |
| QR | 공개 QR 페이지 (`/qr/:id`) |

## 디렉터리

```
yuhyeonApp/
├── app/                       # Flutter 앱 본체
│   ├── lib/
│   │   ├── core/              # config, theme, utils(json_parse 등)
│   │   ├── features/          # 기능별 모듈 (auth, dashboard, sensors, alarms, sites, files, users, qr)
│   │   ├── common/            # 공용 위젯 / AppShell
│   │   └── main.dart
│   ├── android/               # Android 네이티브
│   ├── ios/ macos/ web/       # 그 외 플랫폼
│   └── pubspec.yaml
└── *.md                       # 로컬 노트(.gitignore로 GitHub 미공개)
```

> 로컬 노트(체크리스트·구현 메모·가이드 등)는 `.gitignore` 처리되어 있어 GitHub에는 올라가지 않습니다.

## 핵심 의존성

- `flutter_riverpod` — 상태 관리 (`AuthSession`, `UnackedAlarmCount` 등)
- `go_router` — 라우팅, 역할별 redirect, URL 동기화
- `dio` — HTTP 클라이언트 (JWT 인터셉터)
- `flutter_secure_storage` — JWT 안전 보관 (Android KeyStore / iOS Keychain)
- `shared_preferences` — 화면 상태/필터 영구화
- `path_provider` — 모바일 파일 다운로드 경로
- `file_picker` — 평면도/일반 파일 업로드 (PNG/JPG/PDF 지원)

## 환경 설정

기본 백엔드 URL은 `app/lib/core/config/app_config.dart`에 컴파일타임 상수로 박혀 있습니다.

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://yuhyun-sensor-monitoring-back.onrender.com',
);
```

다른 백엔드(스테이징 등)를 쓰고 싶으면 빌드 시 `--dart-define`으로 덮어씁니다:

```bash
flutter run --dart-define=API_BASE_URL=https://staging.example.com
```

## 실행 / 빌드

### 개발 실행

```bash
cd app
flutter pub get

# Android 에뮬레이터
flutter run -d emulator-5554

# 웹 (백엔드 CORS는 localhost:3000만 허용 → 포트 고정)
flutter run -d chrome --web-port=3000

# macOS 데스크톱
flutter run -d macos
```

### 릴리즈 APK (Android)

```bash
cd app
flutter build apk --release --split-per-abi
```

산출물 — `app/build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` — 일반 폰(64bit), **테스터 배포용**
- `app-armeabi-v7a-release.apk` — 구형 32bit
- `app-x86_64-release.apk` — 에뮬레이터/x86

### 웹 정적 빌드

```bash
cd app
flutter build web --release \
  --dart-define=API_BASE_URL=https://yuhyun-sensor-monitoring-back.onrender.com
```

산출물은 `app/build/web/`. Firebase Hosting / Vercel / Netlify 등에 그대로 업로드 가능합니다 (SPA rewrite는 호스팅 측에서 설정).

## 품질 점검

```bash
cd app
flutter analyze
flutter test
```

## 테스트 계정

| 이메일 | 비밀번호 | 역할 |
|---|---|---|
| `qwer4321@qwer4321.com` | `qwer4321` | MultiMonitor |

> 로그인 화면 하단의 "테스트 계정 (터치 시 자동 입력)" 영역을 누르면 자동 입력됩니다.

## 알려진 사항

- **Render 무료 플랜 콜드 스타트** — 백엔드가 일정 시간 미사용 시 sleep, 첫 요청은 15~30초 지연될 수 있습니다.
- **웹 빌드 CORS** — 백엔드 `index.js`가 `localhost:3000`만 허용하므로 로컬 웹 실행 시 `--web-port=3000` 필수. 다른 도메인에 배포할 경우 백엔드 `FRONTEND_URL` 환경변수 추가 필요.
- **iOS 배포** — Apple Developer Program ($99/년)이 있어야 실기기 설치 가능. 시뮬레이터까지는 Xcode + macOS만으로 무료 검수 가능.

## 관련 레포

- 백엔드: [`yuhyun-sensor-monitoring-back`](https://github.com/ShinYeoJin/yuhyun-sensor-monitoring-back)
- 웹 프론트: [`yuhyun-sensor-monitoring-front`](https://github.com/ShinYeoJin/yuhyun-sensor-monitoring-front)
