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
}
