# ChispOmaMusic

**Idioma / Language:** [🇪🇸 Español](#es) · [🇬🇧 English](#en)

![preview](preview.png)

---

<a id="es"></a>
## 🇪🇸 Español

Widget de barra + panel emergente para **YouTube Music** vía MPRIS
(`Quickshell.Services.Mpris`), para la barra de Omarchy.

Sin servicio en segundo plano, sin claves de API, sin estado persistente:
todo se lee en vivo de la interfaz D-Bus del reproductor. Al hacer clic en el
icono de la barra se abre un panel con carátula, información de la canción,
barra de progreso con *seek*, aleatorio/repetir, controles de reproducción,
volumen y un histograma de espectro en vivo.

El plugin es **independiente de la fuente**: nunca lanza ni requiere una app
concreta. Lo que sea que esté reproduciendo YouTube Music — un cliente nativo
o una pestaña del navegador — es lo que controla.

Inspirado en [omaspotify](https://github.com/cempack/omaspotify), reescrito
para YouTube Music. **Fork de [haripako/omamusic](https://github.com/haripako/omamusic)**
con equalizador neón, temas y volumen corregido para navegadores.

### Equalizador neón

Este fork añade un **equalizador neón** a la barra: mientras suena música,
una fila de barras brillantes alimentadas por `cava` — la misma fuente que el
histograma del panel — se sitúa junto al icono. El clic en el icono sigue
abriendo el menú como siempre; el equalizador es puramente decorativo y nunca
intercepta los clics. Las barras reflejan el audio *del sistema*, igual que el
visualizador del panel.

### Temas

El aspecto se controla con el ajuste `neonTheme` — o haciendo clic en el
pequeño botón de paleta del encabezado del panel para cambiarlo al vuelo
(teclado: `t`):

- **Auto** (predeterminado) — sigue el accent del tema activo, de modo que el
  equalizador combina con el tema que uses. Si fijas un `neonColor` explícito
  en `shell.json`, ese gana sobre el accent.
- **Cyberpunk** — paleta neón multicolor (cian, magenta, morado, verde) con
  un resplandor intenso.
- **Minimalist** — resplandor neutro suave en el color de primer plano del
  tema.

`neonBarCount` controla cuántas barras se dibujan. Pon `barVisualizer` en
`false` para ocultar el equalizador de la barra por completo (el histograma
del panel no se ve afectado).

Cuando `cava` no está instalado, el equalizador no se queda en blanco: por
defecto muestra una **animación idle** suave — claramente decorativa, no
reactiva al audio. Pon `visualizerFallback` en `Nothing` para ocultarla.

### Requisitos

- **Omarchy** (escritorio basado en Quickshell)
- Una Nerd Font v3 (los iconos usan el rango Material Design)
- Una fuente de YouTube Music que hable MPRIS — un cliente nativo o una
  pestaña del navegador, ver abajo
- *Opcional:* [`cava`](https://github.com/karlstav/cava) para el histograma
  de espectro real. Sin él se muestra la animación idle (ver
  `visualizerFallback`).

### Qué reproductores funcionan

**Clientes nativos** se detectan por identidad / entrada de escritorio MPRIS
y siempre ganan a los navegadores:

- [pear-desktop](https://github.com/pear-devs/pear-desktop) — antes
  `th-ch/youtube-music`; se reconocen las identidades nuevas y antiguas
- [YTMDesktop](https://github.com/ytmdesktop/ytmdesktop)

Cualquier otro cliente puede añadirse con el ajuste `extraPlayerNames`.

**Reproducción en navegador** en `music.youtube.com` (pestaña normal o PWA
instalada) funciona a través de la sesión MPRIS del propio navegador, sea
cual sea: Firefox, Chromium, Chrome, Brave, Vivaldi, Edge, Opera, Zen,
LibreWolf, Floorp, Waterfox, qutebrowser, Falkon, Epiphany y similares.

Los forks quedan cubiertos sin necesidad de listarlos por nombre: además de
la identidad, se comprueba el nombre D-Bus, y los navegadores lo derivan de su
motor (`org.mpris.MediaPlayer2.firefox.*` para la familia Firefox,
`.chromium` / `.chrome` / `.brave` para la familia Chromium). El botón *Play*
también es agnóstico — abre la URL con `xdg-open`, así que se usa tu
navegador predeterminado.

Hay un detalle que conviene saber. Un navegador publica **una** sesión MPRIS
para el medio activo en ese momento, y los metadatos de Chromium se limitan a
título, artista, álbum, carátula y duración — no hay URL. Medido contra una
sesión real, YouTube Music deja `album` **vacío**, igual que un vídeo normal
de YouTube, así que los metadatos no permiten distinguirlos. El widget adopta
cualquier sesión de navegador que reporte un artista y nombra la fuente
(`via Chromium`) para que siempre sepas qué estás controlando.

Si eso es demasiado laxo, activa **Strict browser match**: además exige que
haya una ventana con el título *YouTube Music* abierta, que el título de la
pestaña sí expone. El compromiso es real — una ventana del navegador informa
de su pestaña *activa*, así que cambiar esa ventana a otra pestaña mientras
suena música en segundo plano deja el widget inactivo. Por eso está
desactivado por defecto, y necesita Hyprland porque lee `hyprctl`.

Si solo usas un cliente nativo, pon **Player source** en `Native app` y el
adivinado se acaba. `Browser` hace lo contrario: solo sesiones de navegador,
y el botón de play siempre abre `music.youtube.com` en vez de lanzar una app.

Cuando se controla una sesión de navegador, el panel añade `via <navegador>`
bajo la canción para que nunca haya ambigüedad sobre qué sesión controlas.

### Instalación

```bash
omarchy plugin add https://github.com/MrChispa/chispomamusic.git
```

El plugin viene **desactivado por defecto** para que puedas leer el código
primero:

```bash
omarchy plugin enable io.github.mrchispa.chispomamusic
```

Luego añádelo a la barra — te preguntará dónde colocarlo:

```bash
omarchy bar put io.github.mrchispa.chispomamusic
```

Puedes reubicarlo después arrastrándolo, o editando
`~/.config/omarchy/shell.json` a mano.

### Uso

- **Idioma del panel** — por defecto en inglés. El botón **ES** del encabezado
  del panel cambia al español y vuelve (persiste con el ajuste `language`).
- **Clic izquierdo** — abrir/cerrar el panel
- **Clic central** — reproducir/pausar sin abrir el panel, o iniciar YouTube
  Music cuando no suena nada
- **Sin reproducción** — el panel ofrece un botón *Play on YouTube Music* que
  lanza el cliente nativo si está instalado y, si no, abre
  `music.youtube.com` en tu navegador predeterminado. Cámbialo con el ajuste
  `launchCommand`.
- **Rueda sobre el icono** — volumen (cuando el reproductor lo soporta)
- **En el panel** — aleatorio, anterior, play/pausa, siguiente, repetir;
  arrastra la barra de progreso para *seek*, arrastra el slider de volumen
  para ajustarlo
- **Vídeos musicales** — cuando la carátula es 16:9 en vez de cuadrada, se
  dibuja como miniatura de vídeo con una insignia de cámara
- **Histograma de espectro** — anima mientras suena, se oculta al pausar

### Atajos de teclado

Dentro del panel:

| Tecla | Acción |
|-------|--------|
| `Espacio` / `Enter` | Reproducir / Pausar |
| `n` / `Derecha` | Siguiente canción |
| `p` / `Izquierda` | Canción anterior |
| `Arriba` / `Abajo` | Subir / bajar volumen |
| `s` | Alternar aleatorio |
| `r` | Cambiar repetición (off → lista → canción) |
| `t` | Cambiar el tema del equalizador (Auto → Cyberpunk → Minimalist) |
| `1`–`9` | Abrir el enlace rápido correspondiente |
| `Escape` | Cerrar el panel |
| `Tab` | Cambiar al panel adyacente |

Atajo global **opcional** — no se activa automáticamente; si quieres uno,
añádelo tú en `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + M", "Toggle ChispOmaMusic", "omarchy-shell io.github.mrchispa.chispomamusic toggle")
```

### Elegir la fuente

Ambas rutas hablan MPRIS — un navegador publica una sesión igual que un
cliente nativo. Lo que cambia es cuánto implementa cada uno:

| | App nativa | Navegador |
|---|---|---|
| Play/pausa, siguiente, anterior | sí | sí |
| Canción, artista, álbum, carátula | sí | sí |
| Buscar (seek) | sí | normalmente |
| Volumen | sí (MPRIS) | sí, vía su stream de PipeWire |
| Aleatorio / repetir | sí | no — el navegador no los expone |
| Necesita instalación | sí | no |

Los navegadores dejan el volumen fuera de su sesión MPRIS — y en los basados
en Chromium el volumen MPRIS es fijo e ignorado —, así que el slider de
volumen controla el stream de reproducción de PipeWire del reproductor, el
mismo mando que mueve un mezclador. Ese stream solo existe mientras fluye
audio, por lo que el slider aparece con la reproducción en vez de estar
siempre visible.

### Ajustes

Configurables desde los ajustes del widget en Omarchy, o directamente en la
entrada del widget en `~/.config/omarchy/shell.json` (settings planos):

| Ajuste | Por defecto | Qué hace |
|--------|-------------|----------|
| `neonTheme` | `Auto` | Tema del equalizador: `Auto`, `Cyberpunk` o `Minimalist` |
| `language` | `EN` | Idioma de la interfaz del panel: `EN` o `ES` |
| `playerSource` | `Auto` | `Auto`, `Native app` o `Browser` — dónde se controla la reproducción |
| `strictBrowserMatch` | `false` | Exige además una ventana abierta titulada *YouTube Music* (solo Hyprland) |
| `extraPlayerNames` | `""` | Identidades/entradas de escritorio MPRIS separadas por comas para tratar también como YouTube Music |
| `showVolume` | `true` | Mostrar el slider de volumen cuando se soporta |
| `scrollVolume` | `true` | Rueda sobre el icono de la barra para cambiar el volumen |
| `showVisualizer` | `true` | Dibujar el histograma de espectro en vivo mientras suena |
| `barVisualizer` | `true` | Mostrar el equalizador neón en la barra mientras suena |
| `neonColor` | `#00e5ff` | Color neón explícito; si se fija, gana sobre el accent en el tema Auto |
| `neonBarCount` | `10` | Número de barras del equalizador neón |
| `visualizerFallback` | `Idle animation` | Qué mostrar sin `cava`: una animación decorativa o nada |
| `launchCommand` | `""` | Comando del botón de play cuando está inactivo; vacío autodetecta |
| `quickLinks` | Me gusta, Biblioteca | Accesos directos a listas, como `Nombre|URL` separados por comas |
| `quickLinkBehavior` | `Focus if open` | Elevar una ventana existente de YouTube Music en vez de abrir una pestaña |

### Playlists y canciones con "Me gusta"

MPRIS define interfaces `Playlists` y `TrackList` para esto mismo, y los
navegadores no implementan ninguna — verificado llamando a ambas contra una
sesión real de Chromium, donde cada una falla. "Me gusta" no está en la
especificación MPRIS en ningún nivel. Así que el widget no puede leer tu
biblioteca ni alternar el pulgar arriba.

Lo que sí puede hacer es abrir una, porque una playlist de YouTube Music es
solo una URL. El panel muestra una fila de enlaces rápidos — *Liked songs* y
*Library* de serie — que abren en tu navegador predeterminado y empiezan a
reproducir. Se muestran también en reposo, que es cuando más útil es empezar
una playlist, y los nueve primeros están ligados a las teclas `1`–`9`.

Añade las tuyas editando `quickLinks`, con entradas `Nombre|URL` separadas
por comas. Copia la URL directamente de la barra de direcciones:

```
Liked songs|https://music.youtube.com/playlist?list=LM, Chill|https://music.youtube.com/playlist?list=PLxxxxxxxx
```

Las entradas sin una URL `http(s)` válida se ignoran en lugar de mostrarse
como botones que no hacen nada.

**Enfocar en vez de apilar pestañas.** Una pestaña del navegador no se puede
reutilizar desde fuera, así que abrir un enlace repetidamente amontonaría
duplicados. Con `quickLinkBehavior` en `Focus if open`, el widget primero
intenta elevar una ventana existente de YouTube Music y solo abre la URL si
no hay ninguna. La ventana se busca por títulos que *terminan* en "YouTube
Music", para no enfocar por error una página que solo menciona las palabras.
Como una ventana del navegador informa de su pestaña activa, una pestaña de
YouTube Music en segundo plano de otra ventana no se encuentra — el enlace
entonces se abre como siempre. Pon `Always open` para saltarte el intento de
enfoque y navegar siempre.

Esto navega la pestaña en lugar de encolar en el sitio. El control real de
playlists y "me gusta" dentro de la app necesitaría un cliente nativo que
exponga su propia API HTTP (pear-desktop, YTMDesktop) — posible añadirlo
más adelante, pero reintroduciría la dependencia de app que este plugin evita
deliberadamente.

### Notas y limitaciones

- **Seek** requiere que el reproductor lo soporte. Los clientes nativos sí;
  los navegadores suelen reportar posición pero no siempre buscar — la barra
  de progreso se atenúa cuando el seek no está disponible.
- **Volumen** usa MPRIS para clientes nativos y el stream de PipeWire para
  navegadores (el volumen MPRIS de Chromium es un no-op). La ruta del stream
  mueve la salida completa de la aplicación, así que con un navegador también
  afecta a otras pestañas que hagan sonido.
- **Aleatorio / repetir** solo aparecen cuando el reproductor anuncia soporte,
  así que las sesiones de navegador normalmente no muestran ninguno.
- **Me gusta / pulgar arriba** no se exponen por MPRIS y por tanto no están
  disponibles aquí.
- **El visualizador muestra el audio del sistema, no el reproductor.** `cava`
  lee el monitor del sink predeterminado, y Linux no da un espectro por
  aplicación sin capturar ese stream directamente. Si algo más hace ruido, lo
  verás. cava solo corre mientras el panel está abierto y hay reproducción
  activa (y en la barra, mientras suena con `barVisualizer`).
- **La detección de vídeo se infiere de la proporción de la carátula**
  (16:9 frente a cuadrada), no de una marca de metadatos — MPRIS no tiene
  ninguna. Acierta en los casos habituales y puede engañarse con carátulas
  inusuales.

### Actualizar

```bash
omarchy plugin update io.github.mrchispa.chispomamusic
```

### Desinstalar

```bash
omarchy plugin disable io.github.mrchispa.chispomamusic
omarchy plugin remove io.github.mrchispa.chispomamusic
```

Luego elimina la entrada de `~/.config/omarchy/shell.json`.

### Autor

Fork con equalizador neón y mejoras por **MrChispa** — original de Haripako
([@haripako](https://twitter.com/haripako)).

### Licencia

MIT — ver [LICENSE](LICENSE).

---

<a id="en"></a>
## 🇬🇧 English

Bar widget + popup panel for **YouTube Music** via MPRIS
(`Quickshell.Services.Mpris`), for the Omarchy bar.

No background service, no API keys, no persisted state — everything is read
live from the player's D-Bus interface. Click the icon in the bar to open a
popup with album art, track info, a seekable progress bar, shuffle/repeat,
playback controls, volume and a live spectrum histogram.

The plugin is **source-independent**: it never launches or requires any
particular app. Whatever is playing YouTube Music — a native client or a
browser tab — is what it controls.

Inspired by [omaspotify](https://github.com/cempack/omaspotify), rewritten for
YouTube Music. **Fork of [haripako/omamusic](https://github.com/haripako/omamusic)**
with a neon equalizer, themes, and browser volume fixes.

### Neon equalizer

This fork adds a **neon equalizer** to the bar: while music is playing, a row
of glowing bars powered by `cava` — the same source as the popup histogram —
sits right next to the icon. Clicking the icon still opens the menu as usual;
the equalizer is purely decorative and never intercepts clicks. The bars
reflect *system* audio, exactly like the popup visualizer.

### Themes

The look is set with the `neonTheme` setting — or click the small palette
button in the popup header to cycle it on the fly (keyboard: `t`):

- **Auto** (default) — follows the active theme accent, so the equalizer
  matches whatever theme you switch to. If you pin an explicit `neonColor` in
  `shell.json`, that wins over the accent.
- **Cyberpunk** — a multi-color neon palette (cyan, magenta, purple, green)
  with a strong glow.
- **Minimalist** — a soft neutral glow in the theme's foreground.

`neonBarCount` controls how many bars are drawn. Set `barVisualizer` to `false`
to hide the bar equalizer entirely (the popup histogram is unaffected).

When `cava` is not installed the equalizer does not go blank: by default it
shows a soft **idle animation** instead — clearly decorative, not
audio-reactive. Set `visualizerFallback` to `Nothing` to hide it completely.

### Requirements

- **Omarchy** (Quickshell-based desktop)
- A Nerd Font v3 (the icons use the Material Design range)
- A YouTube Music source that speaks MPRIS — either a native client or a
  browser tab, see below
- *Optional:* [`cava`](https://github.com/karlstav/cava) for the real spectrum
  histogram. Without it the idle animation is shown instead (see
  `visualizerFallback`).

### Which players work

**Native clients** are matched by MPRIS identity / desktop entry and always
win over browsers:

- [pear-desktop](https://github.com/pear-devs/pear-desktop) — formerly
  `th-ch/youtube-music`; both the old and new identities are matched
- [YTMDesktop](https://github.com/ytmdesktop/ytmdesktop)

Any other client can be added through the `extraPlayerNames` setting.

**Browser playback** on `music.youtube.com` (a normal tab or an installed PWA)
works through the browser's own MPRIS session, whichever browser you use:
Firefox, Chromium, Chrome, Brave, Vivaldi, Edge, Opera, Zen, LibreWolf,
Floorp, Waterfox, qutebrowser, Falkon, Epiphany and so on.

Forks are covered without needing to be listed by name: besides the identity,
the D-Bus name is checked, and browsers derive it from their engine
(`org.mpris.MediaPlayer2.firefox.*` for the Firefox family,
`.chromium` / `.chrome` / `.brave` for the Chromium family). The *Play* button
is browser-agnostic too — it opens the URL with `xdg-open`, so your default
browser is used, whatever it is.

There is a catch worth knowing. A browser publishes **one** MPRIS session for
whatever media is currently active, and Chromium's metadata is limited to
title, artist, album, artwork and length — there is no URL. Measured against a
live session, YouTube Music leaves `album` **empty**, exactly like a plain
YouTube video does, so the metadata cannot tell the two apart. The widget
therefore adopts any browser media session that reports an artist, and names
the source (`via Chromium`) so you always know what you are driving.

If that is too loose, turn on **Strict browser match**: it additionally
requires a window titled *YouTube Music* to be open, which the tab title does
expose. The trade-off is real — a browser window reports its *active* tab, so
switching that window to another tab while music plays in the background makes
the widget go idle. It is off by default for that reason, and it needs
Hyprland since it reads `hyprctl`.

If you only ever use a native client, set **Player source** to `Native app`
and the guessing stops entirely. Setting it to `Browser` does the opposite:
browser sessions only, and the play button always opens `music.youtube.com`
rather than launching an app.

When a browser session is being controlled, the panel appends `via <browser>`
under the track so it is never ambiguous which session you are driving.

### Install

```bash
omarchy plugin add https://github.com/MrChispa/chispomamusic.git
```

The plugin is **disabled by default** so you can read the code first:

```bash
omarchy plugin enable io.github.mrchispa.chispomamusic
```

Then add it to the bar — you'll be asked where to place it:

```bash
omarchy bar put io.github.mrchispa.chispomamusic
```

You can drag-and-drop it to reposition later, or edit
`~/.config/omarchy/shell.json` by hand.

### Usage

- **Panel language** — English by default. The **ES** button in the popup
  header switches to Spanish and back (persisted via the `language` setting).
- **Left click** — open/close the popup
- **Middle click** — play/pause without opening the popup, or start YouTube
  Music when nothing is playing
- **Nothing playing** — the popup offers a *Play on YouTube Music* button that
  launches the native client if it is installed, and otherwise opens
  `music.youtube.com` in your default browser. Override it with the
  `launchCommand` setting.
- **Scroll over the icon** — volume (when the player supports it)
- **In the popup** — shuffle, previous, play/pause, next, repeat; drag the
  progress bar to seek, drag the volume slider to set volume
- **Music videos** — when the artwork is 16:9 rather than square, the cover is
  drawn as a video thumbnail with a small camera badge
- **Spectrum histogram** — animates while playing, hidden when paused

### Keyboard shortcuts

Inside the popup:

| Key | Action |
|-----|--------|
| `Space` / `Enter` | Play / Pause |
| `n` / `Right` | Next track |
| `p` / `Left` | Previous track |
| `Up` / `Down` | Volume up / down |
| `s` | Toggle shuffle |
| `r` | Cycle repeat (off → playlist → track) |
| `t` | Cycle the equalizer theme (Auto → Cyberpunk → Minimalist) |
| `1`–`9` | Open the matching quick link |
| `Escape` | Close popup |
| `Tab` | Switch to adjacent panel |

Optional global keybinding — not enabled automatically; if you want one, add
it yourself in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + M", "Toggle ChispOmaMusic", "omarchy-shell io.github.mrchispa.chispomamusic toggle")
```

### Choosing a source

Both routes speak MPRIS — a browser publishes a session exactly like a native
client does. What differs is how much of the interface each one implements:

| | Native app | Browser |
|---|---|---|
| Play/pause, next, previous | yes | yes |
| Track, artist, album, artwork | yes | yes |
| Seeking | yes | usually |
| Volume | yes (MPRIS) | yes, via its PipeWire stream |
| Shuffle / repeat | yes | no — the browser does not expose them |
| Needs an install | yes | no |

Browsers leave volume out of their MPRIS session — and Chromium-based ones
report a fixed, ignored MPRIS volume — so the volume slider drives the
player's PipeWire playback stream instead, the same knob a mixer moves. That
stream only exists while audio is flowing, so the slider appears with
playback rather than being permanently visible.

### Settings

Configurable from the widget's settings in Omarchy, or directly in the
widget's entry in `~/.config/omarchy/shell.json` (flat settings):

| Setting | Default | What it does |
|---------|---------|--------------|
| `neonTheme` | `Auto` | Equalizer theme: `Auto`, `Cyberpunk` or `Minimalist` |
| `language` | `EN` | Panel UI language: `EN` or `ES` |
| `playerSource` | `Auto` | `Auto`, `Native app` or `Browser` — where playback is controlled |
| `strictBrowserMatch` | `false` | Also require an open window titled *YouTube Music* (Hyprland only) |
| `extraPlayerNames` | `""` | Comma-separated MPRIS identities/desktop entries to also treat as YouTube Music |
| `showVolume` | `true` | Show the volume slider when supported |
| `scrollVolume` | `true` | Scroll over the bar icon to change volume |
| `showVisualizer` | `true` | Draw the live spectrum histogram while playing |
| `barVisualizer` | `true` | Show the neon equalizer in the bar while playing |
| `neonColor` | `#00e5ff` | Explicit neon color; when pinned it wins over the accent in Auto |
| `neonBarCount` | `10` | Number of bars in the neon equalizer |
| `visualizerFallback` | `Idle animation` | What to show without `cava`: a decorative animation or nothing |
| `launchCommand` | `""` | Command for the play button when idle; empty auto-detects |
| `quickLinks` | Liked songs, Library | Playlist shortcuts, as `Name|URL` separated by commas |
| `quickLinkBehavior` | `Focus if open` | Raise an existing YouTube Music window instead of opening a tab |

### Playlists and Liked songs

MPRIS defines `Playlists` and `TrackList` interfaces for exactly this, and
browsers implement neither — verified by calling both against a live Chromium
session, where each one fails. "Liked" is not in the MPRIS spec at any level.
So the widget cannot read your library or toggle a thumbs-up.

What it can do is open one, because a YouTube Music playlist is just a URL.
The popup shows a row of quick links — *Liked songs* and *Library* out of the
box — which open in your default browser and start playing. They are shown
while idle too, which is when starting a playlist is most useful, and the
first nine are bound to keys `1`–`9`.

Add your own by editing `quickLinks`, using `Name|URL` entries separated by
commas. Copy the URL straight from the address bar:

```
Liked songs|https://music.youtube.com/playlist?list=LM, Chill|https://music.youtube.com/playlist?list=PLxxxxxxxx
```

Entries without a valid `http(s)` URL are ignored rather than rendered as
buttons that do nothing.

**Focus instead of stacking tabs.** A browser tab cannot be reused from
outside, so opening a link repeatedly would pile up duplicates. With
`quickLinkBehavior` left at `Focus if open`, the widget first tries to raise
an existing YouTube Music window and only opens the URL when there is none.
The window is matched on titles *ending* in "YouTube Music", so a page merely
mentioning the words is not focused by mistake. Since a browser window reports
its active tab, a YouTube Music tab sitting in the background of another
window cannot be found — the link then opens as before. Set `Always open` to
skip the focus attempt and navigate every time.

This navigates the tab rather than queueing in place. True in-app playlist and
like control would need a native client that exposes its own HTTP API
(pear-desktop, YTMDesktop) — possible to add later, but it would reintroduce
the app dependency this plugin deliberately avoids.

### Notes and limitations

- **Seeking** requires the player to support it. Native clients do; browsers
  usually report position but not always seek — the progress bar dims when
  seeking is unavailable.
- **Volume** uses MPRIS for native clients and the player's PipeWire stream
  for browsers (Chromium's MPRIS volume is a no-op). The stream route moves
  the whole application's output, so with a browser it also affects other
  tabs making sound.
- **Shuffle / repeat** buttons only appear when the player advertises support,
  so browser sessions typically show neither.
- **Likes / thumbs up** are not exposed over MPRIS and are therefore not
  available here.
- **The visualizer shows system audio, not the player.** `cava` reads the
  default sink monitor, and Linux gives no per-application spectrum without
  capturing that stream directly. If something else is making noise, you will
  see it. cava only runs while the popup is open and playback is active (and
  in the bar, while playing with `barVisualizer`).
- **Video detection is inferred from the artwork ratio** (16:9 vs square), not
  from a metadata flag — MPRIS has none. It is right for the usual cases and
  can be fooled by unusual artwork.

### Update

```bash
omarchy plugin update io.github.mrchispa.chispomamusic
```

### Uninstall

```bash
omarchy plugin disable io.github.mrchispa.chispomamusic
omarchy plugin remove io.github.mrchispa.chispomamusic
```

Then remove the entry from `~/.config/omarchy/shell.json`.

### Author

Fork with neon equalizer and improvements by **MrChispa** — original by
Haripako ([@haripako](https://twitter.com/haripako)).

### License

MIT — see [LICENSE](LICENSE).