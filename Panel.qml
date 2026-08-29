import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.haripako.omamusic"
  ipcTarget: "io.github.haripako.omamusic"

  readonly property string playerSource: root.setting("playerSource", "Auto")
  readonly property bool strictBrowserMatch: root.setting("strictBrowserMatch", false)
  readonly property string extraPlayerNames: root.setting("extraPlayerNames", "")
  readonly property bool showVolume: root.setting("showVolume", true)
  readonly property bool scrollVolume: root.setting("scrollVolume", true)
  readonly property bool showVisualizer: root.setting("showVisualizer", true)
  readonly property string launchCommand: root.setting("launchCommand", "")
  readonly property string quickLinks: root.setting("quickLinks",
    "Liked songs|https://music.youtube.com/playlist?list=LM, Library|https://music.youtube.com/library")
  readonly property var quickLinkList: Model.parseQuickLinks(root.quickLinks)
  readonly property string quickLinkBehavior: root.setting("quickLinkBehavior", "Focus if open")
  readonly property bool focusFirst: String(root.quickLinkBehavior).toLowerCase().indexOf("always") === -1

  // Neon equalizer settings.
  readonly property bool barVisualizer: root.setting("barVisualizer", true)
  readonly property color neonColor: root.setting("neonColor", "#00e5ff")
  readonly property int neonBarCount: root.setting("neonBarCount", 10)
  readonly property string visualizerFallback: root.setting("visualizerFallback", "Idle animation")
  readonly property string neonTheme: root.setting("neonTheme", "Auto")

  // Equalizer theme resolution. Auto follows the active theme accent;
  // Cyberpunk uses a multi-color neon palette with a strong glow; Minimalist
  // uses a soft neutral glow.
  readonly property string neonThemeKey: String(root.neonTheme).toLowerCase()
  readonly property bool cyberpunkTheme: root.neonThemeKey.indexOf("cyber") !== -1
  readonly property bool minimalTheme: root.neonThemeKey.indexOf("minimal") !== -1

  // Auto follows the active theme accent — unless the user pinned an explicit
  // neonColor in shell.json, in which case that wins.
  readonly property color autoNeon: root.setting("neonColor", "") === ""
    ? Color.accent
    : root.neonColor
  readonly property color minimalNeon: Qt.lighter(Color.foreground, 1.2)
  readonly property color effectiveNeon: root.minimalTheme
    ? root.minimalNeon
    : root.autoNeon

  readonly property var cyberPalette: [
    "#00e5ff", "#7df9ff", "#ff2d95", "#a855f7", "#00ffd5",
    "#ff9d00", "#4d7cfe", "#ff4dd8", "#39ff14", "#00e5ff"
  ]
  readonly property var effectivePalette: root.cyberpunkTheme ? root.cyberPalette : []
  readonly property real effectiveGlow: root.cyberpunkTheme
    ? 1.0
    : (root.minimalTheme ? 0.18 : 0.65)

  // Raises an existing YouTube Music window instead of piling up duplicate
  // tabs. The title must *end* with "YouTube Music" so a page merely
  // mentioning it does not get focused. Prints "ok" when a window matched,
  // which is what lets the caller fall back to opening the URL.
  readonly property string focusCommand:
    "hyprctl dispatch 'hl.dsp.focus({ window = \"title:^(.*YouTube Music( [-\u2014|].*)?)$\" })' 2>/dev/null | grep -q '^ok'"

  property var player: Model.selectPlayer(Mpris.players.values, {
    playerSource: root.playerSource,
    titleOk: root.strictBrowserMatch ? windowTitles.matched : true,
    extraPlayerNames: root.extraPlayerNames
  })

  WindowTitles {
    id: windowTitles
    enabled: root.strictBrowserMatch
  }

  readonly property bool playing: player ? player.isPlaying : false
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property string trackTitle: player ? (player.trackTitle || "Untitled track") : ""
  readonly property string artistName: player ? (player.trackArtist || "") : ""
  readonly property string albumName: player ? (player.trackAlbum || "") : ""
  readonly property string sourceLabel: Model.sourceLabel(player, root.extraPlayerNames)
  readonly property bool canSeek: player ? (player.canSeek && player.positionSupported && player.length > 0) : false
  // Prefer the player's own volume; fall back to its PipeWire stream so the
  // browser route gets a working slider instead of no slider at all.
  //
  // Chromium-based browsers advertise volumeSupported and report a fixed
  // MPRIS Volume (always 1.0), but writes to it are a no-op — the real audio
  // level lives on the player's PipeWire stream. So MPRIS volume is only
  // trusted for native clients; browsers always drive the stream.
  readonly property bool mprisVolume: player
    ? player.volumeSupported && Model.isNative(player, Model.parseNames(root.extraPlayerNames))
    : false
  readonly property bool hasVolume: player !== null && root.showVolume
    && (root.mprisVolume || streamVolume.available)
  readonly property real currentVolume: root.mprisVolume
    ? (player ? player.volume : 0)
    : streamVolume.volume

  // Wider-than-tall artwork means a music video rather than a song.
  readonly property bool isVideo: albumArt.status === Image.Ready
    && albumArt.implicitHeight > 0
    && (albumArt.implicitWidth / albumArt.implicitHeight) > 1.25

  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property color dimForeground: Qt.darker(contentForeground, 1.45)
  readonly property color subtleFill: Style.normalFillFor(contentForeground, Color.accent)
  readonly property color subtleBorder: Style.normalBorderFor(contentForeground, Color.accent)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // Shared spectrum source driving both the bar equalizer and the popup
  // histogram. Active whenever playback is live and either visualizer wants
  // data; Spectrum itself decides between real cava and the idle fallback.
  //
  // Declared BEFORE showBarVisualizer: QML property bindings that reference an
  // id created later in the same component evaluate against a not-yet-existing
  // object during construction and die, leaving the property permanently false
  // (the bar slot then never grows to include the equalizer).
  Spectrum {
    id: spectrum
    active: root.playing && (root.barVisualizer || (root.showVisualizer && root.opened))
    barCount: root.neonBarCount
    useCavaFallback: String(root.visualizerFallback).toLowerCase().indexOf("idle") !== -1
  }

  // The bar equalizer shows whenever playback is live and the setting is on;
  // Spectrum owns the data, so "has signal" is the source's verdict.
  readonly property bool showBarVisualizer: root.playing && root.barVisualizer && spectrum.hasSignal

  implicitWidth: root.showBarVisualizer
    ? button.implicitWidth + barVisualizerRow.implicitWidth
    : button.implicitWidth
  implicitHeight: button.implicitHeight

  // MPRIS only pushes position on seek, so poll while playing to keep the
  // progress bar moving.
  Timer {
    interval: 1000
    running: root.playing && root.opened
    repeat: true
    onTriggered: if (root.player) root.player.positionChanged()
  }

  function setVolume(value) {
    var next = Math.max(0, Math.min(1, value))
    if (root.mprisVolume) root.player.volume = next
    else streamVolume.setVolume(next)
  }

  function nudgeVolume(delta) {
    if (!root.hasVolume) return
    root.setVolume(root.currentVolume + delta)
  }

  StreamVolume {
    id: streamVolume
    appHint: root.player ? root.player.identity : ""
  }

  // MPRIS can only talk to a player that already exists, so starting from an
  // idle bar means launching one: the native client when it is installed,
  // otherwise music.youtube.com in the default browser.
  function launchPlayer() {
    var command = root.launchCommand
    if (command === "") {
      var openBrowser = "exec xdg-open https://music.youtube.com"
      // Forcing the browser source and then launching a native app would
      // start something the widget has been told to ignore.
      if (Model.normalizeSource(root.playerSource) === "browser") {
        command = openBrowser
      } else {
        command = "if command -v youtube-music >/dev/null 2>&1; then exec youtube-music; " +
          "elif command -v pear-desktop >/dev/null 2>&1; then exec pear-desktop; " +
          "else " + openBrowser + "; fi"
      }
    }
    Util.execDetached(root.focusFirst ? (root.focusCommand + " || { " + command + " ; }") : command)
  }

  function openQuickLink(url) {
    var open = "exec xdg-open " + Util.shellQuote(url)
    // Focusing wins over navigating when YouTube Music is already up: the
    // tab cannot be reused, so opening one would just accumulate duplicates.
    Util.execDetached(root.focusFirst ? (root.focusCommand + " || " + open) : open)
    root.close()
  }

  function openHome() {
    // Focus an existing YouTube Music window, then fall back to opening the
    // site — the same focus-first pattern the quick links use.
    var open = "exec xdg-open https://music.youtube.com"
    Util.execDetached(root.focusFirst ? (root.focusCommand + " || " + open) : open)
    root.close()
  }

  function cycleLoop() {
    if (!root.player || !root.player.loopSupported) return
    if (root.player.loopState === MprisLoopState.None) root.player.loopState = MprisLoopState.Playlist
    else if (root.player.loopState === MprisLoopState.Playlist) root.player.loopState = MprisLoopState.Track
    else root.player.loopState = MprisLoopState.None
  }

  BarIconButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    bar: root.bar
    text: "\udb81\uddc3"
    active: false
    useActiveColor: false
    foreground: root.playing ? root.contentForeground : Qt.darker(root.contentForeground, 1.9)
    tooltipText: root.player
      ? (root.trackTitle + (root.artistName ? " — " + root.artistName : ""))
      : "YouTube Music"

    onPressed: function(buttonCode) {
      if (buttonCode !== Qt.MiddleButton) root.toggle()
      else if (root.player) root.player.togglePlaying()
      else root.launchPlayer()
    }

    // Wheel-over-icon volume. Transparent to clicks and hover so the button
    // keeps its own press and tooltip behaviour.
    MouseArea {
      anchors.fill: parent
      enabled: root.scrollVolume && root.hasVolume
      acceptedButtons: Qt.NoButton
      hoverEnabled: false
      onWheel: function(wheel) {
        root.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        wheel.accepted = true
      }
    }
  }

  // Neon equalizer beside the icon. Pure rendering and click-through: it has
  // no MouseArea of its own, so the button above remains the click target for
  // the popup and no input ever reaches the bars.
  BarVisualizer {
    id: barVisualizerRow
    anchors.left: button.right
    anchors.leftMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    visible: root.showBarVisualizer
    levels: spectrum.levels
    neon: root.effectiveNeon
    colors: root.effectivePalette
    glowStrength: root.effectiveGlow
    barCount: root.neonBarCount
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.player ? 352 : 244))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.nudgeVolume(dy < 0 ? 0.05 : -0.05)
        else if (dx > 0 && root.player && root.player.canGoNext) root.player.next()
        else if (dx < 0 && root.player && root.player.canGoPrevious) root.player.previous()
      }
      onActivateRequested: {
        if (root.player) root.player.togglePlaying()
        else { root.launchPlayer(); root.close() }
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        // Quick links work with or without playback — starting a playlist is
        // most useful precisely when nothing is playing yet.
        if (text >= "1" && text <= "9") {
          var slot = parseInt(text, 10) - 1
          if (slot < root.quickLinkList.length) {
            root.openQuickLink(root.quickLinkList[slot].url)
            return
          }
        }

        if (!root.player) {
          if (text === " ") { root.launchPlayer(); root.close() }
          return
        }
        if (text === " ") root.player.togglePlaying()
        else if (text === "n" && root.player.canGoNext) root.player.next()
        else if (text === "p" && root.player.canGoPrevious) root.player.previous()
        else if (text === "s" && root.player.shuffleSupported) root.player.shuffle = !root.player.shuffle
        else if (text === "r") root.cycleLoop()
      }

      Column {
        id: contentColumn
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)

        RowLayout {
          visible: root.player !== null
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            id: nowPlayingDot
            Layout.alignment: Qt.AlignVCenter
            width: 6
            height: 6
            radius: 3
            color: root.effectiveNeon
            layer.enabled: true
            layer.samples: 4
            layer.effect: MultiEffect {
              blurEnabled: true
              blur: 1.0
              blurMax: 24
            }
          }

          Text {
            Layout.alignment: Qt.AlignVCenter
            text: "NOW PLAYING · YOUTUBE MUSIC"
            color: root.dimForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          Item { Layout.fillWidth: true }

          Text {
            Layout.alignment: Qt.AlignVCenter
            visible: root.sourceLabel !== ""
            text: root.sourceLabel
            color: root.dimForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          PanelActionButton {
            Layout.alignment: Qt.AlignVCenter
            iconText: "\uf08e"
            tooltipText: "Open YouTube Music"
            foreground: root.dimForeground
            hoverColor: root.effectiveNeon
            fontFamily: root.contentFontFamily
            fontSize: Style.font.caption
            size: Style.space(22)
            bordered: false
            onClicked: root.openHome()
          }
        }

        Row {
          visible: root.player !== null
          width: parent.width
          spacing: Style.space(12)

          Rectangle {
            id: cover
            // Songs carry square art, music videos carry 16:9 thumbnails, so
            // the artwork's own aspect ratio is what tells the two apart.
            width: Style.space(root.isVideo ? 124 : 92)
            height: root.isVideo ? Math.round(width * 9 / 16) : width
            radius: Style.cornerRadius
            color: root.subtleFill
            border.width: Math.max(1, Style.space(1))
            border.color: root.subtleBorder
            clip: true

            Text {
              anchors.centerIn: parent
              text: "\udb81\uddc3"
              color: Color.accent
              opacity: 0.42
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.displayLarge
            }

            Image {
              id: albumArt
              anchors.fill: parent
              visible: root.artUrl !== "" && status !== Image.Error
              source: root.artUrl
              // Width only: constraining both axes would flatten the ratio we
              // need in order to recognise a video thumbnail.
              sourceSize.width: Style.space(320)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
            }

            Rectangle {
              visible: root.isVideo
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: Math.max(2, Style.space(4))
              width: badge.implicitWidth + Style.space(8)
              height: badge.implicitHeight + Style.space(4)
              radius: height / 2
              color: Qt.rgba(0, 0, 0, 0.62)

              Text {
                id: badge
                anchors.centerIn: parent
                text: "\udb81\udd67"
                color: "white"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          Column {
            width: parent.width - cover.width - parent.spacing
            anchors.verticalCenter: cover.verticalCenter
            spacing: Style.space(4)

            Text {
              width: parent.width
              text: root.trackTitle
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              wrapMode: Text.Wrap
              elide: Text.ElideRight
              maximumLineCount: 2
            }

            Text {
              width: parent.width
              text: root.artistName || "YouTube Music"
              color: root.contentForeground
              opacity: 0.82
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              visible: root.albumName !== "" || root.sourceLabel !== ""
              width: parent.width
              // Keep the source visible even when an album is present: which
              // session is being driven should never be a guess.
              text: root.albumName !== "" && root.sourceLabel !== ""
                ? root.albumName + " · " + root.sourceLabel
                : (root.albumName !== "" ? root.albumName : root.sourceLabel)
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }
        }

        Column {
          visible: root.player === null
          width: parent.width
          spacing: Style.space(10)

          Row {
            width: parent.width
            height: Style.space(24)
            spacing: Style.space(10)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\udb81\uddc3"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.icon
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Nothing playing"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
          }

          Button {
            width: parent.width
            bordered: true
            iconText: "\uf04b"
            text: "Play on YouTube Music"
            tooltipText: "Launch the native client, or open music.youtube.com"
            foreground: root.contentForeground
            accent: Color.accent
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              root.launchPlayer()
              root.close()
            }
          }
        }

        Visualizer {
          width: parent.width
          visible: root.showVisualizer && spectrum.levels.length > 0
          levels: spectrum.levels
          neon: root.effectiveNeon
          colors: root.effectivePalette
          glowStrength: root.effectiveGlow
        }

        Column {
          visible: root.player !== null
          width: parent.width
          spacing: Style.space(2)

          PanelSlider {
            id: progressSlider
            width: parent.width
            bar: root.bar
            enabled: root.canSeek
            opacity: root.canSeek ? 1 : 0.45
            minimum: 0
            maximum: root.player ? Math.max(1, root.player.length) : 1
            value: root.player ? root.player.position : 0
            step: 5
            trackHeight: Math.max(3, Style.space(3))
            knobSize: Style.space(10)
            onReleased: function(nextPosition) {
              if (root.canSeek) root.player.position = nextPosition
            }
          }

          RowLayout {
            width: parent.width

            Text {
              text: root.player ? Model.formatTime(progressSlider.dragging ? progressSlider.liveValue : root.player.position) : "0:00"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.player ? Model.formatTime(root.player.length) : "0:00"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Item {
          visible: root.player !== null
          width: parent.width
          height: Style.space(34)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(12)

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.player && root.player.shuffleSupported
              iconText: "\udb81\udc9d"
              tooltipText: root.player && root.player.shuffle ? "Shuffle on" : "Shuffle off"
              foreground: root.player && root.player.shuffle ? Color.accent : root.dimForeground
              hoverColor: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              size: Style.space(24)
              bordered: false
              onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: ""
              tooltipText: "Previous track"
              foreground: root.contentForeground
              hoverColor: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.body
              size: Style.space(28)
              bordered: false
              enabled: root.player && root.player.canGoPrevious
              onClicked: if (root.player) root.player.previous()
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.playing ? "" : ""
              tooltipText: root.playing ? "Pause" : "Play"
              foreground: Color.accent
              hoverColor: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.iconLarge
              size: Style.space(34)
              bordered: false
              enabled: root.player && (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause || root.player.canControl)
              onClicked: if (root.player) root.player.togglePlaying()
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: ""
              tooltipText: "Next track"
              foreground: root.contentForeground
              hoverColor: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.body
              size: Style.space(28)
              bordered: false
              enabled: root.player && root.player.canGoNext
              onClicked: if (root.player) root.player.next()
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.player && root.player.loopSupported
              iconText: root.player && root.player.loopState === MprisLoopState.Track ? "\udb81\udc58" : "\udb81\udc56"
              tooltipText: {
                if (!root.player) return "Repeat"
                if (root.player.loopState === MprisLoopState.Track) return "Repeat track"
                if (root.player.loopState === MprisLoopState.Playlist) return "Repeat playlist"
                return "Repeat off"
              }
              foreground: root.player && root.player.loopState !== MprisLoopState.None ? Color.accent : root.dimForeground
              hoverColor: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              size: Style.space(24)
              bordered: false
              onClicked: root.cycleLoop()
            }
          }
        }

        Row {
          visible: root.player !== null && root.hasVolume
          width: parent.width
          spacing: Style.space(8)

          Text {
            id: volumeIcon
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentVolume <= 0.001 ? "" : ""
            color: root.dimForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - volumeIcon.width - parent.spacing
            bar: root.bar
            minimum: 0
            maximum: 1
            step: 0.05
            value: root.currentVolume
            trackHeight: Math.max(3, Style.space(3))
            knobSize: Style.space(9)
            onMoved: function(nextVolume) {
              root.setVolume(nextVolume)
            }
          }
        }

        // MPRIS cannot switch playlists or read "liked" state, but a YouTube
        // Music playlist is a URL — so these open one directly. Shown while
        // idle as well, which is exactly when starting a playlist is useful.
        // Equal-width cells spanning the full panel, so the row shares the
        // edges of the progress and volume sliders instead of leaving a
        // ragged gap, and sits on the same axis as the transport controls.
        Grid {
          id: quickLinkGrid
          visible: root.quickLinkList.length > 0
          width: parent.width
          spacing: Style.space(6)
          columns: root.quickLinkList.length === 1
            ? 1
            : (root.quickLinkList.length % 3 === 0 ? 3 : 2)

          readonly property real cellWidth:
            (width - spacing * (columns - 1)) / columns

          Repeater {
            model: root.quickLinkList

            Button {
              required property var modelData
              required property int index

              width: quickLinkGrid.cellWidth
              bordered: true
              text: modelData.name
              tooltipText: root.quickLinkList.length <= 9 && index < 9
                ? "Open in your browser (" + (index + 1) + ")"
                : "Open in your browser"
              foreground: root.contentForeground
              accent: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              onClicked: root.openQuickLink(modelData.url)
            }
          }
        }
      }
    }
  }
}