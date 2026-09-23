import { basicSetup } from "codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { json } from "@codemirror/lang-json";
import { EditorState } from "@codemirror/state";
import { StreamLanguage, syntaxHighlighting, HighlightStyle, indentUnit } from "@codemirror/language";
import { EditorView, hoverTooltip } from "@codemirror/view";
import { autocompletion } from "@codemirror/autocomplete";
import { linter, setDiagnostics } from "@codemirror/lint";
import { tags } from "@lezer/highlight";

const qmlKeywords = new Set([
  "as", "component", "default", "enum", "import", "pragma", "property",
  "readonly", "required", "signal", "function", "var", "let", "const",
  "if", "else", "for", "while", "do", "switch", "case", "break",
  "continue", "return", "try", "catch", "finally", "throw", "new",
  "delete", "typeof", "instanceof", "in", "of"
]);

const qmlLanguage = StreamLanguage.define({
  startState: () => ({ inBlockComment: false }),
  token(stream, state) {
    if (state.inBlockComment) {
      if (stream.skipTo("*/")) {
        stream.match("*/");
        state.inBlockComment = false;
      } else {
        stream.skipToEnd();
      }
      return "comment";
    }

    if (stream.eatSpace()) return null;
    if (stream.match("//")) {
      stream.skipToEnd();
      return "comment";
    }
    if (stream.match("/*")) {
      state.inBlockComment = true;
      if (stream.skipTo("*/")) {
        stream.match("*/");
        state.inBlockComment = false;
      } else {
        stream.skipToEnd();
      }
      return "comment";
    }

    const quote = stream.peek();
    if (quote === "\"" || quote === "'") {
      stream.next();
      while (!stream.eol()) {
        const character = stream.next();
        if (character === "\\") stream.next();
        else if (character === quote) break;
      }
      return "string";
    }

    if (stream.match(/^#[0-9a-fA-F]{3,8}\b/)) return "atom";
    if (stream.match(/^(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?(?:px|dp|sp|ms|s|deg|rad|%)?/)) {
      return "number";
    }
    if (stream.match(/^[A-Za-z_$][\w$]*(?=\s*:)/)) return "propertyName";
    if (stream.match(/^[A-Za-z_$][\w$]*/)) {
      const word = stream.current();
      if (qmlKeywords.has(word)) return "keyword";
      if (["true", "false", "null", "undefined", "this"].includes(word)) return "atom";
      if (/^on[A-Z]/.test(word)) return "propertyName";
      if (/^[A-Z]/.test(word)) return "typeName";
      return "variableName";
    }
    if (stream.match(/^(?:===?|!==?|=>|&&|\|\||\?\?|\+\+|--|<=|>=|[+*%&|^!?=<>~/-])/)) {
      return "operator";
    }
    stream.next();
    return "punctuation";
  }
});

const draculaTheme = EditorView.theme({
  "&": { height: "100%", color: "#f8f8f2", backgroundColor: "#282a36", fontSize: "13px" },
  ".cm-scroller": { overflow: "auto", fontFamily: "'JetBrains Mono', 'Fira Code', monospace", lineHeight: "1.4" },
  ".cm-content": { caretColor: "#f8f8f2", padding: "6px 0" },
  ".cm-line": { padding: "0 8px" },
  ".cm-cursor, .cm-dropCursor": { borderLeftColor: "#f8f8f2" },
  ".cm-gutters": { backgroundColor: "#282a36", color: "#6d8a88", border: "none" },
  ".cm-activeLineGutter": { backgroundColor: "#323443", color: "#f8f8f2" },
  ".cm-activeLine": { backgroundColor: "rgba(255, 255, 255, 0.04)" },
  ".cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection": {
    backgroundColor: "rgba(255, 255, 255, 0.16)"
  },
  ".cm-tooltip": { backgroundColor: "#21222c", color: "#f8f8f2", border: "1px solid #44475a" },
  ".cm-tooltip-autocomplete ul li[aria-selected]": { backgroundColor: "#44475a" }
}, { dark: true });

const draculaHighlight = HighlightStyle.define([
  { tag: tags.comment, color: "#6272a4" },
  { tag: tags.string, color: "#f1fa8c" },
  { tag: tags.number, color: "#bd93f9" },
  { tag: tags.atom, color: "#bd93f9" },
  { tag: tags.keyword, color: "#ff79c6" },
  { tag: tags.typeName, color: "#ffb86c" },
  { tag: tags.propertyName, color: "#66d9ef" },
  { tag: tags.variableName, color: "#50fa7b" },
  { tag: tags.operator, color: "#ff79c6" },
  { tag: tags.punctuation, color: "#f8f8f2" },
  { tag: tags.meta, color: "#f8f8f2" },
  { tag: tags.invalid, color: "#ff5555", textDecoration: "underline" }
]);

const sharedExtensions = [
  basicSetup,
  EditorState.tabSize.of(4),
  indentUnit.of("    "),
  EditorView.lineWrapping,
  EditorView.contentAttributes.of({
    autocapitalize: "off",
    autocomplete: "off",
    autocorrect: "off",
    spellcheck: "false"
  }),
  draculaTheme,
  syntaxHighlighting(draculaHighlight)
];

function languageExtension(mode) {
  if (mode === "javascript") return javascript();
  if (mode === "json") return json();
  if (mode === "qml") return qmlLanguage;
  return [];
}

let lspSequence = 100000;
const lspCallbacks = new Map();
let activeMode = "text";
let activePath = "";
let lspStatus = "qmlls no iniciado";
let activeView = null;

function askLsp(type, view, pos) {
  if (!activePath || activeMode !== "qml") return null;
  const line = view.state.doc.lineAt(pos);
  const id = ++lspSequence;
  document.title = "dawn-lsp:" + encodeURIComponent(JSON.stringify({
    type, id, path: activePath, line: line.number - 1, character: pos - line.from
  }));
  return id;
}

function qmlCompletion(context) {
  if (lspStatus !== "qmlls conectado") return null;
  const before = context.matchBefore(/[\w.$]*/);
  if (!before || (!before.text && !context.explicit)) return null;
  return new Promise(resolve => {
    if (!activeView) return resolve(null);
    const id = askLsp("completion", activeView, context.pos);
    if (!id) return resolve(null);
    const timer = setTimeout(() => { lspCallbacks.delete(id); resolve(null); }, 1500);
    lspCallbacks.set(id, response => {
      clearTimeout(timer);
      const raw = response.result?.value !== undefined ? response.result.value : response.result;
      const items = Array.isArray(raw) ? raw : (raw?.items || []);
      resolve({ from: before.from, options: items.map(item => ({
        label: item.label || "", detail: item.detail || "",
        info: (typeof item.documentation === "string" ? item.documentation : item.documentation?.value) || item.detail || "",
        apply: item.insertText || item.label || "",
        type: item.kind === 7 ? "class" : item.kind === 10 ? "property" : item.kind === 3 ? "function" : "text"
      })), validFor: /^[\w.$]*$/ });
    });
  });
}

function qmlHover(view, pos) {
  if (lspStatus !== "qmlls conectado") return null;
  return new Promise(resolve => {
    const id = askLsp("hover", view, pos);
    if (!id) return resolve(null);
    const timer = setTimeout(() => { lspCallbacks.delete(id); resolve(null); }, 1500);
    lspCallbacks.set(id, response => {
      clearTimeout(timer);
      const contents = response.result?.contents;
      if (!contents) return resolve(null);
      const text = Array.isArray(contents) ? contents.map(c => c.value || c).join("\n") : (contents.value || contents);
      const dom = document.createElement("div"); dom.className = "cm-lsp-hover"; dom.textContent = text;
      resolve({ pos, create: () => ({ dom }) });
    });
  });
}

function qmlLspExtensions() {
  return [autocompletion({ override: [qmlCompletion], activateOnTyping: true }), hoverTooltip(qmlHover),
    linter(() => [])];
}

function setActiveLspMode(mode) { activeMode = mode; }
function setActiveLspPath(path) { activePath = path || ""; }
function setLspStatus(status) { lspStatus = status || ""; }
function setActiveEditorView(view) { activeView = view; }

export { EditorState, EditorView, languageExtension, sharedExtensions, qmlLspExtensions,
  setDiagnostics, lspCallbacks, setActiveLspMode, setActiveLspPath, setLspStatus, setActiveEditorView };
