# ⭐ Yıldız Çocuklar — Kurulum Kılavuzu

## Proje Yapısı

```
StarKids/
├── config.js            ← Supabase bilgilerinizi buraya girin
├── login.html           ← Giriş sayfası
├── index.html           ← Ana sayfa (dashboard)
├── children.html        ← Çocuk yönetimi  [Admin]
├── rules.html           ← Kural yönetimi  [Admin]
├── periods.html         ← Dönem yönetimi  [Admin]
├── users.html           ← Kullanıcı yönetimi [Admin]
├── child-detail.html    ← Çocuk detay & puan geçmişi
├── css/style.css        ← Özel stiller
├── js/
│   ├── client.js        ← Supabase istemcisi
│   ├── auth.js          ← Oturum & rol yönetimi
│   ├── nav.js           ← Gezinti çubuğu (rol bazlı)
│   └── toast.js         ← Bildirimler
└── sql/
    ├── schema.sql       ← Temel veritabanı şeması
    ├── users.sql        ← Kullanıcı yönetimi & rol bazlı RLS  ← YENİ
    └── ...              ← Diğer migrationlar
```

---

## 1. Supabase Projesi Oluşturun

1. [https://app.supabase.com](https://app.supabase.com) adresine gidin
2. **"New project"** butonuna tıklayın (ücretsiz plan yeterli)
3. Proje adını girin ve bir şifre belirleyin, **Create new project** deyin

---

## 2. Veritabanını Kurun

Aşağıdaki SQL dosyalarını **sırayla** Supabase → SQL Editor'de çalıştırın:

| Sıra | Dosya | Açıklama |
|------|-------|----------|
| 1 | `sql/schema.sql` | Temel tablolar ve RLS |
| 2 | `sql/categories.sql` | Kategori tablosu |
| 3 | `sql/goals.sql` | Hedef tablosu |
| 4 | `sql/goals_update.sql` | Hedef güncellemesi |
| 5 | `sql/periods.sql` | Dönem tablosu |
| 6 | `sql/storage.sql` | Dosya depolama |
| 7 | `sql/category.sql` | Çocuk kategorisi |
| 8 | `sql/users.sql` | **Kullanıcı yönetimi & rol bazlı RLS** |

---

## 3. Yönetici Hesabı Oluşturun

1. Sol menüden **Authentication** → **Users** bölümüne gidin
2. **"Add user"** → **"Create new user"** tıklayın
3. E-posta ve şifre belirleyin
4. `sql/users.sql` çalıştırıldıysa bu kullanıcı otomatik olarak **Admin** rolü alır
   (ilk oluşturulan kullanıcı varsayılan admin olur)

---

## 3b. Kullanıcı Rolleri

| Rol | Açıklama |
|-----|----------|
| 👑 **Admin** | Her şeyi yapabilir: çocuk, kural, dönem, kullanıcı yönetimi + ödül/ceza |
| ✏️ **Editör** | Çocuk listesini görür, ödül ve ceza verebilir |
| 👁️ **İzleyici** | Yalnızca ana sayfayı görüntüleyebilir |

Giriş yaptıktan sonra **Kullanıcılar** sayfasından yeni kullanıcı ekleyebilir,
mevcut kullanıcıların rollerini değiştirebilirsiniz.

---

## 4. config.js Dosyasını Düzenleyin

1. Sol menüden **Settings** → **API** bölümüne gidin
2. **Project URL** ve **anon public** key'i kopyalayın
3. `config.js` dosyasını açın ve şu satırları güncelleyin:

```javascript
const CONFIG = {
  supabase: {
    url: 'https://PROJE_ID.supabase.co',  // ← Project URL
    anonKey: 'eyJhbGciOiJIUzI1NiI...'    // ← anon public key
  },
  ...
};
```

---

## 5. Uygulamayı Çalıştırın

Dosyaları doğrudan tarayıcıda açabilirsiniz. Ancak CORS kısıtlamaları nedeniyle
bir yerel web sunucusu kullanmanız önerilir:

**VS Code ile:**
- "Live Server" eklentisini yükleyin → `login.html`'e sağ tıklayın → "Open with Live Server"

**Python ile:**
```bash
cd c:\Repos\StarKids
python -m http.server 8080
# Tarayıcıda: http://localhost:8080/login.html
```

**Node.js ile:**
```bash
npx serve c:\Repos\StarKids
```

---

## Özellikler

| Sayfa | Erişim | Açıklama |
|-------|--------|----------|
| 🏠 Ana Sayfa | Tüm kullanıcılar | Özet istatistikler, çocuk kartları, son aktiviteler |
| 👨‍👩‍👧‍👦 Çocuklar | Admin + Editör | Çocuk listesi; editör yalnızca görüntüler |
| 📋 Kurallar | Admin | Ödül ve ceza kuralları, global hedefler |
| 📅 Dönemler | Admin | Dönem oluşturma ve yönetimi |
| 👥 Kullanıcılar | Admin | Kullanıcı ekleme, rol değiştirme |
| 📊 Çocuk Detayı | Tüm kullanıcılar | Puan geçmişi; ödül/ceza yalnızca editör+admin, silme yalnızca admin |

---

## Notlar

- Uygulama tamamen **ücretsiz** Supabase planı ile çalışır
- Supabase ücretsiz planı: 500 MB veritabanı, 50K aylık aktif kullanıcı
- Tüm veriler Supabase bulutunda güvenli şekilde saklanır
- Birden fazla cihazdan aynı anda kullanılabilir
