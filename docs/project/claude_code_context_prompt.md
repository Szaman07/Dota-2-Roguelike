# Claude Code context prompt (short)

_2026-10-12. A short version that gives Claude Code the project context without the milestone-by-milestone plan. Use it to start any session (a quick fix, a question, one feature); for the full build, use [claude_code_build_prompt.md](claude_code_build_prompt.md). Paste everything below the line into Claude Code at the project root._

---

This folder is **"A Dice-Based Tournament Roguelike Deck Builder"**, our CSE311 (Database Systems, North South University) course project, built in **PHP 8 + MySQL 8.0+** on my Windows machine. The database is what gets graded, so the SQL must stay visible.

**The game:** you draft a team of real Dota 2 pro players from 10 packs (each pack is a real org: 5 of its players as era cards plus 5 random heroes; you keep one card per pack, ending with exactly 5 players and 5 heroes). Each player card has a rating (68–99), a main role and alternate roles from real pro data (alternate = ≥ 15% of the card's matches or another card's main role; only other roles get a penalty). Then you play a 16-team tournament against real tier-1 winner and finalist rosters, each using its real final draft: 2 groups of 8 (Bo1), then double elimination. Matches are simulated with 2d6 dice plus small bonuses (lanes, teamfights, pickoffs, Roshan, buildings), boosted by hero mastery, chemistry (matches played together) and draft composition. Group losses give 2 picks and wins 1; upper-bracket series wins give a player upgrade; a 5-slot bench holds extra cards. No accounts, no shop, no network calls during play.

**Where things are:**
- `docs/project/`: `proposal.md` (current rules in plain words), `game_outline.md` (12 screens with their DB reads and writes, every formula), `open_questions.md` (open points with defaults; use the defaults), `build_plan.md`, `dbms_coursework_map.md`, and `schema/` (`schema_draft.sql` with 42 tables, `etl_draft.sql`, `queries_draft.sql`, `er_diagram.md`). The SQL drafts were syntax-checked but never run on a real MySQL.
- `docs/research/game_design.md`: the full design and sim rules. Where it disagrees with the 2026-10-12 project docs (title, alternate roles, exact 5+5 draft), the project docs win.
- `data/`: OpenDota pro matches 2012–2026 (226,846 matches, 2.27M player rows, gzipped CSV), wiki hero mechanics, dotaconstants, and `processed/` pre-fills. `data/README.md` explains every file. Liquipedia placements aren't pulled yet; use the fallback files in `data/processed/` and never run `pull_liquipedia.py` yourself.

**Rules:**
- I make the design decisions. Implement what the docs say; where something is open, use the documented default, put it in config, and tell me. Don't invent mechanics.
- Plain PDO with prepared statements, no ORM or framework. The database enforces integrity (keys, UNIQUE, CHECK, transactions with `SELECT … FOR UPDATE`), not just PHP.
- Every random choice comes from a stored seed, so a refresh never rerolls anything.
- Card and roster names carry no years; years and orgs go in a description field.
- Don't edit `data/raw/`. Commit when a piece works; don't push unless I ask.
- If MySQL turns out to be MariaDB, stop and tell me.

Read `docs/project/README.md` and the docs relevant to the task before writing code. Then wait for my task, or if I've given one below, start on it.
