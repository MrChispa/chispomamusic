import QtQuick
import QtQuick.Effects
import qs.Commons

// Compact neon equalizer row for the bar widget. Pure rendering: `levels`
// comes from Spectrum, and it never touches mouse input — the parent sets
// `enabled: false` so it stays fully click-through and the bar icon keeps its
// own press/tooltip/wheel behaviour.
Item {
  id: root

  property var levels: []
  property color neon: Color.accent
  property int barCount: 9
  property int barSpacing: Style.space(2)
  property real minBarHeight: Math.max(2, Style.space(2))

  readonly property bool hasSignal: levels.length > 0
  readonly property real barWidth: Style.space(3)
  readonly property real rowWidth: root.barCount > 0
    ? root.barCount * root.barWidth + root.barSpacing * (root.barCount - 1)
    : 0

  visible: hasSignal
  implicitWidth: root.rowWidth + Style.space(8)
  implicitHeight: Style.space(14)

  Item {
    id: content
    visible: root.hasSignal
    anchors.centerIn: parent
    width: root.rowWidth
    height: root.implicitHeight

    // Soft neon halo behind the whole row, so the widget itself glows.
    Rectangle {
      id: halo
      anchors.centerIn: parent
      width: parent.width + Style.space(10)
      height: parent.height + Style.space(8)
      radius: height / 2
      color: root.neon
      opacity: 0.10
      layer.enabled: true
      layer.samples: 4
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 64
      }
    }

    Row {
      id: barRow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      spacing: root.barSpacing

      Repeater {
        model: root.barCount

        Item {
          required property int index
          width: root.barWidth
          height: root.implicitHeight

          readonly property real level: index < root.levels.length ? (root.levels[index] || 0) : 0
          readonly property real coreHeight: Math.max(root.minBarHeight, root.level * root.implicitHeight)

          // Glow layer behind the core bar.
          Rectangle {
            id: glow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.barWidth * 2.2
            height: Math.max(root.minBarHeight, root.coreHeight * 1.5)
            radius: width / 2
            color: root.neon
            opacity: 0.28
            layer.enabled: true
            layer.samples: 4
            layer.effect: MultiEffect {
              blurEnabled: true
              blur: 1.0
              blurMax: 64
            }

            Behavior on height {
              NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }
          }

          // Core bar with a vertical neon gradient.
          Rectangle {
            id: core
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.barWidth
            height: root.coreHeight
            radius: width / 2
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.lighter(root.neon, 1.35) }
              GradientStop { position: 1.0; color: Qt.darker(root.neon, 1.6) }
            }

            Behavior on height {
              NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }
          }
        }
      }
    }
  }
}