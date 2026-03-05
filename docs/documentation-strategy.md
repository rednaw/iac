[**<---**](README.md)

# Documentation strategy

Guidance on **style and tone** when writing or editing docs. Use it so documentation stays consistent and readable.

---

## Easy reading, not corporate

Structure is for clarity; the prose should stay human and easy to read.

- **Plain language.** Say it simply. Prefer "use" over "utilize", "get" over "obtain", "run" over "execute". No buzzwords (leverage, synergy, stakeholder, enablement, solutioning).
- **Short sentences.** One idea per sentence when you can. Break up long paragraphs.
- **You and we.** Address the reader as "you". "We" is fine when it means "this project" or "we do it this way". Avoid the passive when the active is clearer ("Ansible copies the file" not "The file is copied by Ansible").
- **Concrete over abstract.** "Add your app's hostname to the Traefik label" rather than "Configure the routing endpoint for your service". Examples and copy-paste snippets help more than long explanations.
- **Scannable but readable.** Headings and lists make docs scannable; the text under them should still read well if someone reads top to bottom. No walls of bullets where a short paragraph would be clearer.

The goal: someone can find the right doc, follow the steps or look up the detail, and not feel they're reading a vendor manual.

---

## Mechanics

- **Every doc** starts with a breadcrumb to the doc index (e.g. `[**<---**](README.md)`). Make it clear who the doc is for in the opening (e.g. first paragraph or section headings) — no need for a formal "Audience:" label.
- **Tone:** Use "you" and imperative for instructions ("Run ...", "Add ..."). Use present tense for facts ("The registry runs on ...").
- **Level:** One main level per doc (or per major section). If a section is "for experts", say so (e.g. "Implementation details (if you joined)").
- **Cross-links:** Prefer "See [Doc](link) for ..." over "see above" or vague "see documentation". Link to the specific section when it helps.
- **Code and commands:** Use fenced blocks with language; show full commands (e.g. `task app:deploy -- dev 706c88c`) so they can be copied.
- **Placeholders:** Prefer parameterized wording (e.g. "observe.&lt;base_domain&gt;", "registry.&lt;base_domain&gt;") where there's a convention; otherwise use a single placeholder (e.g. "&lt;base_domain&gt;") and one real example in parentheses if it helps.
