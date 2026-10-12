# Project pack: A Dice-Based Tournament Roguelike Deck Builder (CSE311)

_2026-10-11. Everything short of writing the game. Research history lives in [../research/](../research/); the settled design is [game_design.md](../research/game_design.md). Files here are drafts for Sadman's review._

## Read in this order
1. [proposal.md](proposal.md): the project proposal, ready to adapt for submission.
2. [game_outline.md](game_outline.md): the full game: run flow, 12 screens with their database reads and writes, every rule and formula.
3. [audit.md](audit.md): full audit: design consistency across all docs and memory, the data pull and what it shows, feasibility, risks, licences.
4. [open_questions.md](open_questions.md): 27 open points, each with a recommended default already used in the drafts.
5. [dbms_coursework_map.md](dbms_coursework_map.md): NSU's 8 official CSE311 objectives and course topics mapped to features, plus report and demo outline.
6. [schema/](schema/): MySQL 8 drafts: [schema_draft.sql](schema/schema_draft.sql) (42 tables, views, a procedure), [er_diagram.md](schema/er_diagram.md), [etl_draft.sql](schema/etl_draft.sql) (load + derive cards, ratings, chemistry, matchups), [queries_draft.sql](schema/queries_draft.sql).
7. [build_plan.md](build_plan.md): milestones, a two-person split, rating smell tests, testing checklist.

## Data
[../../data/README.md](../../data/README.md): what was pulled, from where, when, row counts and sizes, and how to re-run it.

## Building
[claude_code_build_prompt.md](claude_code_build_prompt.md): the prompt to give Claude Code at the project root so it builds the game milestone by milestone.
[claude_code_context_prompt.md](claude_code_context_prompt.md): a short version with just the project context, for starting any Claude Code session.
