import QtQuick
import QtQuick.Effects
import qs.Commons

// Compact neon equalizer row for the bar widget. Pure rendering: `levels`
// comes from Spectrum, and it never touches mouse input — it has no MouseArea
// of its own, so the bar icon keeps its press/tooltip/wheel behaviour.
//
// Theming: pass a single `neon` color, or a `colors` palette (one entry per
// bar, cycled) for multi-color looks like Cyberpunk. `glowStrength` (0..1)
// scales the glow so Minimalist can keep the bars crisp and quiet.
Item {
  id: root

  property var levels: []
  property color neon: Color.accent
  property var colors: []
  property real glowStrength: 1.0
  property int barCount: 9
  property int barSpacing: Style.space(2)
  property real minBarHeight: Math.max(2, Style.space(2))

  readonly property bool hasSignal: levels.length > 0
  readonly property real barWidth: Style.space(3)
  readonly property real rowWidth: root.barCount > 0
    ? root.barCount * root.barWidth + root.barSpacing * (root.barCount - 1)
    : 0

  function barColor(index) {
    if (root.colors && root.colors.length > 0) return root.colors[index % root.colors.length]
    return root.neon
  }

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
      opacity: 0.10 * root.glowStrength
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
          readonly property real coreHeight: Math.max(root.minBarHeight, level * root.implicitHeight)
          readonly property color barColor: root.barColor(index)

          // Glow layer behind the core bar.
          Rectangle {
            id: glow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.barWidth * 2.2
            height: Math.max(root.minBarHeight, coreHeight * 1.5)
            radius: width / 2
            color: barColor
            opacity: 0.28 * root.glowStrength
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

          // Core bar with a vertical gradient of its assigned color.
          Rectangle {
            id: core
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.barWidth
            height: coreHeight
            radius: width / 2
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.lighter(barColor, 1.35) }
              GradientStop { position: 1.0; color: Qt.darker(barColor, 1.6) }
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