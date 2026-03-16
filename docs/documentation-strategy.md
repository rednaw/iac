[**<---**](README.md)

# Documentation strategy

Write for humans who can read code. Be brief. Use pictures.

---

## Core principles

**Brief wins over complete**
- Reference code instead of explaining what it does
- One paragraph beats three bullet points
- Cut anything that doesn't help someone do their job
- Reference docs should scan in under 2 minutes

**Visual over text**
- Use mermaid for flows, architecture, relationships
- Show structure with code examples, not prose
- Tables for parameters and command reference

**Human language**
- Plain words: "use" not "utilize", "run" not "execute"
- No buzzwords: leverage, synergy, stakeholder, enablement, solutioning
- Active voice: "Ansible copies the file" not "the file is copied"
- Concrete: "Add the Traefik label" not "configure the routing endpoint"

**The audience reads code**
- Don't explain implementation details in prose — link to the code
- Show the command, skip the explanation
- Examples over exposition

---

## Length targets

Most reference docs: **under 150 lines** (100 is better)

Cut:
- Long explanations of what code does (link to it instead)
- Repetition between docs (cross-link)
- Architecture/design philosophy (unless that's the doc's purpose)
- Anything that just sounds professional but doesn't help

Keep:
- Commands with full examples
- Quick reference tables
- Mermaid diagrams for context
- Common operations
- Troubleshooting

---

## Structure

Every doc:
- Breadcrumb link: `[**<---**](README.md)`
- Brief opening: what this is, who needs it (no formal "Audience:" label)
- Mermaid diagram if it clarifies
- Commands/quick reference section
- Troubleshooting if relevant

Skip:
- "Introduction" and "Conclusion" headers
- Repetitive "Overview" sections
- Design principles (move to separate doc if essential)

---

## Mechanics

- **Tone:** "you" and imperative for steps ("Run X"), present tense for facts ("Traefik routes traffic")
- **Commands:** Full examples in fenced blocks: `task app:deploy -- dev 706c88c`
- **Placeholders:** Use `<base_domain>` with one real example if helpful
- **Cross-links:** "See [Doc](link)" not "see above"
- **Links to code:** Use backticks in the link text so it renders in monospace and reads as a path: [`path/to/file.yml`](../path/to/file.yml). Doc links use normal text: [Remote-SSH](remote-ssh.md).
