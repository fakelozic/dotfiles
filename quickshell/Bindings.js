.pragma library

// Turns Sway config text into key bindings for the shortcut viewer, kept free
// of QML so tests can run it in Node. Files are separated by "#@file <path>"
// lines. Each binding is {keys, description, section, command}: keys is a
// list of key names ready to show, and command has $variables filled in so
// swaymsg can run it.

const keyNames = {
    Mod4: "Super",
    Mod1: "Alt",
    Control: "Ctrl",
    Return: "Enter",
    Escape: "Esc",
    minus: "-",
    space: "Space",
    Left: "←",
    Right: "→",
    Up: "↑",
    Down: "↓",
    Print: "Print Screen",
    XF86AudioRaiseVolume: "Volume up",
    XF86AudioLowerVolume: "Volume down",
    XF86AudioMute: "Mute",
    XF86AudioMicMute: "Mic mute",
    XF86AudioPlay: "Play",
    XF86AudioPause: "Pause",
    XF86AudioStop: "Stop",
    XF86AudioNext: "Next",
    XF86AudioPrev: "Previous",
    XF86AudioForward: "Forward",
    XF86AudioRewind: "Rewind",
    XF86MonBrightnessUp: "Brightness up",
    XF86MonBrightnessDown: "Brightness down"
};

// Plain descriptions for the commands this setup binds, with the section to
// list them under when the config's comments do not give a good one. The first
// match wins.
const descriptions = [
    [/qs ipc call launcher/, "Search apps and commands"],
    [/qs ipc call windows/, "Switch window"],
    [/qs ipc call clipboard/, "Clipboard history", "Basics"],
    [/qs ipc call notifications toggle/, "Notification center"],
    [/qs ipc call power/, "Power menu"],
    [/^loginctl lock-session/, "Lock the screen"],
    [/screenshot"? clipboard/, "Screenshot an area to the clipboard", "Screenshots"],
    [/screenshot"? output/, "Screenshot a display to Pictures/Screenshots", "Screenshots"],
    [/screenshot"? area/, "Screenshot an area to Pictures/Screenshots", "Screenshots"],
    [/pick-color/, "Pick a color from the screen", "Screenshots"],
    [/grimshot save output/, "Save a screenshot of the display"],
    [/grimshot save active/, "Save a screenshot of the window"],
    [/grimshot save area/, "Save a screenshot of an area"],
    [/playerctl play-pause/, "Play or pause"],
    [/playerctl stop/, "Stop playback"],
    [/playerctl pause/, "Pause"],
    [/playerctl next/, "Next track"],
    [/playerctl previous/, "Previous track"],
    [/playerctl position \+/, "Skip forward"],
    [/playerctl position -/, "Skip back"],
    [/--increase/, "Volume up"],
    [/--decrease/, "Volume down"],
    [/set-sink-mute/, "Mute sound"],
    [/set-source-mute/, "Mute microphone"],
    [/brightnessctl .*%-/, "Brightness down"],
    [/brightnessctl .*\+/, "Brightness up"],
    [/swaynag .*exit/, "Exit Sway (asks first)"],
    [/^swaymsg exit$/, "Exit Sway"],
    [/^kill$/, "Close window"],
    [/^reload$/, "Reload the Sway config"],
    [/^focus (left|right|up|down)$/, m => "Focus " + m[1]],
    [/^focus parent$/, "Focus the parent container"],
    [/^focus mode_toggle$/, "Switch focus between tiled and floating"],
    [/^move (left|right|up|down)$/, m => "Move window " + m[1]],
    [/^workspace (?:number )?(\S+)$/, m => "Go to workspace " + m[1]],
    [/^move (?:container )?to workspace (?:number )?(\S+)$/, m => "Move window to workspace " + m[1]],
    [/^splith$/, "Split horizontally"],
    [/^splitv$/, "Split vertically"],
    [/^layout stacking$/, "Stacked layout"],
    [/^layout tabbed$/, "Tabbed layout"],
    [/^layout toggle split$/, "Toggle split direction"],
    [/^fullscreen/, "Fullscreen"],
    [/^floating toggle$/, "Float or tile the window"],
    [/^move scratchpad$/, "Send window to the scratchpad"],
    [/^scratchpad show$/, "Show the scratchpad"],
    [/^mode "?default"?$/, "Back to normal keys"],
    [/^mode "?([^"]+)"?$/, m => capitalize(m[1]) + " mode"],
    [/^resize (shrink|grow) (width|height)/, m => capitalize(m[1]) + " " + m[2]]
];

const sectionNames = {
    "Layout stuff": "Layout",
    "Resizing containers": "Resizing"
};

function capitalize(text) {
    return text.charAt(0).toUpperCase() + text.slice(1);
}

function substitute(text, vars) {
    return text.replace(/\$(\w+)/g, (match, name) => name in vars ? vars[name] : match);
}

function keyParts(keys) {
    return keys.split("+").map(key => keyNames[key] ?? (key.length === 1 ? key.toUpperCase() : key));
}

function fileSection(path) {
    const name = path.split("/").pop().replace(/\.conf$/, "").replace(/^\d+-/, "").replace(/^(bindings|mode)-/, "");
    return name === "config" ? "Sway" : capitalize(name);
}

// {text, section} for a command, or null when nothing describes it.
function describe(command) {
    const bare = command.replace(/;\s*mode\s+"?default"?\s*$/, "").replace(/^exec\s+(--no-startup-id\s+)?/, "").trim();
    for (const [pattern, text, section] of descriptions) {
        const match = bare.match(pattern);
        if (match)
            return { text: typeof text === "function" ? text(match) : text, section };
    }
    return null;
}

// A readable stand-in for a command nothing describes: "exec alacritty"
// becomes "Open alacritty", and paths are cut to the program name.
function fallback(command) {
    const exec = command.match(/^exec\s+(?:--no-startup-id\s+)?(.*)$/);
    if (!exec)
        return capitalize(command);
    const words = exec[1].replace(/["']/g, "").split(/\s+/);
    words[0] = words[0].split("/").pop();
    return words.length === 1 ? "Open " + words[0] : "Run " + words.join(" ");
}

function parse(text) {
    const vars = {};
    const bindings = [];
    const groups = [];
    let section = "Sway";
    let group = null;
    let commentOpen = false;
    let mode = null;
    let block = false;

    function add(keys, command) {
        const filled = substitute(command.trim(), vars);
        const described = describe(filled);
        const enters = filled.match(/^mode\s+"?([^";]+?)"?$/);
        bindings.push({
            keys: keyParts(substitute(keys, vars)),
            command: filled,
            mode,
            section: mode ? capitalize(mode) + " mode"
                : enters && enters[1] !== "default" ? capitalize(enters[1]) + " mode"
                : described?.section ?? section,
            group,
            description: described?.text
        });
        if (group)
            group.size++;
    }

    const lines = text.replace(/\\\n\s*/g, " ").split("\n");
    for (const raw of lines) {
        const line = raw.trim();
        const isComment = line.startsWith("#");
        if (!isComment)
            commentOpen = false;

        if (line.startsWith("#@file ")) {
            section = fileSection(line.slice(7).trim());
            group = null;
            mode = null;
            block = false;
            continue;
        }
        if (line === "") {
            group = null;
            continue;
        }
        if (isComment) {
            const comment = line.replace(/^#+/, "").trim();
            if (comment === "")
                continue;
            if (line.startsWith("###") || /^[A-Z][\w ]*:$/.test(comment)) {
                const name = comment.replace(/:$/, "");
                section = sectionNames[name] ?? name;
                group = null;
                continue;
            }
            if (commentOpen && group)
                group.text += " " + comment;
            else {
                group = { text: comment, size: 0 };
                groups.push(group);
            }
            commentOpen = true;
            continue;
        }

        let match;
        if ((match = line.match(/^set\s+\$(\w+)\s+(.*)$/)))
            vars[match[1]] = substitute(match[2], vars);
        else if ((match = line.match(/^mode\s+(?:--\S+\s+)*"?([^"{]+?)"?\s*\{$/)))
            mode = match[1];
        else if (line === "}") {
            if (block)
                block = false;
            else if (mode) {
                // What follows a mode block is no longer under the comment
                // heading above it.
                mode = null;
                section = "Other";
            }
        } else if (/^bind(?:sym|code)\s+(?:--\S+\s+)*\{$/.test(line))
            block = true;
        else if ((match = line.match(/^bind(?:sym|code)\s+(?:--\S+\s+)*(\S+)\s+(.+)$/)))
            add(match[1], match[2]);
        else if (block && (match = line.match(/^(\S+)\s+(.+)$/)))
            add(match[1], match[2]);
    }

    // Bindings inside a mode show the key that enters it first.
    const modeKeys = {};
    for (const binding of bindings) {
        const match = binding.command.match(/^mode\s+"?([^";]+?)"?$/);
        if (!binding.mode && match && match[1] !== "default")
            modeKeys[match[1]] = binding.keys;
    }

    return bindings.map(binding => ({
        keys: binding.mode && modeKeys[binding.mode] ? [...modeKeys[binding.mode], "then", ...binding.keys] : binding.keys,
        description: binding.description ?? (binding.group && binding.group.size === 1 ? binding.group.text : fallback(binding.command)),
        section: binding.section,
        command: binding.command
    }));
}

// Bindings whose keys, description or section contain every word of query.
function filter(bindings, query) {
    const words = query.trim().toLowerCase().split(/\s+/).filter(word => word !== "");
    return bindings.filter(binding => {
        const haystack = [binding.description, binding.section, binding.keys.join(" ")].join(" ").toLowerCase();
        return words.every(word => haystack.includes(word));
    });
}
