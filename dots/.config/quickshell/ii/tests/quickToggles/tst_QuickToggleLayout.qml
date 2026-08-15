import QtQuick
import QtTest
import "../../modules/ii/sidebarDashboard/quickToggles/androidStyle/QuickToggleLayout.js" as Layout

TestCase {
    name: "QuickToggleLayout"

    function item(id, width, height) {
        return { id: id, type: id, sizeW: width, sizeH: height };
    }

    function packedById(packed, id) {
        for (var i = 0; i < packed.items.length; i++) {
            if (packed.items[i].id === id)
                return packed.items[i];
        }
        return null;
    }

    function test_bug_empty_cell_before_slider_is_filled() {
        var packed = Layout.pack([
            item("a", 1, 1), item("b", 1, 1), item("c", 1, 1),
            item("slider", 4, 1), item("d", 1, 1)
        ], 4);
        compare(packed.rowsUsed, 2);
        compare(packedById(packed, "d").row, 0);
        compare(packedById(packed, "d").column, 3);
        compare(packedById(packed, "slider").row, 1);
        compare(packedById(packed, "slider").column, 0);
        verify(Layout.validateNoOverlap(packed, 4));
    }

    function test_only_1x1_items_fill_rows() {
        var packed = Layout.pack([
            item("a", 1, 1), item("b", 1, 1), item("c", 1, 1),
            item("d", 1, 1), item("e", 1, 1), item("f", 1, 1)
        ], 4);
        compare(packed.rowsUsed, 2);
        compare(packedById(packed, "e").row, 1);
        compare(packedById(packed, "e").column, 0);
        compare(packedById(packed, "f").column, 1);
    }

    function test_vertical_span_blocks_all_rows() {
        var packed = Layout.pack([
            item("tall", 1, 2), item("a", 1, 1), item("b", 1, 1),
            item("c", 1, 1), item("d", 1, 1)
        ], 3);
        compare(packed.rowsUsed, 2);
        compare(packedById(packed, "c").row, 1);
        compare(packedById(packed, "c").column, 1);
        compare(packedById(packed, "d").row, 1);
        compare(packedById(packed, "d").column, 2);
        verify(Layout.validateNoOverlap(packed, 3));
    }

    function test_complex_spans_have_no_overlap_or_overflow() {
        var packed = Layout.pack([
            item("one", 1, 1), item("wide", 2, 1), item("tall", 1, 2),
            item("large", 2, 2), item("slider", 4, 1)
        ], 4);
        verify(Layout.validateNoOverlap(packed, 4));
        for (var i = 0; i < packed.items.length; i++)
            verify(packed.items[i].column + packed.items[i].columnSpan <= 4);
    }

    function test_resize_repack_is_deterministic() {
        var source = [item("a", 1, 1), item("b", 2, 1), item("c", 1, 1)];
        var resized = [item("a", 2, 2), item("b", 2, 1), item("c", 1, 1)];
        var first = Layout.pack(resized, 4);
        compare(JSON.stringify(first), JSON.stringify(Layout.pack(resized, 4)));
        compare(JSON.stringify(source), JSON.stringify([
            item("a", 1, 1), item("b", 2, 1), item("c", 1, 1)
        ]));
        verify(Layout.validateNoOverlap(first, 4));
    }

    function test_column_changes_keep_items_inside_grid() {
        var source = [item("a", 4, 1), item("b", 2, 2), item("c", 1, 1), item("d", 1, 1)];
        var columns = [4, 5, 3];
        for (var c = 0; c < columns.length; c++) {
            var packed = Layout.pack(source, columns[c]);
            verify(Layout.validateNoOverlap(packed, columns[c]));
            for (var i = 0; i < packed.items.length; i++)
                verify(packed.items[i].column + packed.items[i].columnSpan <= columns[c]);
        }
    }

    function test_move_is_move_not_swap_and_does_not_mutate_input() {
        var source = [item("a", 1, 1), item("b", 1, 1), item("c", 1, 1), item("d", 1, 1)];
        var moved = Layout.moveItem(source, 1, 3);
        compare(moved.map(function(value) { return value.id; }), ["a", "c", "d", "b"]);
        compare(source.map(function(value) { return value.id; }), ["a", "b", "c", "d"]);
    }

    function test_positioned_model_keeps_delegate_identity_during_reorder() {
        var persisted = [
            item("network", 1, 1),
            item("audio", 1, 1),
            item("bluetooth", 1, 1),
            item("brightnessSlider", 4, 1)
        ];
        var preview = [persisted[1], persisted[2], persisted[0], persisted[3]];
        var positioned = Layout.positionedItems(persisted, Layout.pack(preview, 4), 80, 56, 6);

        compare(positioned.map(function(value) { return value.id; }),
                ["network", "audio", "bluetooth", "brightnessSlider"]);
        compare(positioned.map(function(value) { return value.type; }),
                ["network", "audio", "bluetooth", "brightnessSlider"]);
        compare(positioned[0].layoutX, 2 * 86);
        compare(positioned[1].layoutX, 0);
        compare(positioned[3].layoutY, 62);
    }

    function test_positioned_model_backfills_hole_before_full_width_slider() {
        var persisted = [
            item("a", 1, 1), item("b", 1, 1), item("c", 1, 1),
            item("slider", 4, 1), item("d", 1, 1)
        ];
        var positioned = Layout.positionedItems(persisted, Layout.pack(persisted, 4), 80, 56, 6);

        compare(positioned[3].layoutY, 62);
        compare(positioned[4].layoutX, 3 * 86);
        compare(positioned[4].layoutY, 0);
    }

    function test_positioned_drawer_items_do_not_share_the_origin() {
        var drawer = [item("a", 1, 1), item("b", 1, 1), item("c", 1, 1), item("d", 1, 1), item("e", 1, 1)];
        var positioned = Layout.positionedItems(drawer, Layout.pack(drawer, 4), 80, 56, 6);
        var positions = positioned.map(function(value) { return value.layoutX + ":" + value.layoutY; });

        compare(new Set(positions).size, drawer.length);
        compare(positioned[4].layoutX, 0);
        compare(positioned[4].layoutY, 62);
    }

    function test_hovered_item_swaps_in_both_directions() {
        var source = [item("tailscale", 1, 1), item("darkMode", 1, 1)];
        var packed = Layout.pack(source, 4);

        compare(Layout.findInsertionIndex(packed.items, 0, 0, "darkMode"), 0);
        compare(Layout.findInsertionIndex(packed.items, 0, 1, "tailscale"), 2);
    }

    function test_full_width_item_targets_the_whole_hovered_row() {
        var movingUp = [
            item("a", 1, 1), item("b", 1, 1), item("c", 1, 1), item("d", 1, 1),
            item("slider", 4, 1)
        ];
        var packedUp = Layout.pack(movingUp, 4);
        compare(Layout.findInsertionIndex(packedUp.items, 0, 0, "slider", 4), 0);

        var movingDown = [
            item("slider", 4, 1),
            item("a", 1, 1), item("b", 1, 1), item("c", 1, 1), item("d", 1, 1)
        ];
        var packedDown = Layout.pack(movingDown, 4);
        compare(Layout.findInsertionIndex(packedDown.items, 1, 0, "slider", 4), 5);
    }

    function test_resize_span_uses_absolute_gesture_delta() {
        compare(Layout.resizeSpanFromDelta(1, 27, 50, 6, 4), 1);
        compare(Layout.resizeSpanFromDelta(1, 29, 50, 6, 4), 2);
        compare(Layout.resizeSpanFromDelta(1, 40, 50, 6, 4), 2);
        compare(Layout.resizeSpanFromDelta(1, 83, 50, 6, 4), 2);
        compare(Layout.resizeSpanFromDelta(1, 85, 50, 6, 4), 3);
    }

    function test_deterministic_stress_never_overlaps() {
        var source = [];
        for (var i = 0; i < 120; i++) {
            source.push(item("stress-" + i, 1 + (i % 4), 1 + (i % 3)));
        }
        for (var run = 0; run < 20; run++) {
            var packed = Layout.pack(source, 4 + (run % 2));
            verify(Layout.validateNoOverlap(packed, 4 + (run % 2)));
            compare(JSON.stringify(packed), JSON.stringify(Layout.pack(source, 4 + (run % 2))));
        }
    }
}
