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
    // Files sent with this message: {path, name, mime, kind, bytes}. A message
    // carries its own attachments so a reopened chat still shows what was sent
    // with it, and so the next turn can hand them over again.
    property var attachments: []
    property string model
    // Reasoning, kept apart from the answer. `thought` is the summary text the
    // model streamed; the other two are what has to be handed back verbatim on
    // the next turn or multi-step reasoning loses its thread — Gemini's part
    // signature, and Anthropic's signed thinking blocks.
    property string thought
    property string thoughtSignature
    property var thinkingBlocks: []
    // How long the model spent reasoning, and how many tokens it cost. Both
    // are shown on the think block; -1 means the provider never said.
    property real thoughtStartedAt: 0
    property real thoughtDurationMs: 0
    property int thoughtTokens: -1
    property bool thinking: true
    property bool done: false
    property var annotations: []
    property var annotationSources: []
    property list<string> searchQueries: []
    property string functionName
    property var functionCall
    property string functionResponse
    property bool functionPending: false
    // Settings the model wants to write, as {key, current, proposed}, held
    // until the user has seen them next to what they would replace.
    property var pendingChanges: []
    // Handle of this call's entry in the tool log, so the user's answer
    // closes the same entry the call opened. -1 when nothing was logged.
    property int toolCallSerial: -1
    property bool visibleToUser: true
    // Why a request came back with nothing, as something the UI can act on
    // rather than prose in the bubble: "auth", "quota", "notFound", "server",
    // "network", "timeout" or "unknown". Empty on a message that went fine.
    property string errorKind: ""
    property string errorText: ""
    property int errorStatus: 0
    // What the provider actually sent back, kept off the transcript and shown
    // only if the card is unfolded: it is a wall of JSON nobody asked for, and
    // the one line that matters is already in `errorText`.
    property string errorDetails: ""
    // A message the sidebar wrote about its own state, which the transcript
    // draws as a card instead of as text. Currently only "apiKey".
    property string notice: ""
}
