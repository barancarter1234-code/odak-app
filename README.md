# Odak

Instagram ve YouTube'u Reels ve Shorts olmadan açan iki kişisel iPhone uygulaması.
Her uygulama siteyi tam ekran açar (adres çubuğu yok) ve `App/odak.user.js` filtresini her sayfaya ekler.
Ayarlar sağ kenardaki ⚙ menüsünden yapılır.

## Derleme

`main` dalına yapılan her push, GitHub Actions'ta iki uygulamayı imzasız derler.
Sonuç, çalıştırma sayfasındaki **odak-ipa** paketidir: `Instagram.ipa` ve `YouTube.ipa`.

## Telefona yükleme

`.ipa` dosyaları Windows'ta Sideloadly ile kendi Apple ID'nle imzalanıp yüklenir.
Ücretsiz Apple ID ile imza 7 gün geçerlidir; süre dolunca Sideloadly'den yeniden yükle.

## Dosyalar

- `App/odak.user.js`: filtre ve ayar menüsü (Safari'deki Userscripts eklentisinde de çalışır)
- `App/Sources/`: Swift kodu (tam ekran WKWebView)
- `project.yml`: XcodeGen proje tanımı
- `Icons/`: uygulama ikonları
