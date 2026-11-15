# P2P Chess

Twee manieren om te schaken: **tegen de computer** (offline, met een keuze uit
makkelijk / gemiddeld / pittig) of **samen via een lokaal netwerk** (LAN /
zelfde Wi-Fi, geen account, geen server).

## Speelmodi

Bij het opstarten kies je:

- **Tegen de computer** — je speelt direct, offline. Kies het niveau
  (makkelijk = ondiepe zoekdiepte, gemiddeld = diepte 2, pittig = diepte 3
  met alpha-beta-snoeiing en MVV-LVA-zetordening) en of je wit of zwart
  speelt. Wit begint.
- **Met een vriend** — zie hieronder.

## Hoe speel je (multiplayer)?

1. Beide toestellen in hetzelfde Wi-Fi-netwerk.
2. **Speler 1** tikt op **“Nieuw spel host”**. De host staat te wachten en
   zendt elke 2 seconden een UDP-broadcast met zijn aanwezigheid.
3. **Speler 2** tikt op **“Zoeken”**; zodra de host gevonden is, verschijnt
   “Host gevonden op `<ip>`”. Tik daarop (of voer het IP-adres handmatig in en
   tik op **“Verbinden met host”**).
4. De host speelt **wit**, de joiner **zwart**. Wit begint.
   Zetten worden automatisch gesynchroniseerd; het bord draait mee met je
   kleur en je kunt alleen zetten als het jouw beurt is.

Tijdens het spel zie je boven het bord of jij aan zet bent, of het schaak is,
en of het spel voorbij is (schaakmat / remise). Met de
**opnieuw-beginnen**-knop (↺ rechtsboven) start een nieuw potje voor beide
spelers tegelijk.

## Hoe het werkt

- De host draait een WebSocket-server op poort **8080**.
- Hosts zenden elke 2 seconden een UDP-broadcast naar poort **8081**
  (`CHESS_HOST_ALIVE:<poort>`) zodat joiners de host automatisch vinden.
- Het bord wordt gesynchroniseerd met **FEN**-posities; beide toestellen
  houden een eigen kopie van de stelling bij.
- Geen externe server of matchmaking — alleen bereikbaar ín hetzelfde
  netwerk (multicast/broadcast moet aan staan op het netwerk; de meeste
  thuisnetwerken laten dit toe).

## Beperkingen

- Computer tegenstander is een simpele minimax-engine, geen sterke engine.
- Geen internet-matchmaking; alleen lokaal netwerk.
- Geen herverbinding: als de verbinding wegvalt, is het potje voorbij
  (het scherm toont "verbinding verbroken").
- Geen klok/timed games, geen rating, geen geschiedenis.

## Bouwen

```bash
flutter pub get
flutter build apk --release        # Android
flutter build ios                  # iOS (op macOS)
flutter run                        # development
```

## Ontwikkelen

```bash
flutter analyze
flutter test
```
