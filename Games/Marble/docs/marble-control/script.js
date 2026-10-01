const reveals = document.querySelectorAll(".reveal");

const io = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        io.unobserve(entry.target);
      }
    }
  },
  { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
);

for (const el of reveals) {
  io.observe(el);
}

/* —— Luau syntax highlight —— */
const LUAU_KEYWORDS = new Set([
  "and",
  "break",
  "continue",
  "do",
  "else",
  "elseif",
  "end",
  "export",
  "false",
  "for",
  "function",
  "if",
  "in",
  "local",
  "nil",
  "not",
  "or",
  "repeat",
  "return",
  "then",
  "true",
  "type",
  "typeof",
  "until",
  "while",
]);

const LUAU_BUILTINS = new Set([
  "AccelRate",
  "AssemblyLinearVelocity",
  "BrakeRate",
  "Color3",
  "Config",
  "Enum",
  "InputSmooth",
  "Instance",
  "JumpSpeed",
  "Lerp",
  "Magnitude",
  "MaxSpeed",
  "RenderStepped",
  "RunService",
  "SteerRate",
  "Unit",
  "Vector3",
  "Workspace",
  "math",
  "pairs",
  "ipairs",
  "print",
  "require",
  "task",
  "wait",
]);

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function span(cls, text) {
  return `<span class="tok tok--${cls}">${escapeHtml(text)}</span>`;
}

function highlightLuau(source) {
  const tokenRe =
    /(\-\-\[\[[\s\S]*?\]\])|(\-\-[^\n]*)|(\[=*\[[\s\S]*?\]=*\])|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|(\b[A-Za-z_][A-Za-z0-9_]*\b)|([^\sA-Za-z0-9_"']+)/g;

  let out = "";
  let last = 0;
  let match;

  while ((match = tokenRe.exec(source)) !== null) {
    if (match.index > last) {
      out += escapeHtml(source.slice(last, match.index));
    }

    const [full, blockComment, lineComment, longString, stringLit, number, ident, punct] =
      match;

    if (blockComment || lineComment) {
      out += span("comment", full);
    } else if (longString || stringLit) {
      out += span("string", full);
    } else if (number) {
      out += span("number", full);
    } else if (ident) {
      if (LUAU_KEYWORDS.has(ident)) {
        out += span("keyword", ident);
      } else if (LUAU_BUILTINS.has(ident)) {
        out += span("builtin", ident);
      } else {
        out += span("ident", ident);
      }
    } else if (punct) {
      out += span("punct", punct);
    } else {
      out += escapeHtml(full);
    }

    last = match.index + full.length;
  }

  if (last < source.length) {
    out += escapeHtml(source.slice(last));
  }

  return out;
}

for (const block of document.querySelectorAll("pre.code > code")) {
  block.innerHTML = highlightLuau(block.textContent);
  block.classList.add("language-luau");
}
