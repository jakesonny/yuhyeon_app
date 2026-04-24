# yuhyunMobile

유현건설 센서 모니터링 웹 프론트를 Flutter 모바일 목업으로 이식한 프로젝트입니다.

## 프로젝트 목적

- 백엔드 연동 없이 화면 시연 가능한 모바일 앱 목업 제공
- 웹 프론트 디자인 톤을 Flutter에서 최대한 유사하게 재현
- 추후 실제 API 연동으로 전환 가능한 구조 유지

## 현재 구현 상태

- **Demo Mode (백엔드 0호출)** 기반
- 로그인/대시보드/센서목록/센서상세/알람/현장/파일/사용자/QR 화면 구성
- 공통 디자인 토큰 및 공통 위젯(`GeoCard`, `SectionTitle`, `StatusBadge`) 적용
- KPI 카드 필터, 센서상세 탭(정보/트렌드/로그) 등 목업 인터랙션 포함

## 실행 방법

```bash
cd app
flutter pub get
flutter run
```

## 품질 확인

```bash
cd app
flutter analyze
flutter test
```

## Vercel 배포

### 1) Vercel 프로젝트 연결

- Vercel에서 레포 연결 후 Root Directory를 `yuhyunMobile/app`으로 지정
- Build Command: `flutter build web`
- Output Directory: `build/web`

### 2) go_router 라우팅 대응

- `app/vercel.json`에 SPA rewrite 설정이 포함되어 있어 직접 URL 접근 시 404를 방지합니다.

### 3) 첫 배포 전 점검

```bash
cd app
flutter build web
```

빌드가 정상 완료되면 Vercel 배포도 같은 산출물(`build/web`) 기준으로 동작합니다.

## 목업 구현 방식 (상세)

목업 데이터 구조, 데모 모드 인증/라우팅 처리, 디자인 토큰 구성, API 전환 전략은 아래 문서에 정리되어 있습니다.

- [목업구현.md](./목업구현.md)

## 디렉터리 안내

- `app/`: Flutter 앱 본체
- `목업구현.md`: 목업 구현 상세 문서(커밋/공유용)
- `플러터가이드.md`: 개인 학습 가이드(로컬 전용, Git 제외)
