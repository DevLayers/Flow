.pragma library

function integerAtLeastOne(value, fallback) {
    var number = Number(value);
    if (!isFinite(number))
        return fallback;
    return Math.max(1, Math.floor(number));
}
function cloneObject(source) {
    var result = {};
    if (!source || typeof source !== "object")
        return result;
    for (var key in source)
        result[key] = source[key];
    return result;
}

function createOccupancy(columns) {
    var width = integerAtLeastOne(columns, 1);
    return {
        columns: width,
        rows: []
    };
}

function cloneOccupancy(occupancy) {
    var result = {
        columns: occupancy.columns,
        rows: []
    };
    for (var i = 0; i < occupancy.rows.length; i++)
        result.rows.push(occupancy.rows[i].slice());
    return result;
}

function canPlace(occupancy, row, column, width, height) {
    if (!occupancy || row < 0 || column < 0 || width < 1 || height < 1)
        return false;
    if (column + width > occupancy.columns)
        return false;

    for (var rowOffset = 0; rowOffset < height; rowOffset++) {
        var currentRow = occupancy.rows[row + rowOffset];
        if (!currentRow)
            continue;
        for (var columnOffset = 0; columnOffset < width; columnOffset++) {
            if (currentRow[column + columnOffset] === true)
                return false;
        }
    }
    return true;
}

function markOccupied(occupancy, row, column, width, height) {
    var result = cloneOccupancy(occupancy);
    for (var rowOffset = 0; rowOffset < height; rowOffset++) {
        var rowIndex = row + rowOffset;
        while (result.rows.length <= rowIndex)
            result.rows.push(new Array(result.columns).fill(false));
        for (var columnOffset = 0; columnOffset < width; columnOffset++)
            result.rows[rowIndex][column + columnOffset] = true;
    }
    return result;
}

function itemSize(item) {
    var width = Number(item && item.sizeW);
    var height = Number(item && item.sizeH);
    return {
        width: isFinite(width) ? Math.max(1, Math.floor(width)) : 1,
        height: isFinite(height) ? Math.max(1, Math.floor(height)) : 1
    };
}

function firstFit(occupancy, width, height) {
    var row = 0;
    while (true) {
        for (var column = 0; column <= occupancy.columns - width; column++) {
            if (canPlace(occupancy, row, column, width, height))
                return { row: row, column: column };
        }
        row++;
    }
}

function pack(items, columns) {
    var source = Array.isArray(items) ? items : [];
    var occupancy = createOccupancy(columns);
    var result = [];

    for (var index = 0; index < source.length; index++) {
        if (!source[index] || typeof source[index] !== "object")
            continue;

        var dimensions = itemSize(source[index]);
        dimensions.width = Math.min(dimensions.width, occupancy.columns);
        var position = firstFit(occupancy, dimensions.width, dimensions.height);
        occupancy = markOccupied(occupancy, position.row, position.column, dimensions.width, dimensions.height);

        var packedItem = cloneObject(source[index]);
        packedItem.sizeW = dimensions.width;
        packedItem.sizeH = dimensions.height;
        packedItem.row = position.row;
        packedItem.column = position.column;
        packedItem.rowSpan = dimensions.height;
        packedItem.columnSpan = dimensions.width;
        result.push(packedItem);
    }

    return {
        rowsUsed: occupancy.rows.length,
        items: result
    };
}

function rowsUsed(items, columns) {
    return pack(items, columns).rowsUsed;
}

function findItem(items, id) {
    if (!Array.isArray(items))
        return -1;
    for (var i = 0; i < items.length; i++) {
        if (items[i] && items[i].id === id)
            return i;
    }
    return -1;
}

function copyItems(items) {
    var result = [];
    if (!Array.isArray(items))
        return result;
    for (var i = 0; i < items.length; i++)
        result.push(cloneObject(items[i]));
    return result;
}

function moveItem(items, fromIndex, toIndex) {
    var result = copyItems(items);
    if (fromIndex < 0 || fromIndex >= result.length || result.length === 0)
        return result;
    var target = Math.max(0, Math.min(integerAtLeastOne(toIndex + 1, 1) - 1, result.length - 1));
    var moved = result.splice(fromIndex, 1)[0];
    result.splice(target, 0, moved);
    return result;
}

function removeItem(items, id) {
    var result = copyItems(items);
    var index = findItem(result, id);
    if (index >= 0)
        result.splice(index, 1);
    return result;
}

function insertItem(items, item, index) {
    var result = copyItems(items);
    var target = Math.max(0, Math.min(integerAtLeastOne(index + 1, 1) - 1, result.length));
    result.splice(target, 0, cloneObject(item));
    return result;
}

function rectanglesOverlap(a, b) {
    return a.row < b.row + b.rowSpan
        && a.row + a.rowSpan > b.row
        && a.column < b.column + b.columnSpan
        && a.column + a.columnSpan > b.column;
}

function validateNoOverlap(packed, columns) {
    if (!packed || !Array.isArray(packed.items))
        return false;
    var cols = integerAtLeastOne(columns, 1);
    var ids = Object.create(null);
    for (var i = 0; i < packed.items.length; i++) {
        var item = packed.items[i];
        if (!item || item.row < 0 || item.column < 0 || item.column + item.columnSpan > cols)
            return false;
        if (item.id !== undefined) {
            if (ids[item.id])
                return false;
            ids[item.id] = true;
        }
        for (var j = i + 1; j < packed.items.length; j++) {
            if (rectanglesOverlap(item, packed.items[j]))
                return false;
        }
    }
    return true;
}

function findInsertionIndex(packedItems, row, column, draggedId) {
    if (!Array.isArray(packedItems) || packedItems.length === 0)
        return 0;
    for (var i = 0; i < packedItems.length; i++) {
        var item = packedItems[i];
        if (!item || item.id === draggedId)
            continue;
        if (row < item.row || (row === item.row && column < item.column))
            return i;
    }
    return packedItems.length;
}
