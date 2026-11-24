# Odak

Instagram ve YouTube'u Reels ve Shorts olmadan açan iki kişisel iPhone uygulaması.
Her uygulama siteyi tam ekran açar (adres çubuğu yok) ve `App/odak.user.js` filtresini her sayfaya ekler.
Ayarlar sağ kenardaki ⚙ menüsünden yapılır.

YouTube uygulamasında videodan çıkınca video, alttaki mini oynatıcıda sürer.

## Script güncellemeleri

Uygulamalar açılışta ve öne geldiklerinde (en fazla 15 dakikada bir) `App/odak.user.js` dosyasının
`main` dalındaki sürümünü indirir. Bu yüzden script değişiklikleri için telefona yeniden yükleme gerekmez:
değişikliği `main`'e gönder, uygulamayı kapatıp aç.
İndirme için repo herkese açık (public) olmalı; değilse uygulama içindeki kopya kullanılır.

## Derleme

`main` dalına yapılan her push, GitHub Actions'ta iki uygulamayı imzasız derler.
Sonuç, çalıştırma sayfasındaki **odak-ipa** paketidir: `Instagram.ipa` ve `YouTube.ipa`.

## Telefona yükleme

`.ipa` dosyaları Windows'ta Sideloadly ile kendi Apple ID'nle imzalanıp yüklenir.
Ücretsiz Apple ID ile imza 7 gün geçerlidir; süre dolunca Sideloadly'den yeniden yükle.

## Dosyalar

- `App/odak.user.js`: filtre ve ayar menüsü (Safari'deki Userscripts eklentisinde de çalışır)
- `App/Sources/`: Swift kodu (tam ekran WKWebView, mini oynatıcı, script güncelleme)
- `project.yml`: XcodeGen proje tanımı
- `Icons/`: uygulama ikonları
