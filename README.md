# Mustang Studio

App per Mac che registra la chitarra dal **Fender Mustang II** collegato in USB. Salva ogni take in WAV, con una copia pulita e una copia con il preset scelto.

## Cosa fa

- Legge il formato nativo dell’amplificatore e registra a quella frequenza, senza ricampionare.
- Lavora in 32-bit float e scrive **WAV PCM a 24 bit**.
- Non applica controllo automatico del guadagno né filtri “voce”.
- Preset **Pulito**, tre acustici (naturale, calda, fingerstyle) e quattro elettrici (clean, crunch, lead, jazz).
- L’ascolto in cuffia esce dal Mac. Il Mustang II non riproduce l’audio del computer via USB.

Il Mustang II, via USB, invia in genere **stereo 44,1 kHz / 16 bit**: è il massimo del suo convertitore. Il file a 24 bit non inventa dettaglio che l’ampli non ha mandato; evita solo una seconda quantizzazione dopo i preset.

Il segnale USB è quello già passato dal modello d’ampli. Per la take più pulita: sul Mustang un preset neutro, volume sotto il clip, e nell’app il preset **Pulito**.

## Uso

1. Accendi il Mustang II e collegalo al Mac con il cavo USB.
2. Apri Mustang Studio e consenti l’accesso al microfono. È il permesso che macOS chiede per qualsiasi ingresso audio.
3. Controlla che il dispositivo selezionato sia il Mustang e che il meter si muova quando suoni.
4. Regola il guadagno restando sotto la spia CLIP.
5. Scegli un preset, premi **Registra**, poi **Stop**.

Le take finiscono in `~/Music/MustangStudio`. Ogni take ha due file:

- `… pulito.wav` — ingresso con il solo guadagno impostato
- `… [nome preset].wav` — la stessa take con EQ, dinamica ed effetti del preset

Con il preset Pulito il secondo file si chiama `Pulito (preset).wav`: sul disco del Mac `Pulito.wav` e `pulito.wav` sarebbero lo stesso file.

Durante la registrazione il preset resta fisso.

## DMG

Il file `MustangStudio.dmg` si costruisce così, dai Command Line Tools (Xcode non serve):

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

Lo script compila l’app, la firma ad hoc e scrive il DMG sul Desktop. Dentro ci sono l’app, un collegamento ad Applicazioni e un testo di istruzioni.

Se macOS blocca l’apertura perché la firma non è di uno sviluppatore Apple: tasto destro sull’app → **Apri**.
