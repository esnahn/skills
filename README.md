# skills

Agent skills for Claude Code, Codex, and other agents that read `SKILL.md` folders.

| Skill | Description |
| --- | --- |
| [hwp-edit](skills/hwp-edit/SKILL.md) | Windows에서 한컴 COM으로 HWP·HWPX 문서의 본문·서식·표를 읽고 편집하고 새로 만들며, 저장 결과와 렌더링된 페이지를 검증합니다. Read, edit, and create HWP/HWPX documents through Hancom COM on Windows, then verify the saved file and rendered pages. |

## Install

With the [skills CLI](https://github.com/vercel-labs/skills) (Node.js 22.20 or later):

```powershell
npx skills add esnahn/skills -l                     # List the skills in this repository
npx skills add esnahn/skills -g -s hwp-edit         # Install one skill globally
```

Or copy a folder under `skills/` into your agent's skills directory (for example `~/.claude/skills` or `~/.agents/skills`).

## Requirements

- **hwp-edit:** Windows, Hancom Office 한글 with COM automation, and Windows PowerShell. The skill's *Machine setup* section walks through the security module and the official Hancom API manuals; neither is bundled here.

## License

[MIT](LICENSE)
