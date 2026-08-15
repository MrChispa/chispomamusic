import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.haripako.omamusic"
  ipcTarget: "io.github.haripako.omamusic"

  readonly property bool browserFallback: root.setting("browserFallback", true)
  readonly property bool strictBrowserMatch: root.setting("strictBrowserMatch", true)
  readonly property string extraPlayerNames: root.setting("extraPlayerNames", "")
  readonly property bool showVolume: root.setting("showVolume", true)
  readonly property bool scrollVolume: root.setting("scrollVolume", true)

  property var player: Model.selectPlayer(Mpris.players.values, {
    browserFallback: root.browserFallback,
    strictBrowserMatch: root.strictBrowserMatch,
    extraPlayerNames: root.extraPlayerNames
  })

  readonly property bool playing: player ? player.isPlaying : false
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property string trackTitle: player ? (player.trackTitle || "Untitled track") : ""
  readonly property string artistName: player ? (player.trackArtist || "") : ""
  readonly property string albumName: player ? (player.trackAlbum || "") : ""
  readonly property string sourceLabel: Model.sourceLabel(player, root.extraPlayerNames)
  readonly property bool canSeek: player ? (player.canSeek && player.positionSupported && player.length > 0) : false
  readonly property bool hasVolume: player ? (root.showVolume && player.volumeSupported) : false

  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property color dimForeground: Qt.darker(contentForeground, 1.45)
  readonly property color subtleFill: Style.normalFillFor(contentForeground, Color.accent)
  readonly property color subtleBorder: Style.normalBorderFor(contentForeground, Color.accent)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // MPRIS only pushes position on seek, so poll while playing to keep the
  // progress bar moving.
  Timer {
    interval: 1000
    running: root.playing && root.opened
    repeat: true
    onTriggered: if (root.player) root.player.positionChanged()
  }

  function nudgeVolume(delta) {
    if (!root.player || !root.player.volumeSupported) return
    root.player.volume = Math.max(0, Math.min(1, root.player.volume + delta))
  }

  function cycleLoop() {
    if (!root.player || !root.player.loopSupported) return
    if (root.player.loopState === MprisLoopState.None) root.player.loopState = MprisLoopState.Playlist
    else if (root.player.loopState === MprisLoopState.Playlist) root.player.loopState = MprisLoopState.Track
    else root.player.loopState = MprisLoopState.None
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\udb81\uddc3"
    active: false
    useActiveColor: false
    foreground: root.playing ? root.contentForeground : Qt.darker(root.contentForeground, 1.9)
    tooltipText: root.player
      ? (root.trackTitle + (root.artistName ? " — " + root.artistName : ""))
      : "YouTube Music"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton && root.player) root.player.togglePlaying()
      else root.toggle()
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
      onActivateRequested: if (root.player) root.player.togglePlaying()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.player) return
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

        Row {
          visible: root.player !== null
          width: parent.width
          spacing: Style.space(12)

          Rectangle {
            id: cover
            width: Style.space(92)
            height: width
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
              anchors.fill: parent
              visible: root.artUrl !== "" && status !== Image.Error
              source: root.artUrl
              sourceSize.width: Style.space(220)
              sourceSize.height: Style.space(220)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
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
              text: root.albumName !== "" ? root.albumName : root.sourceLabel
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }
        }

        Row {
          visible: root.player === null
          width: parent.width
          height: Style.space(38)
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
            text: "YouTube Music is idle"
            color: root.dimForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }
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
            text: root.player && root.player.volume <= 0.001 ? "" : ""
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
            value: root.player ? root.player.volume : 0
            trackHeight: Math.max(3, Style.space(3))
            knobSize: Style.space(9)
            onMoved: function(nextVolume) {
              if (root.player) root.player.volume = nextVolume
            }
          }
        }
      }
    }
  }
}
