@AGENTS.md

## Claude Code only

Delegation roles: Explorer = Explore agent, model haiku, for locating code;
use sonnet when exploration needs reading and judgment (library behavior,
external docs, research). Implementer = general-purpose agent, model sonnet.
Reviewer = the session model; do not use the code-review agent. Update these
when the user changes the model policy.
