import QtQuick
import qs.Ui

// Flexible blank space that centers its neighbour in the empty gap between
// two bar sections. Place it next to the widget to center, on the side that
// faces the gap's far end:
//   left section:            ... gap, widget       (gap to the center section)
//   center, after the clock:  ... gap, widget      (gap to the right section)
//   center, before the clock: widget, gap ...      (gap to the left section)
//   right section:            widget, gap ...      (gap to the center section)
// Measures the live bar on its own monitor, so it follows screen width and
// title length changes.
BarWidget {
  id: root

  property int gap: 0

  implicitWidth: vertical ? barSize : gap
  implicitHeight: vertical ? 0 : barSize

  Behavior on gap {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
  }

  function isSlot(item) {
    return item && item.entry !== undefined && item.region !== undefined && item.activeItem !== undefined
  }

  // The bar host's per-widget slot that holds this widget.
  function findSlot() {
    for (var p = root.parent; p; p = p.parent)
      if (isSlot(p)) return p
    return null
  }

  // The item holding all three sections: the ancestor with a child that is
  // the center section (the only one carrying anchorEntry).
  function findBarRoot(from) {
    for (var p = from; p; p = p.parent) {
      var kids = p.children || []
      for (var i = 0; i < kids.length; i++)
        if (kids[i] && kids[i].anchorEntry !== undefined) return p
    }
    return null
  }

  // Scene-space horizontal extent of every visible widget, per section.
  function collect(item, acc) {
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i]
      if (!k || !k.visible) continue
      if (isSlot(k)) {
        if (k.width <= 0 || !acc[k.region]) continue
        var p = k.mapToItem(null, 0, 0)
        acc[k.region].min = Math.min(acc[k.region].min, p.x)
        acc[k.region].max = Math.max(acc[k.region].max, p.x + k.width)
      } else {
        collect(k, acc)
      }
    }
    return acc
  }

  function recompute() {
    if (vertical) { gap = 0; return }
    var slot = findSlot()
    var barRoot = slot ? findBarRoot(slot.parent) : null
    var window = root.Window.window
    if (!slot || !barRoot || !window) { gap = 0; return }

    var me = slot.mapToItem(null, 0, 0)
    var mid = window.width / 2
    // Rows in the left section and after the center anchor grow rightwards
    // (their left edge stays put); the others grow leftwards.
    var growsRight = slot.region === "left" || (slot.region === "center" && me.x >= mid)

    var siblings = []
    var kids = slot.parent.children || []
    for (var i = 0; i < kids.length; i++)
      if (isSlot(kids[i])) siblings.push(kids[i])
    siblings.sort(function(a, b) { return a.x - b.x })
    var idx = siblings.indexOf(slot)
    var target = growsRight ? siblings[idx + 1] : siblings[idx - 1]
    var targetWidth = target && target.visible ? target.width : 0

    var ext = collect(barRoot, {
      left: { min: Infinity, max: -Infinity },
      center: { min: Infinity, max: -Infinity },
      right: { min: Infinity, max: -Infinity }
    })

    var free
    if (growsRight) {
      var far = ext[slot.region === "left" ? "center" : "right"].min
      if (far === Infinity) far = slot.region === "left" ? mid : window.width
      free = far - me.x - targetWidth
    } else {
      var near = ext[slot.region === "right" ? "center" : "left"].max
      if (near === -Infinity) near = slot.region === "right" ? mid : 0
      free = me.x + slot.width - near - targetWidth
    }
    var next = Math.max(0, Math.floor(free / 2))
    if (Math.abs(next - gap) >= 1) gap = next
  }

  Timer {
    interval: 150
    running: true
    repeat: true
    onTriggered: root.recompute()
  }
}
