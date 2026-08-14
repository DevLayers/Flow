import QtQuick;

/**
 * Represents a message in an AI conversation. (Kind of) follows the OpenAI API message structure.
 */
QtObject {
    property string role
    property string content
    property string rawContent
    property string fileMimeType
    property string fileUri
    property string localFilePath
    property string model
    // Reasoning, kept apart from the answer. `thought` is the summary text the
    // model streamed; the other two are what has to be handed back verbatim on
    // the next turn or multi-step reasoning loses its thread — Gemini's part
    // signature, and Anthropic's signed thinking blocks.
    property string thought
    property string thoughtSignature
    property var thinkingBlocks: []
    property bool thinking: true
    property bool done: false
    property var annotations: []
    property var annotationSources: []
    property list<string> searchQueries: []
    property string functionName
    property var functionCall
    property string functionResponse
    property bool functionPending: false
    property bool visibleToUser: true
}
