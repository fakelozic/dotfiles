.pragma library

// Search helpers for the launcher, kept free of QML so tests can run them in
// Node.

// How well text answers a query, lower is better, or -1 for no match. The
// tiers: the name starts with the query, a word in the name does, the word
// initials do ("vsc" for Visual Studio Code), the name contains it, one of the
// extra strings (generic name, keywords...) contains it, or the query's
// letters appear in order in the name. A query with spaces must have every
// word somewhere.
function rank(name, extra, query) {
    const q = query.trim().toLowerCase();
    if (q === "")
        return 0;
    const n = name.toLowerCase();
    const words = n.split(/[\s\-_.]+/).filter(word => word !== "");
    const haystack = [n, ...extra.map(text => (text ?? "").toLowerCase())].join("\n");
    if (q.includes(" ")) {
        const parts = q.split(/\s+/);
        if (parts.every(part => n.includes(part)))
            return 3;
        return parts.every(part => haystack.includes(part)) ? 4 : -1;
    }
    if (n.startsWith(q))
        return 0;
    if (words.some(word => word.startsWith(q)))
        return 1;
    if (q.length >= 2 && words.map(word => word[0]).join("").startsWith(q))
        return 2;
    if (n.includes(q))
        return 3;
    if (haystack.includes(q))
        return 4;
    if (q.length >= 2) {
        let at = 0;
        for (const char of n)
            if (char === q[at] && ++at === q.length)
                return 5;
    }
    return -1;
}

// The value of plain arithmetic such as "2 * (3 + 4)", or null when the text
// is not arithmetic, has no operator or gives no finite number. Supports
// + - * / % (remainder) ^ (power), parentheses, × and ÷; commas are ignored.
function calculate(text) {
    const source = text.replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "").trim();
    if (!/^[\d\s.+\-*/%^()]+$/.test(source) || !/\d/.test(source) || !/[+\-*/%^]/.test(source.replace(/^[\s(]*-/, "")))
        return null;
    const tokens = source.match(/\d*\.?\d+|[+\-*/%^()]/g);
    let at = 0;

    function peek() {
        return tokens[at];
    }

    function primary() {
        const token = tokens[at++];
        if (token === "(") {
            const value = sum();
            if (tokens[at++] !== ")")
                throw new Error("unbalanced");
            return value;
        }
        if (token === "-")
            return -power();
        if (token === "+")
            return power();
        if (token === undefined || !/\d/.test(token))
            throw new Error("expected a number");
        return parseFloat(token);
    }

    function power() {
        const base = primary();
        if (peek() === "^") {
            at++;
            return Math.pow(base, power());
        }
        return base;
    }

    function product() {
        let value = power();
        while (["*", "/", "%"].includes(peek())) {
            const op = tokens[at++];
            const right = power();
            value = op === "*" ? value * right : op === "/" ? value / right : value % right;
        }
        return value;
    }

    function sum() {
        let value = product();
        while (["+", "-"].includes(peek())) {
            const op = tokens[at++];
            const right = product();
            value = op === "+" ? value + right : value - right;
        }
        return value;
    }

    try {
        const value = sum();
        if (at !== tokens.length || !isFinite(value))
            return null;
        return value;
    } catch (error) {
        return null;
    }
}

// A result short enough to read: at most 12 significant digits, no trailing
// zeros and no exponent for ordinary sizes.
function formatNumber(value) {
    if (Number.isInteger(value) && Math.abs(value) < 1e15)
        return String(value);
    return String(parseFloat(value.toPrecision(12)));
}
