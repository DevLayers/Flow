import QtQuick
import QtTest
import "../../modules/ii/sidebarDashboard/quickToggles/androidStyle" as QuickToggleStyle

TestCase {
    name: "QuickToggleEditController"

    property var sourcePages: [[
        { id: "a", type: "network", sizeW: 1, sizeH: 1 },
        { id: "b", type: "bluetooth", sizeW: 1, sizeH: 1 },
        { id: "c", type: "vpn", sizeW: 1, sizeH: 1 }
    ]]
    property var fakeConfig: ({ pages: sourcePages, layoutVersion: 2 })

    QuickToggleStyle.QuickToggleEditController {
        id: controller
        config: fakeConfig
        persistedPages: sourcePages
        columns: 4
    }

    function ids(page) {
        return page.map(function(value) { return value.id; });
    }

    function test_reorder_stays_in_draft_until_commit() {
        verify(controller.beginReorder("b", 0));
        verify(controller.active);
        compare(ids(controller.draftPages[0]), ["a", "b", "c"]);
        verify(controller.previewReorder(0, 3));
        compare(ids(controller.draftPages[0]), ["a", "c", "b"]);
        compare(ids(fakeConfig.pages[0]), ["a", "b", "c"]);
        verify(controller.commitReorder());
        verify(!controller.active);
        compare(ids(fakeConfig.pages[0]), ["a", "c", "b"]);
    }

    function test_cancel_discards_draft() {
        fakeConfig.pages = sourcePages;
        controller.persistedPages = sourcePages;
        verify(controller.beginReorder("a", 0));
        verify(controller.previewReorder(0, 2));
        verify(controller.cancelReorder());
        verify(!controller.active);
        compare(ids(fakeConfig.pages[0]), ["a", "b", "c"]);
    }

    function test_pointer_reorder_uses_packed_row_major_position() {
        fakeConfig.pages = sourcePages;
        controller.persistedPages = sourcePages;
        verify(controller.beginReorder("b", 0));
        verify(controller.previewReorderAt(0, 0, 100, 50, 56, 6));
        compare(ids(controller.draftPages[0]), ["a", "c", "b"]);
        compare(ids(fakeConfig.pages[0]), ["a", "b", "c"]);
        verify(controller.cancelReorder());
    }

    function test_resize_changes_only_target_item() {
        controller.persistedPages = [[
            { id: "a", type: "network", sizeW: 1, sizeH: 1 },
            { id: "slider", type: "volumeSlider", sizeW: 4, sizeH: 1 }
        ]];
        verify(controller.beginResize("a", 0));
        verify(controller.previewResize(2, 2));
        compare(controller.draftPages[0][0].sizeW, 2);
        compare(controller.draftPages[0][0].sizeH, 2);
        compare(controller.draftPages[0][1].sizeW, 4);
        compare(controller.draftPages[0][1].sizeH, 1);
        verify(controller.cancelResize());
    }
}
