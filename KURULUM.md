# ⭐ Yıldız Çocuklar — Kurulum Kılavuzu

## Proje Yapısı

```
ChildTracker/
├── config.js            ← Supabase bilgilerinizi buraya girin
├── login.html           ← Giriş sayfası
├── index.html           ← Ana sayfa (dashboard)
├── children.html        ← Çocuk yönetimi
├── rules.html           ← Kural yönetimi
├── child-detail.html    ← Çocuk detay & puan geçmişi
├── css/style.css        ← Özel stiller
├── js/
│   ├── client.js        ← Supabase istemcisi
│   ├── auth.js          ← Oturum yönetimi
│   ├── nav.js           ← Gezinti çubuğu
│   └── toast.js         ← Bildirimler
└── sql/schema.sql       ← Veritabanı şeması
```

---

## 1. Supabase Projesi Oluşturun

1. [https://app.supabase.com](https://app.supabase.com) adresine gidin
2. **"New project"** butonuna tıklayın (ücretsiz plan yeterli)
3. Proje adını girin ve bir şifre belirleyin, **Create new project** deyin

---

## 2. Veritabanını Kurun

1. Sol menüden **SQL Editor**'e girin
2. `sql/schema.sql` dosyasının içeriğini kopyalayıp yapıştırın
3. **Run** butonuna tıklayın
4. "Success" mesajı görmelisiniz

---

## 3. Yönetici Hesabı Oluşturun

1. Sol menüden **Authentication** → **Users** bölümüne gidin
2. **"Invite user"** veya **"Add user"** → **"Create new user"** tıklayın
3. E-posta ve şifre belirleyin (bunlarla giriş yapacaksınız)

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
cd c:\Repos\ChildTracker
python -m http.server 8080
# Tarayıcıda: http://localhost:8080/login.html
```

**Node.js ile:**
```bash
npx serve c:\Repos\ChildTracker
```

---

## Özellikler

| Sayfa | Açıklama |
|-------|----------|
| 🏠 Ana Sayfa | Tüm çocuklar, özet istatistikler, son aktiviteler, hızlı puan verme |
| 👨‍👩‍👧‍👦 Çocuklar | Çocuk ekle/düzenle/sil, emoji avatar seçimi |
| 📋 Kurallar | Ödül ve ceza kuralları ekle/düzenle/sil, ikon seçimi |
| 📊 Çocuk Detayı | Ödül & ceza geçmişi, puan ver, kayıt sil |

---

## Notlar

- Uygulama tamamen **ücretsiz** Supabase planı ile çalışır
- Supabase ücretsiz planı: 500 MB veritabanı, 50K aylık aktif kullanıcı
- Tüm veriler Supabase bulutunda güvenli şekilde saklanır
- Birden fazla cihazdan aynı anda kullanılabilir
