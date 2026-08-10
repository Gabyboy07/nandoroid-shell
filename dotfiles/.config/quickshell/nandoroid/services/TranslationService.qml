pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/functions" as Functions

/**
 * TranslationService.qml
 * Ported logic from ii: handles text translation using 'translate-shell' (trans).
 */
Singleton {
    id: root

    property string translatedText: ""
    property string detectedLanguage: ""
    property bool isTranslating: translateProc.running
    property var availableLanguages: ["auto", "en", "id", "ja", "zh", "ko", "fr", "de", "es", "it", "ru", "pt"]
    
    // Track current active query to prevent race conditions on clear
    property string currentQuery: ""

    function translate(text, source, target) {
        const cleanText = (text || "").trim();
        root.currentQuery = cleanText;
        if (cleanText.length === 0) {
            if (translateProc.running) translateProc.running = false;
            root.translatedText = "";
            return;
        }
        
        if (translateProc.running) translateProc.terminate();

        const s = source || "auto";
        const t = target || "en";

        // If source is auto, we also identify the language code and print it first
        let cmd = "";
        if (s === "auto") {
            cmd = `res=$(trans -brief -s 'auto' -t '${Functions.StringUtils.shellSingleQuoteEscape(t)}' '${Functions.StringUtils.shellSingleQuoteEscape(cleanText)}'); code=$(trans -identify -no-ansi '${Functions.StringUtils.shellSingleQuoteEscape(cleanText)}' | awk '/Code/{print $2}'); echo -e "$code\\n$res"`;
        } else {
            cmd = `echo -e "${s}\\n$(trans -brief -s '${Functions.StringUtils.shellSingleQuoteEscape(s)}' -t '${Functions.StringUtils.shellSingleQuoteEscape(t)}' '${Functions.StringUtils.shellSingleQuoteEscape(cleanText)}')"`
        }

        translateProc.command = ["bash", "-c", cmd];
        translateProc.buffer = "";
        
        translateProc.running = true;
    }

    Process {
        id: translateProc
        command: []
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: (line) => {
                const textLine = line.toString();
                if (translateProc.buffer === "") {
                    // First line is the detected/source language code
                    root.detectedLanguage = textLine.trim();
                    translateProc.buffer = "\n"; // Mark that we've read the first line
                } else {
                    if (translateProc.buffer === "\n") {
                        translateProc.buffer = textLine; // First line of actual translation
                    } else {
                        translateProc.buffer += "\n" + textLine;
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    console.error("[TranslationService] stderr:", this.text.trim());
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.currentQuery.length > 0) {
                root.translatedText = (translateProc.buffer === "\n" ? "" : translateProc.buffer).trim();
            } else if (exitCode !== 0 && root.currentQuery.length > 0) {
                console.error("[TranslationService] Process exited with code:", exitCode);
            }
        }
    }

    // Ported from ii: Dynamic fetch to expand the list
    Process {
        id: getLangsProc
        command: ["trans", "-list-codes", "-no-bidi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim();

                if (output.length > 0) {
                    // Extract codes: trans -list-codes often outputs in columns
                    // We look for 2-3 letter codes at the start of lines or separated by whitespace
                    let codes = output.split(/\s+/)
                        .filter(s => s.length >= 2 && s.length <= 8 && /^[a-z]+(-[A-Z]+)?$/.test(s))
                        .filter(s => s !== "auto")
                        .sort();
                    
                    if (codes.length > 5) {
                        root.availableLanguages = ["auto", ...codes];

                    }
                }
            }
        }
    }
}
