# third_party/chess_vectors_flutter

Lokale kopie van `chess_vectors_flutter` 1.1.0 (pub.dev) met één aanpassing:
elk schaakstuk heeft een vriendelijk gezichtje gekregen (grote ogen + glimlach)
via de helper `cuteFace()` bovenin `lib/chess_vectors_flutter.dart`.

Waarom vendored: het pakket ondersteunt geen custom pieces; de stukken zijn
hardcoded vectordefinities. De originele sprites worden verder ongewijzigd
gebruikt. Updaten = nieuwe versie kopiëren en de cuteFace-oproepen opnieuw
toevoegen (12 stuks).
