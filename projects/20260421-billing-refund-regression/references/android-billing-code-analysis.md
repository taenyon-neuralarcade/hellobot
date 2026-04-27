# Android 결제 코드 분석

> 2.29.5 기준. master(2.40.0.1)에 동일 코드 잔존 확인됨.

## 1. 구조적 변경 요약 (2.29.4 → 2.29.5)

| 항목 | 2.29.4 | 2.29.5 |
|---|---|---|
| BillingManager 패턴 | `object` 싱글턴 | `@Singleton class` + Hilt 주입 |
| unprocessedPurchase | `Purchase?` (단건) | `MutableList<Purchase>` (큐) |
| 앱 시작 시 자동 처리 | 없음 | `notConsumedPurchase()` 자동 호출 |
| 리스너 구조 | callback 파라미터 주입 | 단일 레퍼런스 보관 |
| 에러 재시도 | 없음 | 2회 재시도 + 반대 타입 재호출 |
| DU002 분기 | 없음 | 추가됨 (이미 서버 등록) |

## 2. 의심 포인트

### 2-1. BillingService.notConsumedPurchase — INAPP isAcknowledged 필터 누락

`app/src/main/java/com/thingsflow/hellobot/billing/util/BillingService.kt`

```kotlin
fun notConsumedPurchase() {
    // INAPP — 필터 없음 ⚠️
    billingClient.queryPurchasesAsync(INAPP) { _, list ->
        inAppPurchases.addAll(list)
    }

    // SUBS — 정상
    billingClient.queryPurchasesAsync(SUBS) { _, list ->
        val notAckedList = list.filter { !it.isAcknowledged }
        subPurchases.addAll(notAckedList)
    }
}
```

Google Play Billing Library 권장: `isAcknowledged=false && purchaseState=PURCHASED` 필터링 필수.

### 2-2. BillingManager.listener 단일 레퍼런스 덮어쓰기

```kotlin
override fun connectBilling(listener: ..., ...) {
    this.listener = listener   // 이전 ViewModel 리스너를 덮어씀
}
```

`connectBilling` 호출하는 ViewModel 최소 4개:
- `PurchaseViewModel` (heart_store)
- `BaseChatbotProductViewModel` (chatbot_product)
- `CurrentChatbotProductsViewModel` (chatbot_product)
- `ChatroomChatbotProductsViewModel` (chatroom)

화면 이동 타이밍에 따라 잘못된 ViewModel로 orderId 전달 가능.

### 2-3. consumeProduct 에러 핸들러 — HTTP 400 재시도

```kotlin
if (httpStatusCode == 400 || httpStatusCode == 500 || httpStatusCode == null) {
    return consumeProductWithPurchase(purchase, 반대타입, ...)
}
```

400(Bad Request)는 재시도 의미 없음. 반대 타입 API로 재시도하는 것도 설계상 의심.

### 2-4. PurchaseViewModel.consumePurchases — 타입 하드코딩

```kotlin
billingApi.consumeProduct(
    orderId,
    ConsumeProductResponse::class.java,   // HeartStore 타입 하드코딩
    ::consumeHeartProduct,
    ::consumeChatbotProduct,
)
```

채팅방 상품 구매 orderId도 우선 HeartStore API로 1차 시도됨 → 400 → 반대 타입 재시도 → DU002 흐름 유발 가능.

### 2-5. doFinally { alreadyConfirmPurchase() } 강행

```kotlin
.doFinally {
    alreadyConfirmPurchase()
}

override fun alreadyConfirmPurchase() {
    // unprocessedPurchases 순회 → billingService.confirmPurchase(purchase)
    //   INAPP이면 → consumeAsync
    //   SUBS이면 → acknowledgePurchase
}
```

서버가 DU002(이미 처리됨)를 반환해도 Google 측 consume을 **무조건** 수행. 서버 지급 후 시간이 오래 지나 consume 시점이 72시간을 넘은 과거 토큰이 있다면 Google 자동 환불 정책이 발동할 수 있음.

## 3. 유저 관점 현상 (가설별)

| 시나리오 | 유저 경험 | 매출 영향 | 빈도 추정 |
|---|---|---|---|
| A. 결제 성공+지급 정상+며칠 후 자동 환불 | 알아채기 어려움, 드물게 환불 알림 | 매우 큼 | 높음 |
| B. 과거 완료 구매가 앱 재시작마다 재처리 | 겉으로 변화 없음 | Google이 소급 환불 판정 시 큼 | 중 |
| C. 결제 시도 → 실패 토스트 → 자동 환불 | "결제했는데 상품 안 와요" CS | 중 (재시도 일부 포기) | 낮음 |
| D. 화면 전환 타이밍별 간헐적 실패 | 결제 느림/간헐 실패 | 낮음 | 낮음 |

## 4. 현재(master) 상태

- `git show origin/master:app/.../BillingService.kt` 확인 결과 2-1 버그 그대로 유지
- 2.29.5 이후 1년 이상 결제 모듈에 유의미한 수정 없음

## 5. 개선 방향 (초안)

1. INAPP 쿼리에 `filter { !it.isAcknowledged && it.purchaseState == PURCHASED }` 적용
2. `BillingManager.listener`를 ViewModel별 Set 또는 orderId → productType 맵으로 변경
3. `consumeProduct` 에러 핸들러: HTTP 400 재시도 제거, DU002 응답 시 Google consume만 수행하고 서버 호출 반복하지 않음
4. `unprocessedPurchases` 큐에 넣는 조건 재검토 — DU002는 이미 서버 측 완료이므로 상태 동기화만
5. 결제 플로우 전반에 Crashlytics 이벤트 브레드크럼 강화

> 확정은 /architect 단계에서 진행. 위 방향은 근거 자료.
